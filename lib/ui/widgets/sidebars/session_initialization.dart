import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import '../../themes/vscode_theme.dart';
import '../sidebar_sections/sidebar_components.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../bloc/communication/cnc_communication_bloc.dart';
import '../../../bloc/communication/cnc_communication_event.dart';
import '../../../bloc/communication/cnc_communication_state.dart';
import '../../../bloc/profile/profile_bloc.dart';
import '../../../bloc/profile/profile_state.dart';
import '../../../bloc/machine_controller/machine_controller_bloc.dart';
import '../../../bloc/machine_controller/machine_controller_event.dart';
import '../../../bloc/machine_controller/machine_controller_state.dart';
import '../../../models/machine_controller.dart';
import '../../../utils/logger.dart';

/// Session Initialization section - CNC machine setup and control interface
class SessionInitializationSection extends StatefulWidget {
  const SessionInitializationSection({super.key});

  @override
  State<SessionInitializationSection> createState() =>
      _SessionInitializationSectionState();
}

class _SessionInitializationSectionState
    extends State<SessionInitializationSection> {
  double _selectedJogDistance = 1.0;
  int _selectedJogFeedRate = 500; // Default jog feed rate
  final double _probeDistance = 10.0;
  final double _probeFeedRate = 100.0;
  
  // Joystick continuous jog state
  bool _isJogging = false;
  Timer? _jogUpdateTimer;
  double _lastJogX = 0.0;
  double _lastJogY = 0.0;
  DateTime? _lastJogCommandTime;

  @override
  void dispose() {
    _jogUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device Connection Section
          SidebarComponents.buildSectionWithInfo(
            title: 'Device Connection',
            infoTooltip: 'Configure CNC router connection settings',
            child: _buildDeviceConnection(),
          ),

          const SizedBox(height: 24),

          // Machine Homing Section
          SidebarComponents.buildSectionWithInfo(
            title: 'Machine Homing',
            infoTooltip: 'Initialize machine position by homing all axes',
            child: _buildMachineHoming(),
          ),

          const SizedBox(height: 24),

          // Manual Jog Controls Section
          SidebarComponents.buildSectionWithInfo(
            title: 'Manual Jog Controls',
            infoTooltip: 'Manually move machine axes for positioning',
            child: _buildManualJogControls(),
          ),

          const SizedBox(height: 24),

          // Work Coordinates Section
          SidebarComponents.buildSectionWithInfo(
            title: 'Work Coordinates',
            infoTooltip: 'Set work coordinate system origin points',
            child: _buildWorkCoordinates(),
          ),

          const SizedBox(height: 24),

          // Auto Probe Z-Height Section
          SidebarComponents.buildSectionWithInfo(
            title: 'Auto Probe Z-Height',
            infoTooltip: 'Automatically probe work surface for Z-zero',
            child: _buildAutoProbe(),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDeviceConnection() {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, profileState) {
        // Get current profile information
        MachineProfile? currentProfile;
        bool hasProfile = false;

        if (profileState is ProfileLoaded) {
          currentProfile = profileState.currentProfile;
          hasProfile = true;
        }

        return BlocBuilder<CncCommunicationBloc, CncCommunicationState>(
          builder: (context, commState) {
            final isConnected =
                commState is CncCommunicationConnected ||
                commState is CncCommunicationWithData;
            final isConnecting = commState is CncCommunicationConnecting;
            final hasError = commState is CncCommunicationError;

            // Button should only be enabled if we have a profile and are not connecting
            final isButtonEnabled = hasProfile && !isConnecting;

            // Generate button text based on profile and connection state
            String buttonText;
            if (isConnecting && currentProfile != null) {
              buttonText = 'Connecting to ${currentProfile.name}...';
            } else if (isConnected && currentProfile != null) {
              buttonText = 'Disconnect from ${currentProfile.name}';
            } else if (hasProfile && currentProfile != null) {
              buttonText = 'Connect to ${currentProfile.name}';
            } else {
              buttonText = 'No Profile Selected';
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connection button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isButtonEnabled
                        ? (isConnected
                              ? () => _disconnectDevice(context)
                              : () => _connectDevice(
                                  context,
                                  currentProfile!.controllerAddress,
                                ))
                        : null,
                    icon: Icon(
                      isConnecting
                          ? Icons.hourglass_empty
                          : (isConnected ? Icons.wifi_off : Icons.wifi),
                    ),
                    label: Text(buttonText),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !hasProfile
                          ? VSCodeTheme.secondaryText.withValues(alpha: 0.3)
                          : (isConnected
                                ? VSCodeTheme.error
                                : (hasError
                                      ? VSCodeTheme.warning
                                      : VSCodeTheme.focus)),
                      foregroundColor: hasProfile
                          ? Colors.white
                          : VSCodeTheme.secondaryText,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      textStyle: VSCodeTheme.buttonText,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMachineHoming() {
    return BlocBuilder<CncCommunicationBloc, CncCommunicationState>(
      builder: (context, state) {
        final isConnected =
            state is CncCommunicationConnected ||
            state is CncCommunicationWithData;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isConnected ? _homeMachine : null,
            icon: const Icon(Icons.home),
            label: const Text('Home Machine'),
            style: ElevatedButton.styleFrom(
              backgroundColor: VSCodeTheme.focus.withValues(alpha: 0.8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              disabledBackgroundColor: VSCodeTheme.secondaryText.withValues(
                alpha: 0.3,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildManualJogControls() {
    return BlocBuilder<MachineControllerBloc, MachineControllerState>(
      builder: (context, machineState) {
        // Check if jogging is allowed based on machine state
        final canJog =
            (machineState.hasController) &&
            (machineState.isOnline) &&
            (machineState.grblHalDetected) &&
            (machineState.status == MachineStatus.idle ||
                machineState.status == MachineStatus.jogging ||
                machineState.status == MachineStatus.check);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Jog Distance Selector
            Text(
              'Jog Distance (mm)',
              style: VSCodeTheme.labelText.copyWith(
                color: VSCodeTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => setState(() => _selectedJogDistance = 0.0),
                  child: Text('Free'),
                ),
                const SizedBox(width: 8),
                _buildJogDistanceButton(0.1),
                const SizedBox(width: 8),
                _buildJogDistanceButton(1.0),
                const SizedBox(width: 8),
                _buildJogDistanceButton(10.0),
                const SizedBox(width: 8),
              ],
            ),

            const SizedBox(height: 16),

            // Jog Feed Rate Selector
            Text(
              'Jog Feed Rate (mm/min)',
              style: VSCodeTheme.labelText.copyWith(
                color: VSCodeTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildJogFeedRateButton(100),
                const SizedBox(width: 8),
                _buildJogFeedRateButton(500),
                const SizedBox(width: 8),
                _buildJogFeedRateButton(1000),
                const SizedBox(width: 8),
                _buildJogFeedRateButton(4000),
              ],
            ),

            const SizedBox(height: 16),

            // XY Movement Controls
            Text(
              'XY Movement',
              style: VSCodeTheme.labelText.copyWith(
                color: VSCodeTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            // Show joystick for free mode, traditional buttons for fixed distances
            _selectedJogDistance == 0.0
                ? _buildJoystickControl(canJog)
                : _buildTraditionalJogButtons(canJog),

            const SizedBox(height: 16),

            // Z Movement Controls
            Text(
              'Z Movement',
              style: VSCodeTheme.labelText.copyWith(
                color: VSCodeTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildZButton(
                    'Z+',
                    Icons.keyboard_arrow_up,
                    () => _jogAxis('Z', _selectedJogDistance),
                    canJog,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildZButton(
                    'Z-',
                    Icons.keyboard_arrow_down,
                    () => _jogAxis('Z', -_selectedJogDistance),
                    canJog,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildWorkCoordinates() {
    return BlocBuilder<CncCommunicationBloc, CncCommunicationState>(
      builder: (context, state) {
        final isConnected =
            state is CncCommunicationConnected ||
            state is CncCommunicationWithData;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set Current Position as Work Zero',
              style: VSCodeTheme.labelText.copyWith(
                color: VSCodeTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildZeroButton(
                    'X Zero',
                    Icons.gps_fixed,
                    () => _setWorkZero('X'),
                    isConnected,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildZeroButton(
                    'Y Zero',
                    Icons.gps_fixed,
                    () => _setWorkZero('Y'),
                    isConnected,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildZeroButton(
                    'Z Zero',
                    Icons.gps_fixed,
                    () => _setWorkZero('Z'),
                    isConnected,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildZeroButton(
                    'XYZ Zero',
                    Icons.gps_fixed,
                    () => _setWorkZero('XYZ'),
                    isConnected,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildAutoProbe() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Distance (mm)', style: VSCodeTheme.captionText),
                  const SizedBox(height: 4),
                  Text(
                    _probeDistance.toStringAsFixed(1),
                    style: VSCodeTheme.sectionTitle,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Feed Rate', style: VSCodeTheme.captionText),
                  const SizedBox(height: 4),
                  Text(
                    _probeFeedRate.toStringAsFixed(0),
                    style: VSCodeTheme.sectionTitle,
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        BlocBuilder<CncCommunicationBloc, CncCommunicationState>(
          builder: (context, state) {
            final isConnected =
                state is CncCommunicationConnected ||
                state is CncCommunicationWithData;

            return SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isConnected ? _probeWorkSurface : null,
                icon: const Icon(Icons.height),
                label: const Text('Probe Work Surface'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VSCodeTheme.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  disabledBackgroundColor: VSCodeTheme.secondaryText.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: VSCodeTheme.warning.withValues(alpha: 0.1),
            border: Border.all(
              color: VSCodeTheme.warning.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(Icons.warning, size: 16, color: VSCodeTheme.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ensure probe is connected and positioned above work surface',
                  style: VSCodeTheme.captionText.copyWith(
                    color: VSCodeTheme.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJogDistanceButton(double distance) {
    final isSelected = _selectedJogDistance == distance;
    return Expanded(
      child: ElevatedButton(
        onPressed: () => setState(() => _selectedJogDistance = distance),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? VSCodeTheme.focus
              : VSCodeTheme.sideBarBackground,
          foregroundColor: isSelected ? Colors.white : VSCodeTheme.primaryText,
          side: BorderSide(color: VSCodeTheme.border),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        child: Text(
          distance == distance.toInt()
              ? distance.toInt().toString()
              : distance.toString(),
          style: VSCodeTheme.labelText,
        ),
      ),
    );
  }

  Widget _buildJogFeedRateButton(int feedRate) {
    final isSelected = _selectedJogFeedRate == feedRate;
    return Expanded(
      child: ElevatedButton(
        onPressed: () => setState(() => _selectedJogFeedRate = feedRate),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? VSCodeTheme.focus
              : VSCodeTheme.sideBarBackground,
          foregroundColor: isSelected ? Colors.white : VSCodeTheme.primaryText,
          side: BorderSide(color: VSCodeTheme.border),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        child: Text(feedRate.toString(), style: VSCodeTheme.labelText),
      ),
    );
  }

  Widget _buildJoystickControl(bool canJog) {
    return Center(
      child: SizedBox(
        width: 150,
        height: 150,
        child: Joystick(
          mode: JoystickMode.all,
          period: const Duration(milliseconds: 8), // ~120 FPS
          listener: ((details) {
            _handleJoystickInput(details, canJog);
          }) as dynamic,
          base: JoystickBase(
            decoration: JoystickBaseDecoration(
              color: VSCodeTheme.sideBarBackground,
            ),
            size: 150,
          ),
          stick: JoystickStick(
            decoration: JoystickStickDecoration(
              color: canJog ? VSCodeTheme.focus : VSCodeTheme.secondaryText.withValues(alpha: 0.5),
            ),
            size: 50,
          ),
        ),
      ),
    );
  }

  Widget _buildTraditionalJogButtons(bool canJog) {
    return Center(
      child: Column(
        children: [
          // Y+ button
          _buildJogButton(
            Icons.keyboard_arrow_up,
            'Y+',
            () => _jogAxis('Y', _selectedJogDistance),
            canJog,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // X- button
              _buildJogButton(
                Icons.keyboard_arrow_left,
                'X-',
                () => _jogAxis('X', -_selectedJogDistance),
                canJog,
              ),
              const SizedBox(width: 8),
              // XY label
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: VSCodeTheme.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text('XY', style: VSCodeTheme.smallText),
                ),
              ),
              const SizedBox(width: 8),
              // X+ button
              _buildJogButton(
                Icons.keyboard_arrow_right,
                'X+',
                () => _jogAxis('X', _selectedJogDistance),
                canJog,
              ),
            ],
          ),
          // Y- button
          _buildJogButton(
            Icons.keyboard_arrow_down,
            'Y-',
            () => _jogAxis('Y', -_selectedJogDistance),
            canJog,
          ),
        ],
      ),
    );
  }

  Widget _buildJogButton(
    IconData icon,
    String label,
    VoidCallback? onPressed,
    bool isConnected,
  ) {
    return SizedBox(
      width: 40,
      height: 40,
      child: ElevatedButton(
        onPressed: isConnected ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: VSCodeTheme.sideBarBackground,
          foregroundColor: VSCodeTheme.primaryText,
          side: BorderSide(color: VSCodeTheme.border),
          padding: EdgeInsets.zero,
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }

  Widget _buildZButton(
    String label,
    IconData icon,
    VoidCallback? onPressed,
    bool isConnected,
  ) {
    return ElevatedButton.icon(
      onPressed: isConnected ? onPressed : null,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: VSCodeTheme.sideBarBackground,
        foregroundColor: VSCodeTheme.primaryText,
        side: BorderSide(color: VSCodeTheme.border),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      ),
    );
  }

  Widget _buildZeroButton(
    String label,
    IconData icon,
    VoidCallback? onPressed,
    bool isConnected,
  ) {
    return ElevatedButton.icon(
      onPressed: isConnected ? onPressed : null,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: VSCodeTheme.sideBarBackground,
        foregroundColor: VSCodeTheme.primaryText,
        side: BorderSide(color: VSCodeTheme.border),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      ),
    );
  }

  // Action handlers for actual CNC communication
  void _connectDevice(BuildContext context, String controllerAddress) {
    context.read<CncCommunicationBloc>().add(
      CncCommunicationConnectRequested(controllerAddress),
    );
  }

  void _disconnectDevice(BuildContext context) {
    context.read<CncCommunicationBloc>().add(
      CncCommunicationDisconnectRequested(),
    );
  }

  void _homeMachine() {
    AppLogger.info('Homing machine request');

    // Send homing command through CommunicationBloc (direct GRBL command)
    context.read<CncCommunicationBloc>().add(
      CncCommunicationSendCommand('\$H'), // GRBL homing command
    );
  }

  void _jogAxis(String axis, double distance) {
    AppLogger.info(
      'Jog request: $axis axis by ${distance}mm at ${_selectedJogFeedRate}mm/min',
    );

    // Send jog command through MachineControllerBloc
    context.read<MachineControllerBloc>().add(
      MachineControllerJogRequested(
        axis: axis,
        distance: distance,
        feedRate: _selectedJogFeedRate,
      ),
    );
  }

  void _handleJoystickInput(dynamic details, bool canJog) {
    // Only process joystick input if jogging is allowed and we're in free mode
    if (!canJog || _selectedJogDistance != 0.0) {
      _stopJogging();
      return;
    }

    double x = details.x;
    double y = details.y;
    final now = DateTime.now();

    // When joystick returns to center, stop
    if (x == 0.0 && y == 0.0) {
      if (_isJogging) {
        _stopJogging();
      }
      return;
    }

    // Calculate magnitude for feed rate scaling
    double magnitude = sqrt(x * x + y * y);
    magnitude = magnitude.clamp(0.0, 1.0);

    // Apply dead zone for noise filtering
    if (magnitude < 0.05) {
      if (_isJogging) {
        _stopJogging();
      }
      return;
    }

    // Get current buffer status from machine controller
    final machineState = context.read<MachineControllerBloc>().state;
    final availableBlocks = machineState.plannerBlocksAvailable ?? 100; // Available blocks
    final maxBufferBlocks = machineState.maxObservedBufferBlocks ?? 100; // Total buffer size
    
    // Calculate USED buffer blocks (this is what we should manage!)
    final usedBufferBlocks = maxBufferBlocks - availableBlocks;

    // Target feed rate scaled by magnitude
    final scaledFeedRate = (magnitude * _selectedJogFeedRate).round();
    
    // Calculate distance for high-frequency responsive control
    // Use shorter execution time for higher responsiveness (25ms vs gSender's 60ms)  
    const targetExecutionTimeMs = 25.0;
    final baseDistance = (scaledFeedRate / 60.0) * (targetExecutionTimeMs / 1000.0); // mm per command
    
    // Buffer-aware command rate limiting based on USED blocks
    // Smooth interpolation between aggressive filling (120Hz) and buffer protection (30Hz)
    const targetMinUsed = 1.0;     // Aggressive filling threshold
    const targetMaxUsed = 8.0;     // Buffer protection threshold
    
    // Work with used blocks (clamped to reasonable range)
    final managedUsedBlocks = usedBufferBlocks.clamp(0.0, 15.0);
    
    // Lerp between 8ms (120Hz) and 33ms (30Hz) based on buffer usage
    const minIntervalMs = 8.0;   // 120Hz - aggressive filling
    const maxIntervalMs = 33.0;  // 30Hz - buffer protection
    
    final bufferRatio = (managedUsedBlocks - targetMinUsed) / (targetMaxUsed - targetMinUsed);
    final clampedRatio = bufferRatio.clamp(0.0, 1.0);
    final targetIntervalMs = (minIntervalMs + (maxIntervalMs - minIntervalMs) * clampedRatio).round();
    
    // Check if enough time has passed since last command
    final timeSinceLastCommand = _lastJogCommandTime != null 
        ? now.difference(_lastJogCommandTime!).inMilliseconds 
        : targetIntervalMs;
    
    // Check for direction changes that need immediate response
    final directionChanged = _shouldSendJogUpdate(x, y, magnitude, now);
    
    // Don't send if not enough time passed and no direction change
    if (timeSinceLastCommand < targetIntervalMs && !directionChanged) {
      return; // Not ready to send yet
    }
    
    // Send command - either timing allows or direction changed significantly
    {
      // Calculate move distances using gSender-inspired approach
      final xDistance = x * baseDistance;
      final yDistance = y * baseDistance;
      
      // Only send if move distance is meaningful (> 0.01mm)
      if ((xDistance.abs() + yDistance.abs()) > 0.01) {
        // Send multi-axis jog command
        context.read<MachineControllerBloc>().add(
          MachineControllerMultiAxisJogRequested(
            xDistance: xDistance,
            yDistance: yDistance,
            feedRate: scaledFeedRate,
          ),
        );
        
        // Update state
        _lastJogX = x;
        _lastJogY = y;
        _lastJogCommandTime = now;
        _isJogging = true;
      }
    }
  }

  bool _shouldSendJogUpdate(double x, double y, double magnitude, DateTime now) {
    // Always send if we're not currently jogging
    if (!_isJogging) return true;
    
    // Check for significant direction change (> 30 degrees)
    if (_lastJogX != 0.0 || _lastJogY != 0.0) {
      final lastAngle = atan2(_lastJogY, _lastJogX);
      final currentAngle = atan2(y, x);
      final angleDiff = (currentAngle - lastAngle).abs();
      final normalizedAngleDiff = angleDiff > pi ? (2 * pi - angleDiff) : angleDiff;
      
      if (normalizedAngleDiff > (pi / 6)) { // 30 degrees in radians
        return true; // Significant direction change
      }
    }
    
    // Check for significant magnitude change
    final lastMagnitude = sqrt(_lastJogX * _lastJogX + _lastJogY * _lastJogY);
    if ((magnitude - lastMagnitude).abs() > 0.1) {
      return true; // Significant speed change
    }
    
    // Otherwise, rely on time-based updates
    return false;
  }

  void _stopJogging() {
    if (!_isJogging) return;
    
    _isJogging = false;
    _lastJogX = 0.0;
    _lastJogY = 0.0;
    _lastJogCommandTime = null;
    _jogUpdateTimer?.cancel();
    
    // Send jog stop command
    context.read<MachineControllerBloc>().add(
      const MachineControllerJogStopRequested(),
    );
  }

  void _setWorkZero(String axes) {
    AppLogger.info('Setting work zero for $axes axes');

    // Send work coordinate system commands through CommunicationBloc
    String command;
    switch (axes) {
      case 'X':
        command = 'G92 X0'; // Set current X position as zero
        break;
      case 'Y':
        command = 'G92 Y0'; // Set current Y position as zero
        break;
      case 'Z':
        command = 'G92 Z0'; // Set current Z position as zero
        break;
      case 'XYZ':
        command = 'G92 X0 Y0 Z0'; // Set all current positions as zero
        break;
      default:
        AppLogger.warning('Unknown axes for work zero: $axes');
        return;
    }

    context.read<CncCommunicationBloc>().add(
      CncCommunicationSendCommand(command),
    );
  }

  void _probeWorkSurface() {
    AppLogger.info(
      'Probing work surface - distance: ${_probeDistance}mm, feed: ${_probeFeedRate}mm/min',
    );

    // Send GRBL probe command: G38.2 Z-10 F100 (probe toward workpiece in negative Z direction)
    final probeCommand = 'G38.2 Z-$_probeDistance F${_probeFeedRate.toInt()}';

    context.read<CncCommunicationBloc>().add(
      CncCommunicationSendCommand(probeCommand),
    );
  }
}
