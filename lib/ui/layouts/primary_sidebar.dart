import 'package:flutter/material.dart';
import '../themes/vscode_theme.dart';
import 'vscode_layout.dart';
import '../widgets/sidebars/session_initialization.dart';
import '../widgets/sidebars/files_and_jobs.dart';
import '../widgets/sidebars/graphics.dart';
import '../widgets/sidebars/settings.dart';
import '../widgets/sidebars/performance.dart';
import '../widgets/sidebars/scene.dart';
import '../widgets/sidebars/debug.dart';

/// Primary Sidebar widget - collapsible content area
class PrimarySidebar extends StatelessWidget {
  final double width;
  final ActivitySection activeSection;

  const PrimarySidebar({
    super.key,
    required this.width,
    required this.activeSection,
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
            Expanded(child: _buildSectionContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    String title;
    IconData icon;

    switch (activeSection) {
      case ActivitySection.sessionInitialization:
        title = 'Session Initialization';
        icon = Icons.power_settings_new;
        break;
      case ActivitySection.filesAndJobs:
        title = 'Files & Jobs';
        icon = Icons.description;
        break;
      case ActivitySection.graphics:
        title = 'Graphics';
        icon = Icons.palette;
        break;
      case ActivitySection.settings:
        title = 'Settings';
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
      child: Row(
        children: [
          Icon(icon, color: VSCodeTheme.primaryText, size: 16),
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
      case ActivitySection.sessionInitialization:
        return const SessionInitializationSection();
      case ActivitySection.filesAndJobs:
        return const FilesAndJobsSection();
      case ActivitySection.graphics:
        return const GraphicsSection();
      case ActivitySection.settings:
        return const SettingsSection();
      case ActivitySection.performance:
        return const PerformanceSection();
      case ActivitySection.scene:
        return const SceneSection();
      case ActivitySection.debug:
        return const DebugSection();
    }
  }
}
