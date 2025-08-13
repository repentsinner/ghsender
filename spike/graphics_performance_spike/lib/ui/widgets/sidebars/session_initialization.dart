import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../themes/vscode_theme.dart';
import '../sidebar_sections/sidebar_components.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../bloc/communication/cnc_communication_bloc.dart';
import '../../../bloc/communication/cnc_communication_event.dart';
import '../../../bloc/communication/cnc_communication_state.dart';
import '../../../bloc/profile/profile_bloc.dart';
import '../../../bloc/profile/profile_state.dart';

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
  final double _probeDistance = 10.0;
  final double _probeFeedRate = 100.0;

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
    return BlocBuilder<CncCommunicationBloc, CncCommunicationState>(
      builder: (context, state) {
        final isConnected =
            state is CncCommunicationConnected ||
            state is CncCommunicationWithData;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Jog Distance Selector
            Text(
              'Jog Distance (mm)',
              style: GoogleFonts.inconsolata(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: VSCodeTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildJogDistanceButton(0.1),
                const SizedBox(width: 8),
                _buildJogDistanceButton(1.0),
                const SizedBox(width: 8),
                _buildJogDistanceButton(10.0),
                const SizedBox(width: 8),
                _buildJogDistanceButton(
                  1.0,
                ), // Custom distance input could go here
              ],
            ),

            const SizedBox(height: 16),

            // XY Movement Controls
            Text(
              'XY Movement',
              style: GoogleFonts.inconsolata(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: VSCodeTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Column(
                children: [
                  // Y+ button
                  _buildJogButton(
                    Icons.keyboard_arrow_up,
                    'Y+',
                    () => _jogAxis('Y', _selectedJogDistance),
                    isConnected,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // X- button
                      _buildJogButton(
                        Icons.keyboard_arrow_left,
                        'X-',
                        () => _jogAxis('X', -_selectedJogDistance),
                        isConnected,
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
                          child: Text(
                            'XY',
                            style: GoogleFonts.inconsolata(
                              fontSize: 10,
                              color: VSCodeTheme.secondaryText,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // X+ button
                      _buildJogButton(
                        Icons.keyboard_arrow_right,
                        'X+',
                        () => _jogAxis('X', _selectedJogDistance),
                        isConnected,
                      ),
                    ],
                  ),
                  // Y- button
                  _buildJogButton(
                    Icons.keyboard_arrow_down,
                    'Y-',
                    () => _jogAxis('Y', -_selectedJogDistance),
                    isConnected,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Z Movement Controls
            Text(
              'Z Movement',
              style: GoogleFonts.inconsolata(
                fontSize: 12,
                fontWeight: FontWeight.w500,
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
                    isConnected,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildZButton(
                    'Z-',
                    Icons.keyboard_arrow_down,
                    () => _jogAxis('Z', -_selectedJogDistance),
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
              style: GoogleFonts.inconsolata(
                fontSize: 12,
                fontWeight: FontWeight.w500,
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
                  Text(
                    'Distance (mm)',
                    style: GoogleFonts.inconsolata(
                      fontSize: 11,
                      color: VSCodeTheme.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _probeDistance.toStringAsFixed(1),
                    style: GoogleFonts.inconsolata(
                      fontSize: 14,
                      color: VSCodeTheme.primaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Feed Rate',
                    style: GoogleFonts.inconsolata(
                      fontSize: 11,
                      color: VSCodeTheme.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _probeFeedRate.toStringAsFixed(0),
                    style: GoogleFonts.inconsolata(
                      fontSize: 14,
                      color: VSCodeTheme.primaryText,
                    ),
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
                  style: GoogleFonts.inconsolata(
                    fontSize: 11,
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
          style: GoogleFonts.inconsolata(fontSize: 12),
        ),
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
    // Placeholder for homing functionality
    debugPrint('Homing machine...');
  }

  void _jogAxis(String axis, double distance) {
    // Placeholder for jogging functionality
    debugPrint('Jogging $axis axis by $distance mm');
  }

  void _setWorkZero(String axes) {
    // Placeholder for setting work zero
    debugPrint('Setting work zero for $axes axes');
  }

  void _probeWorkSurface() {
    // Placeholder for probing functionality
    debugPrint('Probing work surface...');
  }

}
