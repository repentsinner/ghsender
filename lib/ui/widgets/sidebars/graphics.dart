import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../themes/vscode_theme.dart';
import '../sidebar_sections/sidebar_components.dart';
import '../../../bloc/graphics/graphics_bloc.dart';
import '../../../bloc/graphics/graphics_state.dart';

/// Graphics section in the sidebar - camera controls and view settings
class GraphicsSection extends StatelessWidget {
  const GraphicsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GraphicsBloc, GraphicsState>(
      builder: (context, state) {
        final cameraInfo = state is GraphicsLoaded ? state.cameraInfo : '';
        final isAutoMode = state is GraphicsLoaded ? state.isAutoMode : false;
        final onCameraToggle = state is GraphicsLoaded ? state.onCameraToggle : null;
        
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
                    _buildCameraModeToggle(
                      isAutoMode: isAutoMode,
                      onCameraToggle: onCameraToggle,
                    ),
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
      },
    );
  }
  
  Widget _buildCameraModeToggle({
    required bool isAutoMode,
    required VoidCallback? onCameraToggle,
  }) {
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