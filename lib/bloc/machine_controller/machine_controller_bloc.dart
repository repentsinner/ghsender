import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/machine_controller.dart';
import '../../models/machine_configuration.dart';
import '../../models/alarm_error_metadata.dart';
import '../../models/problem.dart';
import '../../utils/logger.dart';
import 'machine_controller_event.dart';
import 'machine_controller_state.dart';
import '../communication/cnc_communication_state.dart';
import '../communication/cnc_communication_event.dart';
import '../problems/problems_event.dart';

/// BLoC for managing machine controller state from CNC communication responses
class MachineControllerBloc
    extends Bloc<MachineControllerEvent, MachineControllerState> {
  // Reference to communication bloc for sending commands
  dynamic _communicationBloc;

  // Reference to alarm/error bloc for metadata lookup
  dynamic _alarmErrorBloc;

  // Reference to problems bloc for creating problem entries
  dynamic _problemsBloc;

  // Timer for grblHAL detection timeout
  Timer? _grblHalDetectionTimeout;

  // Timer for firmware unresponsive detection
  Timer? _firmwareUnresponsiveDetectionTimer;
  
  // Timer for initialization response timeout
  Timer? _initializationTimeout;

  // Stream subscription for real-time message processing
  StreamSubscription? _messageStreamSubscription;
  
  // Debug: Track configuration messages received
  int _configMessagesReceived = 0;
  
  // Initialization state tracking
  bool _initializationComplete = false;
  bool _statusPollingStarted = false;

  // Throttling for jog command logging (to avoid spam during continuous jogging)
  DateTime? _lastJogLogTime;

  MachineControllerBloc() : super(const MachineControllerState()) {
    AppLogger.machineInfo('Machine Controller BLoC initialized');

    // Register event handlers
    on<MachineControllerInitialized>(_onInitialized);
    on<MachineControllerCommunicationReceived>(_onCommunicationReceived);
    on<MachineControllerStatusUpdated>(_onStatusUpdated);
    on<MachineControllerCoordinatesUpdated>(_onCoordinatesUpdated);
    on<MachineControllerSpindleUpdated>(_onSpindleUpdated);
    on<MachineControllerFeedUpdated>(_onFeedUpdated);
    on<MachineControllerCodesUpdated>(_onCodesUpdated);
    on<MachineControllerAlarmAdded>(_onAlarmAdded);
    on<MachineControllerAlarmConditionAdded>(_onAlarmConditionAdded);
    on<MachineControllerAlarmsCleared>(_onAlarmsCleared);
    on<MachineControllerErrorAdded>(_onErrorAdded);
    on<MachineControllerErrorConditionAdded>(_onErrorConditionAdded);
    on<MachineControllerErrorsCleared>(_onErrorsCleared);
    on<MachineControllerInfoUpdated>(_onInfoUpdated);
    on<MachineControllerConnectionChanged>(_onConnectionChanged);
    on<MachineControllerReset>(_onReset);

    // grblHAL detection and configuration handlers
    on<MachineControllerGrblHalDetected>(_onGrblHalDetected);
    on<MachineControllerSetCommunicationBloc>(_onSetCommunicationBloc);
    on<MachineControllerSetAlarmErrorBloc>(_onSetAlarmErrorBloc);
    on<MachineControllerSetProblemsBloc>(_onSetProblemsBloc);
    on<MachineControllerConfigurationReceived>(_onConfigurationReceived);
    on<MachineControllerBufferStatusUpdated>(_onBufferStatusUpdated);
    on<MachineControllerPluginsDetected>(_onPluginsDetected);
    on<MachineControllerFirmwareWelcomeReceived>(_onFirmwareWelcomeReceived);

    // Jog control handlers
    on<MachineControllerJogRequested>(_onJogRequested);
    on<MachineControllerJogStopRequested>(_onJogStopRequested);
    on<MachineControllerContinuousJogStarted>(_onContinuousJogStarted);
    on<MachineControllerContinuousJogStopped>(_onContinuousJogStopped);
    on<MachineControllerMultiAxisJogRequested>(_onMultiAxisJogRequested);

    // Initialize in the next tick
    Future.delayed(Duration.zero, () {
      if (!isClosed) {
        add(const MachineControllerInitialized());
      }
    });
  }

  /// Handle initialization
  void _onInitialized(
    MachineControllerInitialized event,
    Emitter<MachineControllerState> emit,
  ) {
    AppLogger.machineInfo('Machine Controller BLoC marked as initialized');
    emit(state.copyWith(isInitialized: true));
  }

  /// Handle incoming CNC communication data
  void _onCommunicationReceived(
    MachineControllerCommunicationReceived event,
    Emitter<MachineControllerState> emit,
  ) {

    final now = DateTime.now();

    switch (event.communicationState.runtimeType) {
      case const (CncCommunicationConnected):
        final connectedState =
            event.communicationState as CncCommunicationConnected;
        _handleConnectedState(connectedState, emit, now);
        break;

      // CncCommunicationWithData removed - now using individual message events

      case const (CncCommunicationDisconnected):
      case const (CncCommunicationError):
        _handleDisconnectedState(emit, now);
        break;

      case const (CncCommunicationInitial):
      case const (CncCommunicationAddressConfigured):
      case const (CncCommunicationConnecting):
        // These states don't provide machine data
        break;
    }
  }

  /// Handle connected state
  void _handleConnectedState(
    CncCommunicationConnected connectedState,
    Emitter<MachineControllerState> emit,
    DateTime timestamp,
  ) {
    AppLogger.machineInfo('=== CONNECTED STATE DEBUG ===');
    AppLogger.machineInfo('grblHalDetected: ${state.grblHalDetected}');
    AppLogger.machineInfo('deviceInfo: "${connectedState.deviceInfo}"');

    // grblHAL detection now happens via individual message events only
    AppLogger.machineInfo(
      'Connected state handled - grblHAL detection via message events',
    );

    // Start grblHAL detection timeout if not already detected
    if (!state.grblHalDetected) {
      _startGrblHalDetectionTimeout();
    }

    // Create or update controller with connection info
    final currentController = state.controller;
    final updatedController =
        (currentController ??
                MachineController(
                  controllerId: _extractControllerIdFromUrl(connectedState.url),
                  lastCommunication: timestamp,
                ))
            .copyWith(isOnline: true, lastCommunication: timestamp);

    emit(
      state.copyWith(controller: updatedController, lastUpdateTime: timestamp),
    );

    AppLogger.machineInfo(
      'Machine controller connected: ${updatedController.controllerId}',
    );
  }

  // _handleDataState method removed - now using individual message events

  /// Handle disconnected state
  void _handleDisconnectedState(
    Emitter<MachineControllerState> emit,
    DateTime timestamp,
  ) {
    // Cancel all timeouts on disconnect
    _cancelGrblHalDetectionTimeout();
    _cancelFirmwareUnresponsiveDetectionTimer();
    _cancelInitializationTimeout();
    
    // Reset initialization state
    _initializationComplete = false;
    _statusPollingStarted = false;

    if (state.controller != null) {
      final updatedController = state.controller!.copyWith(
        isOnline: false,
        machinePosition: null, // Clear machine position on disconnect
        lastCommunication: timestamp,
      );

      emit(
        state.copyWith(
          controller: updatedController,
          lastUpdateTime: timestamp,
        ),
      );

      AppLogger.machineInfo('Machine controller disconnected - machine position cleared');
    }
  }

  /// Extract controller ID from WebSocket URL
  String _extractControllerIdFromUrl(String url) {
    // Simple extraction - could be made more sophisticated
    final uri = Uri.tryParse(url);
    if (uri != null) {
      return '${uri.host}:${uri.port}';
    }
    return url;
  }

  /// Handle status update
  void _onStatusUpdated(
    MachineControllerStatusUpdated event,
    Emitter<MachineControllerState> emit,
  ) {
    if (state.controller != null) {
      final updatedController = state.controller!.copyWith(
        status: event.status,
        lastCommunication: event.timestamp,
      );

      // Clear active alarm conditions if status is no longer alarm
      final newActiveAlarmConditions = event.status == MachineStatus.alarm 
          ? state.activeAlarmConditions 
          : <ActiveCondition>[];

      // Clear legacy alarms if status is no longer alarm
      final newAlarms = event.status == MachineStatus.alarm
          ? updatedController.alarms
          : <String>[];

      final finalController = updatedController.copyWith(alarms: newAlarms);

      emit(
        state.copyWith(
          controller: finalController,
          activeAlarmConditions: newActiveAlarmConditions,
          lastStatusReceivedAt: event.timestamp, // Track when we last received status
          lastUpdateTime: event.timestamp,
        ),
      );

    }
  }

  /// Handle coordinates update
  void _onCoordinatesUpdated(
    MachineControllerCoordinatesUpdated event,
    Emitter<MachineControllerState> emit,
  ) {
    if (state.controller != null) {
      final updatedController = state.controller!.copyWith(
        workPosition: event.workPosition,
        machinePosition: event.machinePosition,
        lastCommunication: event.timestamp,
      );

      emit(
        state.copyWith(
          controller: updatedController,
          lastUpdateTime: event.timestamp,
        ),
      );

    }
  }

  /// Handle spindle update
  void _onSpindleUpdated(
    MachineControllerSpindleUpdated event,
    Emitter<MachineControllerState> emit,
  ) {
    if (state.controller != null) {
      final updatedController = state.controller!.copyWith(
        spindleState: event.spindleState,
        lastCommunication: event.timestamp,
      );

      emit(
        state.copyWith(
          controller: updatedController,
          lastUpdateTime: event.timestamp,
        ),
      );

    }
  }

  /// Handle feed update
  void _onFeedUpdated(
    MachineControllerFeedUpdated event,
    Emitter<MachineControllerState> emit,
  ) {
    if (state.controller != null) {
      final updatedController = state.controller!.copyWith(
        feedState: event.feedState,
        lastCommunication: event.timestamp,
      );

      emit(
        state.copyWith(
          controller: updatedController,
          lastUpdateTime: event.timestamp,
        ),
      );

    }
  }

  /// Handle codes update
  void _onCodesUpdated(
    MachineControllerCodesUpdated event,
    Emitter<MachineControllerState> emit,
  ) {
    if (state.controller != null) {
      final updatedController = state.controller!.copyWith(
        activeCodes: event.activeCodes,
        lastCommunication: event.timestamp,
      );

      emit(
        state.copyWith(
          controller: updatedController,
          lastUpdateTime: event.timestamp,
        ),
      );

      AppLogger.machineDebug(
        'Machine codes updated: G[${event.activeCodes.gCodes.join(', ')}] M[${event.activeCodes.mCodes.join(', ')}]',
      );
    }
  }

  /// Handle alarm added
  void _onAlarmAdded(
    MachineControllerAlarmAdded event,
    Emitter<MachineControllerState> emit,
  ) {
    if (state.controller != null) {
      final currentAlarms = List<String>.from(state.controller!.alarms);
      if (!currentAlarms.contains(event.alarm)) {
        currentAlarms.add(event.alarm);
      }

      final updatedController = state.controller!.copyWith(
        alarms: currentAlarms,
        lastCommunication: event.timestamp,
      );

      emit(
        state.copyWith(
          controller: updatedController,
          lastUpdateTime: event.timestamp,
        ),
      );

      AppLogger.machineWarning('Machine alarm added: ${event.alarm}');
    }
  }

  /// Handle alarm condition added with metadata
  void _onAlarmConditionAdded(
    MachineControllerAlarmConditionAdded event,
    Emitter<MachineControllerState> emit,
  ) {
    if (state.controller != null && _alarmErrorBloc != null) {
      // Create ActiveCondition with metadata from AlarmErrorBloc
      final alarmErrorState = _alarmErrorBloc.state;
      final activeCondition = alarmErrorState.createActiveAlarm(
        event.alarmCode,
        event.timestamp,
      );

      // Add to active alarm conditions
      final currentActiveAlarms = List<ActiveCondition>.from(state.activeAlarmConditions);
      
      // Remove any existing alarm with the same code (replace with newer one)
      currentActiveAlarms.removeWhere((condition) => condition.code == event.alarmCode);
      currentActiveAlarms.add(activeCondition);

      // Also add to legacy alarms list for backward compatibility
      final currentAlarms = List<String>.from(state.controller!.alarms);
      if (!currentAlarms.contains(event.rawMessage)) {
        currentAlarms.add(event.rawMessage);
      }

      final updatedController = state.controller!.copyWith(
        alarms: currentAlarms,
        lastCommunication: event.timestamp,
      );

      emit(
        state.copyWith(
          controller: updatedController,
          activeAlarmConditions: currentActiveAlarms,
          lastUpdateTime: event.timestamp,
        ),
      );

      AppLogger.machineWarning(
        'Machine alarm condition added: Code ${event.alarmCode} - ${activeCondition.name}',
      );
    }
  }

  /// Handle alarms cleared
  void _onAlarmsCleared(
    MachineControllerAlarmsCleared event,
    Emitter<MachineControllerState> emit,
  ) {
    if (state.controller != null) {
      final updatedController = state.controller!.copyWith(
        alarms: [],
        lastCommunication: DateTime.now(),
      );

      emit(
        state.copyWith(
          controller: updatedController,
          activeAlarmConditions: [],
          lastUpdateTime: DateTime.now(),
        ),
      );

      AppLogger.machineInfo('Machine alarms cleared');
    }
  }

  /// Handle error added
  void _onErrorAdded(
    MachineControllerErrorAdded event,
    Emitter<MachineControllerState> emit,
  ) {
    if (state.controller != null) {
      final currentErrors = List<String>.from(state.controller!.errors);
      if (!currentErrors.contains(event.error)) {
        currentErrors.add(event.error);
      }

      final updatedController = state.controller!.copyWith(
        errors: currentErrors,
        lastCommunication: event.timestamp,
      );

      emit(
        state.copyWith(
          controller: updatedController,
          lastUpdateTime: event.timestamp,
        ),
      );

      AppLogger.machineError('Machine error added: ${event.error}');
    }
  }

  /// Handle error condition added with metadata
  void _onErrorConditionAdded(
    MachineControllerErrorConditionAdded event,
    Emitter<MachineControllerState> emit,
  ) {
    if (state.controller != null && _alarmErrorBloc != null) {
      // Create ActiveCondition with metadata from AlarmErrorBloc
      final alarmErrorState = _alarmErrorBloc.state;
      final activeCondition = alarmErrorState.createActiveError(
        event.errorCode,
        event.timestamp,
      );

      // Add to active error conditions
      final currentActiveErrors = List<ActiveCondition>.from(state.activeErrorConditions);
      
      // Remove any existing error with the same code (replace with newer one)
      currentActiveErrors.removeWhere((condition) => condition.code == event.errorCode);
      currentActiveErrors.add(activeCondition);

      // Also add to legacy errors list for backward compatibility
      final currentErrors = List<String>.from(state.controller!.errors);
      if (!currentErrors.contains(event.rawMessage)) {
        currentErrors.add(event.rawMessage);
      }

      final updatedController = state.controller!.copyWith(
        errors: currentErrors,
        lastCommunication: event.timestamp,
      );

      emit(
        state.copyWith(
          controller: updatedController,
          activeErrorConditions: currentActiveErrors,
          lastUpdateTime: event.timestamp,
        ),
      );

      AppLogger.machineError(
        'Machine error condition added: Code ${event.errorCode} - ${activeCondition.name}',
      );
    }
  }

  /// Handle errors cleared
  void _onErrorsCleared(
    MachineControllerErrorsCleared event,
    Emitter<MachineControllerState> emit,
  ) {
    if (state.controller != null) {
      final updatedController = state.controller!.copyWith(
        errors: [],
        lastCommunication: DateTime.now(),
      );

      emit(
        state.copyWith(
          controller: updatedController,
          activeErrorConditions: [],
          lastUpdateTime: DateTime.now(),
        ),
      );

      AppLogger.machineInfo('Machine errors cleared');
    }
  }

  /// Handle info update
  void _onInfoUpdated(
    MachineControllerInfoUpdated event,
    Emitter<MachineControllerState> emit,
  ) {
    if (state.controller != null) {
      final updatedController = state.controller!.copyWith(
        firmwareVersion: event.firmwareVersion,
        hardwareVersion: event.hardwareVersion,
        lastCommunication: DateTime.now(),
      );

      emit(
        state.copyWith(
          controller: updatedController,
          lastUpdateTime: DateTime.now(),
        ),
      );

      if (event.firmwareVersion != null && event.hardwareVersion != null) {
        AppLogger.machineInfo(
          'Machine info updated: FW=${event.firmwareVersion}, HW=${event.hardwareVersion}',
        );
      }
    }
  }

  /// Handle connection change
  void _onConnectionChanged(
    MachineControllerConnectionChanged event,
    Emitter<MachineControllerState> emit,
  ) {
    if (state.controller != null) {
      if (event.isOnline) {
        // Update controller for online status
        final updatedController = state.controller!.copyWith(
          isOnline: event.isOnline,
          lastCommunication: event.timestamp,
        );

        emit(
          state.copyWith(
            controller: updatedController,
            lastUpdateTime: event.timestamp,
          ),
        );
      } else {
        // Comprehensive cleanup and state reset when going offline
        _performDisconnectCleanup();
        
        // Reset all connection-related state
        final clearedController = state.controller!.copyWith(
          isOnline: false,
          lastCommunication: event.timestamp,
          machinePosition: null, // Clear position
        );

        emit(
          state.copyWith(
            controller: clearedController,
            lastUpdateTime: event.timestamp,
            // Reset grblHAL detection state
            grblHalDetected: false,
            grblHalVersion: null,
            grblHalDetectedAt: null,
            // Clear configuration
            configuration: null,
            // Reset buffer status
            plannerBlocksAvailable: null,
            rxBytesAvailable: null,
            maxObservedBufferBlocks: null,
            // Clear plugins
            plugins: const [],
            // Clear alarm/error conditions
            activeAlarmConditions: const [],
            activeErrorConditions: const [],
            // Reset firmware communication timestamps
            firmwareWelcomeReceivedAt: null,
            lastStatusReceivedAt: null,
            // Clear performance data
            performanceData: null,
            // Reset jog test state
            jogTestRunning: false,
            jogTestStartTime: null,
            jogTestDurationSeconds: 0,
            jogCount: 0,
            jogDistance: 0.0,
            jogFeedRate: 0,
            stateTransitions: const [],
          ),
        );
      }

      AppLogger.machineInfo(
        'Machine connection changed: ${event.isOnline ? 'online' : 'offline'}${event.isOnline ? '' : ' - all connection state cleared'}',
      );
    }
  }

  /// Handle reset
  void _onReset(
    MachineControllerReset event,
    Emitter<MachineControllerState> emit,
  ) {
    // Perform comprehensive cleanup (resets timers and state tracking)
    _performDisconnectCleanup();
    
    // Emit clean state
    emit(const MachineControllerState(isInitialized: true));
    AppLogger.machineInfo('Machine controller reset - all state cleared');
  }

  /// Perform comprehensive cleanup when disconnecting from machine
  /// Resets all timeout timers, initialization state, and clears CNC-related problems
  void _performDisconnectCleanup() {
    AppLogger.machineInfo('Performing comprehensive disconnect cleanup...');
    
    // Stop polling
    if (_communicationBloc != null) {
      AppLogger.machineInfo('Machine offline - stopping status polling');
      _communicationBloc.add(
        CncCommunicationPollingControlRequested(enable: false),
      );
    }
    
    // Cancel all timeout timers
    _cancelGrblHalDetectionTimeout();
    _cancelInitializationTimeout();
    _firmwareUnresponsiveDetectionTimer?.cancel();
    _firmwareUnresponsiveDetectionTimer = null;
    
    // Reset initialization state tracking
    _initializationComplete = false;
    _statusPollingStarted = false;
    _configMessagesReceived = 0;
    
    // Clear CNC-related problems from ProblemsBloc
    if (_problemsBloc != null) {
      AppLogger.machineInfo('Clearing CNC-related problems on disconnect');
      _problemsBloc.add(const ProblemsClearedForSource('CNC Communication'));
      _problemsBloc.add(const ProblemsClearedForSource('Machine State'));
      _problemsBloc.add(const ProblemsClearedForSource('Performance'));
    }
    
    AppLogger.machineInfo('Disconnect cleanup completed');
  }

  // Old _checkForGrblHalWelcomeMessage method removed - now using individual message events

  // Old _parseConfigurationResponses method removed - now using individual message events

  /// Set communication bloc reference for command sending
  void _onSetCommunicationBloc(
    MachineControllerSetCommunicationBloc event,
    Emitter<MachineControllerState> emit,
  ) {
    // Cancel existing subscription if any
    _messageStreamSubscription?.cancel();

    _communicationBloc = event.communicationBloc;
    AppLogger.machineDebug(
      'Communication bloc reference set in machine controller',
    );

    // Start listening to message stream for real-time processing
    if (_communicationBloc?.messageStream != null) {
      _messageStreamSubscription = _communicationBloc.messageStream.listen(
        (message) => _processStreamMessage(message),
        onError: (error) =>
            AppLogger.machineError('Message stream error: $error'),
      );
      AppLogger.machineDebug(
        'Started listening to communication message stream',
      );
    }
  }

  /// Set alarm/error bloc reference for metadata lookup
  void _onSetAlarmErrorBloc(
    MachineControllerSetAlarmErrorBloc event,
    Emitter<MachineControllerState> emit,
  ) {
    _alarmErrorBloc = event.alarmErrorBloc;
    AppLogger.machineDebug(
      'Alarm/Error bloc reference set in machine controller',
    );
  }

  /// Handle problems bloc reference setup
  void _onSetProblemsBloc(
    MachineControllerSetProblemsBloc event,
    Emitter<MachineControllerState> emit,
  ) {
    _problemsBloc = event.problemsBloc;
    AppLogger.machineDebug(
      'Problems bloc reference set in machine controller',
    );
  }

  /// Handle grblHAL detection
  void _onGrblHalDetected(
    MachineControllerGrblHalDetected event,
    Emitter<MachineControllerState> emit,
  ) {
    AppLogger.machineInfo('🚨 DEBUG: _onGrblHalDetected handler called!');
    AppLogger.machineInfo(
      'grblHAL controller detected: ${event.firmwareVersion}',
    );
    AppLogger.machineInfo('Welcome message: "${event.welcomeMessage.trim()}"');

    // Cancel timeout since grblHAL was detected successfully
    _cancelGrblHalDetectionTimeout();

    emit(
      state.copyWith(
        grblHalDetected: true,
        grblHalVersion: event.firmwareVersion,
        grblHalDetectedAt: event.timestamp,
      ),
    );

    // Configure grblHAL for optimal status reporting
    _configureGrblHalReporting();
  }

  /// Configure grblHAL for optimal status reporting
  /// Status polling will only start after initialization responses are received
  void _configureGrblHalReporting() {
    if (_communicationBloc == null) {
      AppLogger.machineError(
        'Cannot configure grblHAL - no communication bloc reference',
      );
      return;
    }

    AppLogger.machineInfo('Configuring grblHAL for optimal reporting - status polling will start after responses received');
    
    // Reset initialization state
    _initializationComplete = false;
    _configMessagesReceived = 0;
    _statusPollingStarted = false;

    // Send grblHAL configuration commands directly
    AppLogger.machineInfo('Sending grblHAL initialization sequence with context info...');
    AppLogger.machineInfo('1. Requesting complete real-time report (0x87)');
    _communicationBloc.add(CncCommunicationSendRawBytes([0x87]));

    // Request all context information early - available regardless of alarm/error state
    AppLogger.machineInfo('2. Requesting settings metadata (\$ES) for enhanced UI');
    _communicationBloc.add(CncCommunicationSendCommand('\$ES'));
    
    AppLogger.machineInfo('3. Requesting settings groups (\$EG) for organization');
    _communicationBloc.add(CncCommunicationSendCommand('\$EG'));
    
    AppLogger.machineInfo('4. Requesting alarm metadata (\$EA) for enhanced error reporting');
    _communicationBloc.add(CncCommunicationSendCommand('\$EA'));
    
    AppLogger.machineInfo('5. Requesting error metadata (\$EE) for enhanced error reporting');
    _communicationBloc.add(CncCommunicationSendCommand('\$EE'));
    
    AppLogger.machineInfo('6. Requesting alarm groups (\$EAG) for categorization');
    _communicationBloc.add(CncCommunicationSendCommand('\$EAG'));
    
    AppLogger.machineInfo('7. Requesting error groups (\$EEG) for categorization');
    _communicationBloc.add(CncCommunicationSendCommand('\$EEG'));

    // Configure status reporting mask ($10 setting)
    // Set $10=511 for comprehensive status reporting (all flags enabled)
    AppLogger.machineInfo('8. Setting comprehensive status reporting (\$10=511)');
    _communicationBloc.add(CncCommunicationSendCommand('\$10=511'));

    // Query machine configuration (machine state only)
    AppLogger.machineInfo('9. Requesting machine settings (\$\$) for machine state');
    _configMessagesReceived = 0; // Reset counter
    _communicationBloc.add(CncCommunicationSendCommand('\$\$'));
    
    // Set a timer to check if we received config messages
    Timer(const Duration(seconds: 5), () {
      AppLogger.machineInfo('Configuration query timeout check - received $_configMessagesReceived config messages');
      if (_configMessagesReceived == 0) {
        AppLogger.machineWarning('No configuration messages received - check grblHAL firmware version');
      }
    });

    // Query build info and plugins to detect board capabilities
    AppLogger.machineInfo('10. Requesting build info and plugins (\$I)');
    _communicationBloc.add(CncCommunicationSendCommand('\$I'));

    // Send initial status query to get immediate state
    AppLogger.machineInfo('11. Requesting initial status (0x80)');
    _communicationBloc.add(CncCommunicationSendRawBytes([0x80]));

    // Start initialization timeout - status polling will only start after responses received
    AppLogger.machineInfo('12. Starting initialization timeout - waiting for responses before status polling');
    _startInitializationTimeout();

    // NOTE: Status polling is now deferred until initialization responses are confirmed
    // This prevents flooding an unresponsive controller with 8ms status requests
  }



  /// Handle machine configuration received from $ command parsing
  void _onConfigurationReceived(
    MachineControllerConfigurationReceived event,
    Emitter<MachineControllerState> emit,
  ) {
    // Configuration received - log only final complete configuration
    if (event.configuration.settings.length > 130) {
      AppLogger.machineInfo('Machine configuration loaded: ${event.configuration.settings.length} settings');
    }

    // Merge incoming configuration with existing configuration
    final currentConfig = state.configuration;
    final MachineConfiguration mergedConfig;
    
    if (currentConfig == null) {
      mergedConfig = event.configuration;
    } else {
      final mergedSettings = Map<int, ConfigurationSetting>.from(currentConfig.settings);
      
      mergedSettings.addAll(event.configuration.settings);
      
      mergedConfig = MachineConfiguration(
        settings: mergedSettings,
        lastUpdated: event.timestamp,
        isComplete: mergedSettings.isNotEmpty,
        firmwareVersion: event.configuration.firmwareVersion ?? currentConfig.firmwareVersion,
      );
    }

    emit(
      state.copyWith(
        configuration: mergedConfig,
        lastUpdateTime: event.timestamp,
      ),
    );
  }

  /// Handle buffer status update
  void _onBufferStatusUpdated(
    MachineControllerBufferStatusUpdated event,
    Emitter<MachineControllerState> emit,
  ) {
    // Capture max buffer size from first idle state seen
    int? maxBuffer = state.maxObservedBufferBlocks;
    if (maxBuffer == null && state.status == MachineStatus.idle) {
      maxBuffer = event.plannerBlocksAvailable;
    }
    
    emit(
      state.copyWith(
        plannerBlocksAvailable: event.plannerBlocksAvailable,
        rxBytesAvailable: event.rxBytesAvailable,
        maxObservedBufferBlocks: maxBuffer,
        lastUpdateTime: event.timestamp,
      ),
    );
  }

  /// Handle plugins detected from $I command
  void _onPluginsDetected(
    MachineControllerPluginsDetected event,
    Emitter<MachineControllerState> emit,
  ) {
    // Check for Sienci Indicator Lights plugin specifically
    final hasSienciPlugin = event.plugins.any((plugin) => 
        plugin.toLowerCase().contains('sienci') && 
        plugin.toLowerCase().contains('indicator'));
        
    // Only log when we have a significant change or final plugin list
    final previousPluginCount = state.plugins.length;
    final hadSienciPlugin = state.hasSienciIndicatorPlugin;
    
    if (event.plugins.isNotEmpty && (hasSienciPlugin != hadSienciPlugin || event.plugins.length > previousPluginCount + 3)) {
      AppLogger.machineInfo('Detected ${event.plugins.length} plugins${hasSienciPlugin ? ' (including Sienci LED support)' : ''}');
    }
    
    emit(
      state.copyWith(
        plugins: event.plugins,
        lastUpdateTime: event.timestamp,
      ),
    );
  }

  /// Handle firmware welcome message received
  void _onFirmwareWelcomeReceived(
    MachineControllerFirmwareWelcomeReceived event,
    Emitter<MachineControllerState> emit,
  ) {
    AppLogger.machineInfo('Firmware welcome message received - tracking for unresponsive detection');
    
    // Start firmware unresponsive detection timer
    _startFirmwareUnresponsiveDetectionTimer();
    
    emit(
      state.copyWith(
        firmwareWelcomeReceivedAt: event.timestamp,
        lastUpdateTime: event.timestamp,
      ),
    );
  }


  /// Start grblHAL detection timeout
  /// A correctly functioning grblHAL system automatically sends a welcome message upon connection.
  /// If no welcome message is received within 5 seconds, this indicates either:
  /// 1. The controller is unresponsive but is still accepting connections (zombie state)
  /// 2. The firmware is standard GRBL (not grblHAL) which this sender doesn't support
  /// 3. Network/communication issues preventing message delivery
  void _startGrblHalDetectionTimeout() {
    _cancelGrblHalDetectionTimeout();

    AppLogger.machineInfo('Starting grblHAL detection timeout (5 seconds)');
    _grblHalDetectionTimeout = Timer(const Duration(seconds: 5), () {
      if (!state.grblHalDetected) {
        AppLogger.machineError(
          'grblHAL not detected within timeout - this sender requires grblHAL firmware',
        );
        AppLogger.machineError(
          'This may indicate an unresponsive controller, standard GRBL firmware, or communication issues',
        );

        // Create problem entry for non-grblHAL system
        if (_problemsBloc != null) {
          final problem = ProblemFactory.cncNotGrblHalSystem();
          _problemsBloc.add(ProblemAdded(problem));
          AppLogger.machineInfo('Created grblHAL detection timeout problem: ${problem.id}');
        }

        // Disconnect since we only support grblHAL
        if (_communicationBloc != null) {
          _communicationBloc.add(CncCommunicationDisconnectRequested());
        }

        // Update machine controller state to reflect disconnection and error
        add(
          MachineControllerConnectionChanged(
            isOnline: false,
            timestamp: DateTime.now(),
          ),
        );

        // Update firmware version to show error
        add(
          MachineControllerInfoUpdated(
            firmwareVersion:
                'ERROR: grblHAL required - Standard GRBL not supported',
          ),
        );
      }
    });
  }

  /// Cancel grblHAL detection timeout
  void _cancelGrblHalDetectionTimeout() {
    _grblHalDetectionTimeout?.cancel();
    _grblHalDetectionTimeout = null;
  }

  /// Start initialization response timeout
  /// Monitors for configuration and status responses after grblHAL detection
  /// If no responses received within timeout, creates "grblHAL unresponsive" problem
  void _startInitializationTimeout() {
    _cancelInitializationTimeout();

    AppLogger.machineInfo('Starting initialization response timeout (15 seconds)');
    _initializationTimeout = Timer(const Duration(seconds: 15), () {
      if (!_initializationComplete) {
        AppLogger.machineError(
          'grblHAL initialization timeout - received $_configMessagesReceived config messages, '
          'status polling: $_statusPollingStarted',
        );
        AppLogger.machineError(
          'grblHAL appears unresponsive to configuration commands after successful welcome message',
        );

        // Create problem entry for grblHAL unresponsive during initialization
        if (_problemsBloc != null) {
          final problem = ProblemFactory.cncInitializationTimeout(
            configMessagesReceived: _configMessagesReceived,
          );
          _problemsBloc.add(ProblemAdded(problem));
          AppLogger.machineInfo('Created initialization timeout problem: ${problem.id}');
        }
        if (_communicationBloc != null) {
          _communicationBloc.add(CncCommunicationDisconnectRequested());
        }

        // Update machine controller state to reflect disconnection and error
        add(
          MachineControllerConnectionChanged(
            isOnline: false,
            timestamp: DateTime.now(),
          ),
        );
      }
    });
  }

  /// Cancel initialization timeout
  void _cancelInitializationTimeout() {
    _initializationTimeout?.cancel();
    _initializationTimeout = null;
  }

  /// Check if initialization is complete and start status polling if ready
  void _checkInitializationProgress() {
    if (_initializationComplete || _statusPollingStarted) {
      return; // Already complete or polling already started
    }

    // Check if we have received sufficient responses to consider initialization complete
    // Minimum requirements:
    // 1. At least some configuration messages (indicates controller is responding)
    // 2. At least one status response OR enough config messages to indicate activity
    bool hasConfigResponse = _configMessagesReceived > 0;
    bool hasStatusResponse = state.lastStatusReceivedAt != null;
    bool hasMinimalResponse = _configMessagesReceived >= 5; // Reasonable threshold

    if (hasConfigResponse && (hasStatusResponse || hasMinimalResponse)) {
      AppLogger.machineInfo(
        'Initialization complete - received $_configMessagesReceived config messages, '
        'status response: ${hasStatusResponse ? 'yes' : 'no'}',
      );
      
      _initializationComplete = true;
      _cancelInitializationTimeout();
      
      // Now safe to start status polling
      _startStatusPolling();
    } else {
      AppLogger.machineDebug(
        'Initialization progress - config: $_configMessagesReceived, '
        'status: ${hasStatusResponse ? 'received' : 'pending'}',
      );
    }
  }

  /// Start continuous status polling after initialization is confirmed
  void _startStatusPolling() {
    if (_statusPollingStarted || _communicationBloc == null) {
      return;
    }

    AppLogger.machineInfo('Starting continuous status polling - initialization confirmed');
    _statusPollingStarted = true;
    
    _communicationBloc.add(
      CncCommunicationPollingControlRequested(
        enable: true,
        rawCommand: [0x80], // grblHAL preferred status request
      ),
    );
  }

  /// Start firmware unresponsive detection timer
  /// Checks periodically if firmware appears to be unresponsive after sending welcome message
  void _startFirmwareUnresponsiveDetectionTimer() {
    _cancelFirmwareUnresponsiveDetectionTimer();

    AppLogger.machineInfo('Starting firmware unresponsive detection timer');
    _firmwareUnresponsiveDetectionTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (state.hasSuspectedUnresponsiveFirmware) {
        AppLogger.machineWarning('Firmware unresponsive detected: Welcome received but no status updates');
        // Unresponsive detection is now purely computed - no event needed since Problems bloc 
        // can detect this directly from state.hasSuspectedUnresponsiveFirmware
      }
      
      // Stop timer if no longer needed
      if (state.lastStatusReceivedAt != null || !state.grblHalDetected) {
        _cancelFirmwareUnresponsiveDetectionTimer();
      }
    });
  }

  /// Cancel firmware unresponsive detection timer
  void _cancelFirmwareUnresponsiveDetectionTimer() {
    _firmwareUnresponsiveDetectionTimer?.cancel();
    _firmwareUnresponsiveDetectionTimer = null;
  }

  @override
  void onTransition(
    Transition<MachineControllerEvent, MachineControllerState> transition,
  ) {
    super.onTransition(transition);
    final currentStatus = transition.currentState.status;
    final nextStatus = transition.nextState.status;

    if (currentStatus != nextStatus) {
      AppLogger.machineDebug(
        'Machine status changed: ${currentStatus.name} -> ${nextStatus.name}',
      );
    }
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    super.onError(error, stackTrace);
    AppLogger.machineError('MachineControllerBloc error', error, stackTrace);
  }

  // Jog Control Event Handlers

  /// Handle discrete jog request (move specific distance)
  void _onJogRequested(
    MachineControllerJogRequested event,
    Emitter<MachineControllerState> emit,
  ) {
    if (!_canJog()) {
      AppLogger.machineWarning(
        'Cannot jog - machine not in valid state: ${state.status.displayName}',
      );
      return;
    }

    if (_communicationBloc == null) {
      AppLogger.machineError('Cannot jog - no communication bloc reference');
      return;
    }

    // Build GRBL jog command with G91 incremental mode and G21 metric units
    // Format: $J=G91 G21 X10.0 F500 (jog X axis +10.0mm incrementally at 500mm/min)
    final jogCommand =
        '\$J=G91 G21 ${event.axis}${event.distance} F${event.feedRate}';

    _logJogCommand('Jogging ${event.axis}${event.distance} at ${event.feedRate}mm/min');
    _communicationBloc.add(CncCommunicationSendCommand(jogCommand));

    // Update state to indicate jogging
    emit(state.copyWith(lastUpdateTime: DateTime.now()));
  }

  /// Handle jog stop request
  void _onJogStopRequested(
    MachineControllerJogStopRequested event,
    Emitter<MachineControllerState> emit,
  ) {
    if (_communicationBloc == null) {
      AppLogger.machineError(
        'Cannot stop jog - no communication bloc reference',
      );
      return;
    }

    // Send jog cancel command (0x85 for grblHAL real-time command)
    _logJogCommand('Jog cancelled', forceLog: true);
    _communicationBloc.add(CncCommunicationSendRawBytes([0x85]));

    emit(state.copyWith(lastUpdateTime: DateTime.now()));
  }

  /// Handle continuous jog start (for hold-down buttons)
  void _onContinuousJogStarted(
    MachineControllerContinuousJogStarted event,
    Emitter<MachineControllerState> emit,
  ) {
    if (!_canJog()) {
      AppLogger.machineWarning(
        'Cannot start continuous jog - machine not in valid state: ${state.status.displayName}',
      );
      return;
    }

    if (_communicationBloc == null) {
      AppLogger.machineError(
        'Cannot start continuous jog - no communication bloc reference',
      );
      return;
    }

    // For continuous jog, send a long distance in the specified direction
    // grblHAL will stop when the jog cancel is received
    final distance = event.positive ? '1000' : '-1000'; // Large distance
    final jogCommand = '\$J=G91 G21 ${event.axis}$distance F${event.feedRate}';

    final direction = event.positive ? '+' : '-';
    _logJogCommand('Continuous jog started: ${event.axis}$direction at ${event.feedRate}mm/min', forceLog: true);
    _communicationBloc.add(CncCommunicationSendCommand(jogCommand));

    emit(state.copyWith(lastUpdateTime: DateTime.now()));
  }

  /// Handle continuous jog stop (for button release)
  void _onContinuousJogStopped(
    MachineControllerContinuousJogStopped event,
    Emitter<MachineControllerState> emit,
  ) {
    // Same as regular jog stop
    _onJogStopRequested(const MachineControllerJogStopRequested(), emit);
  }

  /// Handle multi-axis jog request for smooth diagonal movement
  void _onMultiAxisJogRequested(
    MachineControllerMultiAxisJogRequested event,
    Emitter<MachineControllerState> emit,
  ) {
    if (!_canJog()) {
      AppLogger.machineWarning(
        'Cannot multi-axis jog - machine not in valid state: ${state.status.displayName}',
      );
      return;
    }

    if (_communicationBloc == null) {
      AppLogger.machineError('Cannot multi-axis jog - no communication bloc reference');
      return;
    }

    // Build GRBL multi-axis jog command
    // Format: $J=G91 G21 X[xDist] Y[yDist] Z[zDist] F[feedRate]
    List<String> axisParts = [];
    
    if (event.xDistance != 0.0) {
      axisParts.add('X${event.xDistance}');
    }
    
    if (event.yDistance != 0.0) {
      axisParts.add('Y${event.yDistance}');
    }
    
    if (event.zDistance != null && event.zDistance != 0.0) {
      axisParts.add('Z${event.zDistance}');
    }
    
    // Only send command if at least one axis has movement
    if (axisParts.isEmpty) {
      AppLogger.machineWarning('Multi-axis jog requested with no axis movement');
      return;
    }
    
    final jogCommand = '\$J=G91 G21 ${axisParts.join(' ')} F${event.feedRate}';
    
    _logJogCommand('Multi-axis jog: ${axisParts.join(' ')} at ${event.feedRate}mm/min');
    _communicationBloc.add(CncCommunicationSendCommand(jogCommand));

    // Update state to indicate jogging
    emit(state.copyWith(lastUpdateTime: DateTime.now()));
  }

  /// Process individual status message (for stream processing)
  void _processStatusMessage(String message, DateTime timestamp) {
    // Remove "Received: " prefix if present
    final cleanMessage = message.startsWith('Received: ')
        ? message.substring(10)
        : message;

    // Check for firmware welcome messages (grblHAL sends these on startup)
    if (cleanMessage.toLowerCase().contains('grbl') && 
        (cleanMessage.toLowerCase().contains('hal') || cleanMessage.toLowerCase().contains('ready'))) {
      add(MachineControllerFirmwareWelcomeReceived(timestamp: timestamp));
    }

    // Check for alarm messages like "ALARM:1" 
    final alarmMatch = RegExp(r'ALARM:(\d+)', caseSensitive: false).firstMatch(cleanMessage);
    if (alarmMatch != null) {
      final alarmCode = int.tryParse(alarmMatch.group(1)!);
      if (alarmCode != null) {
        AppLogger.machineWarning('Extracted alarm code: $alarmCode');
        add(MachineControllerAlarmConditionAdded(
          alarmCode: alarmCode,
          rawMessage: cleanMessage,
          timestamp: timestamp,
        ));
        return; // Don't process as regular status message
      }
    }

    // Parse status message like: <Idle|MPos:0.000,0.000,0.000|...>
    final statusMatch = RegExp(r'<([^|]+)').firstMatch(cleanMessage);
    if (statusMatch == null) return;

    final statusString = statusMatch.group(1)!;
    final machineStatus = _parseMachineStatus(statusString);

    // Parse coordinates and other data from the full message
    _parseStatusDetailsForStream(cleanMessage, machineStatus, timestamp);
    
    // Check if we can now start status polling (if not already started)
    _checkInitializationProgress();
  }

  /// Process individual configuration message (for stream processing)
  void _processConfigurationMessage(String message, DateTime timestamp) {
    _configMessagesReceived++;
    // Configuration messages processed silently to avoid log spam
    
    // Check if we can now start status polling
    _checkInitializationProgress();
    
    // Remove "Received: " prefix if present
    final cleanMessage = message.startsWith('Received: ')
        ? message.substring(10)
        : message;

    // Message cleaning logged silently to avoid spam

    // Parse configuration line like: $0=10 (Step pulse time)
    _parseConfigurationLineForStream(cleanMessage, timestamp);
  }

  /// Process individual welcome message (for stream processing)
  void _processWelcomeMessage(String message, DateTime timestamp) {
    // Remove "Received: " prefix if present
    final cleanMessage = message.startsWith('Received: ')
        ? message.substring(10)
        : message;


    // Check for grblHAL welcome patterns
    if (!state.grblHalDetected) {
      _checkSingleMessageForGrblHal(cleanMessage, timestamp);
    }

    // Parse firmware information
    _parseFirmwareInfoForStream(cleanMessage, timestamp);
  }

  /// Process acknowledgment message (for stream processing)
  void _processAcknowledgment(String message, DateTime timestamp) {
    // Handle "ok" responses - these confirm command completion
    // (no logging needed for normal acknowledgments)
  }

  /// Process error message (for stream processing)
  void _processErrorMessage(String message, DateTime timestamp) {
    // Remove "Received: " prefix if present
    final cleanMessage = message.startsWith('Received: ')
        ? message.substring(10)
        : message;

    AppLogger.machineError('CNC Error received: $cleanMessage');

    // Try to extract error code for enhanced metadata lookup
    final errorCodeMatch = RegExp(r'error:(\d+)', caseSensitive: false).firstMatch(cleanMessage);
    if (errorCodeMatch != null) {
      final errorCode = int.tryParse(errorCodeMatch.group(1)!);
      if (errorCode != null) {
        AppLogger.machineError('Extracted error code: $errorCode');
        add(MachineControllerErrorConditionAdded(
          errorCode: errorCode,
          rawMessage: cleanMessage,
          timestamp: timestamp,
        ));
      }
    }

    // Add error to state (legacy format)
    add(MachineControllerErrorAdded(error: cleanMessage, timestamp: timestamp));
  }

  /// Process build info and plugin information from $I command (for stream processing)
  void _processBuildInfoMessage(String message, DateTime timestamp) {
    // Remove "Received: " prefix if present
    final cleanMessage = message.startsWith('Received: ')
        ? message.substring(10)
        : message;

    // Look for plugin information in format [PLUGIN:Name]
    final pluginMatch = RegExp(r'\[PLUGIN:([^\]]+)\]').allMatches(cleanMessage);
    if (pluginMatch.isNotEmpty) {
      final newPlugins = pluginMatch.map((match) => match.group(1)!.trim()).toList();
      
      // Accumulate plugins instead of overwriting
      final currentPlugins = List<String>.from(state.plugins);
      for (final plugin in newPlugins) {
        if (!currentPlugins.contains(plugin)) {
          currentPlugins.add(plugin);
        }
      }
      
      // Update state with accumulated plugins
      add(MachineControllerPluginsDetected(plugins: currentPlugins, timestamp: timestamp));
    }
    
    // Also check for board information in format [BOARD:Name]
    final boardMatch = RegExp(r'\[BOARD:([^\]]+)\]').firstMatch(cleanMessage);
    if (boardMatch != null) {
      final boardName = boardMatch.group(1)!.trim();
      AppLogger.machineInfo('Detected board: $boardName');
    }
  }

  /// Parse a single configuration line (for stream processing)
  void _parseConfigurationLineForStream(String line, DateTime timestamp) {
    // Debug: Log the raw line being parsed
    // Config line parsing logged silently to avoid spam
    
    final match = RegExp(
      r'^\$(\d+)=([^(]+)(?:\((.+)\))?',
    ).firstMatch(line.trim());
    
    if (match == null) {
      AppLogger.machineDebug('No regex match for line: "$line"');
      return;
    }

    final settingId = int.tryParse(match.group(1)!);
    final value = match.group(2)!.trim();
    final description = match.group(3)?.trim();

    if (settingId == null) {
      AppLogger.machineDebug('Failed to parse setting ID from: "${match.group(1)}"');
      return;
    }

    // Parsing details logged silently to avoid spam

    // Log travel limit settings specifically for work envelope debugging
    // All configuration settings processed silently to avoid log spam

    // Update configuration incrementally
    final currentConfig = state.configuration;
    final newSettings = Map<int, ConfigurationSetting>.from(
      currentConfig?.settings ?? {},
    );

    newSettings[settingId] = ConfigurationSetting(
      number: settingId,
      rawValue: value,
      description: description ?? 'Setting $settingId',
      lastUpdated: timestamp,
    );

    final newConfig = MachineConfiguration(
      settings: newSettings,
      firmwareVersion: currentConfig?.firmwareVersion,
      lastUpdated: timestamp,
    );

    // Check work envelope status when we have all travel limits  
    if (settingId == 130 || settingId == 131 || settingId == 132) {
      final xTravel = newConfig.xMaxTravel;
      final yTravel = newConfig.yMaxTravel;
      final zTravel = newConfig.zMaxTravel;
      
      // Only log when we have all three limits
      if (xTravel != null && yTravel != null && zTravel != null) {
        AppLogger.machineInfo('Work envelope ready: X=$xTravel, Y=$yTravel, Z=$zTravel');
      }
    }

    // Emit configuration received event
    add(
      MachineControllerConfigurationReceived(
        configuration: newConfig,
        timestamp: timestamp,
      ),
    );

  }

  /// Check a single message for grblHAL patterns
  void _checkSingleMessageForGrblHal(String message, DateTime timestamp) {
    if (_isGrblHalMessage(message)) {
      final version = _extractGrblHalVersion(message);
      AppLogger.machineInfo(
        'grblHAL detected: $version from message: "$message"',
      );

      add(
        MachineControllerGrblHalDetected(
          welcomeMessage: message,
          firmwareVersion: version,
          timestamp: timestamp,
        ),
      );
    }
  }

  /// Parse firmware information from welcome messages (for stream processing)
  void _parseFirmwareInfoForStream(String message, DateTime timestamp) {
    // Look for firmware version patterns in the message
    String? firmwareVersion;

    // Try GrblHAL version patterns
    final grblHalMatch = RegExp(
      r'GrblHAL\s+(\d+\.\d+[a-z]?)',
    ).firstMatch(message);
    if (grblHalMatch != null) {
      firmwareVersion = 'GrblHAL ${grblHalMatch.group(1)}';
    } else {
      // Try standard GRBL version patterns
      final grblMatch = RegExp(r'Grbl\s+(\d+\.\d+[a-z]?)').firstMatch(message);
      if (grblMatch != null) {
        firmwareVersion = 'Grbl ${grblMatch.group(1)}';
      }
    }

    if (firmwareVersion != null) {
      AppLogger.machineInfo('Firmware version detected: $firmwareVersion');

      // Update configuration with firmware version
      final currentConfig = state.configuration;
      final newConfig = MachineConfiguration(
        settings: currentConfig?.settings ?? {},
        firmwareVersion: firmwareVersion,
        lastUpdated: timestamp,
      );

      // Emit configuration received event
      add(
        MachineControllerConfigurationReceived(
          configuration: newConfig,
          timestamp: timestamp,
        ),
      );
    }
  }

  /// Parse machine status from status string
  MachineStatus _parseMachineStatus(String statusString) {
    final lowerStatus = statusString.toLowerCase();

    if (lowerStatus.startsWith('idle')) {
      return MachineStatus.idle;
    } else if (lowerStatus.startsWith('run')) {
      return MachineStatus.running;
    } else if (lowerStatus.startsWith('jog')) {
      return MachineStatus.jogging;
    } else if (lowerStatus.startsWith('hold')) {
      return MachineStatus.hold;
    } else if (lowerStatus.startsWith('alarm')) {
      // Extract alarm code from status string like "Alarm:11" or "alarm"
      final alarmCodeMatch = RegExp(r'alarm:?(\d+)', caseSensitive: false).firstMatch(statusString);
      if (alarmCodeMatch != null) {
        final alarmCode = int.tryParse(alarmCodeMatch.group(1)!);
        if (alarmCode != null) {
          // Trigger alarm condition with metadata instead of just setting status
          add(MachineControllerAlarmConditionAdded(
            alarmCode: alarmCode,
            rawMessage: 'Alarm:$alarmCode',
            timestamp: DateTime.now(),
          ));
          AppLogger.machineWarning('Status alarm detected: Code $alarmCode');
        }
      }
      return MachineStatus.alarm;
    } else if (lowerStatus.startsWith('door') || lowerStatus.contains('door')) {
      return MachineStatus.door;
    } else if (lowerStatus.startsWith('check')) {
      return MachineStatus.check;
    } else if (lowerStatus.startsWith('home')) {
      return MachineStatus.homing;
    } else {
      return MachineStatus.unknown;
    }
  }

  /// Parse status details from full status message (for stream processing)
  void _parseStatusDetailsForStream(
    String statusMessage,
    MachineStatus status,
    DateTime timestamp,
  ) {
    // Parse coordinates, feed rate, spindle speed from status message
    // Format: <Idle|MPos:0.000,0.000,0.000|WPos:0.000,0.000,0.000|FS:0,0|Ov:100,100,100>

    MachineCoordinates? machinePos;
    MachineCoordinates? workPos;
    double? feedRate;
    double? spindleSpeed;
    int? plannerBlocks;
    int? rxBytes;

    // Parse machine position
    final mPosMatch = RegExp(
      r'MPos:([0-9.-]+),([0-9.-]+),([0-9.-]+)',
    ).firstMatch(statusMessage);
    if (mPosMatch != null) {
      machinePos = MachineCoordinates(
        x: double.tryParse(mPosMatch.group(1)!) ?? 0.0,
        y: double.tryParse(mPosMatch.group(2)!) ?? 0.0,
        z: double.tryParse(mPosMatch.group(3)!) ?? 0.0,
        lastUpdated: timestamp,
      );
    }

    // Parse work position
    final wPosMatch = RegExp(
      r'WPos:([0-9.-]+),([0-9.-]+),([0-9.-]+)',
    ).firstMatch(statusMessage);
    if (wPosMatch != null) {
      workPos = MachineCoordinates(
        x: double.tryParse(wPosMatch.group(1)!) ?? 0.0,
        y: double.tryParse(wPosMatch.group(2)!) ?? 0.0,
        z: double.tryParse(wPosMatch.group(3)!) ?? 0.0,
        lastUpdated: timestamp,
      );
    }

    // Parse feed and spindle rates
    final fsMatch = RegExp(
      r'FS:([0-9.-]+),([0-9.-]+)',
    ).firstMatch(statusMessage);
    if (fsMatch != null) {
      feedRate = double.tryParse(fsMatch.group(1)!);
      spindleSpeed = double.tryParse(fsMatch.group(2)!);
    }

    // Parse buffer status
    final bfMatch = RegExp(
      r'Bf:([0-9]+),([0-9]+)',
    ).firstMatch(statusMessage);
    if (bfMatch != null) {
      plannerBlocks = int.tryParse(bfMatch.group(1)!);
      rxBytes = int.tryParse(bfMatch.group(2)!);
    }

    // Emit status update events instead of direct state changes
    add(MachineControllerStatusUpdated(status: status, timestamp: timestamp));

    if (workPos != null || machinePos != null) {
      add(
        MachineControllerCoordinatesUpdated(
          workPosition: workPos,
          machinePosition: machinePos,
          timestamp: timestamp,
        ),
      );
    }

    if (feedRate != null) {
      add(
        MachineControllerFeedUpdated(
          feedState: FeedState(
            rate: feedRate,
            targetRate: feedRate,
            lastUpdated: timestamp,
          ),
          timestamp: timestamp,
        ),
      );
    }

    if (spindleSpeed != null) {
      add(
        MachineControllerSpindleUpdated(
          spindleState: SpindleState(
            isRunning: spindleSpeed > 0,
            speed: spindleSpeed,
            targetSpeed: spindleSpeed,
            lastUpdated: timestamp,
          ),
          timestamp: timestamp,
        ),
      );
    }

    if (plannerBlocks != null && rxBytes != null) {
      add(
        MachineControllerBufferStatusUpdated(
          plannerBlocksAvailable: plannerBlocks,
          rxBytesAvailable: rxBytes,
          timestamp: timestamp,
        ),
      );
    }

  }

  /// Check if message contains grblHAL patterns
  bool _isGrblHalMessage(String message) {
    final lowerMessage = message.toLowerCase();
    return lowerMessage.contains('grblhal') ||
        lowerMessage.contains('grbl hal') ||
        (lowerMessage.contains('grbl') && lowerMessage.contains('hal'));
  }

  /// Extract grblHAL version from message
  String _extractGrblHalVersion(String message) {
    final versionMatch = RegExp(
      r'GrblHAL\s+(\d+\.\d+[a-z]?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (versionMatch != null) {
      return versionMatch.group(1)!;
    }

    // Try to extract just GRBL version if grblHAL version not found
    final grblMatch = RegExp(
      r'Grbl\s+(\d+\.\d+[a-z]?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (grblMatch != null) {
      return grblMatch.group(1)!;
    }

    return 'unknown';
  }

  /// Log jog command with throttling to avoid spam during continuous jogging
  void _logJogCommand(String message, {bool forceLog = false}) {
    final now = DateTime.now();
    
    // Log immediately if forced, or if enough time has passed since last log
    if (forceLog || 
        _lastJogLogTime == null || 
        now.difference(_lastJogLogTime!).inSeconds >= 3) {
      AppLogger.machineInfo(message);
      _lastJogLogTime = now;
    }
  }

  /// Check if machine is in a valid state for jogging
  bool _canJog() {
    if (!state.hasController || !state.isOnline) {
      AppLogger.machineWarning(
        'Cannot jog - controller not available or offline',
      );
      return false;
    }

    if (!state.grblHalDetected) {
      AppLogger.machineWarning('Cannot jog - grblHAL not detected');
      return false;
    }

    // Only allow jogging in Idle, Jog, or Check states
    final currentStatus = state.status;
    final canJog =
        currentStatus == MachineStatus.idle ||
        currentStatus == MachineStatus.jogging ||
        currentStatus == MachineStatus.check;

    if (!canJog) {
      AppLogger.machineWarning(
        'Cannot jog - machine in invalid state: ${currentStatus.displayName}',
      );
    }

    return canJog;
  }

  /// Process message received from communication stream
  void _processStreamMessage(dynamic message) {
    // Handle CncMessage from the stream
    if (message is! CncMessage) {
      AppLogger.machineWarning(
        'Received non-CncMessage from stream: ${message.runtimeType}',
      );
      return;
    }

    final cncMessage = message;

    // Route message by type for efficient processing
    switch (cncMessage.type) {
      case CncMessageType.status:
        _processStatusMessage(cncMessage.content, cncMessage.timestamp);
        break;
      case CncMessageType.configuration:
        _processConfigurationMessage(cncMessage.content, cncMessage.timestamp);
        break;
      case CncMessageType.welcome:
        _processWelcomeMessage(cncMessage.content, cncMessage.timestamp);
        break;
      case CncMessageType.acknowledgment:
        _processAcknowledgment(cncMessage.content, cncMessage.timestamp);
        break;
      case CncMessageType.error:
        _processErrorMessage(cncMessage.content, cncMessage.timestamp);
        break;
      case CncMessageType.other:
        // Check if this is build info or plugin information from $I command
        _processBuildInfoMessage(cncMessage.content, cncMessage.timestamp);
        break;
    }

    // FALLBACK: Force-parse any message that looks like a travel limit setting, 
    // regardless of classification (in case message type detection is wrong)
    if ((cncMessage.content.contains('130') || 
         cncMessage.content.contains('131') || 
         cncMessage.content.contains('132')) &&
        cncMessage.content.startsWith(r'$') && 
        cncMessage.content.contains('=')) {
      _parseConfigurationLineForStream(cncMessage.content, cncMessage.timestamp);
    }
  }

  @override
  Future<void> close() {
    _cancelGrblHalDetectionTimeout();
    _cancelFirmwareUnresponsiveDetectionTimer();
    _cancelInitializationTimeout();
    _messageStreamSubscription?.cancel();
    return super.close();
  }
}
