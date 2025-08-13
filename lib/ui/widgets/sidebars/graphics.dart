import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../themes/vscode_theme.dart';
import '../sidebar_sections/sidebar_components.dart';

/// Graphics section in the sidebar - camera controls and view settings
class GraphicsSection extends StatelessWidget {
  final String cameraInfo;
  final bool isAutoMode;
  final VoidCallback onCameraToggle;

  const GraphicsSection({
    super.key,
    required this.cameraInfo,
    required this.isAutoMode,
    required this.onCameraToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Camera Controls Section
          SidebarComponents.buildSectionWithInfo(
            title: 'Camera Controls',
            infoTooltip: 'Camera positioning and movement controls for 3D scene navigation',
            child: Column(
              children: [
                // Camera Info Display
                SidebarComponents.buildInfoCard(
                  title: 'Camera Position',
                  content: cameraInfo,
                ),
                
                const SizedBox(height: 16),
                
                // Camera Mode Toggle
                _buildCameraModeToggle(),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // View Controls Section
          SidebarComponents.buildSectionWithInfo(
            title: 'View Controls',
            infoTooltip: 'Interaction methods for navigating and viewing the 3D scene',
            child: Column(
              children: [
                SidebarComponents.buildInfoCard(
                  title: 'Navigation',
                  content: 'Drag: Rotate camera\nPinch: Zoom in/out\nScroll: Zoom in/out',
                ),
                
                const SizedBox(height: 16),
                
                SidebarComponents.buildInfoCard(
                  title: 'Auto Mode',
                  content: 'Camera automatically orbits the scene with smooth transitions',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCameraModeToggle() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onCameraToggle,
        icon: Icon(
          isAutoMode ? Icons.pause_circle : Icons.play_circle,
          size: 18,
        ),
        label: Text(
          isAutoMode ? 'Switch to Manual' : 'Switch to Auto',
          style: GoogleFonts.inconsolata(
            fontWeight: FontWeight.w500,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isAutoMode ? VSCodeTheme.warning : VSCodeTheme.success,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }
}