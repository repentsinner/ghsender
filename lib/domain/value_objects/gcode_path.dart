import 'package:vector_math/vector_math.dart' as vm;
import 'gcode_command.dart';
import '../../models/bounding_box.dart';

class GCodePath {
  final List<GCodeCommand> commands;
  
  // Legacy bounds (kept for backward compatibility during migration)
  final vm.Vector3 minBounds;
  final vm.Vector3 maxBounds;
  
  // New unified bounds using BoundingBox architecture
  final BoundingBox bounds;
  
  final int totalOperations;
  
  const GCodePath({
    required this.commands,
    required this.minBounds,
    required this.maxBounds,
    required this.bounds,
    required this.totalOperations,
  });
  
  /// Factory constructor to create GCodePath with bounds calculated from min/max
  /// This maintains backward compatibility while introducing the new BoundingBox
  factory GCodePath.fromBounds({
    required List<GCodeCommand> commands,
    required vm.Vector3 minBounds,
    required vm.Vector3 maxBounds,
    required int totalOperations,
  }) {
    return GCodePath(
      commands: commands,
      minBounds: minBounds,
      maxBounds: maxBounds,
      bounds: BoundingBox(
        minBounds: minBounds,
        maxBounds: maxBounds,
      ),
      totalOperations: totalOperations,
    );
  }
}