import '../models/alarm_error_metadata.dart';
import '../utils/logger.dart';
import '../bloc/communication/cnc_communication_event.dart';

/// Service for handling alarm and error recovery actions
class AlarmErrorRecoveryService {
  final dynamic _communicationBloc;

  AlarmErrorRecoveryService(this._communicationBloc);

  /// Execute unlock recovery action ($X command)
  Future<bool> unlock() async {
    if (_communicationBloc == null) {
      AppLogger.warning('AlarmErrorRecoveryService: Cannot unlock - no communication bloc');
      return false;
    }

    try {
      AppLogger.info('AlarmErrorRecoveryService: Executing unlock command (\$X)');
      _communicationBloc.add(CncCommunicationSendCommand('\$X'));
      return true;
    } catch (e) {
      AppLogger.error('AlarmErrorRecoveryService: Failed to execute unlock command', e);
      return false;
    }
  }

  /// Execute homing cycle recovery action ($H command)
  Future<bool> homingCycle() async {
    if (_communicationBloc == null) {
      AppLogger.warning('AlarmErrorRecoveryService: Cannot home - no communication bloc');
      return false;
    }

    try {
      AppLogger.info('AlarmErrorRecoveryService: Executing homing cycle (\$H)');
      _communicationBloc.add(CncCommunicationSendCommand('\$H'));
      return true;
    } catch (e) {
      AppLogger.error('AlarmErrorRecoveryService: Failed to execute homing cycle', e);
      return false;
    }
  }

  /// Execute soft reset recovery action (0x18 raw bytes)
  Future<bool> softReset() async {
    if (_communicationBloc == null) {
      AppLogger.warning('AlarmErrorRecoveryService: Cannot reset - no communication bloc');
      return false;
    }

    try {
      AppLogger.info('AlarmErrorRecoveryService: Executing soft reset (0x18)');
      _communicationBloc.add(CncCommunicationSendRawBytes([0x18]));
      return true;
    } catch (e) {
      AppLogger.error('AlarmErrorRecoveryService: Failed to execute soft reset', e);
      return false;
    }
  }

  /// Execute recovery action based on the RecoveryAction enum
  Future<bool> executeRecoveryAction(RecoveryAction action) async {
    switch (action) {
      case RecoveryAction.unlock:
        return await unlock();
      case RecoveryAction.home:
        return await homingCycle();
      case RecoveryAction.reset:
        return await softReset();
      case RecoveryAction.none:
        AppLogger.info('AlarmErrorRecoveryService: No recovery action required');
        return true;
      case RecoveryAction.manual:
        AppLogger.info('AlarmErrorRecoveryService: Manual intervention required - no automatic action');
        return false;
    }
  }

  /// Get recommended recovery actions for a specific alarm code
  List<RecoveryAction> getRecommendedActions(int alarmCode) {
    switch (alarmCode) {
      case 1: // Hard limit
        return [RecoveryAction.unlock, RecoveryAction.reset];
      case 2: // Soft limit
        return [RecoveryAction.unlock, RecoveryAction.reset];
      case 10: // E-stop
        return [RecoveryAction.manual, RecoveryAction.unlock];
      case 11: // Homing required
        return [RecoveryAction.home, RecoveryAction.reset];
      default:
        return [RecoveryAction.unlock, RecoveryAction.reset];
    }
  }

  /// Check if a recovery action can be performed in the current state
  bool canPerformAction(RecoveryAction action, MachineStatus currentStatus) {
    switch (action) {
      case RecoveryAction.none:
        return true;
      case RecoveryAction.unlock:
        // Unlock can be performed in alarm state
        return currentStatus == MachineStatus.alarm;
      case RecoveryAction.home:
        // Homing can be performed when machine is idle or in alarm state
        return currentStatus == MachineStatus.idle || 
               currentStatus == MachineStatus.alarm;
      case RecoveryAction.reset:
        // Soft reset can usually be performed in any state
        return true;
      case RecoveryAction.manual:
        // Manual intervention is always "available" but requires user action
        return true;
    }
  }

  /// Get user-friendly instructions for manual recovery actions
  String getManualInstructions(int alarmCode) {
    switch (alarmCode) {
      case 1: // Hard limit
        return 'Check that all axes are within travel limits and no limit switches are triggered. Move the machine away from limits manually if necessary.';
      case 2: // Soft limit
        return 'The machine has exceeded software-defined travel limits. Check your G-code and machine configuration.';
      case 10: // E-stop
        return 'Emergency stop is active. Release the E-stop button, check for safety issues, then try unlocking the machine.';
      case 11: // Homing required
        return 'The machine requires homing before operation. Ensure all axes are clear and run a homing cycle.';
      default:
        return 'Check the alarm condition and follow standard recovery procedures for your machine.';
    }
  }

  /// Get severity-based action priorities
  List<RecoveryAction> getActionsByPriority(ConditionSeverity severity) {
    switch (severity) {
      case ConditionSeverity.fatal:
      case ConditionSeverity.critical:
        return [RecoveryAction.manual, RecoveryAction.reset, RecoveryAction.unlock];
      case ConditionSeverity.error:
        return [RecoveryAction.unlock, RecoveryAction.reset, RecoveryAction.home];
      case ConditionSeverity.warning:
        return [RecoveryAction.home, RecoveryAction.unlock, RecoveryAction.reset];
      case ConditionSeverity.info:
        return [RecoveryAction.none];
    }
  }

  /// Check if any recovery action is available for the current condition
  bool hasAvailableActions(ActiveCondition condition, MachineStatus currentStatus) {
    if (condition.isAlarm) {
      final actions = getRecommendedActions(condition.code);
      return actions.any((action) => canPerformAction(action, currentStatus));
    }
    // Errors typically don't have direct recovery actions
    return false;
  }

  /// Get the most appropriate recovery action for a condition
  RecoveryAction? getBestRecoveryAction(ActiveCondition condition, MachineStatus currentStatus) {
    if (!condition.isAlarm) {
      return null; // Errors don't typically have recovery actions
    }

    final recommendedActions = getRecommendedActions(condition.code);
    
    // Find the first action that can be performed in the current state
    for (final action in recommendedActions) {
      if (canPerformAction(action, currentStatus)) {
        return action;
      }
    }

    return null;
  }
}

/// Machine status enum (duplicated here to avoid circular dependencies)
/// This should match the enum in machine_controller.dart
enum MachineStatus {
  unknown,
  idle,
  running,
  paused,
  alarm,
  error,
  jogging,
  homing,
  hold,
  door,
  check,
  sleep,
}