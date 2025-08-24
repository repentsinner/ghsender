import 'package:vector_math/vector_math.dart' as vm;
import '../entities/machine.dart';
import '../repositories/machine_repository.dart';
import '../value_objects/validation_result.dart';
import '../../models/machine_controller.dart'; // For MachineStatus

/// Request object for jog operations
class JogRequest {
  final vm.Vector3 targetPosition;
  final double feedRate;
  final String? reason; // Optional context for logging/debugging

  const JogRequest({
    required this.targetPosition,
    required this.feedRate,
    this.reason,
  });

  @override
  String toString() => 'JogRequest(target: $targetPosition, feedRate: $feedRate)';
}

/// Result object for jog operations
class JogResult {
  final bool success;
  final Machine? updatedMachine;
  final ValidationResult? validationResult;
  final String? errorMessage;
  final DateTime timestamp;

  JogResult({
    required this.success,
    this.updatedMachine,
    this.validationResult,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create successful jog result
  factory JogResult.success(Machine updatedMachine) {
    return JogResult(
      success: true,
      updatedMachine: updatedMachine,
      timestamp: DateTime.now(),
    );
  }

  /// Create failed jog result with validation details
  factory JogResult.failure({
    required ValidationResult validationResult,
    String? errorMessage,
  }) {
    return JogResult(
      success: false,
      validationResult: validationResult,
      errorMessage: errorMessage ?? validationResult.error,
      timestamp: DateTime.now(),
    );
  }

  /// Create failed jog result with custom error
  factory JogResult.error(String errorMessage) {
    return JogResult(
      success: false,
      errorMessage: errorMessage,
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() => 'JogResult(success: $success, error: $errorMessage)';
}

/// Use case for machine jogging operations with comprehensive safety validation
/// 
/// Orchestrates machine jogging operations by coordinating between machine state,
/// safety validation, and position calculation. Replicates existing jog behavior
/// while adding domain-level validation.
class JogMachine {
  final MachineRepository _machineRepository;

  const JogMachine(
    this._machineRepository,
  );

  /// Execute jog operation with full validation pipeline
  /// 
  /// Flow: Get machine state → Validate move → Execute → Update state → Return result
  /// Returns structured results with success/failure and violation types.
  Future<JogResult> execute(JogRequest request) async {
    try {
      // Step 1: Get current machine state
      final currentMachine = await _machineRepository.getCurrent();

      // Step 2: Validate the jog move through domain Machine entity
      final validationResult = currentMachine.validateMove(request.targetPosition);
      
      // Step 3: Validate feed rate if move is valid
      if (validationResult.isValid && request.feedRate < 0) {
        final feedRateValidationResult = ValidationResult.failure(
          'Feed rate cannot be negative: ${request.feedRate}',
          ViolationType.invalidParameter,
        );
        return JogResult.failure(
          validationResult: feedRateValidationResult,
        );
      }

      if (!validationResult.isValid) {
        return JogResult.failure(
          validationResult: validationResult,
          errorMessage: validationResult.error,
        );
      }

      // Step 3: Execute the move (domain-level)
      final updatedMachine = currentMachine.executeMove(request.targetPosition);

      // Step 4: Update repository with new state
      await _machineRepository.updatePosition(updatedMachine);

      // Step 5: Return success result
      return JogResult.success(updatedMachine);

    } catch (e) {
      // Handle unexpected errors
      return JogResult.error('Jog operation failed: ${e.toString()}');
    }
  }

  /// Validate a jog move without executing it
  /// 
  /// Useful for UI feedback showing whether a move would be valid
  /// before the user commits to executing it.
  Future<ValidationResult> validateMove(JogRequest request) async {
    try {
      final currentMachine = await _machineRepository.getCurrent();
      
      // Use domain Machine entity for validation
      final moveValidation = currentMachine.validateMove(request.targetPosition);
      if (!moveValidation.isValid) {
        return moveValidation;
      }
      
      // Basic feed rate validation
      if (request.feedRate < 0) {
        return ValidationResult.failure(
          'Feed rate cannot be negative: ${request.feedRate}',
          ViolationType.invalidParameter,
        );
      }
      
      // TODO: Add more comprehensive validation in Task 3
      return ValidationResult.success();
    } catch (e) {
      return ValidationResult.failure(
        'Validation failed: ${e.toString()}',
        ViolationType.systemError,
      );
    }
  }

  /// Check if machine is ready for jog operations
  /// 
  /// Quick check for UI state management - determines if jog controls
  /// should be enabled or disabled.
  Future<bool> canJog() async {
    try {
      final machine = await _machineRepository.getCurrent();
      
      // Basic readiness checks
      if (!_machineRepository.isConnected) return false;
      if (machine.status.hasError) return false;
      if (machine.status.isActive && machine.status != MachineStatus.jogging) return false;
      
      return true;
    } catch (e) {
      return false;
    }
  }
}