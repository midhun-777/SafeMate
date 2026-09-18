/// SafeMate Secure One-to-One Realtime Chat Screen.
/// Universal Engineering Rule #6: Strict domain boundaries, privacy-safe identity.
/// Universal Engineering Rule #10: Privacy-first analytics. Never logs message bodies.
/// Universal Engineering Rule #11: Offline resilience, deduplication, deterministic state.
/// Universal Engineering Rule #13: Calm, trustworthy, travel-oriented design.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../safety/domain/services/ai_safety_rule_engine.dart';
import '../../../safety/presentation/widgets/ai_safety_advisory_banner.dart';
import '../../../safety/presentation/widgets/companion_review_dialog.dart';
import '../../domain/models/chat_models.dart';
import '../controllers/chat_room_controller.dart';
import '../controllers/connection_controllers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String? companionName;
  final String? destination;

  const ChatScreen({
    super.key,
    required this.roomId,
    this.companionName,
    this.destination,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showSafetyNotice = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatRoomControllerProvider(widget.roomId).notifier).loadOlderMessages();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    ref.read(chatRoomControllerProvider(widget.roomId).notifier).sendMessage(text);
    _textController.clear();
  }

  void _handleStarterTapped(String starter) {
    _textController.text = starter;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
  }

  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block Traveler?'),
        content: Text(
          'Are you sure you want to block ${widget.companionName ?? "this traveler"}? '
          'They will not be able to message you, view your upcoming journeys, or send connection requests.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final authState = ref.read(authControllerProvider);
              final userId = authState.profile?.id ?? authState.session?.userId;
              final repo = ref.read(connectionRepositoryProvider);
              final analytics = ref.read(analyticsServiceProvider);

              if (userId != null) {
                await repo.blockConnection(
                  blockerId: userId,
                  blockedId: widget.roomId,
                );
              }
              await analytics.logEvent('chat_blocked', parameters: {'room_id': widget.roomId});

              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Traveler blocked. Communication has ended.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _showAiCoordinationDialog(BuildContext context) {
    final dest = widget.destination ?? 'our journey';
    final suggestedMessage =
        'Hi! Looking forward to our trip to $dest. Shall we meet at the main station entrance when we arrive?';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, size: 20, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Copilot Coordination', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'AI Suggestion — Review before sending',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Suggested Meeting Points:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('• Main passenger arrival concourse at $dest', style: const TextStyle(fontSize: 12)),
            const Text('• Well-lit public coffee shop near central terminal', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            const Text('Suggested Message:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                suggestedMessage,
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.edit, size: 14),
            label: const Text('Insert & Edit'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleStarterTapped(suggestedMessage);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(chatRoomControllerProvider(widget.roomId));
    final controller = ref.read(chatRoomControllerProvider(widget.roomId).notifier);
    final authState = ref.watch(authControllerProvider);
    final currentUserId = authState.profile?.id ?? authState.session?.userId ?? '';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.companionName ?? 'Travel Companion',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (widget.destination != null) ...[
              Text(
                'Journey to ${widget.destination}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'safety_check') {
                context.push('/trips/active/safety-check');
              } else if (val == 'ai_coordination') {
                _showAiCoordinationDialog(context);
              } else if (val == 'review') {
                final authState = ref.read(authControllerProvider);
                final myId = authState.profile?.id ?? authState.session?.userId ?? '';
                CompanionReviewDialog.show(
                  context,
                  tripId: widget.roomId,
                  reviewerId: myId,
                  revieweeId: widget.roomId,
                  revieweeName: widget.companionName ?? 'Companion',
                );
              } else if (val == 'report') {
                context.push(
                  '/safety/report?userId=${widget.roomId}&name=${Uri.encodeComponent(widget.companionName ?? "Companion")}&contextType=chat&contextId=${widget.roomId}',
                );
              } else if (val == 'block') {
                _showBlockDialog(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'ai_coordination',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Copilot Coordination'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'safety_check',
                child: Row(
                  children: [
                    Icon(Icons.checklist_rtl, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Safety & Meetup Code'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'review',
                child: Row(
                  children: [
                    Icon(Icons.rate_review_outlined, size: 18, color: AppColors.secondary),
                    SizedBox(width: 8),
                    Text('Review Companion'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 18, color: AppColors.secondary),
                    SizedBox(width: 8),
                    Text('Report Traveler'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block_outlined, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Block Traveler', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Safety Reminder Banner
            if (_showSafetyNotice) _buildSafetyBanner(isDark),

            // 2. Chat message list or Empty state
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.messages.isEmpty
                      ? _buildEmptyState(isDark)
                      : _buildMessageList(state, currentUserId, controller, isDark),
            ),

            // 3. Ephemeral Typing Indicator
            if (state.typingUserId != null) _buildTypingIndicator(isDark),

            // 4. AI Safety Advisory (detected risks in conversation)
            () {
              SafetyWarning? warning;
              for (final m in state.messages.reversed) {
                final w = AiSafetyRuleEngine.analyzeMessage(m.content);
                if (w != null) {
                  warning = w;
                  break;
                }
              }
              if (warning != null) {
                return AiSafetyAdvisoryBanner(
                  warning: warning,
                  onApplySuggestion: _handleStarterTapped,
                );
              }
              return const SizedBox.shrink();
            }(),

            // 5. Message Composer
            _buildComposer(controller, state.isSending, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.security, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Never share passwords, OTPs, financial details, or sensitive IDs with someone you just met.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _showSafetyNotice = false),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final starters = [
      "What's your planned departure time?",
      "Have you finalized your itinerary?",
      "Which part of the journey are you most looking forward to?",
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.handshake_outlined, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              "You're connected!",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Start by introducing yourself and coordinating journey logistics.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Conversation starters:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...starters.map(
              (starter) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: InkWell(
                  onTap: () => _handleStarterTapped(starter),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            starter,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(
    ChatRoomState state,
    String currentUserId,
    ChatRoomController controller,
    bool isDark,
  ) {
    final reversed = state.messages.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: reversed.length + (state.isLoadingOlder ? 1 : 0),
      itemBuilder: (context, index) {
        if (state.isLoadingOlder && index == reversed.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final msg = reversed[index];
        final isMe = msg.senderId == currentUserId;
        return _buildMessageBubble(msg, isMe, controller, isDark);
      },
    );
  }

  Widget _buildMessageBubble(
    ChatMessage msg,
    bool isMe,
    ChatRoomController controller,
    bool isDark,
  ) {
    final timeStr = DateFormat('h:mm a').format(msg.createdAt.toLocal());

    return Semantics(
      label: '${isMe ? "You said" : "Companion said"}: ${msg.content}, at $timeStr',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  widget.companionName?.isNotEmpty == true
                      ? widget.companionName![0].toUpperCase()
                      : 'C',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppColors.primary
                      : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  border: isMe
                      ? null
                      : Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: isMe
                            ? Colors.white
                            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white70
                                : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          _buildDeliveryIcon(msg, controller),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryIcon(ChatMessage msg, ChatRoomController controller) {
    switch (msg.deliveryStatus) {
      case MessageDeliveryStatus.pending:
        return const Icon(Icons.access_time, size: 12, color: Colors.white70);
      case MessageDeliveryStatus.sent:
        return const Icon(Icons.check, size: 12, color: Colors.white70);
      case MessageDeliveryStatus.delivered:
        return const Icon(Icons.done_all, size: 12, color: Colors.white70);
      case MessageDeliveryStatus.read:
        return const Icon(Icons.done_all, size: 12, color: AppColors.secondary);
      case MessageDeliveryStatus.failed:
        return InkWell(
          onTap: () => controller.retryMessage(msg),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 12, color: Colors.yellowAccent),
              SizedBox(width: 2),
              Text(
                'Retry',
                style: TextStyle(fontSize: 10, color: Colors.yellowAccent),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '${widget.companionName ?? "Companion"} is typing...',
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(
    ChatRoomController controller,
    bool isSending,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('chat_composer_input'),
              controller: _textController,
              maxLines: 4,
              minLines: 1,
              maxLength: 4000,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              onChanged: (_) => controller.sendTyping(),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: const Key('chat_send_button'),
            icon: isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send, color: AppColors.primary),
            onPressed: isSending ? null : _handleSend,
          ),
        ],
      ),
    );
  }
}
