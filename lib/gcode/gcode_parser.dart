import 'dart:io';
import '../utils/logger.dart';
import 'dart:math';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:flutter/services.dart';
import '../models/bounding_box.dart';

enum GCodeCommandType { 
  rapidMove,    // G0
  linearMove,   // G1
  clockwiseArc, // G2
  counterClockwiseArc // G3
}

class GCodeCommand {
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
  String toString() => 
    'GCodeCommand(${type.name}, pos: $position, line: $lineNumber)';
}

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

class GCodeParser {
  vm.Vector3 _currentPosition = vm.Vector3.zero();
  double _currentFeedRate = 0.0;
  
  /// Parse G-code file from assets and return path data
  Future<GCodePath> parseAsset(String assetPath) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      return parseString(content);
    } catch (e) {
      throw Exception('Failed to load G-code asset $assetPath: $e');
    }
  }

  /// Parse G-code file and return path data
  Future<GCodePath> parseFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('G-code file not found: $filePath');
    }
    
    final lines = await file.readAsLines();
    return _parseLines(lines);
  }
  
  /// Parse G-code from string content
  GCodePath parseString(String content) {
    final lines = content.split('\n');
    return _parseLines(lines);
  }
  
  GCodePath _parseLines(List<String> lines) {
    final commands = <GCodeCommand>[];
    vm.Vector3 minBounds = vm.Vector3.zero();
    vm.Vector3 maxBounds = vm.Vector3.zero();
    bool boundsInitialized = false;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // Skip comments and empty lines
      if (line.isEmpty || line.startsWith(';') || line.startsWith('(')) {
        continue;
      }
      
      final command = _parseLine(line, i + 1);
      if (command != null) {
        commands.add(command);
        
        // Update bounds
        if (!boundsInitialized) {
          minBounds = vm.Vector3.copy(command.position);
          maxBounds = vm.Vector3.copy(command.position);
          boundsInitialized = true;
        } else {
          minBounds = vm.Vector3(
            min(minBounds.x, command.position.x),
            min(minBounds.y, command.position.y),
            min(minBounds.z, command.position.z),
          );
          maxBounds = vm.Vector3(
            max(maxBounds.x, command.position.x),
            max(maxBounds.y, command.position.y),
            max(maxBounds.z, command.position.z),
          );
        }
      }
    }
    
    AppLogger.info('G-code parsing results:');
    AppLogger.info('Total commands: ${commands.length}');
    AppLogger.info('Bounds: $minBounds to $maxBounds');
    AppLogger.info('Size: ${maxBounds - minBounds}');
    // Logging complete
    
    return GCodePath.fromBounds(
      commands: commands,
      minBounds: minBounds,
      maxBounds: maxBounds,
      totalOperations: commands.length,
    );
  }
  
  GCodeCommand? _parseLine(String line, int lineNumber) {
    // Parse G-code line
    final parts = line.toUpperCase().split(' ');
    if (parts.isEmpty) return null;
    
    GCodeCommandType? commandType;
    vm.Vector3? newPosition;
    vm.Vector3? center;
    double? radius;
    double? feedRate;
    
    // Parse each part of the line
    for (final part in parts) {
      if (part.startsWith('G')) {
        final code = part.substring(1);
        switch (code) {
          case '0':
          case '00':
            commandType = GCodeCommandType.rapidMove;
            break;
          case '1':
          case '01':
            commandType = GCodeCommandType.linearMove;
            break;
          case '2':
          case '02':
            commandType = GCodeCommandType.clockwiseArc;
            break;
          case '3':
          case '03':
            commandType = GCodeCommandType.counterClockwiseArc;
            break;
          default:
            // Other G codes we don't handle for movement
            break;
        }
      } else if (part.startsWith('X')) {
        final x = double.tryParse(part.substring(1));
        if (x != null) {
          newPosition = vm.Vector3(x, newPosition?.y ?? _currentPosition.y, newPosition?.z ?? _currentPosition.z);
        }
      } else if (part.startsWith('Y')) {
        final y = double.tryParse(part.substring(1));
        if (y != null) {
          newPosition = vm.Vector3(newPosition?.x ?? _currentPosition.x, y, newPosition?.z ?? _currentPosition.z);
        }
      } else if (part.startsWith('Z')) {
        final z = double.tryParse(part.substring(1));
        if (z != null) {
          newPosition = vm.Vector3(newPosition?.x ?? _currentPosition.x, newPosition?.y ?? _currentPosition.y, z);
        }
      } else if (part.startsWith('I')) {
        final i = double.tryParse(part.substring(1));
        if (i != null) {
          center = vm.Vector3(i, center?.y ?? 0, center?.z ?? 0);
        }
      } else if (part.startsWith('J')) {
        final j = double.tryParse(part.substring(1));
        if (j != null) {
          center = vm.Vector3(center?.x ?? 0, j, center?.z ?? 0);
        }
      } else if (part.startsWith('K')) {
        final k = double.tryParse(part.substring(1));
        if (k != null) {
          center = vm.Vector3(center?.x ?? 0, center?.y ?? 0, k);
        }
      } else if (part.startsWith('R')) {
        radius = double.tryParse(part.substring(1));
      } else if (part.startsWith('F')) {
        feedRate = double.tryParse(part.substring(1));
      }
    }
    
    // Update current state
    if (newPosition != null) {
      _currentPosition = newPosition;
    }
    if (feedRate != null) {
      _currentFeedRate = feedRate;
    }
    
    // Create command if we have a movement type
    if (commandType != null) {
      return GCodeCommand(
        type: commandType,
        position: vm.Vector3.copy(_currentPosition),
        center: center,
        radius: radius,
        feedRate: _currentFeedRate,
        lineNumber: lineNumber,
      );
    }
    
    return null;
  }
}