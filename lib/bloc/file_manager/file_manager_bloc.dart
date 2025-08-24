import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/logger.dart';
import '../../gcode/gcode_processor.dart';
import '../../domain/value_objects/gcode_file.dart';
import 'file_manager_event.dart';
import 'file_manager_state.dart';

/// BLoC for managing G-code file operations and selection
class FileManagerBloc extends Bloc<FileManagerEvent, FileManagerState> {
  FileManagerBloc() : super(const FileManagerState()) {
    on<FileManagerFileAdded>(_onFileAdded);
    on<FileManagerFilesAdded>(_onFilesAdded);
    on<FileManagerFileSelected>(_onFileSelected);
    on<FileManagerFileDeleted>(_onFileDeleted);
    on<FileManagerFilesClearedAll>(_onFilesClearedAll);
    on<FileManagerSelectionCleared>(_onSelectionCleared);
  }

  /// Handle adding a single file to the list
  Future<void> _onFileAdded(
    FileManagerFileAdded event,
    Emitter<FileManagerState> emit,
  ) async {
    AppLogger.info('Adding file to list: ${event.file.name}');
    
    final updatedFiles = List<GCodeFile>.from(state.files)..add(event.file);
    
    emit(state.copyWith(
      files: updatedFiles,
      clearError: true,
    ));
    
    AppLogger.info('File added successfully. Total files: ${updatedFiles.length}');
  }

  /// Handle adding multiple files from file picker
  Future<void> _onFilesAdded(
    FileManagerFilesAdded event,
    Emitter<FileManagerState> emit,
  ) async {
    if (event.files.isEmpty) {
      AppLogger.info('No files provided to add');
      return;
    }

    AppLogger.info('Adding ${event.files.length} files to list');
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final updatedFiles = List<GCodeFile>.from(state.files)..addAll(event.files);
      
      emit(state.copyWith(
        files: updatedFiles,
        isLoading: false,
      ));
      
      AppLogger.info('Successfully added ${event.files.length} files. Total files: ${updatedFiles.length}');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to add files', error, stackTrace);
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to add files: ${error.toString()}',
      ));
    }
  }

  /// Handle file selection for G-code processing
  Future<void> _onFileSelected(
    FileManagerFileSelected event,
    Emitter<FileManagerState> emit,
  ) async {
    AppLogger.info('Selecting file for processing: ${event.file.name}');
    
    // Update selection immediately for UI responsiveness
    emit(state.copyWith(
      selectedFile: event.file,
      clearError: true,
    ));

    // Process the selected file with the G-code processor
    try {
      AppLogger.info('Processing selected G-code file: ${event.file.name}');
      await GCodeProcessor.instance.processFile(event.file);
      AppLogger.info('G-code file processing completed successfully');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to process G-code file: ${event.file.name}', error, stackTrace);
      
      // Keep the file selected but show error
      emit(state.copyWith(
        errorMessage: 'Failed to process G-code file: ${event.file.name}',
      ));
    }
  }

  /// Handle file deletion
  Future<void> _onFileDeleted(
    FileManagerFileDeleted event,
    Emitter<FileManagerState> emit,
  ) async {
    AppLogger.info('Deleting file: ${event.file.name}');

    final updatedFiles = List<GCodeFile>.from(state.files)..remove(event.file);
    
    // Clear selection if the selected file was deleted
    final bool shouldClearSelection = state.selectedFile == event.file;
    
    emit(state.copyWith(
      files: updatedFiles,
      clearSelectedFile: shouldClearSelection,
      clearError: true,
    ));

    // Clear the G-code processor if selected file was deleted
    if (shouldClearSelection) {
      try {
        GCodeProcessor.instance.clearCurrentFile();
        AppLogger.info('Cleared G-code processor due to file deletion');
      } catch (error, stackTrace) {
        AppLogger.error('Failed to clear G-code processor', error, stackTrace);
      }
    }
    
    AppLogger.info('File deleted successfully. Remaining files: ${updatedFiles.length}');
  }

  /// Handle clearing all files
  Future<void> _onFilesClearedAll(
    FileManagerFilesClearedAll event,
    Emitter<FileManagerState> emit,
  ) async {
    AppLogger.info('Clearing all files');
    
    emit(state.copyWith(
      files: [],
      clearSelectedFile: true,
      clearError: true,
    ));

    // Clear the G-code processor
    try {
      GCodeProcessor.instance.clearCurrentFile();
      AppLogger.info('Cleared G-code processor due to file list clear');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to clear G-code processor', error, stackTrace);
    }
    
    AppLogger.info('All files cleared successfully');
  }

  /// Handle clearing file selection
  Future<void> _onSelectionCleared(
    FileManagerSelectionCleared event,
    Emitter<FileManagerState> emit,
  ) async {
    AppLogger.info('Clearing file selection');
    
    emit(state.copyWith(
      clearSelectedFile: true,
      clearError: true,
    ));

    // Clear the G-code processor
    try {
      GCodeProcessor.instance.clearCurrentFile();
      AppLogger.info('Cleared G-code processor due to selection clear');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to clear G-code processor', error, stackTrace);
    }
  }

  /// Get current selected file (convenience getter)
  GCodeFile? get selectedFile => state.selectedFile;

  /// Get current file list (convenience getter)
  List<GCodeFile> get files => state.files;

  /// Check if a specific file is selected (convenience method)
  bool isFileSelected(GCodeFile file) => state.isFileSelected(file);

  @override
  void onTransition(
    Transition<FileManagerEvent, FileManagerState> transition,
  ) {
    super.onTransition(transition);
    AppLogger.debug(
      'FileManagerBloc transition: ${transition.currentState} -> ${transition.nextState}',
    );
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    super.onError(error, stackTrace);
    AppLogger.error('FileManagerBloc error', error, stackTrace);
  }
}