-- ==============================================================================
-- SAFEMATE MIGRATION 005: CONNECTION REQUESTS & REALTIME COMMUNICATION (PHASE 8)
-- Universal Engineering Rule #6: Strict domain boundaries, privacy-safe identity
-- Universal Engineering Rule #7: Strict RLS and zero-trust client architecture
-- Universal Engineering Rule #11: Deterministic state machines & safe transitions
-- ==============================================================================

-- 1. Harmonize public.connections schema
ALTER TABLE public.connections
    ADD COLUMN IF NOT EXISTS requester_trip_id UUID REFERENCES public.trips(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS recipient_trip_id UUID REFERENCES public.trips(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS responded_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS client_request_id TEXT;

-- Update status constraint to include explicit Phase 8 state machine values
ALTER TABLE public.connections DROP CONSTRAINT IF EXISTS connections_status_check;
ALTER TABLE public.connections
    ADD CONSTRAINT connections_status_check
    CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled', 'blocked', 'requested', 'rejected'));

-- Populate requester_trip_id from existing trip_id where not set
UPDATE public.connections
SET requester_trip_id = trip_id
WHERE requester_trip_id IS NULL AND trip_id IS NOT NULL;

-- Indexes for connection queries and duplicate active request prevention
CREATE UNIQUE INDEX IF NOT EXISTS idx_connections_active_pair
    ON public.connections (requester_id, receiver_id)
    WHERE status IN ('pending', 'requested');

CREATE INDEX IF NOT EXISTS idx_connections_requester_status
    ON public.connections (requester_id, status);

CREATE INDEX IF NOT EXISTS idx_connections_receiver_status
    ON public.connections (receiver_id, status);

CREATE INDEX IF NOT EXISTS idx_connections_receiver_created
    ON public.connections (receiver_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_connections_requester_created
    ON public.connections (requester_id, created_at DESC);


-- 2. Harmonize public.chat_rooms schema
ALTER TABLE public.chat_rooms
    ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';

ALTER TABLE public.chat_rooms DROP CONSTRAINT IF EXISTS chat_rooms_status_check;
ALTER TABLE public.chat_rooms
    ADD CONSTRAINT chat_rooms_status_check
    CHECK (status IN ('active', 'archived', 'restricted'));

-- Ensure only one 1:1 room per connection
CREATE UNIQUE INDEX IF NOT EXISTS idx_chat_rooms_connection_unique
    ON public.chat_rooms (connection_id)
    WHERE connection_id IS NOT NULL;


-- 3. Harmonize public.messages schema
ALTER TABLE public.messages
    ADD COLUMN IF NOT EXISTS client_message_id TEXT,
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Support Phase 8 delivery states
ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_status_check;
ALTER TABLE public.messages
    ADD CONSTRAINT messages_status_check
    CHECK (status IN ('pending', 'sent', 'delivered', 'read', 'failed'));

-- Message length constraint
ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_content_check;
ALTER TABLE public.messages
    ADD CONSTRAINT messages_content_check
    CHECK (char_length(content) > 0 AND char_length(content) <= 4000);

-- Idempotency index: prevent duplicate sends for the same client_message_id within a room
CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_room_client_id
    ON public.messages (room_id, client_message_id)
    WHERE client_message_id IS NOT NULL;

-- Index for efficient reverse cursor pagination
CREATE INDEX IF NOT EXISTS idx_messages_room_created
    ON public.messages (room_id, created_at DESC);


-- ==============================================================================
-- 4. ATOMIC DATABASE RPCS (STATE MACHINE OPERATIONS)
-- ==============================================================================

-- RPC 1: Accept Connection Request & Provision Chat Room Atomically
CREATE OR REPLACE FUNCTION public.accept_connection_request(p_request_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_conn RECORD;
    v_room_id UUID;
    v_auth_uid UUID := auth.uid();
BEGIN
    IF v_auth_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    -- Fetch and lock request row for atomic update
    SELECT * INTO v_conn
    FROM public.connections
    WHERE id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Connection request not found' USING ERRCODE = 'P0002';
    END IF;

    -- Validate authorization: only the designated receiver can accept
    IF v_conn.receiver_id != v_auth_uid THEN
        RAISE EXCEPTION 'Unauthorized: only recipient can accept connection request' USING ERRCODE = '42501';
    END IF;

    -- Validate status transition
    IF v_conn.status NOT IN ('pending', 'requested') THEN
        RAISE EXCEPTION 'Cannot accept connection request with status %', v_conn.status USING ERRCODE = '22023';
    END IF;

    -- Check if either user has blocked the other
    IF public.is_blocked(v_conn.requester_id, v_conn.receiver_id) THEN
        RAISE EXCEPTION 'Cannot accept request: user is blocked' USING ERRCODE = '22023';
    END IF;

    -- Update connection status
    UPDATE public.connections
    SET status = 'accepted',
        accepted_at = timezone('utc'::text, now()),
        responded_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_request_id;

    -- Provision or reuse 1:1 chat room for this connection
    SELECT id INTO v_room_id
    FROM public.chat_rooms
    WHERE connection_id = p_request_id;

    IF v_room_id IS NULL THEN
        INSERT INTO public.chat_rooms (connection_id, room_type, status, last_message_at)
        VALUES (p_request_id, 'direct', 'active', timezone('utc'::text, now()))
        RETURNING id INTO v_room_id;
    END IF;

    -- Ensure chat members exist for both participants
    INSERT INTO public.chat_members (room_id, user_id, role, is_active)
    VALUES 
        (v_room_id, v_conn.requester_id, 'member', TRUE),
        (v_room_id, v_conn.receiver_id, 'member', TRUE)
    ON CONFLICT (room_id, user_id) 
    DO UPDATE SET is_active = TRUE, last_read_at = timezone('utc'::text, now());

    RETURN jsonb_build_object(
        'success', true,
        'connection_id', p_request_id,
        'room_id', v_room_id,
        'status', 'accepted'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- RPC 2: Decline Connection Request Atomically
CREATE OR REPLACE FUNCTION public.decline_connection_request(p_request_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_conn RECORD;
    v_auth_uid UUID := auth.uid();
BEGIN
    IF v_auth_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_conn
    FROM public.connections
    WHERE id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Connection request not found' USING ERRCODE = 'P0002';
    END IF;

    IF v_conn.receiver_id != v_auth_uid THEN
        RAISE EXCEPTION 'Unauthorized: only recipient can decline request' USING ERRCODE = '42501';
    END IF;

    IF v_conn.status NOT IN ('pending', 'requested') THEN
        RAISE EXCEPTION 'Cannot decline request with status %', v_conn.status USING ERRCODE = '22023';
    END IF;

    UPDATE public.connections
    SET status = 'declined',
        responded_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_request_id;

    RETURN jsonb_build_object(
        'success', true,
        'connection_id', p_request_id,
        'status', 'declined'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- RPC 3: Cancel Connection Request Atomically
CREATE OR REPLACE FUNCTION public.cancel_connection_request(p_request_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_conn RECORD;
    v_auth_uid UUID := auth.uid();
BEGIN
    IF v_auth_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_conn
    FROM public.connections
    WHERE id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Connection request not found' USING ERRCODE = 'P0002';
    END IF;

    IF v_conn.requester_id != v_auth_uid THEN
        RAISE EXCEPTION 'Unauthorized: only requester can cancel request' USING ERRCODE = '42501';
    END IF;

    IF v_conn.status NOT IN ('pending', 'requested') THEN
        RAISE EXCEPTION 'Cannot cancel request with status %', v_conn.status USING ERRCODE = '22023';
    END IF;

    UPDATE public.connections
    SET status = 'cancelled',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_request_id;

    RETURN jsonb_build_object(
        'success', true,
        'connection_id', p_request_id,
        'status', 'cancelled'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- RPC 4: Send Chat Message Atomically with Authorization & Idempotency
CREATE OR REPLACE FUNCTION public.send_chat_message(
    p_room_id UUID,
    p_content TEXT,
    p_client_message_id TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_auth_uid UUID := auth.uid();
    v_member_active BOOLEAN;
    v_other_member_id UUID;
    v_existing_msg RECORD;
    v_new_msg RECORD;
BEGIN
    IF v_auth_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    -- Validate membership
    SELECT is_active INTO v_member_active
    FROM public.chat_members
    WHERE room_id = p_room_id AND user_id = v_auth_uid;

    IF v_member_active IS NULL OR v_member_active = FALSE THEN
        RAISE EXCEPTION 'User is not an active member of this chat room' USING ERRCODE = '42501';
    END IF;

    -- Validate recipient is not blocked
    SELECT user_id INTO v_other_member_id
    FROM public.chat_members
    WHERE room_id = p_room_id AND user_id != v_auth_uid
    LIMIT 1;

    IF v_other_member_id IS NOT NULL AND public.is_blocked(v_auth_uid, v_other_member_id) THEN
        RAISE EXCEPTION 'Cannot send message: user is blocked' USING ERRCODE = '22023';
    END IF;

    -- Check for duplicate client_message_id idempotency
    IF p_client_message_id IS NOT NULL THEN
        SELECT * INTO v_existing_msg
        FROM public.messages
        WHERE room_id = p_room_id AND client_message_id = p_client_message_id;

        IF FOUND THEN
            RETURN to_jsonb(v_existing_msg);
        END IF;
    END IF;

    -- Insert new message
    INSERT INTO public.messages (
        room_id,
        sender_id,
        content,
        client_message_id,
        status,
        message_type
    ) VALUES (
        p_room_id,
        v_auth_uid,
        p_content,
        p_client_message_id,
        'sent',
        'text'
    )
    RETURNING * INTO v_new_msg;

    -- Update chat room last_message_at
    UPDATE public.chat_rooms
    SET last_message_at = v_new_msg.created_at,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_room_id;

    RETURN to_jsonb(v_new_msg);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- RPC 5: Mark Room As Read
CREATE OR REPLACE FUNCTION public.mark_chat_room_read(p_room_id UUID)
RETURNS VOID AS $$
DECLARE
    v_auth_uid UUID := auth.uid();
BEGIN
    IF v_auth_uid IS NULL THEN
        RETURN;
    END IF;

    UPDATE public.chat_members
    SET last_read_at = timezone('utc'::text, now())
    WHERE room_id = p_room_id AND user_id = v_auth_uid;

    -- Optionally mark incoming messages in this room as read
    UPDATE public.messages
    SET status = 'read'
    WHERE room_id = p_room_id
      AND sender_id != v_auth_uid
      AND status IN ('sent', 'delivered');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
