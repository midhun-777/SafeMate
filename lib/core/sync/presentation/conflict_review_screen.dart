/// SafeMate Interactive Conflict Review Screen.
/// Universal Engineering Rule #6: Clear, non-technical traveler UX.
/// Universal Engineering Rule #7: Server authority strictly limits client choices.
/// Universal Engineering Rule #18: Server is authoritative on security/safety fields.
library;

import 'package:flutter/material.dart';
import '../conflict_resolution_controller.dart';
import '../conflict_resolution_policy.dart';

/// Screen allowing travelers to inspect field diffs and resolve collisions.
class ConflictReviewScreen extends StatefulWidget {
  final List<ConflictPresentationModel> conflicts;
  final String userId;
  final ConflictResolutionController controller;
  final VoidCallback? onAllResolved;

  const ConflictReviewScreen({
    super.key,
    required this.conflicts,
    required this.userId,
    required this.controller,
    this.onAllResolved,
  });

  @override
  State<ConflictReviewScreen> createState() => _ConflictReviewScreenState();
}

class _ConflictReviewScreenState extends State<ConflictReviewScreen> {
  late List<ConflictPresentationModel> _activeConflicts;
  final Set<String> _resolvingConflictIds = {};

  @override
  void initState() {
    super.initState();
    _activeConflicts = List.from(widget.conflicts);
  }

  Future<void> _handleAction(
    ConflictPresentationModel model,
    UserResolutionAction action,
  ) async {
    final conflict = model.conflict;
    if (conflict == null) return;

    setState(() {
      _resolvingConflictIds.add(model.conflictId);
    });

    try {
      await widget.controller.applyResolution(
        conflict: conflict,
        action: action,
        userId: widget.userId,
        expectedServerVersion: model.serverVersion,
      );

      setState(() {
        _activeConflicts.removeWhere((c) => c.conflictId == model.conflictId);
        _resolvingConflictIds.remove(model.conflictId);
      });

      if (_activeConflicts.isEmpty) {
        widget.onAllResolved?.call();
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context, true);
        }
      }
    } on StaleConflictVersionException catch (e) {
      if (mounted) {
        setState(() {
          _resolvingConflictIds.remove(model.conflictId);
        });
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Server Version Changed'),
            content: Text(
              'The server version has been updated (now v${e.serverVersion}) while you were reviewing. '
              'The conflict review will reload with the latest server state.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (Navigator.canPop(context)) Navigator.pop(context, true);
                },
                child: const Text('Reload'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _resolvingConflictIds.remove(model.conflictId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply resolution: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resolve Sync Differences'),
        elevation: 0,
      ),
      body: _activeConflicts.isEmpty
          ? _buildEmptyState(theme)
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _activeConflicts.length,
              itemBuilder: (context, index) {
                final model = _activeConflicts[index];
                return _buildConflictCard(context, theme, model);
              },
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade600),
            const SizedBox(height: 16),
            Text(
              'All Caught Up!',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your data is fully aligned with the latest verified version.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictCard(
    BuildContext context,
    ThemeData theme,
    ConflictPresentationModel model,
  ) {
    final isResolving = _resolvingConflictIds.contains(model.conflictId);
    final policy = ConflictResolutionPolicyRegistry.instance.getPolicy(model.entityType);
    final canKeepLocal = !model.isServerDeleted &&
        model.availableActions.contains(UserResolutionAction.keepLocal);

    return Semantics(
      container: true,
      label: 'Sync difference in ${model.entityType}: ${model.userMessage}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Entity Type Badge + Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      model.entityType.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  if (model.isServerDeleted) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline, size: 14, color: theme.colorScheme.onErrorContainer),
                          const SizedBox(width: 4),
                          Text(
                            'Server Deleted',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (isResolving)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                model.userMessage,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                model.details,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // Diff Table / List of Conflicting Fields
              if (model.conflictingFields.isNotEmpty) ...[
                Text(
                  'Differences Detected',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: model.conflictingFields.map((field) {
                      final isAuthoritative = policy.serverAuthoritativeFields.contains(field);
                      final localVal = model.localValues[field];
                      final serverVal = model.serverValues[field];

                      return Semantics(
                        label: '$field: offline value ${localVal ?? 'offline change'}, '
                            'latest server ${serverVal ?? 'latest server'}. '
                            '${isAuthoritative ? 'Server authoritative field: cannot be overridden locally.' : ''}',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      field.replaceAll('_', ' '),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (isAuthoritative)
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.shield_outlined, size: 10, color: Colors.blue.shade900),
                                            const SizedBox(width: 3),
                                            Text(
                                              'Server Authority',
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: Colors.blue.shade900,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  localVal != null ? '$localVal' : '(offline change)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  serverVal != null ? '$serverVal' : '(latest server)',
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (canKeepLocal) ...[
                    Semantics(
                      button: true,
                      label: 'Keep my changes for ${model.entityType}',
                      child: OutlinedButton(
                        onPressed: isResolving
                            ? null
                            : () => _handleAction(model, UserResolutionAction.keepLocal),
                        child: const Text('Keep My Changes'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Semantics(
                    button: true,
                    label: model.isInformationOnly
                        ? 'Dismiss conflict notification for ${model.entityType}'
                        : 'Use latest version for ${model.entityType}',
                    child: FilledButton(
                      onPressed: isResolving
                          ? null
                          : () => _handleAction(model, UserResolutionAction.acceptServer),
                      child: Text(model.isInformationOnly ? 'Dismiss' : 'Use Latest Version'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
