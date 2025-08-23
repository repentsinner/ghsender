import '../value_objects/gcode_program.dart';
import '../value_objects/gcode_program_id.dart';

/// Abstract repository interface for G-code program management
/// 
/// Handles program loading, saving, listing, and deletion operations.
/// Integrates with existing file management without breaking workflows.
abstract class GCodeRepository {
  /// Load a G-code program by ID
  /// 
  /// Returns the complete program with parsed data, metadata, and validation results.
  /// Throws [GCodeProgramNotFoundException] if program doesn't exist.
  Future<GCodeProgram> load(GCodeProgramId id);
  
  /// Save a G-code program
  /// 
  /// Persists the program to storage with metadata and validation results.
  /// Updates existing program if ID matches, creates new one otherwise.
  Future<void> save(GCodeProgram program);
  
  /// List all available G-code programs
  /// 
  /// Returns metadata for all stored programs, suitable for file browser display.
  /// Results are sorted by upload date (newest first).
  Future<List<GCodeProgramMetadata>> listPrograms();
  
  /// Delete a G-code program
  /// 
  /// Removes program from storage. No-op if program doesn't exist.
  Future<void> delete(GCodeProgramId id);
  
  /// Watch for program list changes
  /// 
  /// Returns stream of program list updates for reactive UI updates.
  /// Emits immediately with current program list when subscribed.
  Stream<List<GCodeProgramMetadata>> watchPrograms();
  
  /// Watch a specific program for changes
  /// 
  /// Returns stream of updates for a specific program.
  /// Useful for monitoring processing status, validation results, etc.
  Stream<GCodeProgram> watchProgram(GCodeProgramId id);
  
  /// Check if a program exists
  /// 
  /// Quick existence check without loading full program data.
  Future<bool> exists(GCodeProgramId id);
}

/// Metadata for G-code program list display
class GCodeProgramMetadata {
  final GCodeProgramId id;
  final String name;
  final String path;
  final int sizeBytes;
  final DateTime uploadDate;
  final String status;
  final Duration? estimatedTime;
  
  const GCodeProgramMetadata({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.uploadDate,
    required this.status,
    this.estimatedTime,
  });
}

/// Exception thrown when a G-code program is not found
class GCodeProgramNotFoundException implements Exception {
  final GCodeProgramId id;
  final String message;
  
  const GCodeProgramNotFoundException(this.id, this.message);
  
  @override
  String toString() => 'GCodeProgramNotFoundException: $message (ID: $id)';
}