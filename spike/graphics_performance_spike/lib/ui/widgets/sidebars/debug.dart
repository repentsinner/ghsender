import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../themes/vscode_theme.dart';
import '../sidebar_sections/sidebar_components.dart';
import '../../../bloc/machine_controller/machine_controller_bloc.dart';
import '../../../bloc/machine_controller/machine_controller_state.dart';
import '../../../models/machine_controller.dart';

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
            infoTooltip: 'Platform and runtime environment details for debugging',
            child: Column(
              children: [
                SidebarComponents.buildInfoCard(
                  title: 'Platform',
                  content: 'macOS (Darwin)\nFlutter 3.33.0-1.0.pre-1145\nDart 3.10.0',
                ),
                
                const SizedBox(height: 12),
                
                SidebarComponents.buildInfoCard(
                  title: 'Graphics Backend',
                  content: 'Flutter Impeller (Metal)\nNative GPU acceleration\nHardware shader compilation',
                ),
                
                const SizedBox(height: 12),
                
                SidebarComponents.buildInfoCard(
                  title: 'Renderer Details',
                  content: 'FlutterScene Batch Renderer\nCustom line geometry shaders\nThree.js Line2/LineSegments2 style',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Debug Tools Section
          SidebarComponents.buildSectionWithInfo(
            title: 'Debug Tools',
            infoTooltip: 'Development and debugging utilities for troubleshooting',
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
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Application State Section
          SidebarComponents.buildSectionWithInfo(
            title: 'Application State',
            infoTooltip: 'Current status of core application components and systems',
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
          
          // Log Levels Section
          SidebarComponents.buildSectionWithInfo(
            title: 'Log Configuration',
            infoTooltip: 'Application logging settings and output configuration',
            child: SidebarComponents.buildInfoCard(
              title: 'Current Log Level',
              content: 'INFO level logging\nReal-time application events\nPerformance monitoring active',
            ),
          ),
        ],
      ),
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
                      Text(
                        'Current Status',
                        style: GoogleFonts.inconsolata(
                          color: VSCodeTheme.primaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInputStateRow('Machine Status', machineState.status.displayName, machineState.status.icon),
                  const SizedBox(height: 4),
                  if (machineState.workPosition != null)
                    _buildInputStateRow('Work Position', '${machineState.workPosition!.x.toStringAsFixed(2)}, ${machineState.workPosition!.y.toStringAsFixed(2)}, ${machineState.workPosition!.z.toStringAsFixed(2)}', '📍'),
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
                      Icon(
                        Icons.input,
                        color: VSCodeTheme.warning,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Input States',
                        style: GoogleFonts.inconsolata(
                          color: VSCodeTheme.primaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                          style: GoogleFonts.inconsolata(
                            color: VSCodeTheme.primaryText,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInputStateRow('Firmware', machineState.grblHalVersion ?? 'Unknown', '⚙️'),
                    const SizedBox(height: 4),
                    _buildInputStateRow('Auto Reporting', machineState.autoReportingConfigured ? 'Enabled (60Hz)' : 'Disabled', machineState.autoReportingConfigured ? '✅' : '❌'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: VSCodeTheme.warning.withValues(alpha: 0.1),
                        border: Border.all(color: VSCodeTheme.warning.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, size: 14, color: VSCodeTheme.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Input polarity settings require \$ config query to be parsed',
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
      inputRows.add(_buildInputStateRow('Limit Switches', 'ALARM - Possible activation', '⚠️'));
    } else {
      inputRows.add(_buildInputStateRow('Limit Switches', 'Normal', '✅'));
    }
    
    // If no specific input state info is available
    if (inputRows.isEmpty) {
      inputRows.add(_buildInputStateRow('Input Detection', 'Status parsing active', 'ℹ️'));
    }
    
    return Column(children: inputRows);
  }
  
  Widget _buildInputStateRow(String label, String value, String icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inconsolata(
                color: VSCodeTheme.secondaryText,
                fontSize: 11,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inconsolata(
              color: VSCodeTheme.primaryText,
              fontSize: 11,
              fontWeight: FontWeight.w500,
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
              child: Icon(
                icon,
                color: VSCodeTheme.focus,
                size: 16,
              ),
            ),
            
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inconsolata(
                      color: VSCodeTheme.primaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.inconsolata(
                      color: VSCodeTheme.secondaryText,
                      fontSize: 10,
                    ),
                  ),
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
          Icon(
            icon,
            color: color,
            size: 16,
          ),
          
          const SizedBox(width: 10),
          
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inconsolata(
                color: VSCodeTheme.primaryText,
                fontSize: 12,
              ),
            ),
          ),
          
          Text(
            status,
            style: GoogleFonts.inconsolata(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showFeatureNotImplemented(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Feature not yet implemented',
          style: GoogleFonts.inconsolata(),
        ),
        backgroundColor: VSCodeTheme.warning,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}