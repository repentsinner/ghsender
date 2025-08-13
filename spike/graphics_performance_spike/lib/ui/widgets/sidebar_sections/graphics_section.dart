import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../themes/vscode_theme.dart';

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
          _buildSectionTitle('Camera Controls'),
          const SizedBox(height: 12),
          
          // Camera Info Display
          _buildInfoCard(
            title: 'Camera Position',
            content: cameraInfo,
          ),
          
          const SizedBox(height: 16),
          
          // Camera Mode Toggle
          _buildCameraModeToggle(),
          
          const SizedBox(height: 24),
          
          // View Controls Section
          _buildSectionTitle('View Controls'),
          const SizedBox(height: 12),
          
          _buildInfoCard(
            title: 'Navigation',
            content: 'Drag: Rotate camera\nPinch: Zoom in/out\nScroll: Zoom in/out',
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoCard(
            title: 'Auto Mode',
            content: 'Camera automatically orbits the scene with smooth transitions',
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inconsolata(
        color: VSCodeTheme.primaryText,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
  
  Widget _buildInfoCard({required String title, required String content}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VSCodeTheme.editorBackground,
        borderRadius: VSCodeTheme.containerRadius,
        border: Border.all(color: VSCodeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inconsolata(
              color: VSCodeTheme.accentText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: GoogleFonts.inconsolata(
              color: VSCodeTheme.secondaryText,
              fontSize: 11,
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