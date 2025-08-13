import 'package:flutter/material.dart';
import '../themes/vscode_theme.dart';
import 'activity_bar.dart';
import 'primary_sidebar.dart';
import 'main_view.dart';
import 'bottom_panel.dart';
import 'status_bar.dart';

/// Activity bar sections
enum ActivitySection {
  sessionInitialization,
  graphics,
  renderer,
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
  
  // DRO position values
  final double wPosX;
  final double wPosY;
  final double wPosZ;
  final double mPosX;
  final double mPosY;
  final double mPosZ;

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
    this.wPosX = 0.0,
    this.wPosY = 0.0,
    this.wPosZ = 0.0,
    this.mPosX = 0.0,
    this.mPosY = 0.0,
    this.mPosZ = 0.0,
  });

  @override
  State<VSCodeLayout> createState() => _VSCodeLayoutState();
}

class _VSCodeLayoutState extends State<VSCodeLayout> {
  ActivitySection _activeSection = ActivitySection.sessionInitialization;
  bool _sidebarVisible = true;
  bool _panelVisible = false;
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
                    fps: widget.fps,
                    polygons: widget.polygons,
                    drawCalls: widget.drawCalls,
                    cameraInfo: widget.cameraInfo,
                    onLineWeightChanged: widget.onLineWeightChanged,
                    onLineSmoothnessChanged: widget.onLineSmoothnessChanged,
                    onLineOpacityChanged: widget.onLineOpacityChanged,
                    onCameraToggle: widget.onCameraToggle,
                    lineWeight: widget.lineWeight,
                    lineSmoothness: widget.lineSmoothness,
                    lineOpacity: widget.lineOpacity,
                    isAutoMode: widget.isAutoMode,
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
                          wPosX: widget.wPosX,
                          wPosY: widget.wPosY,
                          wPosZ: widget.wPosZ,
                          mPosX: widget.mPosX,
                          mPosY: widget.mPosY,
                          mPosZ: widget.mPosZ,
                          child: widget.graphicsRenderer,
                        ),
                      ),
                      
                      // Bottom Panel (collapsible)
                      if (_panelVisible) ...[
                        _buildHorizontalResizer(),
                        SizedBox(
                          height: _panelHeight,
                          child: BottomPanel(
                            onTogglePanel: _togglePanel,
                          ),
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
            fps: widget.fps,
            polygons: widget.polygons,
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
          width: VSCodeTheme.splitterWidth,
          color: VSCodeTheme.border,
          child: const SizedBox.expand(),
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
          height: VSCodeTheme.splitterWidth,
          color: VSCodeTheme.border,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}