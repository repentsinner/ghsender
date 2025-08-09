import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import '../scene/scene_manager.dart';
import 'gcode_parser.dart';

/// Types of G-code path segments for rendering
enum GCodeSegmentType {
  line,        // Linear movement (G0/G1)
  arc,         // Arc movement (G2/G3)
  rapidMove,   // Rapid positioning (G0)
}

/// A renderable segment from G-code
class GCodeSegment {
  final GCodeSegmentType type;
  final vm.Vector3 start;
  final vm.Vector3 end;
  final vm.Vector3? center;  // Arc center (for arcs only)
  final bool clockwise;      // Arc direction (for arcs only)
  final Color color;
  final double thickness;
  final String id;

  const GCodeSegment({
    required this.type,
    required this.start,
    required this.end,
    this.center,
    this.clockwise = true,
    required this.color,
    this.thickness = 0.1,
    required this.id,
  });
}

/// Converts G-code path to scene objects for rendering
class GCodeSceneGenerator {
  static const double _cuttingThickness = 1.0; // Thickness for cutting moves (increased for visibility)
  static const double _rapidThickness = 0.5;   // Thickness for rapid moves (increased for visibility)
  
  /// Convert G-code path to scene objects with timing and state information
  static List<SceneObject> generateSceneObjects(GCodePath gcodePath) {
    final sceneObjects = <SceneObject>[];
    final rawSegments = _generateSegments(gcodePath);
    
    // Join consecutive short segments to reduce visual artifacts and improve performance
    final segments = _joinShortSegments(rawSegments);
    
    AppLogger.info('G-code to scene conversion:');
    AppLogger.info('Generated ${rawSegments.length} raw segments -> ${segments.length} joined segments');
    
    // Convert segments to scene objects with state and timing information
    double cumulativeTime = 0.0;
    
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      
      // Estimate operation time based on segment type and length
      final operationTime = _estimateOperationTime(segment);
      cumulativeTime += operationTime;
      
      if (segment.type == GCodeSegmentType.line || segment.type == GCodeSegmentType.rapidMove) {
        // Create line object with timing info (handles both G1 linear and G0 rapid moves)
        final lineObject = _createLineObjectWithState(segment, i, operationTime, cumulativeTime);
        sceneObjects.add(lineObject);
        
      } else if (segment.type == GCodeSegmentType.arc) {
        // Tessellate arc into line segments with timing
        final arcLines = _tessellateArcWithState(segment, i, operationTime, cumulativeTime);
        sceneObjects.addAll(arcLines);
      }
    }
    
    // Add coordinate axes for reference
    sceneObjects.addAll(_createCoordinateAxes(gcodePath));
    
    AppLogger.info('Total scene objects: ${sceneObjects.length}');
    // Scene conversion complete
    
    return sceneObjects;
  }
  
  /// Generate path segments from G-code commands
  static List<GCodeSegment> _generateSegments(GCodePath gcodePath) {
    final segments = <GCodeSegment>[];
    vm.Vector3? previousPosition;
    
    int rapidCount = 0;
    int linearCount = 0;
    int arcCount = 0;
    
    for (int i = 0; i < gcodePath.commands.length; i++) {
      final command = gcodePath.commands[i];
      
      if (previousPosition != null) {
        final segment = _createSegmentFromCommand(command, previousPosition, i);
        if (segment != null) {
          segments.add(segment);
          
          // Count segment types
          switch (segment.type) {
            case GCodeSegmentType.rapidMove:
              rapidCount++;
              break;
            case GCodeSegmentType.line:
              linearCount++;
              break;
            case GCodeSegmentType.arc:
              arcCount++;
              break;
          }
        }
      }
      
      previousPosition = command.position;
    }
    
    AppLogger.info('G-code segments: $rapidCount rapids (blue), $linearCount linear (green), $arcCount arcs (red/orange)');
    return segments;
  }
  
  /// Create a segment from a G-code command
  static GCodeSegment? _createSegmentFromCommand(GCodeCommand command, vm.Vector3 start, int index) {
    Color segmentColor;
    GCodeSegmentType segmentType;
    double thickness;
    
    switch (command.type) {
      case GCodeCommandType.rapidMove:
        segmentColor = Colors.blue;
        segmentType = GCodeSegmentType.rapidMove;
        thickness = _rapidThickness;
        break;
      case GCodeCommandType.linearMove:
        segmentColor = Colors.green;
        segmentType = GCodeSegmentType.line;
        thickness = _cuttingThickness;
        break;
      case GCodeCommandType.clockwiseArc:
        segmentColor = Colors.red;
        segmentType = GCodeSegmentType.arc;
        thickness = _cuttingThickness;
        break;
      case GCodeCommandType.counterClockwiseArc:
        segmentColor = Colors.orange;
        segmentType = GCodeSegmentType.arc;
        thickness = _cuttingThickness;
        break;
    }
    
    return GCodeSegment(
      type: segmentType,
      start: start,
      end: command.position,
      center: command.center != null ? start + command.center! : null,
      clockwise: command.type == GCodeCommandType.clockwiseArc,
      color: segmentColor,
      thickness: thickness,
      id: 'gcode_segment_$index',
    );
  }
  
  /// Create a line scene object with G-code state information
  static SceneObject _createLineObjectWithState(GCodeSegment segment, int index, double operationTime, double cumulativeTime) {
    final direction = segment.end - segment.start;
    final length = direction.length;
    final center = (segment.start + segment.end) * 0.5;
    
    // Calculate rotation to align with line direction
    final rotation = _calculateLineRotation(direction.normalized());
    
    // Determine G-code operation type
    final isRapid = segment.type == GCodeSegmentType.rapidMove;
    final isCutting = segment.type == GCodeSegmentType.line && !isRapid;
    
    return SceneObject(
      type: SceneObjectType.line,
      position: center,
      scale: vm.Vector3(length, segment.thickness, segment.thickness),
      rotation: rotation,
      color: segment.color,
      id: segment.id,
      operationIndex: index,
      estimatedTime: operationTime,
      isRapidMove: isRapid,
      isCuttingMove: isCutting,
      isArcMove: false,
    );
  }
  
  
  /// Tessellate an arc into multiple line segments with state information
  static List<SceneObject> _tessellateArcWithState(GCodeSegment arcSegment, int baseIndex, double totalArcTime, double cumulativeTime) {
    if (arcSegment.center == null) return [];
    
    final lineObjects = _tessellateArc(arcSegment, baseIndex);
    
    // Add state information to each tessellated segment
    final timePerSegment = totalArcTime / lineObjects.length;
    
    for (int i = 0; i < lineObjects.length; i++) {
      final obj = lineObjects[i];
      // Create new object with state information
      lineObjects[i] = SceneObject(
        type: obj.type,
        position: obj.position,
        scale: obj.scale,
        rotation: obj.rotation,
        color: obj.color,
        id: obj.id,
        operationIndex: baseIndex,
        estimatedTime: timePerSegment,
        isRapidMove: false,
        isCuttingMove: false,
        isArcMove: true,
      );
    }
    
    return lineObjects;
  }
  
  /// Tessellate an arc into multiple line segments
  static List<SceneObject> _tessellateArc(GCodeSegment arcSegment, int baseIndex) {
    if (arcSegment.center == null) return [];
    
    final center = arcSegment.center!;
    final startVector = arcSegment.start - center;
    final endVector = arcSegment.end - center;
    final radius = startVector.length;
    
    // Calculate arc angle
    double startAngle = atan2(startVector.y, startVector.x);
    double endAngle = atan2(endVector.y, endVector.x);
    
    // Handle angle wrapping for arc direction
    double totalAngle;
    if (arcSegment.clockwise) {
      if (endAngle > startAngle) endAngle -= 2 * pi;
      totalAngle = startAngle - endAngle;
    } else {
      if (endAngle < startAngle) endAngle += 2 * pi;
      totalAngle = endAngle - startAngle;
    }
    
    // Tessellate arc based on angle and radius
    final segments = max(8, (totalAngle.abs() * radius * 10).round());
    final angleStep = totalAngle / segments;
    
    final lineObjects = <SceneObject>[];
    
    for (int i = 0; i < segments; i++) {
      final currentAngle = startAngle + (arcSegment.clockwise ? -angleStep * i : angleStep * i);
      final nextAngle = startAngle + (arcSegment.clockwise ? -angleStep * (i + 1) : angleStep * (i + 1));
      
      final startPoint = center + vm.Vector3(
        radius * cos(currentAngle),
        radius * sin(currentAngle),
        arcSegment.start.z + (arcSegment.end.z - arcSegment.start.z) * (i / segments),
      );
      
      final endPoint = center + vm.Vector3(
        radius * cos(nextAngle),
        radius * sin(nextAngle),
        arcSegment.start.z + (arcSegment.end.z - arcSegment.start.z) * ((i + 1) / segments),
      );
      
      final direction = endPoint - startPoint;
      final length = direction.length;
      final lineCenter = (startPoint + endPoint) * 0.5;
      final rotation = _calculateLineRotation(direction.normalized());
      
      lineObjects.add(SceneObject(
        type: SceneObjectType.line,
        position: lineCenter,
        scale: vm.Vector3(length, arcSegment.thickness, arcSegment.thickness),
        rotation: rotation,
        color: arcSegment.color,
        id: '${arcSegment.id}_arc_$i',
      ));
    }
    
    return lineObjects;
  }
  
  /// Calculate rotation quaternion to align with line direction
  static vm.Quaternion _calculateLineRotation(vm.Vector3 direction) {
    // Default orientation is along X axis
    final defaultDirection = vm.Vector3(1, 0, 0);
    
    // Handle parallel/anti-parallel cases
    if (direction.dot(defaultDirection).abs() > 0.9999) {
      if (direction.x > 0) {
        return vm.Quaternion.identity();
      } else {
        return vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), pi);
      }
    }
    
    // Calculate rotation axis and angle
    final axis = defaultDirection.cross(direction).normalized();
    final angle = acos(defaultDirection.dot(direction));
    
    return vm.Quaternion.axisAngle(axis, angle);
  }
  
  /// Create coordinate axes for reference
  static List<SceneObject> _createCoordinateAxes(GCodePath gcodePath) {
    final center = (gcodePath.minBounds + gcodePath.maxBounds) * 0.5;
    final size = gcodePath.maxBounds - gcodePath.minBounds;
    final axisLength = max(size.x, size.y) * 0.2;
    
    return [
      // X-axis (Red)
      SceneObject(
        type: SceneObjectType.axis,
        position: vm.Vector3(center.x + axisLength/2, gcodePath.minBounds.y - 5, gcodePath.maxBounds.z + 2),
        scale: vm.Vector3(axisLength, 0.5, 0.5),
        rotation: vm.Quaternion.identity(),
        color: Colors.red,
        id: 'gcode_axis_x',
      ),
      // Y-axis (Green)
      SceneObject(
        type: SceneObjectType.axis,
        position: vm.Vector3(gcodePath.minBounds.x - 5, center.y + axisLength/2, gcodePath.maxBounds.z + 2),
        scale: vm.Vector3(0.5, axisLength, 0.5),
        rotation: vm.Quaternion.identity(),
        color: Colors.green,
        id: 'gcode_axis_y',
      ),
      // Z-axis (Blue)
      SceneObject(
        type: SceneObjectType.axis,
        position: vm.Vector3(gcodePath.minBounds.x - 5, gcodePath.minBounds.y - 5, center.z + axisLength/2),
        scale: vm.Vector3(0.5, 0.5, axisLength),
        rotation: vm.Quaternion.identity(),
        color: Colors.blue,
        id: 'gcode_axis_z',
      ),
    ];
  }
  
  /// Join consecutive short segments to reduce visual artifacts and improve performance
  static List<GCodeSegment> _joinShortSegments(List<GCodeSegment> segments) {
    const double shortSegmentThreshold = 0.5; // Segments shorter than this will be candidates for joining
    const double maxJoinedLength = 5.0; // Don't create segments longer than this
    
    final joinedSegments = <GCodeSegment>[];
    int i = 0;
    
    while (i < segments.length) {
      final currentSegment = segments[i];
      final currentLength = (currentSegment.end - currentSegment.start).length;
      
      // If this segment is long enough, keep it as-is
      if (currentLength >= shortSegmentThreshold) {
        joinedSegments.add(currentSegment);
        i++;
        continue;
      }
      
      // Try to join consecutive short segments of the same type
      final segmentsToJoin = <GCodeSegment>[currentSegment];
      double totalLength = currentLength;
      int j = i + 1;
      
      while (j < segments.length && 
             totalLength < maxJoinedLength && 
             segments[j].type == currentSegment.type &&
             segments[j].color == currentSegment.color) {
        
        final nextSegment = segments[j];
        final nextLength = (nextSegment.end - nextSegment.start).length;
        
        // Check if segments are connected (end of previous ≈ start of next)
        final connectionDistance = (segmentsToJoin.last.end - nextSegment.start).length;
        if (connectionDistance > 0.01) break; // Not connected
        
        segmentsToJoin.add(nextSegment);
        totalLength += nextLength;
        j++;
        
        // Stop if the next segment is already long enough
        if (nextLength >= shortSegmentThreshold) break;
      }
      
      // Create joined segment if we found multiple short segments to combine
      if (segmentsToJoin.length > 1) {
        final joinedSegment = GCodeSegment(
          type: currentSegment.type,
          start: segmentsToJoin.first.start,
          end: segmentsToJoin.last.end,
          color: currentSegment.color,
          thickness: currentSegment.thickness,
          id: '${currentSegment.id}_joined_${segmentsToJoin.length}',
        );
        joinedSegments.add(joinedSegment);
      } else {
        // Keep original segment if no joining was possible
        joinedSegments.add(currentSegment);
      }
      
      i = j;
    }
    
    final originalCount = segments.length;
    final joinedCount = joinedSegments.length;
    final reduction = ((originalCount - joinedCount) / originalCount * 100).round();
    AppLogger.info('Segment joining: $originalCount -> $joinedCount segments ($reduction% reduction)');
    
    return joinedSegments;
  }

  /// Calculate appropriate camera position for G-code visualization
  static CameraConfiguration calculateCamera(GCodePath gcodePath) {
    final center = (gcodePath.minBounds + gcodePath.maxBounds) * 0.5;
    final size = gcodePath.maxBounds - gcodePath.minBounds;
    final maxDimension = max(max(size.x, size.y), size.z);
    
    // Position camera to view the entire part
    final cameraDistance = maxDimension * 2.0;
    final cameraHeight = maxDimension * 0.8;
    
    return CameraConfiguration(
      position: vm.Vector3(
        center.x + cameraDistance * 0.7, 
        center.y + cameraDistance * 0.7, 
        center.z + cameraHeight
      ),
      target: center,
      up: vm.Vector3(0, 0, 1), // Z-up for CNC coordinate system
      fov: 45.0,
    );
  }
  
  /// Estimate operation time for a G-code segment based on type and length
  static double _estimateOperationTime(GCodeSegment segment) {
    final distance = (segment.end - segment.start).length;
    
    switch (segment.type) {
      case GCodeSegmentType.rapidMove:
        // Rapids: ~3000 mm/min (50 mm/s)
        return distance / 50.0;
        
      case GCodeSegmentType.line:
        // Linear cuts: ~600 mm/min (10 mm/s) 
        return distance / 10.0;
        
      case GCodeSegmentType.arc:
        // Arcs: slightly slower than linear ~480 mm/min (8 mm/s)
        return distance / 8.0;
    }
  }
}