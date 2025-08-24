import 'package:equatable/equatable.dart';
import 'gcode_path.dart';
import 'gcode_program_id.dart';
import 'validation_result.dart';

/// Domain representation of a G-code program
/// 
/// Encapsulates program metadata, parsed G-code data, and validation results.
/// Bridges between file system representation and domain logic.
class GCodeProgram extends Equatable {
  final GCodeProgramId id;
  final String name;
  final String path;
  final int sizeBytes;
  final DateTime uploadDate;
  final String status;
  final Duration? estimatedTime;
  final GCodePath? parsedData;
  final ValidationResult? validationResult;

  const GCodeProgram({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.uploadDate,
    required this.status,
    this.estimatedTime,
    this.parsedData,
    this.validationResult,
  });
  
  /// Create program from existing GCodeFile model (migration helper)
  factory GCodeProgram.fromGCodeFile(
    dynamic gCodeFile, {  // Using dynamic for now to avoid import issues
    GCodePath? parsedData,
    ValidationResult? validationResult,
  }) {
    return GCodeProgram(
      id: GCodeProgramId.fromPath(gCodeFile.path),
      name: gCodeFile.name,
      path: gCodeFile.path,
      sizeBytes: gCodeFile.sizeBytes,
      uploadDate: gCodeFile.uploadDate,
      status: gCodeFile.status,
      estimatedTime: gCodeFile.estimatedTime,
      parsedData: parsedData,
      validationResult: validationResult,
    );
  }
  
  /// Check if program has been successfully parsed
  bool get isParsed => parsedData != null;
  
  /// Check if program has been validated
  bool get isValidated => validationResult != null;
  
  /// Check if program passed validation
  bool get isValid => validationResult?.isValid ?? false;
  
  /// Get total number of G-code operations
  int get totalOperations => parsedData?.totalOperations ?? 0;
  
  /// Create copy with updated fields
  GCodeProgram copyWith({
    GCodeProgramId? id,
    String? name,
    String? path,
    int? sizeBytes,
    DateTime? uploadDate,
    String? status,
    Duration? estimatedTime,
    GCodePath? parsedData,
    ValidationResult? validationResult,
  }) {
    return GCodeProgram(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      uploadDate: uploadDate ?? this.uploadDate,
      status: status ?? this.status,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      parsedData: parsedData ?? this.parsedData,
      validationResult: validationResult ?? this.validationResult,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        path,
        sizeBytes,
        uploadDate,
        status,
        estimatedTime,
        parsedData,
        validationResult,
      ];

  @override
  String toString() => 'GCodeProgram(id: $id, name: $name, status: $status)';
}