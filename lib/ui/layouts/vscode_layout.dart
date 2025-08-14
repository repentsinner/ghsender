import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../themes/vscode_theme.dart';
import 'activity_bar.dart';
import 'primary_sidebar.dart';
import 'main_view.dart';
import 'bottom_panel.dart';
import 'status_bar.dart';
import '../../bloc/performance/performance_bloc.dart';
import '../../bloc/performance/performance_event.dart';
import '../../bloc/graphics/graphics_bloc.dart';
import '../../bloc/graphics/graphics_event.dart';

/// Activity bar sections
enum ActivitySection {
  sessionInitialization,
  filesAndJobs,
  graphics,
  settings, // Renamed from 'renderer' to 'settings'
  performance,
  scene,
  debug,
}

/// Main VS Code-like layout container
class VSCodeLayout extends StatefulWidget {
  final Widget graphicsRenderer;
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

  // DRO position values now handled by MachineControllerBloc

  const VSCodeLayout({
    super.key,
    required this.graphicsRenderer,
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
  State<VSCodeLayout> createState() => _VSCodeLayoutState();
}

class _VSCodeLayoutState extends State<VSCodeLayout> {
  ActivitySection _activeSection = ActivitySection.sessionInitialization;
  bool _sidebarVisible = true;
  bool _panelVisible = true;
  double _sidebarWidth = VSCodeTheme.sidebarDefaultWidth;
  double _panelHeight = VSCodeTheme.panelDefaultHeight;

  void _setActiveSection(ActivitySection section) {
    setState(() {
      if (_activeSection == section) {
        // Clicking on already active section toggles sidebar (VS Code behavior)
        _sidebarVisible = !_sidebarVisible;
      } else {
        // Clicking on different section switches to it and shows sidebar
        _activeSection = section;
        _sidebarVisible = true;
      }
    });
  }

  void _togglePanel() {
    setState(() {
      _panelVisible = !_panelVisible;
    });
  }

  void _onSidebarResize(double delta) {
    setState(() {
      _sidebarWidth = (_sidebarWidth + delta).clamp(
        VSCodeTheme.sidebarMinWidth,
        VSCodeTheme.sidebarMaxWidth,
      );
    });
  }

  void _onPanelResize(double delta) {
    setState(() {
      _panelHeight = (_panelHeight - delta).clamp(
        VSCodeTheme.panelMinHeight,
        VSCodeTheme.panelMaxHeight,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Update BLoCs with current data
    context.read<PerformanceBloc>().add(PerformanceMetricsUpdated(
      fps: widget.fps,
      polygons: widget.polygons,
      drawCalls: widget.drawCalls,
    ));
    
    context.read<GraphicsBloc>().add(GraphicsCameraStateUpdated(
      cameraInfo: widget.cameraInfo,
      isAutoMode: widget.isAutoMode,
      onCameraToggle: widget.onCameraToggle,
    ));
    
    context.read<GraphicsBloc>().add(GraphicsLineControlsUpdated(
      lineWeight: widget.lineWeight,
      lineSmoothness: widget.lineSmoothness,
      lineOpacity: widget.lineOpacity,
      onLineWeightChanged: widget.onLineWeightChanged,
      onLineSmoothnessChanged: widget.onLineSmoothnessChanged,
      onLineOpacityChanged: widget.onLineOpacityChanged,
    ));
    
    return Scaffold(
      backgroundColor: VSCodeTheme.editorBackground,
      body: Column(
        children: [
          // Main content area
          Expanded(
            child: Row(
              children: [
                // Activity Bar
                ActivityBar(
                  activeSection: _activeSection,
                  sidebarVisible: _sidebarVisible,
                  onSectionSelected: _setActiveSection,
                ),

                // Primary Sidebar (collapsible)
                if (_sidebarVisible) ...[
                  PrimarySidebar(
                    width: _sidebarWidth,
                    activeSection: _activeSection,
                  ),

                  // Vertical resizer
                  _buildVerticalResizer(),
                ],

                // Main View
                Expanded(
                  child: Column(
                    children: [
                      // Graphics renderer area
                      Expanded(
                        child: MainView(
                          fps: widget.fps,
                          polygons: widget.polygons,
                          child: widget.graphicsRenderer,
                        ),
                      ),

                      // Bottom Panel (collapsible)
                      if (_panelVisible) ...[
                        _buildHorizontalResizer(),
                        SizedBox(
                          height: _panelHeight,
                          child: BottomPanel(onTogglePanel: _togglePanel),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Status Bar
          StatusBar(
            cameraInfo: widget.cameraInfo,
            isAutoMode: widget.isAutoMode,
            onTogglePanel: _togglePanel,
            panelVisible: _panelVisible,
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalResizer() {
    return GestureDetector(
      onPanUpdate: (details) => _onSidebarResize(details.delta.dx),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 4.0, // 4px mouse target area
          color: VSCodeTheme.sideBarBackground, // Match sidebar background
          child: Center(
            child: Container(
              width: 1.0, // 1px visual splitter
              color: Colors.transparent,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalResizer() {
    return GestureDetector(
      onPanUpdate: (details) => _onPanelResize(details.delta.dy),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        child: Container(
          height: 4.0, // 4px mouse target area
          color: Colors.transparent, // Transparent background for larger target
          child: Center(
            child: Container(
              height: 1.0, // 1px visual splitter
              color: VSCodeTheme.border,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}
