import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import '../../themes/vscode_theme.dart';
import '../sidebar_sections/sidebar_components.dart';
import '../../../bloc/bloc_exports.dart';
import '../../../domain/enums/machine_status.dart';
import '../../../domain/entities/machine_profile.dart';

/// Session Initialization section - CNC machine setup and control interface
class SessionInitializationSection extends StatefulWidget {
  const SessionInitializationSection({super.key});

  @override
  State<SessionInitializationSection> createState() =>
      _SessionInitializationSectionState();
}

class _SessionInitializationSectionState
    extends State<SessionInitializationSection> {

  @override
  void dispose() {
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

        return BlocBuilder<JogControllerBloc, JogControllerState>(
          builder: (context, jogState) {
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
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.read<JogControllerBloc>().add(
                          const JogSettingsUpdated(
                            selectedDistance: 0.0,
                            mode: JogMode.joystick,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: jogState.settings.selectedDistance == 0.0
                              ? VSCodeTheme.focus
                              : VSCodeTheme.sideBarBackground,
                          foregroundColor: jogState.settings.selectedDistance == 0.0
                              ? Colors.white 
                              : VSCodeTheme.primaryText,
                          side: BorderSide(color: VSCodeTheme.border),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('Free'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildJogDistanceButton(0.1, jogState.settings.selectedDistance),
                    const SizedBox(width: 8),
                    _buildJogDistanceButton(1.0, jogState.settings.selectedDistance),
                    const SizedBox(width: 8),
                    _buildJogDistanceButton(10.0, jogState.settings.selectedDistance),
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
                    _buildJogFeedRateButton(100, jogState.settings.selectedFeedRate),
                    const SizedBox(width: 8),
                    _buildJogFeedRateButton(500, jogState.settings.selectedFeedRate),
                    const SizedBox(width: 8),
                    _buildJogFeedRateButton(1000, jogState.settings.selectedFeedRate),
                    const SizedBox(width: 8),
                    _buildJogFeedRateButton(4000, jogState.settings.selectedFeedRate),
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
                jogState.settings.selectedDistance == 0.0
                    ? _buildJoystickControl(canJog)
                    : _buildTraditionalJogButtons(canJog, jogState.settings.selectedDistance),

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
                        () => context.read<JogControllerBloc>().add(
                          DiscreteJogRequested(
                            axis: 'Z',
                            distance: jogState.settings.selectedDistance,
                          ),
                        ),
                        canJog,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildZButton(
                        'Z-',
                        Icons.keyboard_arrow_down,
                        () => context.read<JogControllerBloc>().add(
                          DiscreteJogRequested(
                            axis: 'Z',
                            distance: -jogState.settings.selectedDistance,
                          ),
                        ),
                        canJog,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
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
    return BlocBuilder<JogControllerBloc, JogControllerState>(
      builder: (context, jogState) {
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
                        jogState.probeSettings.distance.toStringAsFixed(1),
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
                        jogState.probeSettings.feedRate.toStringAsFixed(0),
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
      },
    );
  }

  Widget _buildJogDistanceButton(double distance, double selectedDistance) {
    final isSelected = selectedDistance == distance;
    return Expanded(
      child: ElevatedButton(
        onPressed: () => context.read<JogControllerBloc>().add(
          JogSettingsUpdated(
            selectedDistance: distance,
            mode: JogMode.discrete,
          ),
        ),
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

  Widget _buildJogFeedRateButton(int feedRate, int selectedFeedRate) {
    final isSelected = selectedFeedRate == feedRate;
    return Expanded(
      child: ElevatedButton(
        onPressed: () => context.read<JogControllerBloc>().add(
          JogSettingsUpdated(selectedFeedRate: feedRate),
        ),
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
            if (canJog) {
              context.read<JogControllerBloc>().add(
                JoystickInputReceived(
                  x: details.x,
                  y: details.y,
                ),
              );
            }
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

  Widget _buildTraditionalJogButtons(bool canJog, double selectedDistance) {
    return Center(
      child: Column(
        children: [
          // Y+ button
          _buildJogButton(
            Icons.keyboard_arrow_up,
            'Y+',
            () => context.read<JogControllerBloc>().add(
              DiscreteJogRequested(
                axis: 'Y',
                distance: selectedDistance,
              ),
            ),
            canJog,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // X- button
              _buildJogButton(
                Icons.keyboard_arrow_left,
                'X-',
                () => context.read<JogControllerBloc>().add(
                  DiscreteJogRequested(
                    axis: 'X',
                    distance: -selectedDistance,
                  ),
                ),
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
                () => context.read<JogControllerBloc>().add(
                  DiscreteJogRequested(
                    axis: 'X',
                    distance: selectedDistance,
                  ),
                ),
                canJog,
              ),
            ],
          ),
          // Y- button
          _buildJogButton(
            Icons.keyboard_arrow_down,
            'Y-',
            () => context.read<JogControllerBloc>().add(
              DiscreteJogRequested(
                axis: 'Y',
                distance: -selectedDistance,
              ),
            ),
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
    context.read<JogControllerBloc>().add(
      const HomingRequested(),
    );
  }


  void _setWorkZero(String axes) {
    context.read<JogControllerBloc>().add(
      WorkZeroRequested(axes: axes),
    );
  }

  void _probeWorkSurface() {
    context.read<JogControllerBloc>().add(
      const ProbeRequested(),
    );
  }
}
