/// SafeMate Deterministic Reconciliation Engine.
/// Universal Engineering Rule #6: Strict schema validation and sanitized domain models.
/// Universal Engineering Rule #7: Client never overrides server authority.
/// Universal Engineering Rule #11: Deterministic three-way field reconciliation.
/// Universal Engineering Rule #18: Server is authoritative on conflict; no wall-clock LWW.
library;

import 'conflict_resolution_policy.dart';
import 'deterministic_conflict_detector.dart';

/// Pure, deterministic three-way reconciliation coordinator.
/// Executes entity-specific policies registered in [ConflictResolutionPolicyRegistry].
class DeterministicReconciler {
  final ConflictResolutionPolicyRegistry policyRegistry;

  DeterministicReconciler({ConflictResolutionPolicyRegistry? registry})
      : policyRegistry = registry ?? ConflictResolutionPolicyRegistry.instance;

  static final DeterministicReconciler instance = DeterministicReconciler();

  /// Reconciles a detected concurrency divergence using the registered entity policy.
  ReconciliationResult reconcile({
    required String entityType,
    required String entityId,
    required String userId,
    int? baseVersion,
    int? serverVersion,
    Map<String, dynamic>? baseState,
    Map<String, dynamic>? localState,
    Map<String, dynamic>? serverState,
    bool isServerDeleted = false,
    bool isLocalDeleted = false,
  }) {
    // 1. Compute 3-way differences across BASE, LOCAL, and SERVER
    final threeWay = DeterministicConflictDetector.compareThreeWay(
      baseState,
      localState,
      serverState,
      entityType: entityType,
    );

    // 2. Fetch the entity-specific policy
    final policy = policyRegistry.getPolicy(entityType);

    // 3. Assemble execution context
    final context = ReconciliationContext(
      entityType: entityType,
      entityId: entityId,
      userId: userId,
      baseVersion: baseVersion,
      serverVersion: serverVersion,
      baseState: baseState,
      localState: localState,
      serverState: serverState,
      threeWay: threeWay,
      isServerDeleted: isServerDeleted,
      isLocalDeleted: isLocalDeleted,
    );

    // 4. Delegate to deterministic policy
    return policy.reconcile(context);
  }

  /// Convenience helper to reconcile directly from a [ConflictDetectionInput].
  ReconciliationResult reconcileInput(ConflictDetectionInput input) {
    return reconcile(
      entityType: input.entityType,
      entityId: input.entityId,
      userId: input.userId,
      baseVersion: input.localBaseVersion,
      serverVersion: input.serverVersion,
      baseState: input.baseState,
      localState: input.localState,
      serverState: input.serverState,
      isServerDeleted: input.isServerDeleted,
      isLocalDeleted: input.isLocalDeleted || input.operation == EntityOperation.delete,
    );
  }
}
