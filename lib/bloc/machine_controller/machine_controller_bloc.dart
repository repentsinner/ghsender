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
class MachineControllerBloc extends Bloc<MachineControllerEvent, MachineControllerState> {
  
  // Reference to communication bloc for sending commands
  dynamic _communicationBloc;
  
  // Timer for grblHAL detection timeout
  Timer? _grblHalDetectionTimeout;
  
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
    on<MachineControllerAutoReportingConfigured>(_onAutoReportingConfigured);
    on<MachineControllerConfigurationReceived>(_onConfigurationReceived);
    
    // Jog control handlers
    on<MachineControllerJogRequested>(_onJogRequested);
    on<MachineControllerJogStopRequested>(_onJogStopRequested);
    on<MachineControllerContinuousJogStarted>(_onContinuousJogStarted);
    on<MachineControllerContinuousJogStopped>(_onContinuousJogStopped);
    
    // Initialize in the next tick
    Future.delayed(Duration.zero, () {
      if (!isClosed) {
        add(const MachineControllerInitialized());
      }
    });
  }
  
  /// Handle initialization
  void _onInitialized(MachineControllerInitialized event, Emitter<MachineControllerState> emit) {
    AppLogger.machineInfo('Machine Controller BLoC marked as initialized');
    emit(state.copyWith(isInitialized: true));
  }
  
  /// Handle incoming CNC communication data
  void _onCommunicationReceived(
    MachineControllerCommunicationReceived event, 
    Emitter<MachineControllerState> emit,
  ) {
    AppLogger.machineDebug('Received communication state: ${event.communicationState.runtimeType}');
    
    final now = DateTime.now();
    
    switch (event.communicationState.runtimeType) {
      case const (CncCommunicationConnected):
        final connectedState = event.communicationState as CncCommunicationConnected;
        _handleConnectedState(connectedState, emit, now);
        break;
        
      case const (CncCommunicationWithData):
        final dataState = event.communicationState as CncCommunicationWithData;
        AppLogger.machineDebug('Processing WithData state with ${dataState.messages.length} messages');
        _handleDataState(dataState, emit, now);
        break;
        
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
    // Check for grblHAL welcome message in device info
    if (!state.grblHalDetected && connectedState.deviceInfo != null && connectedState.deviceInfo!.isNotEmpty) {
      AppLogger.machineDebug('Checking connected state deviceInfo for grblHAL: "${connectedState.deviceInfo}"');
      _checkForGrblHalWelcomeMessage([connectedState.deviceInfo!], timestamp);
    }
    
    // Start grblHAL detection timeout if not already detected
    if (!state.grblHalDetected) {
      _startGrblHalDetectionTimeout();
    }
    
    // Create or update controller with connection info
    final currentController = state.controller;
    final updatedController = (currentController ?? MachineController(
      controllerId: _extractControllerIdFromUrl(connectedState.url),
      lastCommunication: timestamp,
    )).copyWith(
      isOnline: true,
      lastCommunication: timestamp,
    );
    
    emit(state.copyWith(
      controller: updatedController,
      lastUpdateTime: timestamp,
    ));
    
    AppLogger.machineInfo('Machine controller connected: ${updatedController.controllerId}');
  }
  
  /// Handle data state with machine information
  void _handleDataState(
    CncCommunicationWithData dataState, 
    Emitter<MachineControllerState> emit,
    DateTime timestamp,
  ) {
    // Check for grblHAL welcome message first
    if (!state.grblHalDetected) {
      AppLogger.machineDebug('Checking for grblHAL welcome message in ${dataState.messages.length} messages');
      AppLogger.machineDebug('WithData messages: ${dataState.messages.take(10).join(" | ")}');
      _checkForGrblHalWelcomeMessage(dataState.messages, timestamp);
    } else {
      AppLogger.machineDebug('grblHAL already detected, skipping welcome message check');
    }
    
    // Check for configuration response ($ command responses)
    AppLogger.machineDebug('Checking for configuration in ${dataState.messages.length} messages');
    _parseConfigurationResponses(dataState.messages, timestamp);
    
    // Create or update controller with all available data
    final currentController = state.controller;
    final controllerId = currentController?.controllerId ?? 
                        _extractControllerIdFromUrl(dataState.url);
    
    // Parse machine state from raw messages
    MachineStatus status = MachineStatus.unknown;
    MachineCoordinates? workPos;
    MachineCoordinates? machinePos;
    double? feedRate;
    double? spindleSpeed;
    List<String> alarms = [];
    
    // Parse the most recent status message from the message list
    final statusMessage = _findMostRecentStatusMessage(dataState.messages);
    AppLogger.machineDebug('Found status message: $statusMessage');
    
    if (statusMessage != null) {
      final parsedData = _parseGrblStatusMessage(statusMessage, timestamp);
      status = parsedData['status'] ?? MachineStatus.unknown;
      workPos = parsedData['workPosition'];
      machinePos = parsedData['machinePosition'];
      feedRate = parsedData['feedRate'];
      spindleSpeed = parsedData['spindleSpeed'];
      
      AppLogger.machineDebug('Parsed status: ${status.displayName}');
      if (workPos != null) AppLogger.machineDebug('Work position: ${workPos.toString()}');
      if (machinePos != null) AppLogger.machineDebug('Machine position: ${machinePos.toString()}');
      
      // Check for alarms in the status
      if (status.hasError || status == MachineStatus.alarm) {
        alarms.add('Machine alarm: ${status.displayName}');
      }
    } else {
      AppLogger.machineDebug('No status message found in ${dataState.messages.length} messages');
    }
    
    // Create feed state if we have feed rate data
    FeedState? feedState;
    if (feedRate != null) {
      feedState = FeedState(
        rate: feedRate,
        targetRate: feedRate,
        lastUpdated: timestamp,
      );
    }
    
    // Create spindle state if we have spindle data
    SpindleState? spindleState;
    if (spindleSpeed != null) {
      spindleState = SpindleState(
        isRunning: spindleSpeed > 0,
        speed: spindleSpeed,
        targetSpeed: spindleSpeed,
        lastUpdated: timestamp,
      );
    }
    
    // Create active codes if available in status message
    ActiveCodes? activeCodes;
    // Note: Modal codes parsing would need to be implemented if required
    // For now, we focus on basic status, coordinates, feed, and spindle
    
    final updatedController = (currentController ?? MachineController(
      controllerId: controllerId,
      lastCommunication: timestamp,
    )).copyWith(
      status: status,
      workPosition: workPos,
      machinePosition: machinePos,
      spindleState: spindleState,
      feedState: feedState,
      activeCodes: activeCodes,
      alarms: alarms,
      isOnline: true,
      lastCommunication: timestamp,
    );
    
    // Store last raw message for debugging
    String lastMessage = '';
    if (dataState.messages.isNotEmpty) {
      lastMessage = dataState.messages.last;
    }
    
    emit(state.copyWith(
      controller: updatedController,
      lastRawMessage: lastMessage,
      lastUpdateTime: timestamp,
    ));
    
    // Status updates happen at 60Hz - reduced logging
  }
  
  /// Handle disconnected state
  void _handleDisconnectedState(Emitter<MachineControllerState> emit, DateTime timestamp) {
    // Cancel grblHAL detection timeout on disconnect
    _cancelGrblHalDetectionTimeout();
    
    if (state.controller != null) {
      final updatedController = state.controller!.copyWith(
        isOnline: false,
        lastCommunication: timestamp,
      );
      
      emit(state.copyWith(
        controller: updatedController,
        lastUpdateTime: timestamp,
      ));
      
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
  
  /// Find the most recent GRBL status message from the message list
  String? _findMostRecentStatusMessage(List<String> messages) {
    AppLogger.machineDebug('Searching for status message in ${messages.length} messages');
    AppLogger.machineDebug('Last 5 messages: ${messages.reversed.take(5).join(" | ")}');
    
    // Look for the most recent message that starts with '<' (GRBL status)
    for (int i = messages.length - 1; i >= 0; i--) {
      final message = messages[i];
      AppLogger.machineDebug('Checking message $i: "${message.trim()}"');
      
      if (message.contains('Received: <')) {
        // Extract the status part from "Received: <status>"
        final statusStart = message.indexOf('<');
        if (statusStart != -1) {
          final statusMessage = message.substring(statusStart);
          AppLogger.machineDebug('Found status message at index $i: "${statusMessage.trim()}"');
          return statusMessage;
        }
      }
    }
    
    AppLogger.machineDebug('No status messages found (looking for "Received: <")');
    return null;
  }
  
  /// Parse GRBL status message and extract machine data
  Map<String, dynamic> _parseGrblStatusMessage(String message, DateTime timestamp) {
    final result = <String, dynamic>{};
    
    if (!message.startsWith('<')) return result;
    
    AppLogger.machineDebug('Parsing status message: $message');
    
    // Parse GRBL status: <Idle|MPos:0.000,0.000,0.000|WPos:0.000,0.000,0.000|FS:0,0>
    final stateMatch = RegExp(r'<([^|]+)').firstMatch(message);
    if (stateMatch != null) {
      final stateString = stateMatch.group(1)!;
      final parsedStatus = MachineController.parseStatus(stateString);
      AppLogger.machineDebug('Parsed state string: "$stateString" -> ${parsedStatus.displayName}');
      result['status'] = parsedStatus;
    } else {
      AppLogger.machineWarning('Could not extract state from status message: $message');
    }
    
    // Parse work position
    final workPosMatch = RegExp(
      r'WPos:([+-]?\d*\.?\d+),([+-]?\d*\.?\d+),([+-]?\d*\.?\d+)',
    ).firstMatch(message);
    if (workPosMatch != null) {
      result['workPosition'] = MachineCoordinates(
        x: double.parse(workPosMatch.group(1)!),
        y: double.parse(workPosMatch.group(2)!),
        z: double.parse(workPosMatch.group(3)!),
        lastUpdated: timestamp,
      );
    }
    
    // Parse machine position
    final machinePosMatch = RegExp(
      r'MPos:([+-]?\d*\.?\d+),([+-]?\d*\.?\d+),([+-]?\d*\.?\d+)',
    ).firstMatch(message);
    if (machinePosMatch != null) {
      result['machinePosition'] = MachineCoordinates(
        x: double.parse(machinePosMatch.group(1)!),
        y: double.parse(machinePosMatch.group(2)!),
        z: double.parse(machinePosMatch.group(3)!),
        lastUpdated: timestamp,
      );
    }
    
    // Parse feed rate and spindle speed
    final fsMatch = RegExp(r'FS:(\d+),(\d+)').firstMatch(message);
    if (fsMatch != null) {
      result['feedRate'] = double.parse(fsMatch.group(1)!);
      result['spindleSpeed'] = double.parse(fsMatch.group(2)!);
    }
    
    return result;
  }
  
  /// Handle status update
  void _onStatusUpdated(MachineControllerStatusUpdated event, Emitter<MachineControllerState> emit) {
    if (state.controller != null) {
      final updatedController = state.controller!.copyWith(
        status: event.status,
        lastCommunication: event.timestamp,
      );
      
      emit(state.copyWith(
        controller: updatedController,
        lastUpdateTime: event.timestamp,
      ));
      
      AppLogger.machineDebug('Machine status updated: ${event.status.displayName}');
    }
  }
  
  /// Handle coordinates update
  void _onCoordinatesUpdated(MachineControllerCoordinatesUpdated event, Emitter<MachineControllerState> emit) {
    if (state.controller != null) {
      final updatedController = state.controller!.copyWith(
        workPosition: event.workPosition,
        machinePosition: event.machinePosition,
        lastCommunication: event.timestamp,
      );
      
      emit(state.copyWith(
        controller: updatedController,
        lastUpdateTime: event.timestamp,
      ));
      
      AppLogger.machineDebug('Machine coordinates updated');
    }
  }
  
  /// Handle spindle update
  void _onSpindleUpdated(MachineControllerSpindleUpdated event, Emitter<MachineControllerState> emit) {
    if (state.controller != null) {
      final updatedController = state.controller!.copyWith(
        spindleState: event.spindleState,
        lastCommunication: event.timestamp,
      );
      
      emit(state.copyWith(
        controller: updatedController,
        lastUpdateTime: event.timestamp,
      ));
      
      AppLogger.machineDebug('Machine spindle updated: ${event.spindleState.speed} RPM');
    }
  }
  
  /// Handle feed update
  void _onFeedUpdated(MachineControllerFeedUpdated event, Emitter<MachineControllerState> emit) {
    if (state.controller != null) {
      final updatedController = state.controller!.copyWith(
        feedState: event.feedState,
        lastCommunication: event.timestamp,
      );
      
      emit(state.copyWith(
        controller: updatedController,
        lastUpdateTime: event.timestamp,
      ));
      
      AppLogger.machineDebug('Machine feed updated: ${event.feedState.rate} ${event.feedState.units}');
    }
  }
  
  /// Handle codes update
  void _onCodesUpdated(MachineControllerCodesUpdated event, Emitter<MachineControllerState> emit) {
    if (state.controller != null) {
      final updatedController = state.controller!.copyWith(
        activeCodes: event.activeCodes,
        lastCommunication: event.timestamp,
      );
      
      emit(state.copyWith(
        controller: updatedController,
        lastUpdateTime: event.timestamp,
      ));
      
      AppLogger.machineDebug('Machine codes updated: G[${event.activeCodes.gCodes.join(', ')}] M[${event.activeCodes.mCodes.join(', ')}]');
    }
  }
  
  /// Handle alarm added
  void _onAlarmAdded(MachineControllerAlarmAdded event, Emitter<MachineControllerState> emit) {
    if (state.controller != null) {
      final currentAlarms = List<String>.from(state.controller!.alarms);
      if (!currentAlarms.contains(event.alarm)) {
        currentAlarms.add(event.alarm);
      }
      
      final updatedController = state.controller!.copyWith(
        alarms: currentAlarms,
        lastCommunication: event.timestamp,
      );
      
      emit(state.copyWith(
        controller: updatedController,
        lastUpdateTime: event.timestamp,
      ));
      
      AppLogger.machineWarning('Machine alarm added: ${event.alarm}');
    }
  }
  
  /// Handle alarms cleared
  void _onAlarmsCleared(MachineControllerAlarmsCleared event, Emitter<MachineControllerState> emit) {
    if (state.controller != null) {
      final updatedController = state.controller!.copyWith(
        alarms: [],
        lastCommunication: DateTime.now(),
      );
      
      emit(state.copyWith(
        controller: updatedController,
        lastUpdateTime: DateTime.now(),
      ));
      
      AppLogger.machineInfo('Machine alarms cleared');
    }
  }
  
  /// Handle error added
  void _onErrorAdded(MachineControllerErrorAdded event, Emitter<MachineControllerState> emit) {
    if (state.controller != null) {
      final currentErrors = List<String>.from(state.controller!.errors);
      if (!currentErrors.contains(event.error)) {
        currentErrors.add(event.error);
      }
      
      final updatedController = state.controller!.copyWith(
        errors: currentErrors,
        lastCommunication: event.timestamp,
      );
      
      emit(state.copyWith(
        controller: updatedController,
        lastUpdateTime: event.timestamp,
      ));
      
      AppLogger.machineError('Machine error added: ${event.error}');
    }
  }
  
  /// Handle errors cleared
  void _onErrorsCleared(MachineControllerErrorsCleared event, Emitter<MachineControllerState> emit) {
    if (state.controller != null) {
      final updatedController = state.controller!.copyWith(
        errors: [],
        lastCommunication: DateTime.now(),
      );
      
      emit(state.copyWith(
        controller: updatedController,
        lastUpdateTime: DateTime.now(),
      ));
      
      AppLogger.machineInfo('Machine errors cleared');
    }
  }
  
  /// Handle info update
  void _onInfoUpdated(MachineControllerInfoUpdated event, Emitter<MachineControllerState> emit) {
    if (state.controller != null) {
      final updatedController = state.controller!.copyWith(
        firmwareVersion: event.firmwareVersion,
        hardwareVersion: event.hardwareVersion,
        lastCommunication: DateTime.now(),
      );
      
      emit(state.copyWith(
        controller: updatedController,
        lastUpdateTime: DateTime.now(),
      ));
      
      if (event.firmwareVersion != null && event.hardwareVersion != null) {
        AppLogger.machineInfo('Machine info updated: FW=${event.firmwareVersion}, HW=${event.hardwareVersion}');
      }
    }
  }
  
  /// Handle connection change
  void _onConnectionChanged(MachineControllerConnectionChanged event, Emitter<MachineControllerState> emit) {
    if (state.controller != null) {
      final updatedController = state.controller!.copyWith(
        isOnline: event.isOnline,
        lastCommunication: event.timestamp,
      );
      
      emit(state.copyWith(
        controller: updatedController,
        lastUpdateTime: event.timestamp,
      ));
      
      AppLogger.machineInfo('Machine connection changed: ${event.isOnline ? 'online' : 'offline'}');
    }
  }
  
  /// Handle reset
  void _onReset(MachineControllerReset event, Emitter<MachineControllerState> emit) {
    emit(const MachineControllerState(isInitialized: true));
    AppLogger.machineInfo('Machine controller reset');
  }
  
  /// Check for grblHAL welcome message in recent messages
  void _checkForGrblHalWelcomeMessage(List<String> messages, DateTime timestamp) {
    AppLogger.machineDebug('_checkForGrblHalWelcomeMessage called with ${messages.length} messages');
    AppLogger.machineDebug('Recent messages: ${messages.take(5).join(" | ")}');
    
    // Look for grblHAL welcome message patterns (more robust)
    final grblHalPatterns = [
      // Match "GrblHAL 1.1f" format (most common)
      RegExp(r'grblhal\s+([0-9]+\.[0-9]+[a-z]*)', caseSensitive: false),
      // Match "Grbl 1.1f [grblHAL" format  
      RegExp(r'grbl\s+([0-9]+\.[0-9]+[a-z]*)\s*\[.*grblhal', caseSensitive: false),
      // Simple pattern to just look for "grblhal" anywhere in the message
      RegExp(r'grblhal', caseSensitive: false),
    ];
    
    for (final message in messages.reversed.take(10)) {
      AppLogger.machineDebug('Checking message for grblHAL: "${message.trim()}"');
      
      for (int i = 0; i < grblHalPatterns.length; i++) {
        final pattern = grblHalPatterns[i];
        final match = pattern.firstMatch(message);
        if (match != null) {
          String version = 'unknown';
          
          // Try to extract version from first two patterns, fallback for simple pattern
          if (i < 2 && match.groupCount >= 1 && match.group(1) != null) {
            version = match.group(1)!;
          } else if (i == 2) {
            // For simple "grblhal" pattern, try to extract version manually
            final versionMatch = RegExp(r'([0-9]+\.[0-9]+[a-z]*)', caseSensitive: false).firstMatch(message);
            if (versionMatch != null) {
              version = versionMatch.group(0)!;
            }
          }
          
          AppLogger.machineInfo('grblHAL detected: version $version from message: "$message"');
          
          // Trigger grblHAL detection event
          add(MachineControllerGrblHalDetected(
            welcomeMessage: message,
            firmwareVersion: version,
            timestamp: timestamp,
          ));
          return; // Found grblHAL, exit search
        }
      }
    }
    
    AppLogger.machineDebug('No grblHAL patterns matched in ${messages.length} messages');
  }

  /// Parse configuration responses from $ command
  void _parseConfigurationResponses(List<String> messages, DateTime timestamp) {
    final configurationLines = <String>[];
    final allMessages = <String>[];
    
    // Look for configuration setting lines in format: $<number>=<value>
    // May have prefixes like "Received: $100=250.000"
    final settingPattern = RegExp(r'\$\d+=.+');
    
    for (final message in messages) {
      final trimmed = message.trim();
      allMessages.add(trimmed);
      
      // Check if this message contains a configuration setting
      final match = settingPattern.firstMatch(trimmed);
      if (match != null) {
        // Extract just the setting part (e.g., "$100=250.000")
        final settingLine = match.group(0)!;
        configurationLines.add(settingLine);
        AppLogger.machineDebug('Found configuration setting: "$settingLine" in message: "$trimmed"');
      }
    }
    
    // If we found configuration settings or any messages that might contain firmware info, parse them
    if (configurationLines.isNotEmpty || allMessages.isNotEmpty) {
      // Parse configuration from all messages (includes both settings and potential firmware info)
      final configuration = MachineConfiguration.parseFromMessages(allMessages);
      
      AppLogger.machineDebug('Parsed configuration: ${configuration.settings.length} settings, firmware: ${configuration.firmwareVersion}');
      
      // Merge with existing configuration if present
      final existingConfig = state.configuration;
      final mergedConfig = existingConfig != null 
          ? existingConfig.withSettings(configuration.settings.values.toList()).copyWith(
              firmwareVersion: configuration.firmwareVersion ?? existingConfig.firmwareVersion,
            )
          : configuration;
      
      // Only trigger event if we actually have configuration data
      if (mergedConfig.settings.isNotEmpty || mergedConfig.firmwareVersion != null) {
        AppLogger.machineInfo('Configuration update: ${mergedConfig.settings.length} settings, firmware: ${mergedConfig.firmwareVersion}');
        
        // Trigger configuration received event
        add(MachineControllerConfigurationReceived(
          configuration: mergedConfig,
          timestamp: timestamp,
        ));
      }
    }
  }
  
  /// Set communication bloc reference for command sending
  void _onSetCommunicationBloc(
    MachineControllerSetCommunicationBloc event,
    Emitter<MachineControllerState> emit,
  ) {
    _communicationBloc = event.communicationBloc;
    AppLogger.machineDebug('Communication bloc reference set in machine controller');
  }
  
  /// Handle grblHAL detection
  void _onGrblHalDetected(
    MachineControllerGrblHalDetected event, 
    Emitter<MachineControllerState> emit,
  ) {
    AppLogger.machineInfo('grblHAL controller detected: ${event.firmwareVersion}');
    AppLogger.machineInfo('Welcome message: "${event.welcomeMessage.trim()}"');
    
    // Cancel timeout since grblHAL was detected successfully
    _cancelGrblHalDetectionTimeout();
    
    emit(state.copyWith(
      grblHalDetected: true,
      grblHalVersion: event.firmwareVersion,
      grblHalDetectedAt: event.timestamp,
    ));
    
    // Automatically configure grblHAL auto reporting
    _configureGrblHalAutoReporting();
  }
  
  /// Configure grblHAL automatic status reporting
  void _configureGrblHalAutoReporting() {
    if (_communicationBloc == null) {
      AppLogger.machineError('Cannot configure grblHAL - no communication bloc reference');
      return;
    }
    
    AppLogger.machineInfo('Configuring grblHAL automatic status reporting (16ms/60Hz)...');
    
    // Send grblHAL configuration commands directly
    AppLogger.machineInfo('Sending 0x84 0x10 raw bytes for 60Hz auto-reporting');
    _communicationBloc.add(CncCommunicationSendRawBytes([0x84, 0x10]));
    
    // Query machine configuration to understand capabilities and settings
    AppLogger.machineInfo('Querying machine configuration with \$ command');
    _communicationBloc.add(CncCommunicationSendCommand('\$'));
    
    // Send multiple status queries to ensure we get machine state
    AppLogger.machineInfo('Sending initial status queries to determine machine state');
    _communicationBloc.add(CncCommunicationSendCommand('?'));
    
    // Send additional status queries with delays to ensure we get a response
    Timer(const Duration(milliseconds: 100), () {
      if (_communicationBloc != null) {
        AppLogger.machineInfo('Sending delayed status query (100ms)');
        _communicationBloc.add(CncCommunicationSendCommand('?'));
      }
    });
    
    Timer(const Duration(milliseconds: 500), () {
      if (_communicationBloc != null) {
        AppLogger.machineInfo('Sending delayed status query (500ms)');
        _communicationBloc.add(CncCommunicationSendCommand('?'));
      }
    });
    
    Timer(const Duration(milliseconds: 1000), () {
      if (_communicationBloc != null) {
        AppLogger.machineInfo('Sending delayed status query (1000ms)');
        _communicationBloc.add(CncCommunicationSendCommand('?'));
      }
    });
    
    // Mark as configured
    add(MachineControllerAutoReportingConfigured(
      enabled: true,
      timestamp: DateTime.now(),
    ));
  }
  
  
  /// Handle auto reporting configuration completion
  void _onAutoReportingConfigured(
    MachineControllerAutoReportingConfigured event,
    Emitter<MachineControllerState> emit,
  ) {
    emit(state.copyWith(
      autoReportingConfigured: event.enabled,
    ));
    
    if (event.enabled) {
      AppLogger.machineInfo('grblHAL configured for 60Hz event-based status updates (0x84 0x10)');
    }
  }

  /// Handle machine configuration received from $ command parsing
  void _onConfigurationReceived(
    MachineControllerConfigurationReceived event,
    Emitter<MachineControllerState> emit,
  ) {
    AppLogger.machineInfo('Machine configuration received: ${event.configuration.settings.length} settings');
    
    emit(state.copyWith(
      configuration: event.configuration,
      lastUpdateTime: event.timestamp,
    ));
  }
  
  /// Start grblHAL detection timeout
  void _startGrblHalDetectionTimeout() {
    _cancelGrblHalDetectionTimeout();
    
    AppLogger.machineInfo('Starting grblHAL detection timeout (5 seconds)');
    _grblHalDetectionTimeout = Timer(const Duration(seconds: 5), () {
      if (!state.grblHalDetected) {
        AppLogger.machineError('grblHAL not detected within timeout - this sender requires grblHAL firmware');
        
        // Disconnect since we only support grblHAL
        if (_communicationBloc != null) {
          _communicationBloc.add(CncCommunicationDisconnectRequested());
        }
        
        // Update firmware version to show error
        add(MachineControllerInfoUpdated(
          firmwareVersion: 'ERROR: grblHAL required - Standard GRBL not supported',
        ));
      }
    });
  }
  
  /// Cancel grblHAL detection timeout
  void _cancelGrblHalDetectionTimeout() {
    _grblHalDetectionTimeout?.cancel();
    _grblHalDetectionTimeout = null;
  }

  @override
  void onTransition(Transition<MachineControllerEvent, MachineControllerState> transition) {
    super.onTransition(transition);
    final currentStatus = transition.currentState.status;
    final nextStatus = transition.nextState.status;
    
    if (currentStatus != nextStatus) {
      AppLogger.machineDebug('Machine status changed: ${currentStatus.name} -> ${nextStatus.name}');
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
      AppLogger.machineWarning('Cannot jog - machine not in valid state: ${state.status.displayName}');
      return;
    }

    if (_communicationBloc == null) {
      AppLogger.machineError('Cannot jog - no communication bloc reference');
      return;
    }

    // Build GRBL jog command: $J=X10.0F500 (jog X axis 10mm at 500mm/min)
    final jogCommand = '\$J=${event.axis}${event.distance}F${event.feedRate}';
    
    AppLogger.machineInfo('Sending jog command: $jogCommand');
    _communicationBloc.add(CncCommunicationSendCommand(jogCommand));
    
    // Update state to indicate jogging
    emit(state.copyWith(
      lastUpdateTime: DateTime.now(),
    ));
  }

  /// Handle jog stop request
  void _onJogStopRequested(
    MachineControllerJogStopRequested event,
    Emitter<MachineControllerState> emit,
  ) {
    if (_communicationBloc == null) {
      AppLogger.machineError('Cannot stop jog - no communication bloc reference');
      return;
    }

    // Send jog cancel command (0x85 for grblHAL real-time command)
    AppLogger.machineInfo('Sending jog cancel command');
    _communicationBloc.add(CncCommunicationSendRawBytes([0x85]));
    
    emit(state.copyWith(
      lastUpdateTime: DateTime.now(),
    ));
  }

  /// Handle continuous jog start (for hold-down buttons)
  void _onContinuousJogStarted(
    MachineControllerContinuousJogStarted event,
    Emitter<MachineControllerState> emit,
  ) {
    if (!_canJog()) {
      AppLogger.machineWarning('Cannot start continuous jog - machine not in valid state: ${state.status.displayName}');
      return;
    }

    if (_communicationBloc == null) {
      AppLogger.machineError('Cannot start continuous jog - no communication bloc reference');
      return;
    }

    // For continuous jog, send a long distance in the specified direction
    // grblHAL will stop when the jog cancel is received
    final distance = event.positive ? '1000' : '-1000'; // Large distance
    final jogCommand = '\$J=${event.axis}${distance}F${event.feedRate}';
    
    AppLogger.machineInfo('Starting continuous jog: $jogCommand');
    _communicationBloc.add(CncCommunicationSendCommand(jogCommand));
    
    emit(state.copyWith(
      lastUpdateTime: DateTime.now(),
    ));
  }

  /// Handle continuous jog stop (for button release)
  void _onContinuousJogStopped(
    MachineControllerContinuousJogStopped event,
    Emitter<MachineControllerState> emit,
  ) {
    // Same as regular jog stop
    _onJogStopRequested(const MachineControllerJogStopRequested(), emit);
  }

  /// Check if machine is in a valid state for jogging
  bool _canJog() {
    AppLogger.machineDebug('Checking jog eligibility:');
    AppLogger.machineDebug('  hasController: ${state.hasController}');
    AppLogger.machineDebug('  isOnline: ${state.isOnline}');
    AppLogger.machineDebug('  status: ${state.status.displayName} (${state.status.name})');
    AppLogger.machineDebug('  grblHalDetected: ${state.grblHalDetected}');
    AppLogger.machineDebug('  autoReportingConfigured: ${state.autoReportingConfigured}');
    
    if (!state.hasController || !state.isOnline) {
      AppLogger.machineWarning('Cannot jog - controller not available or offline');
      return false;
    }

    if (!state.grblHalDetected) {
      AppLogger.machineWarning('Cannot jog - grblHAL not detected');
      return false;
    }

    // Only allow jogging in Idle, Jog, or Check states
    final currentStatus = state.status;
    final canJog = currentStatus == MachineStatus.idle || 
                   currentStatus == MachineStatus.jogging ||
                   currentStatus == MachineStatus.check;
                   
    if (!canJog) {
      AppLogger.machineWarning('Cannot jog - machine in invalid state: ${currentStatus.displayName}');
    }
    
    return canJog;
  }

  @override
  Future<void> close() {
    _cancelGrblHalDetectionTimeout();
    return super.close();
  }
}