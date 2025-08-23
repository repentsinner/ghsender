import 'package:equatable/equatable.dart';

/// Types of safety violations that can occur during machine operations
enum ViolationType {
  workEnvelopeExceeded,
  machineAlarmed,
  machineMoving,
  feedRateExceeded,
  accelerationExceeded,
  toolCollision,
  programValidation,
  systemError,
}

/// Result of a domain validation operation
/// 
/// Provides structured success/failure results with detailed error information
/// and violation types for proper error handling and user feedback.
class ValidationResult extends Equatable {
  final bool isValid;
  final String? error;
  final ViolationType? violationType;

  const ValidationResult._({
    required this.isValid,
    this.error,
    this.violationType,
  });

  /// Create a successful validation result
  const ValidationResult.success() : this._(isValid: true);

  /// Create a failed validation result with error details
  const ValidationResult.failure(String error, ViolationType violationType)
      : this._(
          isValid: false,
          error: error,
          violationType: violationType,
        );

  @override
  List<Object?> get props => [isValid, error, violationType];

  @override
  String toString() {
    if (isValid) return 'ValidationResult.success()';
    return 'ValidationResult.failure($error, $violationType)';
  }
}