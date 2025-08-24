import 'package:equatable/equatable.dart';
import '../../domain/value_objects/gcode_file.dart';

/// Base class for all file manager events
abstract class FileManagerEvent extends Equatable {
  const FileManagerEvent();

  @override
  List<Object?> get props => [];
}

/// Event triggered when a single file is added to the list
class FileManagerFileAdded extends FileManagerEvent {
  const FileManagerFileAdded(this.file);

  final GCodeFile file;

  @override
  List<Object?> get props => [file];

  @override
  String toString() => 'FileManagerFileAdded { file: ${file.name} }';
}

/// Event triggered when multiple files are added from file picker
class FileManagerFilesAdded extends FileManagerEvent {
  const FileManagerFilesAdded(this.files);

  final List<GCodeFile> files;

  @override
  List<Object?> get props => [files];

  @override
  String toString() => 'FileManagerFilesAdded { count: ${files.length} }';
}

/// Event triggered when user selects a file for processing
class FileManagerFileSelected extends FileManagerEvent {
  const FileManagerFileSelected(this.file);

  final GCodeFile file;

  @override
  List<Object?> get props => [file];

  @override
  String toString() => 'FileManagerFileSelected { file: ${file.name} }';
}

/// Event triggered when a file is deleted from the list
class FileManagerFileDeleted extends FileManagerEvent {
  const FileManagerFileDeleted(this.file);

  final GCodeFile file;

  @override
  List<Object?> get props => [file];

  @override
  String toString() => 'FileManagerFileDeleted { file: ${file.name} }';
}

/// Event triggered to clear all files from the list
class FileManagerFilesClearedAll extends FileManagerEvent {
  const FileManagerFilesClearedAll();

  @override
  String toString() => 'FileManagerFilesClearedAll';
}

/// Event triggered when file selection is cleared
class FileManagerSelectionCleared extends FileManagerEvent {
  const FileManagerSelectionCleared();

  @override
  String toString() => 'FileManagerSelectionCleared';
}