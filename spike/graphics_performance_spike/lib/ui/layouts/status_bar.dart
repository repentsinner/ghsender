import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../themes/vscode_theme.dart';
import '../../bloc/bloc_exports.dart';

/// Status Bar widget - bottom status information
class StatusBar extends StatelessWidget {
  final String cameraInfo;
  final bool isAutoMode;
  final VoidCallback onTogglePanel;
  final bool panelVisible;

  const StatusBar({
    super.key,
    required this.cameraInfo,
    required this.isAutoMode,
    required this.onTogglePanel,
    required this.panelVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: VSCodeTheme.statusBarHeight,
      color: VSCodeTheme.statusBarBackground,
      child: Row(
        children: [
          // Left section - Connection status
          BlocBuilder<ProfileBloc, ProfileState>(
            builder: (context, profileState) {
              return BlocBuilder<CncCommunicationBloc, CncCommunicationState>(
                builder: (context, commState) {
                  return _buildConnectionStatusItem(commState, profileState);
                },
              );
            },
          ),

          _buildDivider(),

          // Camera mode indicator
          _buildStatusItem(
            icon: isAutoMode ? Icons.play_circle : Icons.pause_circle,
            text: isAutoMode ? 'Auto' : 'Manual',
          ),

          const Spacer(),

          // Panel toggle
          GestureDetector(
            onTap: onTogglePanel,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              height: VSCodeTheme.statusBarHeight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    panelVisible
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    panelVisible ? 'Hide Panel' : 'Show Panel',
                    style: GoogleFonts.inconsolata(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusItem(
    CncCommunicationState commState,
    ProfileState profileState,
  ) {
    // Get current profile name for display
    String? profileName;
    if (profileState is ProfileLoaded) {
      profileName = profileState.currentProfile.name;
    }

    final (IconData icon, String text, Color iconColor) = switch (commState) {
      CncCommunicationInitial() => (
        Icons.portable_wifi_off,
        'Not connected',
        Colors.grey,
      ),
      CncCommunicationConnecting() => (
        Icons.wifi,
        profileName != null ? 'Connecting to $profileName...' : 'Connecting...',
        Colors.orange,
      ),
      CncCommunicationConnected() => (
        Icons.wifi,
        profileName != null ? 'Connected to $profileName' : 'Connected',
        Colors.green,
      ),
      CncCommunicationWithData() => (
        Icons.wifi,
        profileName ?? 'Active connection',
        Colors.green,
      ),
      CncCommunicationDisconnected() => (
        Icons.portable_wifi_off,
        commState.statusMessage,
        Colors.red,
      ),
      CncCommunicationError() => (
        Icons.error,
        commState.statusMessage,
        Colors.red,
      ),
      _ => (Icons.help, 'Unknown', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      height: VSCodeTheme.statusBarHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inconsolata(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      height: VSCodeTheme.statusBarHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inconsolata(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 14,
      color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
