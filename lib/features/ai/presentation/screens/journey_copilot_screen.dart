/// SafeMate Journey Copilot Screen.
/// Universal Engineering Rule #11: Calm, intelligent travel assistant; non-alarmist, zero autonomous mutations.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safemate/core/constants/app_colors.dart';
import '../controllers/journey_copilot_controller.dart';
import '../widgets/ai_suggestion_chip.dart';
import '../widgets/itinerary_proposal_card.dart';

class JourneyCopilotScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String? destination;

  const JourneyCopilotScreen({
    super.key,
    required this.tripId,
    this.destination,
  });

  @override
  ConsumerState<JourneyCopilotScreen> createState() => _JourneyCopilotScreenState();
}

class _JourneyCopilotScreenState extends ConsumerState<JourneyCopilotScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();

    await ref
        .read(journeyCopilotControllerProvider(widget.tripId).notifier)
        .sendQuery(text);

    _scrollToBottom();
  }

  Future<void> _handleApplyProposal() async {
    final success = await ref
        .read(journeyCopilotControllerProvider(widget.tripId).notifier)
        .applyActiveProposal();

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Suggested itinerary added to trip details!'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  void _handleDismissProposal() {
    ref
        .read(journeyCopilotControllerProvider(widget.tripId).notifier)
        .dismissActiveProposal();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(journeyCopilotControllerProvider(widget.tripId));
    final controller = ref.read(journeyCopilotControllerProvider(widget.tripId).notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Journey Copilot',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (widget.destination != null)
              Text(
                widget.destination!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About AI Copilot',
            onPressed: () => _showAboutDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Suggestion chips header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.grey[100],
                border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    AiSuggestionChip(
                      icon: Icons.map,
                      label: 'PLAN',
                      onTap: () {
                        controller.requestItinerary();
                        _scrollToBottom();
                      },
                    ),
                    const SizedBox(width: 8),
                    AiSuggestionChip(
                      icon: Icons.checklist,
                      label: 'PREPARE',
                      onTap: () {
                        controller.sendQuery('What preparation and packing checklist do you recommend for this journey?');
                        _scrollToBottom();
                      },
                    ),
                    const SizedBox(width: 8),
                    AiSuggestionChip(
                      icon: Icons.tune,
                      label: 'ADAPT',
                      onTap: () {
                        _showAdaptDialog(context, controller);
                      },
                    ),
                    const SizedBox(width: 8),
                    AiSuggestionChip(
                      icon: Icons.shield_outlined,
                      label: 'SAFETY',
                      onTap: () {
                        controller.requestSafetyGuidance();
                        _scrollToBottom();
                      },
                    ),
                    const SizedBox(width: 8),
                    AiSuggestionChip(
                      icon: Icons.people_outline,
                      label: 'COMPANION',
                      onTap: () {
                        controller.requestCompanionCoordination();
                        _scrollToBottom();
                      },
                    ),
                    const SizedBox(width: 8),
                    AiSuggestionChip(
                      icon: Icons.summarize_outlined,
                      label: 'SUMMARY',
                      onTap: () {
                        controller.sendQuery('Summarize my journey details, dates, and companion goals.');
                        _scrollToBottom();
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Error banner if any
            if (state.errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                color: Colors.red.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            // Messages chat list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: state.messages.length,
                itemBuilder: (context, index) {
                  final msg = state.messages[index];

                  if (msg.isProposal && msg.structuredData != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMessageBubble(msg, isDark),
                        ItineraryProposalCard(
                          proposal: msg.structuredData!,
                          onApply: _handleApplyProposal,
                          onDismiss: _handleDismissProposal,
                        ),
                      ],
                    );
                  }

                  return _buildMessageBubble(msg, isDark);
                },
              ),
            ),

            // Loading indicator
            if (state.isLoading)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Journey Copilot is thinking...',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

            // Input bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        hintText: 'Ask about itinerary, safety, or planning...',
                        hintStyle: TextStyle(fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                    onPressed: state.isLoading ? null : _handleSend,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(CopilotMessage msg, bool isDark) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: msg.isUser
              ? AppColors.primary
              : (isDark ? AppColors.surfaceVariantDark : Colors.grey[200]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            fontSize: 13,
            color: msg.isUser
                ? Colors.white
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }

  void _showAdaptDialog(BuildContext context, JourneyCopilotController controller) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adapt My Journey Plan', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tell the copilot how you would like to adjust this trip:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                hintText: 'e.g., Make it more relaxed, optimize for public transit, lower budget...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = textController.text.trim();
              Navigator.pop(ctx);
              if (val.isNotEmpty) {
                controller.requestAdaptivePlan(val);
                _scrollToBottom();
              }
            },
            child: const Text('Propose Plan'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About Journey Copilot', style: TextStyle(fontSize: 16)),
        content: const Text(
          'SafeMate Journey Copilot provides guidance and contextual planning assistance.\n\n'
          '• AI suggestions are strictly advisory and never mutate your trip without your confirmation.\n'
          '• Sensitive identity credentials and exact GPS locations are never shared with AI.\n'
          '• For emergencies, always refer to the Safety Center.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }
}
