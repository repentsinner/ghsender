import 'package:equatable/equatable.dart';
import 'package:vector_math/vector_math.dart' as vm;

enum GCodeCommandType { 
  rapidMove,    // G0
  linearMove,   // G1
  clockwiseArc, // G2
  counterClockwiseArc // G3
}

class GCodeCommand extends Equatable {
  final GCodeCommandType type;
  final vm.Vector3 position;
  final vm.Vector3? center; // I,J,K values for arcs (relative to start point)
  final double? radius;     // R value for arcs
  final double feedRate;
  final int lineNumber;
  
  const GCodeCommand({
    required this.type,
    required this.position,
    this.center,
    this.radius,
    this.feedRate = 0,
    required this.lineNumber,
  });
  
  @override
  List<Object?> get props => [type, position, center, radius, feedRate, lineNumber];
  
  @override
  String toString() => 
    'GCodeCommand(${type.name}, pos: $position, line: $lineNumber)';
}