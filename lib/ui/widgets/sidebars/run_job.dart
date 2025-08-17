import 'package:flutter/material.dart';
import '../../themes/vscode_theme.dart';
import '../sidebar_sections/sidebar_components.dart';
import '../../../bloc/bloc_exports.dart';
import '../../../models/gcode_file.dart';

/// Run Job section - Job execution control interface
class RunJobSection extends StatefulWidget {
  const RunJobSection({super.key});

  @override
  State<RunJobSection> createState() => _RunJobSectionState();
}

class _RunJobSectionState extends State<RunJobSection> {
  // Runtime override values (0-200%)
  double _feedOverride = 100.0;
  double _spindleOverride = 100.0;
  double _rapidOverride = 100.0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileManagerBloc, FileManagerState>(
      builder: (context, fileState) {
        return BlocBuilder<MachineControllerBloc, MachineControllerState>(
          builder: (context, machineState) {
            return Column(
              children: [
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current Job Section
                        SidebarComponents.buildSectionWithInfo(
                          title: 'Current Job',
                          infoTooltip: 'Currently selected job from Files & Jobs',
                          child: _buildCurrentJobCard(fileState.selectedFile),
                        ),

                        const SizedBox(height: 24),

                        // Job Controls Section
                        SidebarComponents.buildSectionWithInfo(
                          title: 'Job Controls',
                          infoTooltip: 'Start, pause, stop, and reset job execution',
                          child: _buildJobControls(fileState.selectedFile),
                        ),

                        const SizedBox(height: 24),

                        // Runtime Overrides Section
                        SidebarComponents.buildSectionWithInfo(
                          title: 'Runtime Overrides',
                          infoTooltip: 'Adjust machine speeds during job execution',
                          child: _buildRuntimeOverrides(),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                
                // Fixed Emergency Stop at bottom
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: VSCodeTheme.border),
                    ),
                  ),
                  child: _buildEmergencyStop(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCurrentJobCard(GCodeFile? selectedFile) {
    if (selectedFile == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VSCodeTheme.editorBackground,
          borderRadius: VSCodeTheme.containerRadius,
          border: Border.all(color: VSCodeTheme.border),
        ),
        child: Column(
          children: [
            Icon(
              Icons.description_outlined,
              size: 32,
              color: VSCodeTheme.secondaryText,
            ),
            const SizedBox(height: 8),
            Text(
              'No Job Selected',
              style: VSCodeTheme.sectionTitle.copyWith(
                color: VSCodeTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a job from Files & Jobs',
              style: VSCodeTheme.captionText,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSCodeTheme.editorBackground,
        borderRadius: VSCodeTheme.containerRadius,
        border: Border.all(color: VSCodeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Job name and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedFile.name.split('.').first, // Use name without extension as display name
                      style: VSCodeTheme.sectionTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      selectedFile.name,
                      style: VSCodeTheme.captionText,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: VSCodeTheme.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: VSCodeTheme.success),
                ),
                child: Text(
                  'Ready',
                  style: VSCodeTheme.statusText.copyWith(
                    color: VSCodeTheme.success,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress bar
          Row(
            children: [
              Text(
                'Progress:',
                style: VSCodeTheme.labelText.copyWith(
                  color: VSCodeTheme.secondaryText,
                ),
              ),
              const Spacer(),
              Text(
                '0.0%',
                style: VSCodeTheme.labelText,
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: 0.0,
            backgroundColor: VSCodeTheme.border,
            valueColor: AlwaysStoppedAnimation<Color>(VSCodeTheme.focus),
          ),

          const SizedBox(height: 16),

          // Job statistics
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Line:',
                      style: VSCodeTheme.captionText,
                    ),
                    Text(
                      '0/1000', // TODO: Get actual line count from parsed G-code
                      style: VSCodeTheme.labelText,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Elapsed:',
                      style: VSCodeTheme.captionText,
                    ),
                    Text(
                      '0m 0s',
                      style: VSCodeTheme.labelText,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Remaining:',
                      style: VSCodeTheme.captionText,
                    ),
                    Text(
                      '--',
                      style: VSCodeTheme.labelText,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated:',
                      style: VSCodeTheme.captionText,
                    ),
                    Text(
                      '--',
                      style: VSCodeTheme.labelText,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJobControls(GCodeFile? selectedFile) {
    final hasJob = selectedFile != null;

    return Column(
      children: [
        // Primary controls row
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: hasJob ? _startJob : null,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Start'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VSCodeTheme.focus,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  textStyle: VSCodeTheme.buttonText,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: hasJob ? _pauseJob : null,
                icon: const Icon(Icons.pause, size: 18),
                label: const Text('Pause'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VSCodeTheme.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  textStyle: VSCodeTheme.buttonText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Stop button (full width)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: hasJob ? _stopJob : null,
            icon: const Icon(Icons.stop, size: 18),
            label: const Text('Stop Job'),
            style: ElevatedButton.styleFrom(
              backgroundColor: VSCodeTheme.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              textStyle: VSCodeTheme.buttonText,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Reset button with info icon
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: hasJob ? _resetJob : null,
            icon: const Icon(Icons.refresh, size: 18),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Reset to Beginning'),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Reset job progress to line 1',
                  child: Icon(
                    Icons.info_outline,
                    size: 14,
                    color: VSCodeTheme.infoTooltip,
                  ),
                ),
              ],
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: VSCodeTheme.primaryText,
              side: BorderSide(color: VSCodeTheme.border),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              textStyle: VSCodeTheme.buttonText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRuntimeOverrides() {
    return Column(
      children: [
        _buildOverrideSlider(
          'Feed Override',
          'Adjust cutting speed for material conditions',
          _feedOverride,
          (value) => setState(() => _feedOverride = value),
        ),
        const SizedBox(height: 16),
        _buildOverrideSlider(
          'Spindle Override',
          'Adjust spindle speed for tool performance',
          _spindleOverride,
          (value) => setState(() => _spindleOverride = value),
        ),
        const SizedBox(height: 16),
        _buildOverrideSlider(
          'Rapid Override',
          'Reduce rapid speed if needed for safety',
          _rapidOverride,
          (value) => setState(() => _rapidOverride = value),
        ),
      ],
    );
  }

  Widget _buildOverrideSlider(
    String title,
    String description,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: VSCodeTheme.labelText,
            ),
            Tooltip(
              message: description,
              child: Icon(
                Icons.info_outline,
                size: 14,
                color: VSCodeTheme.infoTooltip,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: VSCodeTheme.focus,
                  inactiveTrackColor: VSCodeTheme.border,
                  thumbColor: VSCodeTheme.focus,
                  overlayColor: VSCodeTheme.focus.withValues(alpha: 0.2),
                  trackHeight: 6.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                ),
                child: Slider(
                  value: value,
                  min: 10.0,
                  max: 200.0,
                  divisions: 190,
                  onChanged: onChanged,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 45,
              child: Text(
                '${value.round()}%',
                style: VSCodeTheme.valueText,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmergencyStop() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _emergencyStop,
            icon: const Icon(Icons.warning, size: 20),
            label: const Text('Emergency Stop'),
            style: ElevatedButton.styleFrom(
              backgroundColor: VSCodeTheme.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              textStyle: VSCodeTheme.sectionTitle,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Immediately stops all motion and spindle',
          style: VSCodeTheme.smallText,
        ),
      ],
    );
  }

  // Job control methods (to be connected to machine controller)
  void _startJob() {
    // TODO: Integrate with JobExecutionBloc when implemented
    // For now, send directly to MachineControllerBloc
    // final machineBloc = context.read<MachineControllerBloc>();
    // TODO: Implement job start logic
    debugPrint('Start job requested');
  }

  void _pauseJob() {
    // TODO: Integrate with JobExecutionBloc when implemented
    // final machineBloc = context.read<MachineControllerBloc>();
    // TODO: Implement job pause logic
    debugPrint('Pause job requested');
  }

  void _stopJob() {
    // TODO: Integrate with JobExecutionBloc when implemented
    // final machineBloc = context.read<MachineControllerBloc>();
    // TODO: Implement job stop logic
    debugPrint('Stop job requested');
  }

  void _resetJob() {
    // TODO: Integrate with JobExecutionBloc when implemented
    // Reset job progress to line 1
    debugPrint('Reset job requested');
  }

  void _emergencyStop() {
    // Send emergency stop directly to machine controller
    // final machineBloc = context.read<MachineControllerBloc>();
    // TODO: Implement emergency stop logic
    debugPrint('Emergency stop requested');
  }
}