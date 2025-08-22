import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../themes/vscode_theme.dart';
import '../sidebar_sections/sidebar_components.dart';
import '../../../bloc/machine_controller/machine_controller_bloc.dart';
import '../../../bloc/machine_controller/machine_controller_state.dart';
import '../../../bloc/communication/cnc_communication_bloc.dart';
import '../../../bloc/communication/cnc_communication_state.dart';
import '../../../models/machine_controller.dart';
import '../../../renderers/text_texture_factory.dart';
import '../../../utils/logger.dart';

/// Debug section in the sidebar - system information and debugging tools
class DebugSection extends StatelessWidget {
  const DebugSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System Information Section
          SidebarComponents.buildSectionWithInfo(
            title: 'System Information',
            infoTooltip:
                'Platform and runtime environment details for debugging',
            child: Column(
              children: [
                SidebarComponents.buildInfoCard(
                  title: 'Platform',
                  content:
                      'macOS (Darwin)\nFlutter 3.33.0-1.0.pre-1145\nDart 3.10.0',
                ),

                const SizedBox(height: 12),

                SidebarComponents.buildInfoCard(
                  title: 'Graphics Backend',
                  content:
                      'Flutter Impeller (Metal)\nNative GPU acceleration\nHardware shader compilation',
                ),

                const SizedBox(height: 12),

                SidebarComponents.buildInfoCard(
                  title: 'Renderer Details',
                  content:
                      'FlutterScene Batch Renderer\nCustom line geometry shaders\nThree.js Line2/LineSegments2 style',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Debug Tools Section
          SidebarComponents.buildSectionWithInfo(
            title: 'Debug Tools',
            infoTooltip:
                'Development and debugging utilities for troubleshooting',
            child: Column(
              children: [
                _buildActionCard(
                  icon: Icons.refresh,
                  title: 'Reload Shaders',
                  description: 'Recompile and reload custom shaders',
                  onTap: () {
                    // TODO: Implement shader reload
                    _showFeatureNotImplemented(context);
                  },
                ),

                const SizedBox(height: 12),

                _buildActionCard(
                  icon: Icons.bug_report,
                  title: 'Export Debug Info',
                  description: 'Generate system and performance report',
                  onTap: () {
                    // TODO: Implement debug export
                    _showFeatureNotImplemented(context);
                  },
                ),

                const SizedBox(height: 12),

                _buildActionCard(
                  icon: Icons.memory,
                  title: 'Memory Usage',
                  description: 'View GPU and system memory statistics',
                  onTap: () {
                    // TODO: Implement memory viewer
                    _showFeatureNotImplemented(context);
                  },
                ),

                const SizedBox(height: 12),

                _buildActionCard(
                  icon: Icons.texture,
                  title: 'Save Text Texture',
                  description: 'Generate and save billboard text texture sample',
                  onTap: () => _saveTextTextureSample(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Application State Section
          SidebarComponents.buildSectionWithInfo(
            title: 'Application State',
            infoTooltip:
                'Current status of core application components and systems',
            child: Column(
              children: [
                _buildStatusItem(
                  icon: Icons.check_circle,
                  label: 'Scene Manager',
                  status: 'Initialized',
                  color: VSCodeTheme.success,
                ),

                const SizedBox(height: 8),

                _buildStatusItem(
                  icon: Icons.check_circle,
                  label: 'Camera Director',
                  status: 'Active',
                  color: VSCodeTheme.success,
                ),

                const SizedBox(height: 8),

                _buildStatusItem(
                  icon: Icons.check_circle,
                  label: 'Renderer',
                  status: 'Ready',
                  color: VSCodeTheme.success,
                ),

                const SizedBox(height: 8),

                _buildStatusItem(
                  icon: Icons.check_circle,
                  label: 'Shader Pipeline',
                  status: 'Compiled',
                  color: VSCodeTheme.success,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Machine Input States Section
          SidebarComponents.buildSectionWithInfo(
            title: 'Machine Input States',
            infoTooltip: 'Real-time machine input status and polarity settings',
            child: _buildMachineInputStates(context),
          ),

          const SizedBox(height: 24),

          // Communication Performance Section
          SidebarComponents.buildSectionWithInfo(
            title: 'Communication Performance',
            infoTooltip:
                'Real-time communication metrics and status message rate analysis',
            child: _buildCommunicationPerformance(context),
          ),

          const SizedBox(height: 24),

          // Log Levels Section
          SidebarComponents.buildSectionWithInfo(
            title: 'Log Configuration',
            infoTooltip:
                'Application logging settings and output configuration',
            child: SidebarComponents.buildInfoCard(
              title: 'Current Log Level',
              content:
                  'INFO level logging\nReal-time application events\nPerformance monitoring active',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunicationPerformance(BuildContext context) {
    return BlocBuilder<CncCommunicationBloc, CncCommunicationState>(
      builder: (context, commState) {
        final commBloc = BlocProvider.of<CncCommunicationBloc>(context);

        // Get performance data from state if available, otherwise from bloc directly
        final performanceData =
            commState is CncCommunicationConnectedWithPerformance
            ? commState.performanceData
            : commBloc.performanceData;

        if (!commBloc.isConnected) {
          return SidebarComponents.buildInfoCard(
            title: 'Communication Offline',
            content: 'Connect to machine to view communication metrics',
          );
        }

        return Column(
          children: [
            // Connection Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VSCodeTheme.editorBackground,
                borderRadius: VSCodeTheme.containerRadius,
                border: Border.all(color: VSCodeTheme.border, width: 1),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.wifi, size: 16, color: VSCodeTheme.accent),
                      const SizedBox(width: 8),
                      Text('Connection Status', style: VSCodeTheme.labelText),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInputStateRow(
                    'Connection',
                    commBloc.statusMessage,
                    '🔗',
                  ),
                  const SizedBox(height: 4),
                  _buildInputStateRow(
                    'WebSocket State',
                    commBloc.isConnected ? 'Connected' : 'Disconnected',
                    commBloc.isConnected ? '✅' : '❌',
                  ),
                ],
              ),
            ),

            if (performanceData != null) ...[
              const SizedBox(height: 12),

              // Status Rate Metrics
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VSCodeTheme.editorBackground,
                  borderRadius: VSCodeTheme.containerRadius,
                  border: Border.all(color: VSCodeTheme.border, width: 1),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.speed, size: 16, color: VSCodeTheme.accent),
                        const SizedBox(width: 8),
                        Text(
                          'Polled Status Messages',
                          style: VSCodeTheme.labelText,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInputStateRow(
                      'Expected Rate',
                      '125.0 Hz (8ms polling)',
                      '🎯',
                    ),
                    const SizedBox(height: 4),
                    _buildInputStateRow(
                      'Actual Rate',
                      '${performanceData.statusMessagesPerSecond.toStringAsFixed(1)} Hz',
                      performanceData.statusRateStatus.contains('✅')
                          ? '✅'
                          : '⚠️',
                    ),
                    const SizedBox(height: 4),
                    _buildInputStateRow(
                      'Drop Rate',
                      '${performanceData.statusMessageDropRate.toStringAsFixed(1)}%',
                      performanceData.statusMessageDropRate < 5.0 ? '✅' : '❌',
                    ),
                    const SizedBox(height: 4),
                    _buildInputStateRow(
                      'Total Messages',
                      '${performanceData.totalStatusMessages}',
                      '📊',
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: performanceData.meetsStatusRateRequirement
                            ? VSCodeTheme.success.withValues(alpha: 0.1)
                            : VSCodeTheme.error.withValues(alpha: 0.1),
                        borderRadius: VSCodeTheme.containerRadius,
                        border: Border.all(
                          color: performanceData.meetsStatusRateRequirement
                              ? VSCodeTheme.success
                              : VSCodeTheme.error,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            performanceData.meetsStatusRateRequirement
                                ? '✅ Status Rate: PASS'
                                : '❌ Status Rate: FAIL',
                            style: VSCodeTheme.bodyText.copyWith(
                              color: performanceData.meetsStatusRateRequirement
                                  ? VSCodeTheme.success
                                  : VSCodeTheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMachineInputStates(BuildContext context) {
    return BlocBuilder<MachineControllerBloc, MachineControllerState>(
      builder: (context, machineState) {
        if (!machineState.hasController || !machineState.isOnline) {
          return SidebarComponents.buildInfoCard(
            title: 'Machine Offline',
            content: 'Connect to machine to view input states',
          );
        }

        return Column(
          children: [
            // Current machine status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VSCodeTheme.editorBackground,
                borderRadius: VSCodeTheme.containerRadius,
                border: Border.all(color: VSCodeTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.settings_input_component,
                        color: VSCodeTheme.focus,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text('Current Status', style: VSCodeTheme.labelText),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInputStateRow(
                    'Machine Status',
                    machineState.status.displayName,
                    machineState.status.icon,
                  ),
                  const SizedBox(height: 4),
                  if (machineState.workPosition != null)
                    _buildInputStateRow(
                      'Work Position',
                      '${machineState.workPosition!.x.toStringAsFixed(2)}, ${machineState.workPosition!.y.toStringAsFixed(2)}, ${machineState.workPosition!.z.toStringAsFixed(2)}',
                      '📍',
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Input states from machine status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VSCodeTheme.editorBackground,
                borderRadius: VSCodeTheme.containerRadius,
                border: Border.all(color: VSCodeTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.input, color: VSCodeTheme.warning, size: 16),
                      const SizedBox(width: 8),
                      Text('Input States', style: VSCodeTheme.labelText),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInputStatesFromStatus(machineState),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // grblHAL Configuration Info
            if (machineState.grblHalDetected)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VSCodeTheme.editorBackground,
                  borderRadius: VSCodeTheme.containerRadius,
                  border: Border.all(color: VSCodeTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.settings,
                          color: VSCodeTheme.success,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'grblHAL Configuration',
                          style: VSCodeTheme.labelText,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInputStateRow(
                      'Firmware',
                      _getFirmwareVersion(machineState),
                      '⚙️',
                    ),
                    const SizedBox(height: 4),
                    if (machineState.configuration != null &&
                        machineState.configuration!.settings.isNotEmpty)
                      _buildInputStateRow(
                        'Configuration',
                        '${machineState.configuration!.settings.length} settings loaded',
                        '📋',
                      ),
                    if (machineState.configuration != null &&
                        machineState.configuration!.settings.isNotEmpty)
                      const SizedBox(height: 4),
                    _buildInputStateRow(
                      'Status Polling',
                      'Enabled (125Hz)',
                      '✅',
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
                          Icon(
                            Icons.info,
                            size: 14,
                            color: VSCodeTheme.warning,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Input polarity settings require \$ config query to be parsed',
                              style: VSCodeTheme.captionText.copyWith(
                                color: VSCodeTheme.warning,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildInputStatesFromStatus(MachineControllerState machineState) {
    // Parse input states from the machine status
    final status = machineState.status;
    List<Widget> inputRows = [];

    // Door state
    if (status == MachineStatus.door) {
      inputRows.add(_buildInputStateRow('Door Switch', 'Open', '🚪'));
    } else {
      inputRows.add(_buildInputStateRow('Door Switch', 'Closed', '🔒'));
    }

    // Alarm/Error states indicate potential limit switch activation
    if (status == MachineStatus.alarm) {
      inputRows.add(
        _buildInputStateRow(
          'Limit Switches',
          'ALARM - Possible activation',
          '⚠️',
        ),
      );
    } else {
      inputRows.add(_buildInputStateRow('Limit Switches', 'Normal', '✅'));
    }

    // If no specific input state info is available
    if (inputRows.isEmpty) {
      inputRows.add(
        _buildInputStateRow('Input Detection', 'Status parsing active', 'ℹ️'),
      );
    }

    return Column(children: inputRows);
  }

  String _getFirmwareVersion(MachineControllerState machineState) {
    // Priority: Configuration firmware version > grblHAL version > Unknown
    if (machineState.configuration?.firmwareVersion != null) {
      return machineState.configuration!.firmwareVersion!;
    }
    if (machineState.grblHalVersion != null) {
      return machineState.grblHalVersion!;
    }
    return 'Unknown';
  }

  Widget _buildInputStateRow(String label, String value, String icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: VSCodeTheme.captionText)),
          Text(
            value,
            style: VSCodeTheme.statusText.copyWith(
              color: VSCodeTheme.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: VSCodeTheme.editorBackground,
          borderRadius: VSCodeTheme.containerRadius,
          border: Border.all(color: VSCodeTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VSCodeTheme.focus.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: VSCodeTheme.focus, size: 16),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: VSCodeTheme.labelText),
                  const SizedBox(height: 2),
                  Text(description, style: VSCodeTheme.smallText),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right,
              color: VSCodeTheme.secondaryText,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String status,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: VSCodeTheme.editorBackground,
        borderRadius: VSCodeTheme.containerRadius,
        border: Border.all(color: VSCodeTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),

          const SizedBox(width: 10),

          Expanded(child: Text(label, style: VSCodeTheme.labelText)),

          Text(status, style: VSCodeTheme.statusText.copyWith(color: color)),
        ],
      ),
    );
  }

  Future<void> _saveTextTextureSample(BuildContext context) async {
    try {
      final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Get the Documents directory for reliable file access
      final documentsDir = await getApplicationDocumentsDirectory();
      final filename = 'debug_text_texture_$timestamp.png';
      final filePath = path.join(documentsDir.path, filename);
      
      AppLogger.info('Generating text texture sample with device pixel ratio: $devicePixelRatio');
      AppLogger.info('Target file path: $filePath');
      
      await TextTextureFactory.createTextTexture(
        text: 'Sample Text 18pt\nMulti-line Test\nDevice Ratio: ${devicePixelRatio.toStringAsFixed(1)}x',
        textStyle: const TextStyle(
          fontSize: 18,
          color: Colors.white,
          fontWeight: FontWeight.normal,
        ),
        devicePixelRatio: devicePixelRatio,
        backgroundColor: Colors.black,
        debugSaveToFile: filePath,
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Text texture saved to:\n$filePath',
              style: VSCodeTheme.labelText,
            ),
            backgroundColor: VSCodeTheme.success,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      
    } catch (e) {
      AppLogger.error('Failed to save text texture sample: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save text texture: $e',
              style: VSCodeTheme.labelText,
            ),
            backgroundColor: VSCodeTheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showFeatureNotImplemented(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Feature not yet implemented',
          style: VSCodeTheme.labelText,
        ),
        backgroundColor: VSCodeTheme.warning,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
