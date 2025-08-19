import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/problem.dart';
import '../../models/alarm_error_metadata.dart';
import '../../utils/logger.dart';
import 'problems_event.dart';
import 'problems_state.dart';
import '../communication/cnc_communication_state.dart';
import '../profile/profile_state.dart';
import '../../models/machine_controller.dart';

/// BLoC for managing system-wide problems and issues
class ProblemsBloc extends Bloc<ProblemsEvent, ProblemsState> {
  /// Note: Removed automatic cleanup timer - problems persist until resolved

  ProblemsBloc() : super(const ProblemsState()) {
    AppLogger.info('Problems BLoC initialized');

    // Register event handlers
    on<ProblemAdded>(_onProblemAdded);
    on<ProblemRemoved>(_onProblemRemoved);
    on<ProblemUpdated>(_onProblemUpdated);
    on<ProblemsCleared>(_onProblemsCleared);
    on<ProblemsInitialized>(_onProblemsInitialized);
    on<ProblemsClearedForSource>(_onProblemsClearedForSource);

    // State analysis handlers
    on<CncCommunicationStateAnalyzed>(_onCncCommunicationStateAnalyzed);
    on<FileManagerStateAnalyzed>(_onFileManagerStateAnalyzed);
    on<ProfileStateAnalyzed>(_onProfileStateAnalyzed);
    on<MachineControllerStateAnalyzed>(_onMachineControllerStateAnalyzed);

    // Note: Removed stale cleanup functionality

    // Initialize the state in the next tick to avoid emit in constructor
    Future.delayed(Duration.zero, () {
      if (!isClosed) {
        add(const ProblemsInitialized());
      }
    });
  }

  /// Handle adding a new problem
  void _onProblemAdded(ProblemAdded event, Emitter<ProblemsState> emit) {
    final updatedProblems = List<Problem>.from(state.problems);

    // Check if problem with same ID already exists
    final existingIndex = updatedProblems.indexWhere(
      (p) => p.id == event.problem.id,
    );

    if (existingIndex != -1) {
      // Update existing problem
      updatedProblems[existingIndex] = event.problem;
      AppLogger.debug('Updated existing problem: ${event.problem.id}');
    } else {
      // Add new problem
      updatedProblems.add(event.problem);
      AppLogger.info(
        'Added new problem: ${event.problem.title} (${event.problem.severity.name})',
      );
    }

    emit(state.copyWith(problems: updatedProblems));
  }

  /// Handle removing a problem by ID
  void _onProblemRemoved(ProblemRemoved event, Emitter<ProblemsState> emit) {
    final updatedProblems = state.problems
        .where((p) => p.id != event.problemId)
        .toList();

    if (updatedProblems.length != state.problems.length) {
      AppLogger.info('Removed problem: ${event.problemId}');
      emit(state.copyWith(problems: updatedProblems));
    }
  }

  /// Handle updating an existing problem
  void _onProblemUpdated(ProblemUpdated event, Emitter<ProblemsState> emit) {
    final updatedProblems = List<Problem>.from(state.problems);
    final index = updatedProblems.indexWhere((p) => p.id == event.problem.id);

    if (index != -1) {
      updatedProblems[index] = event.problem;
      AppLogger.debug('Updated problem: ${event.problem.id}');
      emit(state.copyWith(problems: updatedProblems));
    } else {
      // Problem doesn't exist, add it
      AppLogger.debug(
        'Problem not found for update, adding: ${event.problem.id}',
      );
      add(ProblemAdded(event.problem));
    }
  }

  /// Handle clearing all problems
  void _onProblemsCleared(ProblemsCleared event, Emitter<ProblemsState> emit) {
    AppLogger.info('Cleared all problems');
    emit(state.copyWith(problems: [], isInitialized: true));
  }

  /// Handle BLoC initialization
  void _onProblemsInitialized(
    ProblemsInitialized event,
    Emitter<ProblemsState> emit,
  ) {
    AppLogger.info('Problems BLoC marked as initialized');
    emit(state.copyWith(isInitialized: true));
  }

  /// Handle clearing problems from a specific source
  void _onProblemsClearedForSource(
    ProblemsClearedForSource event,
    Emitter<ProblemsState> emit,
  ) {
    final updatedProblems = state.problems
        .where((p) => p.source != event.source)
        .toList();

    if (updatedProblems.length != state.problems.length) {
      AppLogger.info('Cleared problems for source: ${event.source}');
      emit(state.copyWith(problems: updatedProblems));
    }
  }

  /// Analyze CNC Communication state for problems
  void _onCncCommunicationStateAnalyzed(
    CncCommunicationStateAnalyzed event,
    Emitter<ProblemsState> emit,
  ) {

    // Clear existing CNC-related problems first
    final nonCncProblems = state.problems
        .where(
          (p) =>
              !p.source.contains('CNC') &&
              p.source != 'Performance' &&
              p.source != 'Machine State',
        )
        .toList();

    final newProblems = List<Problem>.from(nonCncProblems);

    // Analyze current state and add relevant problems
    switch (event.state.runtimeType) {
      case const (CncCommunicationInitial):
      case const (CncCommunicationAddressConfigured):
        newProblems.add(ProblemFactory.cncNotConnected());
        break;

      case const (CncCommunicationDisconnected):
        final disconnectedState = event.state as CncCommunicationDisconnected;
        newProblems.add(
          ProblemFactory.cncDisconnected(
            reason: disconnectedState.reason,
            disconnectedAt: disconnectedState.disconnectedAt,
          ),
        );
        break;

      case const (CncCommunicationError):
        final errorState = event.state as CncCommunicationError;
        if (errorState.errorMessage.contains('timeout')) {
          newProblems.add(ProblemFactory.cncConnectionTimeout());
        } else {
          newProblems.add(ProblemFactory.cncNotConnected());
        }
        break;

      case const (CncCommunicationWithData):
        // Note: Performance data checking moved to MachineControllerBloc
        // Note: Machine alarm checking moved to MachineControllerBloc
        // CommunicationWithData state is now lightweight - no performance metrics
        break;

      // Connected and Connecting states are considered healthy
      case const (CncCommunicationConnected):
      case const (CncCommunicationConnecting):
        // No problems for these states
        break;
    }

    if (newProblems.length != state.problems.length ||
        !_problemListsEqual(newProblems, state.problems)) {
      emit(state.copyWith(problems: newProblems));
    }
  }

  /// Analyze File Manager state for problems
  void _onFileManagerStateAnalyzed(
    FileManagerStateAnalyzed event,
    Emitter<ProblemsState> emit,
  ) {
    AppLogger.debug('Analyzing File Manager state');

    // Clear existing file manager problems
    final nonFileProblems = state.problems
        .where((p) => p.source != 'File Manager')
        .toList();

    final newProblems = List<Problem>.from(nonFileProblems);

    // Check for errors
    if (event.state.hasError) {
      newProblems.add(
        ProblemFactory.fileManagerError(event.state.errorMessage!),
      );
    } else {
      // Check for independent file-related problems

      // Problem 1: No files uploaded at all
      if (event.state.isEmpty) {
        newProblems.add(ProblemFactory.fileManagerNoFiles());
      }

      // Problem 2: No file selected (independent of whether files exist)
      if (!event.state.hasSelection) {
        newProblems.add(ProblemFactory.fileManagerNoSelection());
      }

      // Both problems can exist simultaneously:
      // - If files.isEmpty && !hasSelection: both problems show
      // - If files.isNotEmpty && !hasSelection: only "no selection" shows
      // - If files.isNotEmpty && hasSelection: no problems
    }

    if (newProblems.length != state.problems.length ||
        !_problemListsEqual(newProblems, state.problems)) {
      emit(state.copyWith(problems: newProblems));
    }
  }

  /// Analyze Profile state for problems
  void _onProfileStateAnalyzed(
    ProfileStateAnalyzed event,
    Emitter<ProblemsState> emit,
  ) {
    AppLogger.debug('Analyzing Profile state: ${event.state.runtimeType}');

    // Clear existing profile problems
    final nonProfileProblems = state.problems
        .where((p) => p.source != 'Profile Manager')
        .toList();

    final newProblems = List<Problem>.from(nonProfileProblems);

    switch (event.state.runtimeType) {
      case const (ProfileEmpty):
        newProblems.add(ProblemFactory.profileNoProfiles());
        break;

      case const (ProfileError):
        final errorState = event.state as ProfileError;
        newProblems.add(
          ProblemFactory.profileLoadError(errorState.errorMessage),
        );
        break;

      case const (ProfileLoaded):
        final loadedState = event.state as ProfileLoaded;
        // Check if current profile has missing controller address
        if (loadedState.currentProfile.controllerAddress.isEmpty) {
          newProblems.add(
            Problem(
              id: ProblemIds.profileMissingAddress,
              severity: ProblemSeverity.warning,
              source: 'Profile Manager',
              title: 'Missing Controller Address',
              description:
                  'Current profile "${loadedState.currentProfile.name}" does not have a controller address configured.',
              timestamp: DateTime.now(),
            ),
          );
        }
        break;

      // Other states (Loading, OperationInProgress, OperationSuccess) are transitional
    }

    if (newProblems.length != state.problems.length ||
        !_problemListsEqual(newProblems, state.problems)) {
      emit(state.copyWith(problems: newProblems));
    }
  }

  /// Analyze Machine Controller state for problems
  void _onMachineControllerStateAnalyzed(
    MachineControllerStateAnalyzed event,
    Emitter<ProblemsState> emit,
  ) {

    // Clear existing machine state problems
    final nonMachineProblems = state.problems
        .where((p) => p.source != 'Machine State')
        .toList();

    final newProblems = List<Problem>.from(nonMachineProblems);

    // Check for door open state
    if (event.state.hasController && event.state.status == MachineStatus.door) {
      newProblems.add(ProblemFactory.cncDoorOpen());
      AppLogger.warning('Machine door is open - added problem');
    }

    // Check for firmware unresponsive
    if (event.state.hasSuspectedUnresponsiveFirmware) {
      newProblems.add(ProblemFactory.cncFirmwareUnresponsive());
      AppLogger.warning('Firmware unresponsive suspected - added problem');
    }

    // Check for alarm conditions with metadata
    if (event.state.hasActiveAlarmConditions) {
      for (final alarmCondition in event.state.activeAlarmConditions) {
        final problemId = 'alarm_${alarmCondition.code}';
        final actions = _getActionsForAlarm(alarmCondition.code, alarmCondition.name);
        final alarmProblem = Problem(
          id: problemId,
          severity: _convertConditionSeverityToProblemSeverity(alarmCondition.severity),
          source: 'Machine State',
          title: 'Alarm: ${alarmCondition.name}',
          description: alarmCondition.description,
          timestamp: alarmCondition.detectedAt,
          metadata: {
            'alarmCode': alarmCondition.code,
            'isAlarm': true,
            'severity': alarmCondition.severity.name,
          },
          actions: actions,
        );
        newProblems.add(alarmProblem);
        AppLogger.warning('Added alarm condition to problems: Code ${alarmCondition.code} - ${alarmCondition.name}');
      }
    }

    // Check for error conditions with metadata  
    if (event.state.hasActiveErrorConditions) {
      for (final errorCondition in event.state.activeErrorConditions) {
        final problemId = 'error_${errorCondition.code}';
        final errorProblem = Problem(
          id: problemId,
          severity: _convertConditionSeverityToProblemSeverity(errorCondition.severity),
          source: 'Machine State',
          title: 'Error: ${errorCondition.name}',
          description: errorCondition.description,
          timestamp: errorCondition.detectedAt,
          metadata: {
            'errorCode': errorCondition.code,
            'isAlarm': false,
            'severity': errorCondition.severity.name,
          },
        );
        newProblems.add(errorProblem);
        AppLogger.error('Added error condition to problems: Code ${errorCondition.code} - ${errorCondition.name}');
      }
    }

    // Fallback: Check legacy alarm/error strings if no metadata available
    if (event.state.hasController && !event.state.hasActiveAlarmConditions && event.state.hasAlarms) {
      final alarmDetails = event.state.controller!.alarms.join(', ');
      newProblems.add(ProblemFactory.cncMachineAlarm(alarmDetails));
      AppLogger.warning('Added legacy alarm to problems: $alarmDetails');
    }

    if (newProblems.length != state.problems.length ||
        !_problemListsEqual(newProblems, state.problems)) {
      emit(state.copyWith(problems: newProblems));
    }
  }

  /// Note: Removed automatic stale cleanup functionality
  /// Problems now persist until they are resolved or explicitly cleared
  /// This follows VS Code's behavior where problems remain visible until fixed

  /// Helper to compare problem lists for equality
  bool _problemListsEqual(List<Problem> list1, List<Problem> list2) {
    if (list1.length != list2.length) return false;

    // Sort both lists by ID for comparison
    final sorted1 = List<Problem>.from(list1)
      ..sort((a, b) => a.id.compareTo(b.id));
    final sorted2 = List<Problem>.from(list2)
      ..sort((a, b) => a.id.compareTo(b.id));

    for (int i = 0; i < sorted1.length; i++) {
      if (sorted1[i].id != sorted2[i].id) return false;
    }

    return true;
  }

  /// Convert ConditionSeverity to ProblemSeverity
  ProblemSeverity _convertConditionSeverityToProblemSeverity(ConditionSeverity conditionSeverity) {
    switch (conditionSeverity) {
      case ConditionSeverity.fatal:
      case ConditionSeverity.critical:
      case ConditionSeverity.error:
        return ProblemSeverity.error;
      case ConditionSeverity.warning:
        return ProblemSeverity.warning;
      case ConditionSeverity.info:
        return ProblemSeverity.info;
    }
  }

  /// Get appropriate actions for an alarm based on alarm code and name
  List<ProblemAction> _getActionsForAlarm(int alarmCode, String alarmName) {
    final actions = <ProblemAction>[];
    final lowerName = alarmName.toLowerCase();

    // Hard limit alarms - need homing
    if (lowerName.contains('hard limit') || lowerName.contains('limit switch') || alarmCode == 1 || alarmCode == 11) {
      actions.add(ProblemActions.resetAlarms);
      actions.add(ProblemActions.homeMachine);
    }
    // Soft limit alarms - need homing  
    else if (lowerName.contains('soft limit') || alarmCode == 2 || alarmCode == 12) {
      actions.add(ProblemActions.resetAlarms);
      actions.add(ProblemActions.homeMachine);
    }
    // Emergency stop - just reset and unlock
    else if (lowerName.contains('emergency') || lowerName.contains('e-stop') || alarmCode == 10) {
      actions.add(ProblemActions.resetAlarms);
      actions.add(ProblemActions.unlockMachine);
    }
    // Homing failure - try homing again
    else if (lowerName.contains('homing') || alarmCode == 8 || alarmCode == 9) {
      actions.add(ProblemActions.resetAlarms);
      actions.add(ProblemActions.homeMachine);
    }
    // Generic alarms - reset and unlock
    else {
      actions.add(ProblemActions.resetAlarms);
      actions.add(ProblemActions.unlockMachine);
    }

    return actions;
  }

  @override
  void onTransition(Transition<ProblemsEvent, ProblemsState> transition) {
    super.onTransition(transition);
    if (transition.currentState.problems.length !=
        transition.nextState.problems.length) {
      AppLogger.debug(
        'Problems count changed: ${transition.currentState.problems.length} -> ${transition.nextState.problems.length}',
      );
    }
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    super.onError(error, stackTrace);
    AppLogger.error('ProblemsBloc error', error, stackTrace);
  }

  @override
  Future<void> close() {
    // Note: No cleanup timer to cancel anymore
    return super.close();
  }
}
