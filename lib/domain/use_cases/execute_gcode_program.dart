import '../entities/machine.dart';
import '../repositories/machine_repository.dart';
import '../repositories/gcode_repository.dart';
import '../value_objects/gcode_program.dart';
import '../value_objects/gcode_program_id.dart';
import '../value_objects/validation_result.dart';
import '../../models/machine_controller.dart'; // For MachineStatus

/// Request object for G-code program execution
class ExecuteProgramRequest {
  final GCodeProgramId programId;
  final String? reason; // Optional context for logging/debugging

  const ExecuteProgramRequest({
    required this.programId,
    this.reason,
  });

  @override
  String toString() => 'ExecuteProgramRequest(programId: $programId)';
}

/// Result object for G-code program execution
class ExecuteProgramResult {
  final bool success;
  final GCodeProgram? program;
  final ValidationResult? validationResult;
  final String? errorMessage;
  final DateTime timestamp;

  ExecuteProgramResult({
    required this.success,
    this.program,
    this.validationResult,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create successful execution result
  factory ExecuteProgramResult.success(GCodeProgram program) {
    return ExecuteProgramResult(
      success: true,
      program: program,
      timestamp: DateTime.now(),
    );
  }

  /// Create failed execution result with validation details
  factory ExecuteProgramResult.failure({
    required ValidationResult validationResult,
    String? errorMessage,
  }) {
    return ExecuteProgramResult(
      success: false,
      validationResult: validationResult,
      errorMessage: errorMessage ?? validationResult.error,
      timestamp: DateTime.now(),
    );
  }

  /// Create failed execution result with custom error
  factory ExecuteProgramResult.error(String errorMessage) {
    return ExecuteProgramResult(
      success: false,
      errorMessage: errorMessage,
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() => 'ExecuteProgramResult(success: $success, error: $errorMessage)';
}

/// Use case for G-code program execution with pre-validation and progress tracking
/// 
/// Handles G-code program execution by integrating with existing G-code parser
/// and execution pipeline. Provides program validation before execution begins.
class ExecuteGCodeProgram {
  final MachineRepository _machineRepository;
  final GCodeRepository _gcodeRepository;

  const ExecuteGCodeProgram(
    this._machineRepository,
    this._gcodeRepository,
  );

  /// Execute G-code program with full validation pipeline
  /// 
  /// Flow: Get machine state → Load program → Validate → Execute → Return result
  /// Returns structured results with success/failure and validation details.
  Future<ExecuteProgramResult> execute(ExecuteProgramRequest request) async {
    try {
      // Step 1: Get current machine state
      final currentMachine = await _machineRepository.getCurrent();

      // Step 2: Check if machine is ready for program execution
      if (!_canExecuteProgram(currentMachine)) {
        return ExecuteProgramResult.error(
          'Machine is not ready for program execution: ${currentMachine.status.displayName}',
        );
      }

      // Step 3: Load the G-code program
      final program = await _gcodeRepository.load(request.programId);

      // Step 4: Basic program validation
      // TODO: Implement comprehensive program validation in Task 3
      if (program.parsedData == null) {
        final validationResult = ValidationResult.failure(
          'Program has not been parsed yet',
          ViolationType.programValidation,
        );
        return ExecuteProgramResult.failure(
          validationResult: validationResult,
          errorMessage: validationResult.error,
        );
      }
      
      if (program.parsedData!.commands.isEmpty) {
        final validationResult = ValidationResult.failure(
          'Program is empty',
          ViolationType.invalidParameter,
        );
        return ExecuteProgramResult.failure(
          validationResult: validationResult,
          errorMessage: validationResult.error,
        );
      }

      // Step 5: For now, just return success (actual execution will be implemented later)
      // TODO: Implement actual program execution pipeline
      return ExecuteProgramResult.success(program);

    } catch (e) {
      // Handle unexpected errors
      return ExecuteProgramResult.error('Program execution failed: ${e.toString()}');
    }
  }

  /// Validate a G-code program without executing it
  /// 
  /// Useful for UI feedback showing whether a program would be valid
  /// before the user commits to executing it.
  Future<ValidationResult> validateProgram(ExecuteProgramRequest request) async {
    try {
      final program = await _gcodeRepository.load(request.programId);
      
      // Basic program validation
      if (program.parsedData == null) {
        return ValidationResult.failure(
          'Program has not been parsed yet',
          ViolationType.programValidation,
        );
      }
      
      if (program.parsedData!.commands.isEmpty) {
        return ValidationResult.failure(
          'Program is empty',
          ViolationType.invalidParameter,
        );
      }
      
      // TODO: Implement comprehensive program validation in Task 3
      return ValidationResult.success();
    } catch (e) {
      return ValidationResult.failure(
        'Program validation failed: ${e.toString()}',
        ViolationType.systemError,
      );
    }
  }

  /// Check if a program exists and is ready for execution
  /// 
  /// Quick check for UI state management - determines if execute button
  /// should be enabled or disabled.
  Future<bool> canExecuteProgram(GCodeProgramId programId) async {
    try {
      final machine = await _machineRepository.getCurrent();
      final programExists = await _gcodeRepository.exists(programId);
      
      return _canExecuteProgram(machine) && programExists;
    } catch (e) {
      return false;
    }
  }

  /// Internal helper to check machine readiness
  bool _canExecuteProgram(Machine machine) {
    if (!_machineRepository.isConnected) return false;
    if (machine.status.hasError) return false;
    if (machine.status.isActive) return false;
    
    return true;
  }
}