import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../scene/scene_manager.dart';
import '../ui/themes/visualizer_theme.dart';
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
  /// Current theme for visualization colors and settings
  static VisualizerThemeData _currentTheme = VisualizerTheme.createTheme(VisualizerThemeVariant.classic);
  
  /// Set the theme for G-code visualization
  static void setTheme(VisualizerThemeData theme) {
    _currentTheme = theme;
  }
  
  /// Get current theme
  static VisualizerThemeData get currentTheme => _currentTheme;
  
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
        segmentColor = _currentTheme.rapidMoveColor;
        segmentType = GCodeSegmentType.rapidMove;
        thickness = _currentTheme.rapidMoveThickness;
        break;
      case GCodeCommandType.linearMove:
        segmentColor = _currentTheme.linearMoveColor;
        segmentType = GCodeSegmentType.line;
        thickness = _currentTheme.cuttingMoveThickness;
        break;
      case GCodeCommandType.clockwiseArc:
        segmentColor = _currentTheme.clockwiseArcColor;
        segmentType = GCodeSegmentType.arc;
        thickness = _currentTheme.cuttingMoveThickness;
        break;
      case GCodeCommandType.counterClockwiseArc:
        segmentColor = _currentTheme.counterClockwiseArcColor;
        segmentType = GCodeSegmentType.arc;
        thickness = _currentTheme.cuttingMoveThickness;
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
    // Determine G-code operation type
    final isRapid = segment.type == GCodeSegmentType.rapidMove;
    final isCutting = segment.type == GCodeSegmentType.line && !isRapid;
    
    return SceneObject(
      type: SceneObjectType.line,
      color: segment.color,
      id: segment.id,
      // Use startPoint/endPoint for proper line segment rendering
      startPoint: segment.start,
      endPoint: segment.end,
      thickness: segment.thickness, // Pass through thickness from segment
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
      // Create new object with state information, preserving startPoint/endPoint
      lineObjects[i] = SceneObject(
        type: obj.type,
        color: obj.color,
        id: obj.id,
        startPoint: obj.startPoint,
        endPoint: obj.endPoint,
        thickness: arcSegment.thickness, // Preserve thickness from original arc
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
      
      // Use startPoint/endPoint directly
      lineObjects.add(SceneObject(
        type: SceneObjectType.line,
        color: arcSegment.color,
        id: '${arcSegment.id}_arc_$i',
        startPoint: startPoint,
        endPoint: endPoint,
      ));
    }
    
    return lineObjects;
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