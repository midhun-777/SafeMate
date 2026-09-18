# SafeMate AI Architecture & Journey Intelligence Specification

## 1. Primary Principles & Non-Negotiable Constitution

SafeMate is an **AI-powered real-time trusted travel companion network**, not a dating app and never a surveillance or covert tracking tool.

AI inside SafeMate functions strictly as an **Assistant**, never an **Authority**:
- AI cannot autonomously activate or deactivate SafeTrip.
- AI cannot alter emergency settings, privacy controls, or trusted contacts.
- AI cannot contact emergency services directly (no simulated 911 dispatch).
- AI cannot ban or suspend users or alter verification statuses.
- AI cannot modify match scores or trust scores.
- AI cannot mutate user trip records silently; all adaptations follow the **Review-and-Apply** pattern.

---

## 2. Target Architecture

```
                    ┌──────────────────────┐
                    │      SafeMate App    │
                    │       Flutter        │
                    └──────────┬───────────┘
                               │
                         AI Repository
                               │
                         AI Gateway
                               │
                    ┌──────────▼───────────┐
                    │  Context Builder     │
                    │ Auth + Privacy + RLS │
                    └──────────┬───────────┘
                               │
                    Secure Server / Edge
                               │
                    ┌──────────▼───────────┐
                    │    AI Provider       │
                    │   Gemini / approved  │
                    │      provider        │
                    └──────────┬───────────┘
                               │
                       Validated Output
                               │
                 ┌─────────────▼─────────────┐
                 │       User Review         │
                 │  "Review before applying" │
                 └─────────────┬─────────────┘
                               │
                         User confirms
                               │
                 ┌─────────────▼─────────────┐
                 │ Deterministic App Logic   │
                 │ + Server Authorization    │
                 └───────────────────────────┘
```

---

## 3. Privacy Boundary: Allowlist & Denylist

### Allowlist (`AI_DATA_ALLOWLIST`)
Only whitelisted, non-sensitive journey context is compiled into AI prompts:
- Destination (City / Region label)
- Approximate Origin (City label)
- Start Date and End Date (YYYY-MM-DD)
- Duration in calendar days
- Budget Tier (Budget, Moderate, Luxury, Flexible)
- Transport Mode (Flight, Train, Bus, Drive, Flexible)
- Trip Purpose (Vacation, Business, Relocation, Event)
- Trip Vibe / Styles (Culture, Nature, Food, etc.)
- SafeTrip Status (Non-sensitive status string)
- Approximate location active flag (boolean)
- Sanitized notes (PII stripped)

### Denylist (`AI_DATA_DENYLIST`)
The following fields are strictly prohibited from entering any AI prompt:
- Government ID / Aadhaar / Passport / Verification documents
- Personal phone numbers and email addresses
- Emergency contact names, phone numbers, or relationships
- Exact latitude/longitude GPS coordinates or raw street addresses
- Authentication tokens, session cookies, passwords, or secret keys
- Private moderation logs, internal risk scores, or confidential reports

---

## 4. Journey Copilot Experience & Contextual Chips

The Copilot is embedded into the journey flow (Trip Details, SafeTrip Active, and Journey Room), avoiding empty generic chat boxes:
1. **PLAN**: Generates day-by-day suggested itineraries with clear activity schedules.
2. **PREPARE**: Outlines packing, documentation, and pre-departure verification checklists.
3. **ADAPT**: Allows travelers to request pace, budget, or transit adjustments with an explicit `[Apply Plan]` or `[Keep Current Plan]` review card.
4. **SAFETY**: Explains SafeTrip check-ins, ~20km coarse location privacy, and links directly to the Safety Center for emergency dialer handoffs.
5. **COMPANION**: Suggests well-lit public transit meeting points and polite coordination message drafts.
6. **SUMMARY**: Provides high-level synthesis of journey parameters.

---

## 5. Travel Disruption Provider Abstraction

SafeMate does **not** fabricate or hallucinate real-time travel disruptions:
- `TravelDisruptionProvider` defines the abstract interface for verified external feeds (weather, transit, airport).
- `NoopTravelDisruptionProvider` serves as the fallback when live external feeds are not connected.
- The AI explicitly notifies travelers: *"Please verify operating hours and live transit schedules directly with local transport authorities."*

---

## 6. Prompt Injection Defense & Safety Filtering

- All user inputs are sanitized using `AiResponseValidator.sanitizePromptInput` to strip delimiter escapes (`<SYSTEM>`, `IGNORE PREVIOUS INSTRUCTIONS`, etc.).
- Post-generation filtering scans output for prohibited patterns (`SELECT * FROM`, `911 DISPATCHED`, `POLICE CONTACTED`, private key headers). Responses attempting policy violations are rejected with `AiErrorKind.policyViolation`.

---

## 7. Cost Controls, Rate Limiting & Observability

- **Rate Limiting**: Sliding window rate limiter enforcing a maximum of 10 AI queries per 5-minute window per client session (`AiRateLimiter`).
- **Token Budget**: Maximum output token budget capped at 1024 tokens.
- **Privacy-Safe Telemetry**: Analytics events record operations (`ai_request_started`, `ai_request_completed`, `ai_request_failed`, `ai_proposal_applied`) while strictly forbidding prompt content, response text, or PII.
