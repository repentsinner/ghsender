import 'package:equatable/equatable.dart';

/// Unique identifier for a G-code program
/// 
/// Wraps string-based program identification in a type-safe manner.
/// Typically uses file path or generated UUID for unique identification.
class GCodeProgramId extends Equatable {
  final String value;

  const GCodeProgramId(this.value);
  
  /// Create program ID from file path
  factory GCodeProgramId.fromPath(String filePath) {
    return GCodeProgramId(filePath);
  }
  
  /// Create program ID from name (for compatibility with existing code)
  factory GCodeProgramId.fromName(String name) {
    return GCodeProgramId(name);
  }

  @override
  List<Object?> get props => [value];

  @override
  String toString() => 'GCodeProgramId($value)';
}