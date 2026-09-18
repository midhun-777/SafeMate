/// SafeMate Database Exceptions.
/// Universal Engineering Rule #6: Never expose raw database internals or secrets in error messages.
library;

/// Base exception for all local SQLite operations.
abstract class SafeMateDatabaseException implements Exception {
  final String message;
  final Object? cause;

  const SafeMateDatabaseException(this.message, [this.cause]);

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when local database fails to open, configure, or initialize.
class DatabaseInitializationException extends SafeMateDatabaseException {
  const DatabaseInitializationException(super.message, [super.cause]);
}

/// Thrown when a database migration fails to execute cleanly.
class DatabaseMigrationException extends SafeMateDatabaseException {
  final int fromVersion;
  final int toVersion;

  const DatabaseMigrationException(
    super.message, [
    super.cause,
    this.fromVersion = 0,
    this.toVersion = 0,
  ]);

  @override
  String toString() =>
      'DatabaseMigrationException(v$fromVersion -> v$toVersion): $message';
}

/// Thrown when a unique constraint or foreign key constraint is violated.
class DatabaseConstraintException extends SafeMateDatabaseException {
  final String? constraintName;

  const DatabaseConstraintException(
    super.message, [
    super.cause,
    this.constraintName,
  ]);
}

/// Thrown when a database query or read operation fails.
class DatabaseReadException extends SafeMateDatabaseException {
  const DatabaseReadException(super.message, [super.cause]);
}

/// Thrown when an insert, update, or transaction write operation fails.
class DatabaseWriteException extends SafeMateDatabaseException {
  const DatabaseWriteException(super.message, [super.cause]);
}

/// Thrown when a write or query violates LocalDataPolicy (Category C or unallowed field).
class DatabasePolicyViolationException extends SafeMateDatabaseException
    implements ArgumentError {
  final String? tableName;
  final String? fieldName;

  const DatabasePolicyViolationException(
    super.message, [
    super.cause,
    this.tableName,
    this.fieldName,
  ]);

  @override
  dynamic get invalidValue => null;

  @override
  String? get name => fieldName;

  @override
  StackTrace? get stackTrace => null;

  @override
  String toString() =>
      'DatabasePolicyViolationException${tableName != null ? ' (table: $tableName)' : ''}: $message';
}

/// Thrown when an operation attempts to read, write, update, or delete across user boundaries.
class DatabaseUserScopeException extends SafeMateDatabaseException {
  final String currentScope;
  final String attemptedScope;

  const DatabaseUserScopeException(
    super.message, [
    super.cause,
    this.currentScope = '',
    this.attemptedScope = '',
  ]);

  @override
  String toString() =>
      'DatabaseUserScopeException (active: "$currentScope", attempted: "$attemptedScope"): $message';
}

/// Thrown when device storage is exhausted or database disk write encounters ENOSPC/full disk.
class DatabaseLowStorageException extends SafeMateDatabaseException {
  final int? availableBytes;

  const DatabaseLowStorageException(
    super.message, [
    super.cause,
    this.availableBytes,
  ]);

  @override
  String toString() =>
      'DatabaseLowStorageException${availableBytes != null ? ' ($availableBytes bytes free)' : ''}: $message';
}
