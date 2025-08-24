import 'package:equatable/equatable.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../entities/machine_configuration.dart';
import '../../models/bounding_box.dart';
import '../../utils/logger.dart';

/// Work envelope representing machine soft limits and travel boundaries
/// 
/// Based on grblHAL's limits_set_work_envelope() logic:
/// - Represents the safe operating boundaries within the machine's physical limits
/// - Calculated as: hard limits minus homing pulloff distance  
/// - This is the boundary that MACHINE POSITION (MPos) should stay within
/// - Different from work position (WPos) which is workpiece coordinates
/// 
/// Usage in soft limits checking:
/// - Check: Machine Position + Jog Vector vs Work Envelope
/// - NOT: Work Position vs Work Envelope (that's for different use cases)
///
/// Example: If machine can travel X=-285 to X=0, the work envelope might be
/// X=-284 to X=-1 after applying pulloff distance safety buffer.
class WorkEnvelope extends Equatable {
  /// The geometric bounding box representing machine soft limits
  final BoundingBox bounds;
  
  /// When this envelope was last updated (for state change detection)
  final DateTime lastUpdated;
  
  // Note: Removed 'units' field as per BOUNDING_BOX.md - always mm internally

  const WorkEnvelope({
    required this.bounds,
    required this.lastUpdated,
  });
  
  /// Legacy constructor for backward compatibility during migration
  /// Creates WorkEnvelope from individual minBounds/maxBounds
  factory WorkEnvelope.fromBounds({
    required vm.Vector3 minBounds,
    required vm.Vector3 maxBounds,
    String? units, // Ignored - always mm internally
    required DateTime lastUpdated,
  }) {
    return WorkEnvelope(
      bounds: BoundingBox(
        minBounds: minBounds,
        maxBounds: maxBounds,
      ),
      lastUpdated: lastUpdated,
    );
  }

  /// Legacy getters for backward compatibility
  vm.Vector3 get minBounds => bounds.minBounds;
  vm.Vector3 get maxBounds => bounds.maxBounds;
  String get units => 'mm'; // Always mm internally

  @override
  List<Object?> get props => [bounds, lastUpdated];

  /// Calculate work envelope from grblHAL machine configuration
  /// Based on grblHAL's limits_set_work_envelope() logic
  /// 
  /// Creates the soft limits boundary by taking machine travel limits and applying
  /// safety margins. This boundary should be checked against MACHINE POSITION (MPos),
  /// not work position (WPos).
  static WorkEnvelope? fromConfiguration(MachineConfiguration config) {
    // Require all three axis travel limits to be available
    final xTravel = config.xMaxTravel;
    final yTravel = config.yMaxTravel;
    final zTravel = config.zMaxTravel;
    
    if (xTravel == null || yTravel == null || zTravel == null) {
      final missing = <String>[];
      if (xTravel == null) missing.add('xMaxTravel');
      if (yTravel == null) missing.add('yMaxTravel');
      if (zTravel == null) missing.add('zMaxTravel');
      AppLogger.jogInfo('WorkEnvelope creation FAILED: missing ${missing.join(', ')} from machine configuration');
      return null;
    }

    // grblHAL stores max_travel as negative values internally
    // The actual travel distance is the absolute value
    final xMax = xTravel.abs();
    final yMax = yTravel.abs();
    final zMax = zTravel.abs();

    // For grblHAL with default settings (force_set_origin typically true):
    // - Home position becomes origin (0,0,0)
    // - Work envelope extends in negative direction from home
    // This follows the standard CNC convention where home is at max positive position
    final minBounds = vm.Vector3(-xMax, -yMax, -zMax);
    final maxBounds = vm.Vector3(0.0, 0.0, 0.0);

    // Only log WorkEnvelope creation once when it first succeeds, not on every call

    return WorkEnvelope.fromBounds(
      minBounds: minBounds,
      maxBounds: maxBounds,
      units: config.reportInches == true ? 'inch' : 'mm',
      lastUpdated: config.lastUpdated,
    );
  }

  /// Get work envelope dimensions  
  vm.Vector3 get dimensions => bounds.size;

  /// Get work envelope center point
  vm.Vector3 get center => bounds.center;

  WorkEnvelope copyWith({
    BoundingBox? bounds,
    vm.Vector3? minBounds,
    vm.Vector3? maxBounds,
    String? units, // Ignored - always mm internally
    DateTime? lastUpdated,
  }) {
    // If new bounds provided directly, use them
    if (bounds != null) {
      return WorkEnvelope(
        bounds: bounds,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
    }
    
    // Legacy support: if minBounds/maxBounds provided, create BoundingBox
    if (minBounds != null || maxBounds != null) {
      return WorkEnvelope.fromBounds(
        minBounds: minBounds ?? this.minBounds,
        maxBounds: maxBounds ?? this.maxBounds,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
    }
    
    // No bounds changes, just update lastUpdated if provided
    return WorkEnvelope(
      bounds: this.bounds,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() => 'WorkEnvelope($minBounds to $maxBounds $units)';
}