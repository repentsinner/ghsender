import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/jog_service.dart';
import '../../utils/logger.dart';
import '../machine_controller/machine_controller_bloc.dart';
import '../machine_controller/machine_controller_event.dart';
import '../communication/cnc_communication_bloc.dart';
import '../communication/cnc_communication_event.dart';
import 'jog_controller_event.dart';
import 'jog_controller_state.dart';

/// BLoC for managing jog control logic
class JogControllerBloc extends Bloc<JogControllerEvent, JogControllerState> {
  final MachineControllerBloc _machineControllerBloc;
  final CncCommunicationBloc _communicationBloc;

  JogControllerBloc({
    required MachineControllerBloc machineControllerBloc,
    required CncCommunicationBloc communicationBloc,
  })  : _machineControllerBloc = machineControllerBloc,
        _communicationBloc = communicationBloc,
        super(JogControllerState.initial) {
    
    AppLogger.info('Jog Controller BLoC initialized');

    // Register event handlers
    on<JogControllerInitialized>(_onInitialized);
    on<JogSettingsUpdated>(_onSettingsUpdated);
    on<JoystickInputReceived>(_onJoystickInput);
    on<DiscreteJogRequested>(_onDiscreteJog);
    on<JogStopRequested>(_onJogStop);
    on<WorkZeroRequested>(_onWorkZero);
    on<ProbeRequested>(_onProbe);
    on<ProbeSettingsUpdated>(_onProbeSettingsUpdated);
    on<HomingRequested>(_onHoming);
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
    if (event.mode != null && event.mode != JogMode.joystick && state.joystickState.isActive) {
      add(const JogStopRequested());
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
    final processed = JoystickProcessor.process(
      event.x,
      event.y,
      state.settings.selectedFeedRate,
    );

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

    // Get buffer info for timing calculations
    final machineState = _machineControllerBloc.state;
    final targetInterval = BufferManager.calculateCommandInterval(
      machineState.plannerBlocksAvailable,
      machineState.maxObservedBufferBlocks,
    );

    // Check if we should send a command
    final shouldSend = _shouldSendJoystickCommand(processed, targetInterval, now);

    emit(state.copyWith(joystickState: newJoystickState));

    if (shouldSend) {
      _sendJoystickCommand(processed, now, emit);
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
  void _onJogStop(
    JogStopRequested event,
    Emitter<JogControllerState> emit,
  ) {
    // Update joystick state to inactive
    emit(state.copyWith(joystickState: JoystickState.inactive));

    // Send stop command to machine
    _machineControllerBloc.add(const MachineControllerJogStopRequested());
  }

  /// Handle work zero request
  void _onWorkZero(
    WorkZeroRequested event,
    Emitter<JogControllerState> emit,
  ) {
    try {
      final command = JogCommandBuilder.buildWorkZeroCommand(event.axes);
      AppLogger.info('Setting work zero for ${event.axes} axes');
      
      _communicationBloc.add(CncCommunicationSendCommand(command));
    } catch (e) {
      AppLogger.warning('Failed to set work zero: $e');
    }
  }

  /// Handle probe request
  void _onProbe(
    ProbeRequested event,
    Emitter<JogControllerState> emit,
  ) {
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
  void _onHoming(
    HomingRequested event,
    Emitter<JogControllerState> emit,
  ) {
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

  /// Determine if joystick command should be sent
  bool _shouldSendJoystickCommand(
    JoystickProcessResult processed,
    int targetInterval,
    DateTime now,
  ) {
    // Always send if not currently jogging
    if (!state.joystickState.isActive) return true;

    // Check timing
    if (!JogTiming.shouldSendCommand(state.joystickState.lastCommandTime, targetInterval)) {
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

  /// Send joystick command to machine (called from within event handler)
  void _sendJoystickCommand(
    JoystickProcessResult processed,
    DateTime now,
    Emitter<JogControllerState> emit,
  ) {
    final xDistance = processed.x * processed.baseDistance;
    // Invert Y-axis to convert from UI convention (Y+ = down) to CNC convention (Y+ = away from operator)
    final yDistance = -processed.y * processed.baseDistance;

    if (BufferManager.isMeaningfulMove(xDistance, yDistance)) {
      _machineControllerBloc.add(
        MachineControllerMultiAxisJogRequested(
          xDistance: xDistance,
          yDistance: yDistance,
          feedRate: processed.scaledFeedRate,
        ),
      );

      // Update last command time
      final newJoystickState = state.joystickState.copyWith(
        lastCommandTime: now,
      );
      
      emit(state.copyWith(joystickState: newJoystickState));
    }
  }
}