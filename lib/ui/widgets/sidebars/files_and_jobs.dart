import 'package:flutter/material.dart';
import '../../themes/vscode_theme.dart';
import '../sidebar_sections/sidebar_components.dart';
import 'package:file_picker/file_picker.dart';
import '../../../utils/logger.dart';
import '../../../bloc/bloc_exports.dart';
import '../../../models/gcode_file.dart';

/// Files & Jobs section - G-code file management interface
class FilesAndJobsSection extends StatelessWidget {
  const FilesAndJobsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FileManagerBloc, FileManagerState>(
      listener: (context, state) {
        // Show error messages as snackbars
        if (state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Upload G-Code Files Section
              SidebarComponents.buildSectionWithInfo(
                title: 'Upload G-Code Files',
                infoTooltip: 'Upload .gcode or .nc files for CNC machining',
                child: _buildUploadSection(context),
              ),

              const SizedBox(height: 24),

              // File List Section
              if (state.isNotEmpty) ...[
                SidebarComponents.buildSectionWithInfo(
                  title: 'G-Code Files',
                  infoTooltip: 'Manage uploaded G-code files and job queue',
                  child: _buildFileList(context, state),
                ),
              ] else ...[
                _buildEmptyState(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildUploadSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: VSCodeTheme.border, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(8),
        color: VSCodeTheme.sideBarBackground.withValues(alpha: 0.3),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 32,
            color: VSCodeTheme.secondaryText,
          ),
          const SizedBox(height: 8),
          Text(
            'Upload G-Code Files',
            style: VSCodeTheme.sectionTitle,
          ),
          const SizedBox(height: 4),
          Text(
            'Drop files here or click to browse',
            style: VSCodeTheme.captionText,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _uploadFiles(context),
            icon: const Icon(Icons.upload_file, size: 16),
            label: const Text('Browse Files'),
            style: ElevatedButton.styleFrom(
              backgroundColor: VSCodeTheme.focus,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              textStyle: VSCodeTheme.buttonText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList(BuildContext context, FileManagerState state) {
    return Column(
      children: state.files.map((file) => _buildFileItem(context, file, state)).toList(),
    );
  }

  Widget _buildFileItem(BuildContext context, GCodeFile file, FileManagerState state) {
    final statusColor = _getStatusColor(file.status);
    final isSelected = state.isFileSelected(file);

    return GestureDetector(
      onTap: () => _selectFile(context, file),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? VSCodeTheme.focus
                : statusColor.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? VSCodeTheme.focus.withValues(alpha: 0.1)
              : VSCodeTheme.sideBarBackground.withValues(alpha: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isSelected) ...[
                  Icon(
                    Icons.radio_button_checked,
                    size: 16,
                    color: VSCodeTheme.focus,
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  Icon(
                    Icons.radio_button_unchecked,
                    size: 16,
                    color: VSCodeTheme.secondaryText.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    file.name,
                    style: VSCodeTheme.sectionTitle.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? VSCodeTheme.focus
                          : VSCodeTheme.primaryText,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteFile(context, file),
                  icon: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: VSCodeTheme.error,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 24), // Align with text above
                Text(
                  file.formattedSize,
                  style: VSCodeTheme.captionText,
                ),
                const Text(' • '),
                Text(
                  file.formattedTime,
                  style: VSCodeTheme.captionText,
                ),
                const Text(' • '),
                Text(
                  file.status,
                  style: VSCodeTheme.statusText.copyWith(
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const SizedBox(width: 24), // Align with text above
                Text(
                  'Uploaded ${file.formattedDate}',
                  style: VSCodeTheme.smallText.copyWith(
                    color: VSCodeTheme.secondaryText.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.description_outlined,
            size: 48,
            color: VSCodeTheme.secondaryText.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No G-Code files uploaded',
            style: VSCodeTheme.sectionTitle.copyWith(
              color: VSCodeTheme.secondaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload files to get started',
            style: VSCodeTheme.captionText.copyWith(
              color: VSCodeTheme.secondaryText.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ready':
        return const Color(0xFF007ACC); // VS Code blue
      case 'completed':
        return VSCodeTheme.secondaryText;
      case 'processing':
        return VSCodeTheme.warning;
      default:
        return VSCodeTheme.secondaryText;
    }
  }

  void _uploadFiles(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gcode', 'nc'],
        allowMultiple: true,
      );

      if (result != null) {
        final List<GCodeFile> newFiles = [];
        for (PlatformFile file in result.files) {
          if (file.path != null) {
            final gcodeFile = GCodeFile(
              name: file.name,
              path: file.path!,
              sizeBytes: file.size,
              uploadDate: DateTime.now(),
              status: 'ready',
              estimatedTime: _estimateProcessingTime(file.size),
            );
            newFiles.add(gcodeFile);
          }
        }
        
        if (newFiles.isNotEmpty && context.mounted) {
          context.read<FileManagerBloc>().add(FileManagerFilesAdded(newFiles));
        }
      }
    } catch (e) {
      // Handle file picker errors
      AppLogger.error('File picker error', e);
    }
  }

  void _selectFile(BuildContext context, GCodeFile file) async {
    // Trigger file selection through the BLoC
    context.read<FileManagerBloc>().add(FileManagerFileSelected(file));
  }

  void _deleteFile(BuildContext context, GCodeFile file) {
    // Trigger file deletion through the BLoC
    context.read<FileManagerBloc>().add(FileManagerFileDeleted(file));
  }

  Duration _estimateProcessingTime(int sizeBytes) {
    // Simple estimation: ~1 minute per 100KB (very rough approximation)
    final minutes = (sizeBytes / (100 * 1024)).ceil();
    return Duration(minutes: minutes.clamp(1, 240)); // 1 minute to 4 hours max
  }
}
