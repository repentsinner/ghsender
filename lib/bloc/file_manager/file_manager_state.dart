import 'package:equatable/equatable.dart';
import '../../models/gcode_file.dart';

/// State for file management operations
class FileManagerState extends Equatable {
  const FileManagerState({
    this.files = const [],
    this.selectedFile,
    this.isLoading = false,
    this.errorMessage,
  });

  /// List of all uploaded G-code files
  final List<GCodeFile> files;
  
  /// Currently selected file for processing
  final GCodeFile? selectedFile;
  
  /// Whether a file operation is in progress
  final bool isLoading;
  
  /// Error message if operation failed
  final String? errorMessage;

  /// Create a copy of the state with updated fields
  FileManagerState copyWith({
    List<GCodeFile>? files,
    GCodeFile? selectedFile,
    bool? clearSelectedFile = false,
    bool? isLoading,
    String? errorMessage,
    bool? clearError = false,
  }) {
    return FileManagerState(
      files: files ?? this.files,
      selectedFile: clearSelectedFile == true ? null : selectedFile ?? this.selectedFile,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError == true ? null : errorMessage ?? this.errorMessage,
    );
  }

  /// Whether the file list is empty
  bool get isEmpty => files.isEmpty;

  /// Whether the file list has content
  bool get isNotEmpty => files.isNotEmpty;

  /// Whether a file is currently selected
  bool get hasSelection => selectedFile != null;

  /// Whether there is an error state
  bool get hasError => errorMessage != null;

  /// Get file by name (for testing/debugging)
  GCodeFile? getFileByName(String name) {
    try {
      return files.firstWhere((file) => file.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Check if a specific file is selected
  bool isFileSelected(GCodeFile file) => selectedFile == file;

  @override
  List<Object?> get props => [
    files,
    selectedFile,
    isLoading,
    errorMessage,
  ];

  @override
  String toString() {
    return 'FileManagerState { files: ${files.length}, selectedFile: ${selectedFile?.name}, isLoading: $isLoading, hasError: $hasError }';
  }
}