import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../../services/jog_service.dart';
import '../../services/proportional_jog_controller.dart';
import '../../services/jog_input_driver.dart';
import '../../utils/logger.dart';
import '../../domain/value_objects/work_envelope.dart';
import '../../domain/enums/machine_status.dart';
import '../machine_controller/machine_controller_bloc.dart';
import '../machine_controller/machine_controller_event.dart';
import '../machine_controller/machine_controller_state.dart';
import '../communication/cnc_communication_bloc.dart';
import '../communication/cnc_communication_event.dart';
import 'jog_controller_event.dart';
import 'jog_controller_state.dart';

/// BLoC for managing jog control logic
class JogControllerBloc extends Bloc<JogControllerEvent, JogControllerState> {
  final MachineControllerBloc _machineControllerBloc;
  final CncCommunicationBloc _communicationBloc;

  // Input drivers management
  final List<JogInputDriver> _inputDrivers = [];
  final List<StreamSubscription<JogInputEvent>> _driverSubscriptions = [];

  // Predicted position tracking for soft limit filtering
  vm.Vector3? _predictedPosition;
  DateTime? _lastPositionUpdate;
  
  // Machine state monitoring for prediction reset
  StreamSubscription<MachineControllerState>? _machineStateSubscription;
  MachineStatus? _lastMachineStatus;

  JogControllerBloc({
    required MachineControllerBloc machineControllerBloc,
    required CncCommunicationBloc communicationBloc,
  }) : _machineControllerBloc = machineControllerBloc,
       _communicationBloc = communicationBloc,
       super(JogControllerState.initial) {
    AppLogger.info('Jog Controller BLoC initialized');

    // Register event handlers
    on<JogControllerInitialized>(_onInitialized);
    on<JogSettingsUpdated>(_onSettingsUpdated);
    on<ProportionalJogInputReceived>(_onProportionalJogInput);
    on<JoystickInputReceived>(_onJoystickInput); // Legacy support
    on<DiscreteJogRequested>(_onDiscreteJog);
    on<JogStopRequested>(_onJogStop);
    on<WorkZeroRequested>(_onWorkZero);
    on<ProbeRequested>(_onProbe);
    on<ProbeSettingsUpdated>(_onProbeSettingsUpdated);
    on<HomingRequested>(_onHoming);
    
    // Monitor machine state changes to reset prediction state
    _setupMachineStateMonitoring();
  }

  /// Handle initialization
  void _onInitialized(
    JogControllerInitialized event,
    Emitter<JogControllerState> emit,
  ) {
    AppLogger.info('Jog Controller initialized');
    emit(state.copyWith(isInitialized: true));
  }

  /// Handle jog settings updates
  void _onSettingsUpdated(
    JogSettingsUpdated event,
    Emitter<JogControllerState> emit,
  ) {
    final newSettings = state.settings.copyWith(
      selectedDistance: event.selectedDistance,
      selectedFeedRate: event.selectedFeedRate,
      mode: event.mode,
    );

    emit(state.copyWith(settings: newSettings));

    // If switching away from joystick mode, stop any active jogging
    if (event.mode != null &&
        event.mode != JogMode.joystick &&
        state.joystickState.isActive) {
      add(const JogStopRequested());
    }
  }

  /// Handle proportional jog input from any input driver
  void _onProportionalJogInput(
    ProportionalJogInputReceived event,
    Emitter<JogControllerState> emit,
  ) {
    // Only process if in joystick mode
    if (state.settings.mode != JogMode.joystick) {
      return;
    }

    // Check if machine can jog
    if (!_canJog()) {
      if (state.joystickState.isActive) {
        add(const JogStopRequested());
      }
      return;
    }

    final now = DateTime.now();
    final input = event.inputEvent;

    // Get current machine state for soft limit checking
    final machineState = _machineControllerBloc.state;
    final machinePosition = machineState.machinePosition;
    final configuration = machineState.configuration;

    final workEnvelope = configuration != null
        ? WorkEnvelope.fromConfiguration(configuration)
        : null;

    // Get the best position for soft limit checking
    vm.Vector3? actualMachinePosition;
    if (machinePosition != null) {
      actualMachinePosition = vm.Vector3(
        machinePosition.x,
        machinePosition.y,
        machinePosition.z,
      );
    }
    final currentPosition = _getPositionForFiltering(actualMachinePosition);

    // Create proportional jog input
    final proportionalInput = ProportionalJogInput(
      x: input.x,
      y: input.y,
      z: input.z,
      a: input.a,
      b: input.b,
      c: input.c,
      selectedFeedRate: state.settings.selectedFeedRate,
      currentPosition: currentPosition,
      workEnvelope: workEnvelope,
    );

    // Process input through proportional controller
    final processed = ProportionalJogController.process(proportionalInput);

    // Update joystick state (convert to 2D for state compatibility)
    final newJoystickState = state.joystickState.copyWith(
      x: processed.x,
      y: processed.y,
      magnitude: processed.to2D().magnitude,
      isActive: processed.isActive,
      lastInputTime: now,
    );

    // If joystick is not active, stop jogging
    if (!processed.isActive) {
      if (state.joystickState.isActive) {
        emit(state.copyWith(joystickState: newJoystickState));
        add(const JogStopRequested());
      }
      return;
    }

    // Get buffer info for timing calculations
    final targetInterval = BufferManager.calculateCommandInterval(
      machineState.plannerBlocksAvailable,
      machineState.maxObservedBufferBlocks,
    );

    // Check if we should send a command
    final shouldSend = _shouldSendProportionalCommand(
      processed,
      targetInterval,
      now,
    );

    emit(state.copyWith(joystickState: newJoystickState));

    if (shouldSend) {
      _sendProportionalCommand(processed, now, emit);
    }
  }

  /// Handle joystick input processing
  void _onJoystickInput(
    JoystickInputReceived event,
    Emitter<JogControllerState> emit,
  ) {
    // Only process if in joystick mode
    if (state.settings.mode != JogMode.joystick) {
      return;
    }

    // Check if machine can jog
    if (!_canJog()) {
      if (state.joystickState.isActive) {
        add(const JogStopRequested());
      }
      return;
    }

    final now = DateTime.now();

    // Get current machine state for soft limit checking
    final machineState = _machineControllerBloc.state;
    final machinePosition = machineState
        .machinePosition; // Use machine position, not work position!
    final configuration = machineState.configuration;

    final workEnvelope = configuration != null
        ? WorkEnvelope.fromConfiguration(configuration)
        : null;

    // Get the best position for soft limit checking (predicted or actual machine position)
    vm.Vector3? actualMachinePosition;
    if (machinePosition != null) {
      actualMachinePosition = vm.Vector3(
        machinePosition.x,
        machinePosition.y,
        machinePosition.z,
      );
    }
    final currentPosition = _getPositionForFiltering(actualMachinePosition);

    // Use soft-limits-aware processing if we have position and envelope data
    final useSoftLimitsProcessing =
        currentPosition != null && workEnvelope != null;

    // Process joystick input with appropriate method based on Z-axis availability
    final JoystickProcessResult processed;
    final double? zDistance;

    if (event.z != null && useSoftLimitsProcessing) {
      // 3D processing with soft limits
      final processed3D = JoystickProcessor.processWithSoftLimits3D(
        rawX: event.x,
        rawY: event.y,
        rawZ: event.z!,
        selectedFeedRate: state.settings.selectedFeedRate,
        currentPosition: currentPosition,
        workEnvelope: workEnvelope,
      );
      // Convert 3D result to 2D result for state management
      processed = JoystickProcessResult(
        x: processed3D.x,
        y: processed3D.y,
        magnitude: processed3D.magnitude,
        isActive: processed3D.isActive,
        scaledFeedRate: processed3D.scaledFeedRate,
        baseDistance: processed3D.baseDistance,
      );
      zDistance =
          -processed3D.z *
          processed3D.baseDistance; // Apply Z-axis inversion if needed
    } else {
      // 2D processing (with or without soft limits)
      processed = useSoftLimitsProcessing
          ? JoystickProcessor.processWithSoftLimits(
              rawX: event.x,
              rawY: event.y,
              selectedFeedRate: state.settings.selectedFeedRate,
              currentPosition: currentPosition,
              workEnvelope: workEnvelope,
            )
          : JoystickProcessor.process(
              event.x,
              event.y,
              state.settings.selectedFeedRate,
            );
      zDistance = null;
    }

    // Update joystick state
    final newJoystickState = state.joystickState.copyWith(
      x: processed.x,
      y: processed.y,
      magnitude: processed.magnitude,
      isActive: processed.isActive,
      lastInputTime: now,
    );

    // If joystick is not active, stop jogging
    if (!processed.isActive) {
      if (state.joystickState.isActive) {
        emit(state.copyWith(joystickState: newJoystickState));
        add(const JogStopRequested());
      }
      return;
    }

    // Get buffer info for timing calculations (use existing machineState)
    final targetInterval = BufferManager.calculateCommandInterval(
      machineState.plannerBlocksAvailable,
      machineState.maxObservedBufferBlocks,
    );

    // Check if we should send a command
    final shouldSend = _shouldSendJoystickCommand(
      processed,
      targetInterval,
      now,
    );

    emit(state.copyWith(joystickState: newJoystickState));

    if (shouldSend) {
      _sendJoystickCommand(processed, zDistance, now, emit);
    }
  }

  /// Handle discrete jog request
  void _onDiscreteJog(
    DiscreteJogRequested event,
    Emitter<JogControllerState> emit,
  ) {
    if (!_canJog()) {
      AppLogger.machineWarning('Cannot jog - machine not ready');
      return;
    }

    _machineControllerBloc.add(
      MachineControllerJogRequested(
        axis: event.axis,
        distance: event.distance,
        feedRate: state.settings.selectedFeedRate,
      ),
    );
  }

  /// Handle jog stop request
  void _onJogStop(JogStopRequested event, Emitter<JogControllerState> emit) {
    // Reset predicted position state immediately when jog is stopped
    _resetPredictedPosition();
    
    // Update joystick state to inactive
    emit(state.copyWith(joystickState: JoystickState.inactive));

    // Send stop command to machine
    _machineControllerBloc.add(const MachineControllerJogStopRequested());
  }

  /// Handle work zero request
  void _onWorkZero(WorkZeroRequested event, Emitter<JogControllerState> emit) {
    try {
      final command = JogCommandBuilder.buildWorkZeroCommand(event.axes);
      AppLogger.info('Setting work zero for ${event.axes} axes');

      _communicationBloc.add(CncCommunicationSendCommand(command));
    } catch (e) {
      AppLogger.warning('Failed to set work zero: $e');
    }
  }

  /// Handle probe request
  void _onProbe(ProbeRequested event, Emitter<JogControllerState> emit) {
    final command = JogCommandBuilder.buildProbeCommand(
      state.probeSettings.distance,
      state.probeSettings.feedRate,
    );

    AppLogger.info(
      'Probing work surface - distance: ${state.probeSettings.distance}mm, '
      'feed: ${state.probeSettings.feedRate}mm/min',
    );

    _communicationBloc.add(CncCommunicationSendCommand(command));
  }

  /// Handle probe settings update
  void _onProbeSettingsUpdated(
    ProbeSettingsUpdated event,
    Emitter<JogControllerState> emit,
  ) {
    final newProbeSettings = state.probeSettings.copyWith(
      distance: event.distance,
      feedRate: event.feedRate,
    );

    emit(state.copyWith(probeSettings: newProbeSettings));
  }

  /// Handle homing request
  void _onHoming(HomingRequested event, Emitter<JogControllerState> emit) {
    AppLogger.info('Homing machine request');

    final command = JogCommandBuilder.buildHomingCommand();
    _communicationBloc.add(CncCommunicationSendCommand(command));
  }

  /// Check if machine is ready for jogging
  bool _canJog() {
    final machineState = _machineControllerBloc.state;
    return machineState.hasController &&
        machineState.isOnline &&
        machineState.grblHalDetected &&
        (machineState.status.name == 'idle' ||
            machineState.status.name == 'jogging' ||
            machineState.status.name == 'check');
  }

  /// Determine if proportional command should be sent
  bool _shouldSendProportionalCommand(
    ProportionalJogResult processed,
    int targetInterval,
    DateTime now,
  ) {
    // Always send if not currently jogging
    if (!state.joystickState.isActive) return true;

    // Check timing
    if (!JogTiming.shouldSendCommand(
      state.joystickState.lastCommandTime,
      targetInterval,
    )) {
      // Check for significant direction or magnitude changes
      final directionChanged = ProportionalJogController.hasSignificantDirectionChange(
        processed.x,
        processed.y,
        state.joystickState.x,
        state.joystickState.y,
      );

      final magnitudeChanged = ProportionalJogController.hasSignificantMagnitudeChange(
        processed.magnitude,
        state.joystickState.x,
        state.joystickState.y,
      );

      return directionChanged || magnitudeChanged;
    }

    return true;
  }

  /// Determine if joystick command should be sent (legacy method)
  bool _shouldSendJoystickCommand(
    JoystickProcessResult processed,
    int targetInterval,
    DateTime now,
  ) {
    // Always send if not currently jogging
    if (!state.joystickState.isActive) return true;

    // Check timing
    if (!JogTiming.shouldSendCommand(
      state.joystickState.lastCommandTime,
      targetInterval,
    )) {
      // Check for significant direction or magnitude changes
      final directionChanged = JoystickProcessor.hasSignificantDirectionChange(
        processed.x,
        processed.y,
        state.joystickState.x,
        state.joystickState.y,
      );

      final magnitudeChanged = JoystickProcessor.hasSignificantMagnitudeChange(
        processed.magnitude,
        state.joystickState.x,
        state.joystickState.y,
      );

      return directionChanged || magnitudeChanged;
    }

    return true;
  }

  /// Send proportional command to machine (called from within event handler)
  void _sendProportionalCommand(
    ProportionalJogResult processed,
    DateTime now,
    Emitter<JogControllerState> emit,
  ) {
    final xDistance = processed.x * processed.baseDistance;
    // Invert Y-axis to convert from UI convention (Y+ = down) to CNC convention (Y+ = away from operator)
    final yDistance = -processed.y * processed.baseDistance;
    final zDistance = processed.z * processed.baseDistance;

    // Check if any axis has meaningful movement
    if (BufferManager.isMeaningfulMove(xDistance, yDistance) ||
        zDistance.abs() > 0.001) {
      _machineControllerBloc.add(
        MachineControllerMultiAxisJogRequested(
          xDistance: xDistance,
          yDistance: yDistance,
          zDistance: zDistance,
          feedRate: processed.scaledFeedRate,
        ),
      );

      // Update last command time
      final newJoystickState = state.joystickState.copyWith(
        lastCommandTime: now,
      );

      emit(state.copyWith(joystickState: newJoystickState));

      // Update predicted position for future soft limit checks
      _updatePredictedPosition(xDistance, yDistance, zDistance);
    }
  }

  /// Send joystick command to machine (legacy method)
  void _sendJoystickCommand(
    JoystickProcessResult processed,
    double? zDistance,
    DateTime now,
    Emitter<JogControllerState> emit,
  ) {
    final xDistance = processed.x * processed.baseDistance;
    // Invert Y-axis to convert from UI convention (Y+ = down) to CNC convention (Y+ = away from operator)
    final yDistance = -processed.y * processed.baseDistance;

    if (BufferManager.isMeaningfulMove(xDistance, yDistance) ||
        (zDistance != null && zDistance.abs() > 0.001)) {
      _machineControllerBloc.add(
        MachineControllerMultiAxisJogRequested(
          xDistance: xDistance,
          yDistance: yDistance,
          zDistance: zDistance,
          feedRate: processed.scaledFeedRate,
        ),
      );

      // Update last command time
      final newJoystickState = state.joystickState.copyWith(
        lastCommandTime: now,
      );

      emit(state.copyWith(joystickState: newJoystickState));

      // Update predicted position for future soft limit checks
      _updatePredictedPosition(xDistance, yDistance, zDistance);
    }
  }

  /// Get the best available position for soft limit checking
  /// Uses predicted machine position if recent, otherwise falls back to actual machine position
  vm.Vector3? _getPositionForFiltering(vm.Vector3? actualMachinePosition) {
    const maxPositionAge = Duration(
      seconds: 2,
    ); // Use predicted position for up to 2 seconds

    // If we have a recent predicted position, use it
    if (_predictedPosition != null &&
        _lastPositionUpdate != null &&
        DateTime.now().difference(_lastPositionUpdate!) < maxPositionAge) {
      return _predictedPosition;
    }

    // Otherwise, use actual machine position and update our prediction
    if (actualMachinePosition != null) {
      _predictedPosition = actualMachinePosition;
      _lastPositionUpdate = DateTime.now();
      return actualMachinePosition;
    }

    return null;
  }

  /// Update predicted position based on sent movement command
  void _updatePredictedPosition(
    double xDistance,
    double yDistance,
    double? zDistance,
  ) {
    if (_predictedPosition != null) {
      _predictedPosition = vm.Vector3(
        _predictedPosition!.x + xDistance,
        _predictedPosition!.y + yDistance,
        _predictedPosition!.z +
            (zDistance ?? 0.0), // Include Z-axis change if provided
      );
      _lastPositionUpdate = DateTime.now();
    }
  }
  
  /// Reset predicted position state (called when jogging stops or machine status changes)
  void _resetPredictedPosition() {
    if (_predictedPosition != null || _lastPositionUpdate != null) {
      _predictedPosition = null;
      _lastPositionUpdate = null;
      AppLogger.info('Reset jog controller predicted position state');
    }
  }
  
  /// Set up machine state monitoring to detect jog transitions
  void _setupMachineStateMonitoring() {
    _lastMachineStatus = _machineControllerBloc.state.status;
    
    _machineStateSubscription = _machineControllerBloc.stream.listen((machineState) {
      final currentStatus = machineState.status;
      
      // Check for transition from jogging to any other state
      if (_lastMachineStatus == MachineStatus.jogging && 
          currentStatus != MachineStatus.jogging) {
        AppLogger.info('Machine transitioned from jogging to ${currentStatus.name}, resetting prediction state');
        _resetPredictedPosition();
      }
      
      // Update last known status
      _lastMachineStatus = currentStatus;
    });
    
    AppLogger.info('Machine state monitoring initialized for jog controller prediction reset');
  }

  /// Add input driver to the controller
  Future<void> addInputDriver(JogInputDriver driver) async {
    if (_inputDrivers.contains(driver)) return;

    // Initialize the driver
    await driver.initialize();
    
    // Add to list
    _inputDrivers.add(driver);

    // Subscribe to its input stream
    final subscription = driver.inputStream.listen((inputEvent) {
      // Only process if the driver is active and enabled
      if (driver.isActive && driver.isEnabled) {
        add(ProportionalJogInputReceived(inputEvent: inputEvent));
      }
    });
    
    _driverSubscriptions.add(subscription);

    AppLogger.info('Added input driver: ${driver.displayName} (${driver.deviceId})');
  }

  /// Remove input driver from the controller
  Future<void> removeInputDriver(String deviceId) async {
    final index = _inputDrivers.indexWhere((driver) => driver.deviceId == deviceId);
    if (index == -1) return;

    final driver = _inputDrivers[index];
    final subscription = _driverSubscriptions[index];

    // Cancel subscription and dispose driver
    await subscription.cancel();
    await driver.dispose();

    // Remove from lists
    _inputDrivers.removeAt(index);
    _driverSubscriptions.removeAt(index);

    AppLogger.info('Removed input driver: ${driver.displayName} (${driver.deviceId})');
  }

  /// Get list of active input drivers
  List<JogInputDriver> get inputDrivers => List.unmodifiable(_inputDrivers);

  /// Enable/disable specific input driver
  void setInputDriverEnabled(String deviceId, bool enabled) {
    final driver = _inputDrivers.firstWhere(
      (driver) => driver.deviceId == deviceId,
      orElse: () => throw ArgumentError('Driver with ID $deviceId not found'),
    );
    
    driver.setEnabled(enabled);
    AppLogger.info('${enabled ? 'Enabled' : 'Disabled'} input driver: ${driver.displayName}');
  }

  @override
  Future<void> close() async {
    // Clean up machine state monitoring
    await _machineStateSubscription?.cancel();
    _machineStateSubscription = null;
    
    // Clean up all input drivers
    for (int i = 0; i < _inputDrivers.length; i++) {
      await _driverSubscriptions[i].cancel();
      await _inputDrivers[i].dispose();
    }
    _inputDrivers.clear();
    _driverSubscriptions.clear();
    
    return super.close();
  }
}
