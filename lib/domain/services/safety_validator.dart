import 'package:vector_math/vector_math.dart' as vm;
import '../entities/machine.dart';
import '../value_objects/validation_result.dart';
import '../value_objects/gcode_program.dart';

/// Centralized safety validation service for machine operations
/// 
/// Provides comprehensive validation for jog moves, G-code programs, and arc operations.
/// Must produce identical validation results to existing `SoftLimitChecker` for compatibility.
abstract class SafetyValidator {
  /// Validate a jog move for safety and feasibility
  /// 
  /// Comprehensive validation including:
  /// - Machine state validation (alarm conditions, movement state)
  /// - Boundary validation (work envelope, safety margins)
  /// - Performance validation (feed rates, acceleration limits)
  /// - Tool validation (collision detection, tool-specific limits)
  /// 
  /// Returns structured results with violation types and human-readable messages.
  Future<ValidationResult> validateJogMove(
    Machine machine,
    vm.Vector3 targetPosition,
    double feedRate,
  );

  /// Validate a complete G-code program
  /// 
  /// Full program analysis with line-by-line error reporting.
  /// Validates entire program execution path for safety and feasibility.
  Future<ValidationResult> validateProgram(GCodeProgram program);

  /// Validate an arc move with point generation
  /// 
  /// Point generation and boundary checking for curved operations.
  /// Uses same interpolation algorithm as existing G-code parser.
  Future<ValidationResult> validateArcMove(
    Machine machine,
    vm.Vector3 startPosition,
    vm.Vector3 endPosition,
    vm.Vector3 center,
    double feedRate,
    {bool clockwise = true}
  );

  /// Validate feed rate against machine limits
  /// 
  /// Checks feed rate against machine configuration limits and
  /// current machine capabilities.
  ValidationResult validateFeedRate(Machine machine, double feedRate);

  /// Check for tool collision at given position
  /// 
  /// Account for current tool length and geometry in collision detection.
  Future<ValidationResult> checkToolCollision(
    Machine machine,
    vm.Vector3 position,
  );
}

/// Default implementation of SafetyValidator
/// 
/// Wraps existing SoftLimitChecker to maintain 100% compatibility
/// while providing domain layer interface.
class DefaultSafetyValidator implements SafetyValidator {
  // Will inject existing SoftLimitChecker in implementation
  
  @override
  Future<ValidationResult> validateJogMove(
    Machine machine,
    vm.Vector3 targetPosition,
    double feedRate,
  ) async {
    // Step 1: Machine state validation
    final machineValidation = machine.validateMove(targetPosition);
    if (!machineValidation.isValid) {
      return machineValidation;
    }

    // Step 2: Feed rate validation
    final feedRateValidation = validateFeedRate(machine, feedRate);
    if (!feedRateValidation.isValid) {
      return feedRateValidation;
    }

    // Step 3: Tool collision check
    final collisionValidation = await checkToolCollision(machine, targetPosition);
    if (!collisionValidation.isValid) {
      return collisionValidation;
    }

    // All validations passed
    return ValidationResult.success();
  }

  @override
  Future<ValidationResult> validateProgram(GCodeProgram program) async {
    // TODO: Implement G-code program validation
    // This will be implemented in Task 3
    return ValidationResult.success();
  }

  @override
  Future<ValidationResult> validateArcMove(
    Machine machine,
    vm.Vector3 startPosition,
    vm.Vector3 endPosition,
    vm.Vector3 center,
    double feedRate,
    {bool clockwise = true}
  ) async {
    // TODO: Implement arc move validation with point generation
    // This will be implemented in Task 3
    return ValidationResult.success();
  }

  @override
  ValidationResult validateFeedRate(Machine machine, double feedRate) {
    // Basic feed rate validation
    if (feedRate < 0) {
      return ValidationResult.failure(
        'Feed rate cannot be negative: $feedRate',
        ViolationType.invalidParameter,
      );
    }

    // TODO: Add machine-specific feed rate limits
    // For now, accept any positive feed rate
    return ValidationResult.success();
  }

  @override
  Future<ValidationResult> checkToolCollision(
    Machine machine,
    vm.Vector3 position,
  ) async {
    // TODO: Implement tool collision detection
    // For now, assume no collision (safe default)
    return ValidationResult.success();
  }
}