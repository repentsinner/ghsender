import 'package:equatable/equatable.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../../models/bounding_box.dart';
import 'work_envelope.dart';

/// G-code job geometry envelope
/// 
/// Represents the bounding box containing all G-code geometry for a job.
/// This is semantically distinct from WorkEnvelope (machine limits) and is used
/// for visualization, camera positioning, and job-related calculations.
/// 
/// Key distinction:
/// - JobEnvelope: Actual G-code geometry bounds (what the job will create)
/// - WorkEnvelope: Machine soft limits (where the machine can safely travel)
class JobEnvelope extends Equatable {
  /// The geometric bounding box containing the job's G-code geometry
  final BoundingBox bounds;
  
  /// When these bounds were last updated (for state change detection)
  final DateTime lastUpdated;
  
  /// Optional metadata about the job for display purposes
  final String? jobName;
  final int? totalOperations;

  const JobEnvelope({
    required this.bounds,
    required this.lastUpdated,
    this.jobName,
    this.totalOperations,
  });

  /// Create a JobEnvelope from legacy minBounds/maxBounds format
  factory JobEnvelope.fromBounds({
    required vm.Vector3 minBounds,
    required vm.Vector3 maxBounds,
    DateTime? lastUpdated,
    String? jobName,
    int? totalOperations,
  }) {
    return JobEnvelope(
      bounds: BoundingBox(
        minBounds: minBounds,
        maxBounds: maxBounds,
      ),
      lastUpdated: lastUpdated ?? DateTime.now(),
      jobName: jobName,
      totalOperations: totalOperations,
    );
  }

  /// Create an empty JobEnvelope (no job loaded)
  factory JobEnvelope.empty({String? jobName}) {
    return JobEnvelope(
      bounds: BoundingBox.empty(),
      lastUpdated: DateTime.now(),
      jobName: jobName,
    );
  }

  /// Convenience getters for accessing bounds geometry
  
  /// Get the minimum bounds (lower-left-back corner)
  vm.Vector3 get minBounds => bounds.minBounds;
  
  /// Get the maximum bounds (upper-right-front corner)  
  vm.Vector3 get maxBounds => bounds.maxBounds;
  
  /// Get the center point of the job geometry
  vm.Vector3 get center => bounds.center;
  
  /// Get the size/dimensions of the job geometry
  vm.Vector3 get size => bounds.size;
  
  /// Get the width (X-axis extent) of the job
  double get width => bounds.width;
  
  /// Get the height (Y-axis extent) of the job
  double get height => bounds.height;
  
  /// Get the depth (Z-axis extent) of the job
  double get depth => bounds.depth;
  
  /// Check if this envelope contains any valid geometry
  bool get isEmpty => bounds.isEmpty;
  
  /// Check if the job geometry is essentially 2D (zero or minimal Z depth)
  bool get is2D => bounds.depth < 0.001; // 1 micron threshold
  
  /// Check if the job geometry fits within the specified work envelope
  bool fitsWithin(WorkEnvelope workEnvelope) {
    if (isEmpty || workEnvelope.bounds.isEmpty) return false;
    
    return workEnvelope.bounds.containsBox(bounds);
  }
  
  /// Get a summary string for display purposes
  String get summary {
    if (isEmpty) return 'No job geometry';
    
    final name = jobName ?? 'Job';
    final ops = totalOperations != null ? ' ($totalOperations ops)' : '';
    final dimensions = '${width.toStringAsFixed(1)} × ${height.toStringAsFixed(1)} × ${depth.toStringAsFixed(1)} mm';
    
    return '$name$ops: $dimensions';
  }
  
  /// Get display string for job dimensions
  String get dimensionsString {
    if (isEmpty) return 'No geometry';
    
    if (is2D) {
      // For 2D jobs, show only X×Y dimensions
      return '${width.toStringAsFixed(1)} × ${height.toStringAsFixed(1)} mm';
    } else {
      // For 3D jobs, show all dimensions
      return '${width.toStringAsFixed(1)} × ${height.toStringAsFixed(1)} × ${depth.toStringAsFixed(1)} mm';
    }
  }

  @override
  List<Object?> get props => [bounds, lastUpdated, jobName, totalOperations];

  /// Create a copy with optional modifications
  JobEnvelope copyWith({
    BoundingBox? bounds,
    DateTime? lastUpdated,
    String? jobName,
    int? totalOperations,
  }) {
    return JobEnvelope(
      bounds: bounds ?? this.bounds,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      jobName: jobName ?? this.jobName,
      totalOperations: totalOperations ?? this.totalOperations,
    );
  }

  @override
  String toString() {
    if (isEmpty) return 'JobEnvelope.empty()';
    return 'JobEnvelope($summary)';
  }
}