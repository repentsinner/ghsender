import 'package:flutter/material.dart';
import '../themes/vscode_theme.dart';
import '../constants/ui_strings.dart';
import 'vscode_layout.dart';
import '../widgets/sidebars/session_initialization.dart';
import '../widgets/sidebars/files_and_jobs.dart';
import '../widgets/sidebars/run_job.dart';
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

    switch (activeSection) {
      case ActivitySection.sessionInitialization:
        title = UIStrings.sessionInitialization;
        break;
      case ActivitySection.filesAndJobs:
        title = UIStrings.filesAndJobs;
        break;
      case ActivitySection.runJob:
        title = UIStrings.runJob;
        break;
      case ActivitySection.graphics:
        title = UIStrings.graphics;
        break;
      case ActivitySection.settings:
        title = UIStrings.settings;
        break;
      case ActivitySection.performance:
        title = UIStrings.performance;
        break;
      case ActivitySection.scene:
        title = UIStrings.sceneExplorer;
        break;
      case ActivitySection.debug:
        title = UIStrings.debug;
        break;
    }

    return Container(
      height: 35,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(), 
              style: VSCodeTheme.sidebarOrPanelHeading,
              overflow: TextOverflow.ellipsis,
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
      case ActivitySection.runJob:
        return const RunJobSection();
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
