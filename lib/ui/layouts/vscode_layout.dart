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
  filesAndJobs,
  runJob,
  graphics,
  settings,
  performance,
  scene,
  debug,
}

/// Main VS Code-like layout container
class VSCodeLayout extends StatefulWidget {
  final Widget graphicsRenderer;

  const VSCodeLayout({super.key, required this.graphicsRenderer});

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
                      Expanded(child: MainView(child: widget.graphicsRenderer)),

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
          StatusBar(onTogglePanel: _togglePanel, panelVisible: _panelVisible),
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
