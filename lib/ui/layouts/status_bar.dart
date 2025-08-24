import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../themes/vscode_theme.dart';
import '../widgets/problem_item.dart';
import '../utils/status_colors.dart';
import '../../bloc/bloc_exports.dart';
import '../../bloc/performance/performance_bloc.dart';
import '../../bloc/performance/performance_state.dart';
import '../../domain/enums/machine_status.dart';

/// Status Bar widget - bottom status information
class StatusBar extends StatelessWidget {
  final VoidCallback onTogglePanel;
  final bool panelVisible;

  const StatusBar({
    super.key,
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

          // Machine status indicator
          BlocBuilder<MachineControllerBloc, MachineControllerState>(
            builder: (context, machineState) {
              return _buildMachineStatusItem(machineState);
            },
          ),

          // Problems indicator
          BlocBuilder<ProblemsBloc, ProblemsState>(
            builder: (context, problemsState) {
              return GestureDetector(
                onTap: onTogglePanel, // Open panel to show problems
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  height: VSCodeTheme.statusBarHeight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ProblemSummary(
                        errorCount: problemsState.errorCount,
                        warningCount: problemsState.warningCount,
                        infoCount: problemsState.infoCount,
                        onTap: onTogglePanel,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const Spacer(),

          InkWell(
            onTap: () {
              // Handle bug report tap
              launchUrl(
                Uri.parse('https://github.com/repentsinner/ghsender/issues'),
              );
            },
            child: Row(
              children: [
                Icon(Icons.bug_report_outlined, size: 12),
                Text(
                  ' Report a bug / Suggest an improvement',
                  style: GoogleFonts.inconsolata(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // FPS and Status Rate display with performance color coding
          BlocBuilder<PerformanceBloc, PerformanceState>(
            builder: (context, performanceState) {
              return BlocBuilder<CncCommunicationBloc, CncCommunicationState>(
                builder: (context, commState) {
                  final fps = performanceState is PerformanceLoaded
                      ? performanceState.fps
                      : 0.0;

                  // Get performance data only from state to ensure real-time updates
                  // Only CncCommunicationConnectedWithPerformance state contains performance data
                  final performanceData =
                      commState is CncCommunicationConnectedWithPerformance
                      ? commState.performanceData
                      : null;

                  final statusRate = performanceData?.statusMessagesPerSecond
                      .toDouble();
                  final isConnected =
                      commState is CncCommunicationConnected ||
                      commState is CncCommunicationConnectedWithPerformance ||
                      commState is CncCommunicationWithData;

                  // Calculate performance percentages
                  // Expected: 60 FPS, 125 Hz status rate
                  final fpsPercentage = fps / 60.0;

                  // Determine performance color - only factor in status rate if connected and available
                  final Color iconColor;
                  if (isConnected && statusRate != null) {
                    final statusRatePercentage = statusRate / 125.0;
                    iconColor = _getPerformanceColor(
                      fpsPercentage,
                      statusRatePercentage,
                    );
                  } else {
                    // Only use FPS for color coding when not connected
                    iconColor = _getPerformanceColorFpsOnly(fpsPercentage);
                  }

                  // Build display text - include status rate only when connected and available
                  final String displayText;
                  if (isConnected && statusRate != null) {
                    displayText =
                        '${fps.toStringAsFixed(1)} FPS / ${statusRate.toStringAsFixed(1)} Hz';
                  } else {
                    displayText = '${fps.toStringAsFixed(1)} FPS';
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.speed, color: iconColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        displayText,
                        style: GoogleFonts.inconsolata(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(width: 16),

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

  Widget _buildMachineStatusItem(MachineControllerState machineState) {
    if (!machineState.hasController || !machineState.isOnline) {
      return Container(); // Hide when no controller or offline
    }

    final status = machineState.status;
    
    // Get the appropriate color provider based on detected plugins
    final colorProvider = StatusColorProviders.getProviderForPlugins(machineState.plugins);
    final statusColor = colorProvider.getColorForStatus(status);
    
    // Map status to appropriate icons
    final IconData icon = switch (status) {
      MachineStatus.idle => Icons.circle,
      MachineStatus.running => Icons.play_circle_filled,
      MachineStatus.paused => Icons.pause_circle_filled,
      MachineStatus.alarm || MachineStatus.error => Icons.error,
      MachineStatus.homing => Icons.home,
      MachineStatus.jogging => Icons.open_with,
      MachineStatus.hold => Icons.pause,
      MachineStatus.door => Icons.door_front_door,
      MachineStatus.check => Icons.check_circle,
      MachineStatus.sleep => Icons.bedtime,
      _ => Icons.help,
    };

    // Build status text with buffer info if available
    String statusText = status.displayName;
    if (machineState.plannerBlocksAvailable != null && machineState.maxObservedBufferBlocks != null) {
      final usedBlocks = machineState.maxObservedBufferBlocks! - machineState.plannerBlocksAvailable!;
      statusText += ' ($usedBlocks/${machineState.maxObservedBufferBlocks} blocks)';
    } else if (machineState.plannerBlocksAvailable != null) {
      statusText += ' (${machineState.plannerBlocksAvailable} avail)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      height: VSCodeTheme.statusBarHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: statusColor, size: 14),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: GoogleFonts.inconsolata(color: Colors.white, fontSize: 11),
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

  /// Determine performance color based on FPS and status rate percentages
  /// Green (success): Both metrics >= 95% of expected values
  /// Orange (warning): Both metrics >= 90% of expected values
  /// Red (error): Either metric < 90% of expected values
  Color _getPerformanceColor(
    double fpsPercentage,
    double statusRatePercentage,
  ) {
    final minPercentage = [
      fpsPercentage,
      statusRatePercentage,
    ].reduce((a, b) => a < b ? a : b);

    if (minPercentage >= 0.95) {
      return VSCodeTheme.success; // Green: Both >= 95%
    } else if (minPercentage >= 0.90) {
      return VSCodeTheme.warning; // Orange: Both >= 90%
    } else {
      return VSCodeTheme.error; // Red: Either < 90%
    }
  }

  /// Determine performance color based only on FPS percentage (when not connected)
  /// Green (success): FPS >= 95% of expected value (60 FPS)
  /// Orange (warning): FPS >= 90% of expected value
  /// Red (error): FPS < 90% of expected value
  Color _getPerformanceColorFpsOnly(double fpsPercentage) {
    if (fpsPercentage >= 0.95) {
      return VSCodeTheme.success; // Green: >= 95%
    } else if (fpsPercentage >= 0.90) {
      return VSCodeTheme.warning; // Orange: >= 90%
    } else {
      return VSCodeTheme.error; // Red: < 90%
    }
  }
}
