import 'package:flutter/material.dart';
import '../themes/vscode_theme.dart';
import 'vscode_layout.dart';
import '../widgets/sidebar_sections/graphics_section.dart';
import '../widgets/sidebar_sections/renderer_section.dart';
import '../widgets/sidebar_sections/performance_section.dart';
import '../widgets/sidebar_sections/scene_section.dart';
import '../widgets/sidebar_sections/debug_section.dart';

/// Primary Sidebar widget - collapsible content area
class PrimarySidebar extends StatelessWidget {
  final double width;
  final ActivitySection activeSection;
  final double fps;
  final int polygons;
  final int drawCalls;
  final String cameraInfo;
  
  // Line control callbacks
  final ValueChanged<double> onLineWeightChanged;
  final ValueChanged<double> onLineSmoothnessChanged;
  final ValueChanged<double> onLineOpacityChanged;
  final VoidCallback onCameraToggle;
  
  // Current line values
  final double lineWeight;
  final double lineSmoothness;
  final double lineOpacity;
  final bool isAutoMode;

  const PrimarySidebar({
    super.key,
    required this.width,
    required this.activeSection,
    required this.fps,
    required this.polygons,
    required this.drawCalls,
    required this.cameraInfo,
    required this.onLineWeightChanged,
    required this.onLineSmoothnessChanged,
    required this.onLineOpacityChanged,
    required this.onCameraToggle,
    required this.lineWeight,
    required this.lineSmoothness,
    required this.lineOpacity,
    required this.isAutoMode,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: VSCodeTheme.sidebarTheme,
      child: Container(
        width: width,
        color: VSCodeTheme.sideBarBackground,
        child: Column(
          children: [
            // Section header
            _buildSectionHeader(),
            
            // Section content
            Expanded(
              child: _buildSectionContent(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader() {
    String title;
    IconData icon;
    
    switch (activeSection) {
      case ActivitySection.graphics:
        title = 'Graphics';
        icon = Icons.palette;
        break;
      case ActivitySection.renderer:
        title = 'Renderer Settings';
        icon = Icons.settings;
        break;
      case ActivitySection.performance:
        title = 'Performance';
        icon = Icons.analytics;
        break;
      case ActivitySection.scene:
        title = 'Scene Explorer';
        icon = Icons.folder_outlined;
        break;
      case ActivitySection.debug:
        title = 'Debug';
        icon = Icons.bug_report;
        break;
    }
    
    return Container(
      height: 35,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: VSCodeTheme.border),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: VSCodeTheme.primaryText,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: VSCodeTheme.primaryText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionContent() {
    switch (activeSection) {
      case ActivitySection.graphics:
        return GraphicsSection(
          cameraInfo: cameraInfo,
          isAutoMode: isAutoMode,
          onCameraToggle: onCameraToggle,
        );
      case ActivitySection.renderer:
        return RendererSection(
          lineWeight: lineWeight,
          lineSmoothness: lineSmoothness,
          lineOpacity: lineOpacity,
          onLineWeightChanged: onLineWeightChanged,
          onLineSmoothnessChanged: onLineSmoothnessChanged,
          onLineOpacityChanged: onLineOpacityChanged,
        );
      case ActivitySection.performance:
        return PerformanceSection(
          fps: fps,
          polygons: polygons,
          drawCalls: drawCalls,
        );
      case ActivitySection.scene:
        return const SceneSection();
      case ActivitySection.debug:
        return const DebugSection();
    }
  }
}