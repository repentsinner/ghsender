import 'package:flutter/material.dart';
import '../themes/vscode_theme.dart';
import '../constants/ui_strings.dart';
import 'vscode_layout.dart';

/// Activity Bar widget - left edge icon bar for navigation
class ActivityBar extends StatefulWidget {
  final ActivitySection activeSection;
  final bool sidebarVisible;
  final ValueChanged<ActivitySection> onSectionSelected;

  const ActivityBar({
    super.key,
    required this.activeSection,
    required this.sidebarVisible,
    required this.onSectionSelected,
  });

  @override
  State<ActivityBar> createState() => _ActivityBarState();
}

class _ActivityBarState extends State<ActivityBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: VSCodeTheme.activityBarWidth,
      color: VSCodeTheme.activityBarBackground,
      child: Column(
        children: [
          // Main activity icons
          Expanded(
            child: Column(
              children: [
                _buildActivityIcon(
                  Icons.power_settings_new,
                  UIStrings.sessionInitialization,
                  ActivitySection.sessionInitialization,
                ),
                _buildActivityIcon(
                  Icons.description,
                  UIStrings.filesAndJobs,
                  ActivitySection.filesAndJobs,
                ),
                _buildActivityIcon(
                  Icons.play_arrow,
                  UIStrings.runJob,
                  ActivitySection.runJob,
                ),
                _buildActivityIcon(
                  Icons.palette,
                  UIStrings.graphics,
                  ActivitySection.graphics,
                ),
                _buildActivityIcon(
                  Icons.analytics,
                  UIStrings.performance,
                  ActivitySection.performance,
                ),
                _buildActivityIcon(
                  Icons.folder_outlined,
                  UIStrings.sceneExplorer,
                  ActivitySection.scene,
                ),
                _buildActivityIcon(
                  Icons.bug_report,
                  UIStrings.debug,
                  ActivitySection.debug,
                ),
              ],
            ),
          ),

          // Bottom settings
          _buildActivityIcon(
            Icons.settings,
            UIStrings.settings,
            ActivitySection.settings,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityIcon(
    IconData icon,
    String tooltip,
    ActivitySection section,
  ) {
    final isActive = widget.sidebarVisible && widget.activeSection == section;

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: GestureDetector(
        onTap: () => widget.onSectionSelected(section),
        child: Container(
          width: VSCodeTheme.activityBarWidth,
          height: VSCodeTheme.activityBarWidth,
          decoration: BoxDecoration(
            //color: isActive ? VSCodeTheme.selection : null,
            border: Border(
              left: BorderSide(
                color: isActive 
                    ? Theme.of(context).colorScheme.primary 
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Icon(
            icon,
            color: isActive ? VSCodeTheme.activeIcon : VSCodeTheme.inactiveIcon,
            size: 24,
          ),
        ),
      ),
    );
  }
}
