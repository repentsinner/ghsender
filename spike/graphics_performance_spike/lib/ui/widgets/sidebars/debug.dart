import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../themes/vscode_theme.dart';
import '../sidebar_sections/sidebar_components.dart';

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