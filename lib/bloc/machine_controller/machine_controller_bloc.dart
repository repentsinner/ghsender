import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/machine_controller.dart';
import '../../models/machine_configuration.dart';
import '../../utils/logger.dart';
import 'machine_controller_event.dart';
import 'machine_controller_state.dart';
import '../communication/cnc_communication_state.dart';
import '../communication/cnc_communication_event.dart';

/// BLoC for managing machine controller state from CNC communication responses
class MachineControllerBloc
    extends Bloc<MachineControllerEvent, MachineControllerState> {
  // Reference to communication bloc for sending commands
  dynamic _communicationBloc;

  // Timer for grblHAL detection timeout
  Timer? _grblHalDetectionTimeout;

  // Stream subscription for real-time message processing
  StreamSubscription? _messageStreamSubscription;

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
    on<MachineControllerAlarmsCleared>(_onAlarmsCleared);
    on<MachineControllerErrorAdded>(_onErrorAdded);
    on<MachineControllerErrorsCleared>(_onErrorsCleared);
    on<MachineControllerInfoUpdated>(_onInfoUpdated);
    on<MachineControllerConnectionChanged>(_onConnectionChanged);
    on<MachineControllerReset>(_onReset);

    // grblHAL detection and configuration handlers
    on<MachineControllerGrblHalDetected>(_onGrblHalDetected);
    on<MachineControllerSetCommunicationBloc>(_onSetCommunicationBloc);
    on<MachineControllerConfigurationReceived>(_onConfigurationReceived);
    on<MachineControllerBufferStatusUpdated>(_onBufferStatusUpdated);

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
    // Cancel grblHAL detection timeout on disconnect
    _cancelGrblHalDetectionTimeout();

    if (state.controller != null) {
      final updatedController = state.controller!.copyWith(
        isOnline: false,
        lastCommunication: timestamp,
      );

      emit(
        state.copyWith(
          controller: updatedController,
          lastUpdateTime: timestamp,
        ),
      );

      AppLogger.machineInfo('Machine controller disconnected');
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

      emit(
        state.copyWith(
          controller: updatedController,
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

      AppLogger.machineInfo(
        'Machine connection changed: ${event.isOnline ? 'online' : 'offline'}',
      );

      // Stop polling when machine goes offline
      if (!event.isOnline && _communicationBloc != null) {
        AppLogger.machineInfo('Machine offline - stopping status polling');
        _communicationBloc.add(
          CncCommunicationPollingControlRequested(enable: false),
        );
      }
    }
  }

  /// Handle reset
  void _onReset(
    MachineControllerReset event,
    Emitter<MachineControllerState> emit,
  ) {
    emit(const MachineControllerState(isInitialized: true));
    AppLogger.machineInfo('Machine controller reset');
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

  /// Handle grblHAL detection
  void _onGrblHalDetected(
    MachineControllerGrblHalDetected event,
    Emitter<MachineControllerState> emit,
  ) {
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

  /// Configure grblHAL for optimal status reporting and start polling
  void _configureGrblHalReporting() {
    if (_communicationBloc == null) {
      AppLogger.machineError(
        'Cannot configure grblHAL - no communication bloc reference',
      );
      return;
    }

    AppLogger.machineInfo('=== CONFIGURING grblHAL STATUS REPORTING ===');

    // Send grblHAL configuration commands directly
    AppLogger.machineInfo(
      'MACHINE CONTROLLER: Sending 0x87 (enable extended status format)',
    );
    _communicationBloc.add(CncCommunicationSendRawBytes([0x87]));

    // Configure status reporting mask ($10 setting)
    // Set $10=511 for comprehensive status reporting (all flags enabled)
    AppLogger.machineInfo(
      'MACHINE CONTROLLER: Setting \$10=511 (enable comprehensive status reporting)',
    );
    _communicationBloc.add(CncCommunicationSendCommand('\$10=511'));

    // Query machine configuration to understand capabilities and settings
    AppLogger.machineInfo(
      'MACHINE CONTROLLER: Sending \$ (query configuration)',
    );
    _communicationBloc.add(CncCommunicationSendCommand('\$'));

    // Send initial status query to get immediate state
    AppLogger.machineInfo(
      'MACHINE CONTROLLER: Sending initial 0x80 (status query)',
    );
    _communicationBloc.add(CncCommunicationSendRawBytes([0x80]));

    // Start continuous status polling using CommunicationBloc
    AppLogger.machineInfo(
      'MACHINE CONTROLLER: Starting status polling with 0x80 at 125Hz',
    );
    _communicationBloc.add(
      CncCommunicationPollingControlRequested(
        enable: true,
        rawCommand: [0x80], // grblHAL preferred status request
      ),
    );
  }


  /// Handle machine configuration received from $ command parsing
  void _onConfigurationReceived(
    MachineControllerConfigurationReceived event,
    Emitter<MachineControllerState> emit,
  ) {
    AppLogger.machineInfo(
      'Machine configuration received: ${event.configuration.settings.length} settings',
    );

    emit(
      state.copyWith(
        configuration: event.configuration,
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

  /// Start grblHAL detection timeout
  void _startGrblHalDetectionTimeout() {
    _cancelGrblHalDetectionTimeout();

    AppLogger.machineInfo('Starting grblHAL detection timeout (5 seconds)');
    _grblHalDetectionTimeout = Timer(const Duration(seconds: 5), () {
      if (!state.grblHalDetected) {
        AppLogger.machineError(
          'grblHAL not detected within timeout - this sender requires grblHAL firmware',
        );

        // Disconnect since we only support grblHAL
        if (_communicationBloc != null) {
          _communicationBloc.add(CncCommunicationDisconnectRequested());
        }

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

    AppLogger.machineInfo('Sending jog command: $jogCommand');
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
    AppLogger.machineInfo('Sending jog cancel command');
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

    AppLogger.machineInfo('Starting continuous jog: $jogCommand');
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
    // Format: $J=G91 G21 X[xDist] Y[yDist] F[feedRate]
    List<String> axisParts = [];
    
    if (event.xDistance != 0.0) {
      axisParts.add('X${event.xDistance}');
    }
    
    if (event.yDistance != 0.0) {
      axisParts.add('Y${event.yDistance}');
    }
    
    // Only send command if at least one axis has movement
    if (axisParts.isEmpty) {
      AppLogger.machineWarning('Multi-axis jog requested with no axis movement');
      return;
    }
    
    final jogCommand = '\$J=G91 G21 ${axisParts.join(' ')} F${event.feedRate}';
    
    AppLogger.machineInfo('Sending multi-axis jog command: $jogCommand');
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


    // Parse status message like: <Idle|MPos:0.000,0.000,0.000|...>
    final statusMatch = RegExp(r'<([^|]+)').firstMatch(cleanMessage);
    if (statusMatch == null) return;

    final statusString = statusMatch.group(1)!;
    final machineStatus = _parseMachineStatus(statusString);

    // Parse coordinates and other data from the full message
    _parseStatusDetailsForStream(cleanMessage, machineStatus, timestamp);
  }

  /// Process individual configuration message (for stream processing)
  void _processConfigurationMessage(String message, DateTime timestamp) {
    // Remove "Received: " prefix if present
    final cleanMessage = message.startsWith('Received: ')
        ? message.substring(10)
        : message;

    AppLogger.machineDebug('Processing configuration message: $cleanMessage');

    // Parse configuration line like: $0=10 (Step pulse time)
    _parseConfigurationLineForStream(cleanMessage, timestamp);
  }

  /// Process individual welcome message (for stream processing)
  void _processWelcomeMessage(String message, DateTime timestamp) {
    // Remove "Received: " prefix if present
    final cleanMessage = message.startsWith('Received: ')
        ? message.substring(10)
        : message;

    AppLogger.machineDebug('Processing welcome message: $cleanMessage');

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
    AppLogger.machineDebug('Command acknowledged');
  }

  /// Process error message (for stream processing)
  void _processErrorMessage(String message, DateTime timestamp) {
    // Remove "Received: " prefix if present
    final cleanMessage = message.startsWith('Received: ')
        ? message.substring(10)
        : message;

    AppLogger.machineError('CNC Error received: $cleanMessage');

    // Add error to state
    add(MachineControllerErrorAdded(error: cleanMessage, timestamp: timestamp));
  }

  /// Parse a single configuration line (for stream processing)
  void _parseConfigurationLineForStream(String line, DateTime timestamp) {
    final match = RegExp(
      r'^\$(\d+)=([^(]+)(?:\((.+)\))?',
    ).firstMatch(line.trim());
    if (match == null) return;

    final settingId = int.tryParse(match.group(1)!);
    final value = match.group(2)!.trim();
    final description = match.group(3)?.trim();

    if (settingId == null) return;

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

    // Emit configuration received event
    add(
      MachineControllerConfigurationReceived(
        configuration: newConfig,
        timestamp: timestamp,
      ),
    );

    AppLogger.machineDebug(
      'Configuration setting updated: \$$settingId=$value',
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

  /// Check if machine is in a valid state for jogging
  bool _canJog() {
    AppLogger.machineDebug('Checking jog eligibility:');
    AppLogger.machineDebug('  hasController: ${state.hasController}');
    AppLogger.machineDebug('  isOnline: ${state.isOnline}');
    AppLogger.machineDebug(
      '  status: ${state.status.displayName} (${state.status.name})',
    );
    AppLogger.machineDebug('  grblHalDetected: ${state.grblHalDetected}');

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
        // Handle other message types as needed
        break;
    }
  }

  @override
  Future<void> close() {
    _cancelGrblHalDetectionTimeout();
    _messageStreamSubscription?.cancel();
    return super.close();
  }
}
