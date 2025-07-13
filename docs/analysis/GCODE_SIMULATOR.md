# G-Code Interpreter & Simulator Architecture Analysis

**Author**: Product Management & System Architecture Team  
**Date**: 2025-07-13  
**Purpose**: Define comprehensive G-Code interpretation, simulation, and collision detection architecture

## Executive Summary

The G-Code interpreter/simulator is a critical architectural component that bridges the gap between raw G-Code commands and safe machine operation. This system must interpret G-Code semantically (not just syntactically), maintain machine state throughout program execution, model the complete physical machine context, and provide real-time collision detection and visualization. This analysis defines the architecture for a high-performance simulator that meets our <50ms collision detection and 60fps visualization requirements.

## 1. Core Requirements Analysis

### 1.0 Physical Context Understanding

The G-Code simulator operates with an inherently limited understanding of the physical environment, as G-code itself contains no information about the workpiece, fixtures, or machine context. However, we can still perform meaningful safety checks and visualization by maintaining:

**Known Machine Context:**
- Machine axis travel limits (from configuration)
- Spoilboard location and dimensions
- Pre-configured locations:
  - Tool length sensor position
  - Tool change position
  - Probe positions
  - Parking positions
- Work coordinate system origins (G54-G59)

**Approximated Physical Elements:**
- Simple bounding box representation of the workpiece
- Basic geometric primitives for fixtures and clamps
- Simplified tool geometry (length, diameter, holder dimensions)
- Conservative safety envelope around known positions

**Simulation Capabilities Within These Limitations:**
1. Validate motion within machine travel limits
2. Detect obvious collisions with known fixed elements
3. Verify tool changes happen in valid positions
4. Ensure probing operations occur in expected regions
5. Track work coordinate system transformations

**Important Limitations to Document:**
1. Cannot detect collisions with actual workpiece features
2. No understanding of material properties or cutting conditions
3. Limited fixture collision detection (only known fixed positions)
4. Simplified tool geometry may miss some potential collisions

### 1.1 Functional Requirements

**G-Code Interpretation:**
- Parse and validate G-Code syntax according to grblHAL specifications
- Maintain modal state throughout program execution (coordinate systems, tool offsets, feed rates)
- Handle coordinate system transformations (G54-G59, G92 offsets, tool length compensation)
- Support all grblHAL motion commands (G0/G1 linear, G2/G3 arcs, G38 probing)
- Process auxiliary commands (M3/M4/M5 spindle, M7/M8/M9 coolant, M6 tool change)

**Machine State Simulation:**
- Track real-time machine position in multiple coordinate frames
- Simulate feed rate and acceleration effects on actual motion
- Maintain synchronization with physical controller state
- Handle state transitions during manual interventions

**Physical Context Modeling:**
- Track known machine boundaries from configuration
- Maintain pre-configured positions (tool sensor, tool changer, parking)
- Record work coordinate system origins and offsets
- Store simplified geometric representations:
  - Basic workpiece bounding volume
  - Known fixture and clamp positions
  - Tool geometry (length, diameter, holder)
  - Spoilboard dimensions and position

**Collision Detection:**
- Real-time boundary checking during program execution (<50ms latency)
- Pre-execution validation of entire toolpath
- Tool geometry collision detection (not just tool center point)
- Fixture and workpiece collision avoidance
- Clearance zone validation for manual operations

### 1.2 Performance Requirements

- **Real-time Position Updates**: <16ms latency from controller to visualizer
- **Collision Detection**: <50ms for complete toolpath validation
- **Visualization Rendering**: 60fps during all operations
- **Large File Support**: Handle G-Code files up to 500,000 lines
- **Memory Efficiency**: <200MB total memory footprint including visualization
- **Background Processing**: Heavy operations in isolates to maintain UI responsiveness

## 2. Architectural Overview

### 2.1 Component Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    G-Code Simulator System                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   G-Code        │  │   Machine       │  │   Physical      │ │
│  │  Interpreter    │  │    State        │  │    Context      │ │
│  │                 │  │   Simulator     │  │     Model       │ │
│  │ • Modal State   │  │ • Position      │  │ • Boundaries    │ │
│  │ • Command Parse │  │ • Coordinates   │  │ • Fixtures      │ │
│  │ • Validation    │  │ • Tool Offsets  │  │ • Workpiece     │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│           │                     │                     │        │
│           └─────────────────────┼─────────────────────┘        │
│                                 │                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   Toolpath      │  │   Collision     │  │   Visualization │ │
│  │   Generator     │  │   Detector      │  │     Engine      │ │
│  │                 │  │                 │  │                 │ │
│  │ • Arc Expansion │  │ • Boundary Check│  │ • Real-time     │ │
│  │ • Segmentation  │  │ • Spatial Hash  │  │ • 60fps Render  │ │
│  │ • Optimization  │  │ • Tool Geometry │  │ • Adaptive LOD  │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                 │
                    ┌─────────────────────────┐
                    │   Flutter Application   │
                    │                         │
                    │ • BLoC State Management │
                    │ • Real-time UI Updates  │
                    │ • User Interaction      │
                    └─────────────────────────┘
```

### 2.2 Data Flow Architecture

```dart
// High-level data flow
GCode Input → Interpreter → Modal State → Toolpath Generator → Collision Detector → Visualizer
     ↓              ↓           ↓              ↓                   ↓
   Parse        Modal       Position        Segments          Validated      Rendered
  Commands      State       Tracking        Generation        Toolpath       Display
     ↓              ↓           ↓              ↓                   ↓
 Syntax        Coordinate   Real-time       Arc              Collision        60fps
Validation     System      Updates       Expansion           Detection       Updates
```

## 3. Core Components Design

### 3.1 G-Code Interpreter

```dart
/// Immutable modal state tracking all G-Code modal groups
@freezed
class ModalState with _$ModalState {
  const factory ModalState({
    // Motion mode group (G0, G1, G2, G3, G38)
    @Default(MotionMode.rapid) MotionMode motionMode,
    
    // Plane selection group (G17, G18, G19)
    @Default(PlaneSelect.xy) PlaneSelect planeSelect,
    
    // Distance mode group (G90, G91)
    @Default(false) bool incrementalMode,
    
    // Feed rate mode group (G93, G94, G95)
    @Default(FeedMode.unitsPerMinute) FeedMode feedMode,
    
    // Units group (G20, G21)
    @Default(false) bool imperialUnits,
    
    // Coordinate system group (G54-G59)
    @Default(CoordinateSystem.g54) CoordinateSystem coordinateSystem,
    
    // Tool length offset group (G43, G49)
    @Default(ToolOffsetMode.none) ToolOffsetMode toolOffsetMode,
    
    // Spindle state (M3, M4, M5)
    @Default(SpindleState.off) SpindleState spindleState,
    
    // Coolant state (M7, M8, M9)
    @Default(CoolantState.off) CoolantState coolantState,
    
    // Current feed rate and spindle speed
    @Default(0.0) double feedRate,
    @Default(0.0) double spindleSpeed,
    
    // Current tool number
    @Default(0) int currentTool,
    
    // Line number for error reporting
    @Default(0) int lineNumber,
  }) = _ModalState;
  
  factory ModalState.fromJson(Map<String, dynamic> json) =>
      _$ModalStateFromJson(json);
}

/// High-performance G-Code interpreter with strict modal state management
class GCodeInterpreter {
  ModalState _currentState = const ModalState();
  final List<ParsedCommand> _commandHistory = [];
  
  /// Parse a single line of G-Code and return updated modal state
  ParseResult parseCommand(String gcodeLine, {bool validateOnly = false}) {
    try {
      final words = _parseWords(gcodeLine.trim());
      if (words.isEmpty) return ParseResult.empty();
      
      final newState = _applyModalCommands(_currentState, words);
      
      // Validate modal group conflicts (critical for safety)
      final validation = _validateModalGroups(newState, words);
      if (!validation.isValid) {
        return ParseResult.error(validation.errorMessage);
      }
      
      // Generate command for toolpath generation
      final command = _generateCommand(newState, words);
      
      if (!validateOnly) {
        _currentState = newState;
        _commandHistory.add(command);
      }
      
      return ParseResult.success(
        newState: newState,
        command: command,
        endPosition: command.endPosition,
      );
      
    } catch (e) {
      return ParseResult.error('Parse error on line ${_currentState.lineNumber}: $e');
    }
  }
  
  /// Parse complete G-Code program and return toolpath
  Future<ToolpathResult> parseProgram(String gcode) async {
    return await compute(_parseInIsolate, ParseRequest(
      gcode: gcode,
      initialState: _currentState,
    ));
  }
  
  List<Word> _parseWords(String line) {
    // Remove comments and parse G/M/X/Y/Z/F/S etc. words
    final cleanLine = line.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
    if (cleanLine.isEmpty) return [];
    
    final words = <Word>[];
    final regex = RegExp(r'([A-Z])([+-]?\d*\.?\d+)');
    
    for (final match in regex.allMatches(cleanLine)) {
      final letter = match.group(1)!;
      final value = double.parse(match.group(2)!);
      words.add(Word(letter: letter, value: value));
    }
    
    return words;
  }
  
  ModalState _applyModalCommands(ModalState state, List<Word> words) {
    ModalState newState = state;
    
    // Process G-codes first (motion and modal groups)
    for (final word in words.where((w) => w.letter == 'G')) {
      newState = _applyGCode(newState, word.value.toInt());
    }
    
    // Process M-codes (auxiliary functions)
    for (final word in words.where((w) => w.letter == 'M')) {
      newState = _applyMCode(newState, word.value.toInt());
    }
    
    // Process parameter words (F, S, T)
    for (final word in words) {
      switch (word.letter) {
        case 'F':
          newState = newState.copyWith(feedRate: word.value);
          break;
        case 'S':
          newState = newState.copyWith(spindleSpeed: word.value);
          break;
        case 'T':
          newState = newState.copyWith(currentTool: word.value.toInt());
          break;
      }
    }
    
    return newState.copyWith(lineNumber: state.lineNumber + 1);
  }
  
  ValidationResult _validateModalGroups(ModalState state, List<Word> words) {
    // Implement grblHAL's modal group validation logic
    final gCodes = words.where((w) => w.letter == 'G').map((w) => w.value.toInt());
    
    // Check for conflicting G-codes in same modal group
    final motionCodes = gCodes.where((g) => [0, 1, 2, 3, 38].contains(g));
    if (motionCodes.length > 1) {
      return ValidationResult.error('Multiple motion commands in same block');
    }
    
    final planeCodes = gCodes.where((g) => [17, 18, 19].contains(g));
    if (planeCodes.length > 1) {
      return ValidationResult.error('Multiple plane selection commands in same block');
    }
    
    // Additional modal group validations...
    
    return ValidationResult.valid();
  }
  
  ParsedCommand _generateCommand(ModalState state, List<Word> words) {
    final endPosition = _calculateEndPosition(state, words);
    
    switch (state.motionMode) {
      case MotionMode.rapid:
        return RapidMoveCommand(
          endPosition: endPosition,
          modalState: state,
        );
        
      case MotionMode.linear:
        return LinearMoveCommand(
          endPosition: endPosition,
          feedRate: state.feedRate,
          modalState: state,
        );
        
      case MotionMode.clockwiseArc:
      case MotionMode.counterclockwiseArc:
        final center = _parseArcCenter(words, state.planeSelect);
        return ArcMoveCommand(
          endPosition: endPosition,
          centerOffset: center,
          clockwise: state.motionMode == MotionMode.clockwiseArc,
          plane: state.planeSelect,
          feedRate: state.feedRate,
          modalState: state,
        );
        
      case MotionMode.probe:
        return ProbeCommand(
          endPosition: endPosition,
          feedRate: state.feedRate,
          modalState: state,
        );
    }
  }
}
```

### 3.2 Machine State Simulator

```dart
/// Complete machine state simulation with multiple coordinate systems
class MachineStateSimulator {
  // Core position tracking in machine coordinates
  Position _machinePosition = Position.zero();
  Position _workPosition = Position.zero();
  
  // Coordinate system offsets (G54-G59)
  final Map<CoordinateSystem, Position> _workOffsets = {
    CoordinateSystem.g54: Position.zero(),
    CoordinateSystem.g55: Position.zero(),
    CoordinateSystem.g56: Position.zero(),
    CoordinateSystem.g57: Position.zero(),
    CoordinateSystem.g58: Position.zero(),
    CoordinateSystem.g59: Position.zero(),
  };
  
  // Additional offsets
  Position _g92Offset = Position.zero();
  Position _toolLengthOffset = Position.zero();
  
  // Current modal state
  ModalState _currentModalState = const ModalState();
  
  /// Update machine position based on command execution
  void executeCommand(ParsedCommand command) {
    switch (command.runtimeType) {
      case RapidMoveCommand:
      case LinearMoveCommand:
        _executeMoveCommand(command as MoveCommand);
        break;
      case ArcMoveCommand:
        _executeArcCommand(command as ArcMoveCommand);
        break;
      case ProbeCommand:
        _executeProbeCommand(command as ProbeCommand);
        break;
    }
    
    _currentModalState = command.modalState;
  }
  
  void _executeMoveCommand(MoveCommand command) {
    final targetPosition = _transformToMachineCoordinates(
      command.endPosition,
      command.modalState,
    );
    
    _machinePosition = targetPosition;
    _workPosition = command.endPosition;
  }
  
  void _executeArcCommand(ArcMoveCommand command) {
    // Generate arc segments and execute final position
    final segments = _generateArcSegments(command);
    final finalSegment = segments.last;
    
    _machinePosition = _transformToMachineCoordinates(
      finalSegment.endPosition,
      command.modalState,
    );
    _workPosition = finalSegment.endPosition;
  }
  
  /// Transform work coordinates to machine coordinates
  Position _transformToMachineCoordinates(Position workPos, ModalState state) {
    final workOffset = _workOffsets[state.coordinateSystem] ?? Position.zero();
    return workPos + workOffset + _g92Offset + _toolLengthOffset;
  }
  
  /// Get current position in specified coordinate frame
  Position getCurrentPosition(CoordinateFrame frame) {
    switch (frame) {
      case CoordinateFrame.machine:
        return _machinePosition;
      case CoordinateFrame.work:
        return _workPosition;
      case CoordinateFrame.probe:
        return _machinePosition; // TODO: Implement probe coordinate system
    }
  }
  
  /// Set work coordinate system offset (G10 command)
  void setWorkOffset(CoordinateSystem system, Position offset) {
    _workOffsets[system] = offset;
  }
  
  /// Set G92 coordinate system offset
  void setG92Offset(Position offset) {
    _g92Offset = offset;
  }
  
  /// Set tool length offset (G43 command)
  void setToolLengthOffset(Position offset) {
    _toolLengthOffset = offset;
  }
}
```

### 3.3 Physical Context Model

```dart
/// Physical machine context with known fixed positions and simplified geometry
@freezed
class MachineContext with _$MachineContext {
  const factory MachineContext({
    // Machine configuration
    required MachineLimits limits,
    required Map<String, Position> configuredPositions, // Tool sensor, changer, etc.
    
    // Work coordinate systems
    required Map<CoordinateSystem, Position> workOrigins,
    required Position g92Offset,
    
    // Simplified physical elements
    required BoundingBox spoilBoard,
    required List<SimplifiedGeometry> fixtures,
    required List<SimplifiedGeometry> clamps,
    BoundingBox? workpieceBounds,
    
    // Current tool
    Tool? currentTool,
    
    // Protected zones around known positions
    required List<SafetyEnvelope> protectedZones,
  }) = _MachineContext;
  
  factory MachineContext.fromJson(Map<String, dynamic> json) =>
      _$MachineContextFromJson(json);
}

/// Tool geometry for accurate collision detection
@freezed
class Tool with _$Tool {
  const factory Tool({
    required int toolNumber,
    required String description,
    required ToolType type,
    required double diameter,
    required double length,
    required double fluteLength,
    required double cornerRadius,
    
    // Tool geometry for collision detection
    @Default(0.0) double shoulderDiameter,
    @Default(0.0) double shankDiameter,
    @Default(0.0) double overhang,
  }) = _Tool;
  
  /// Calculate tool envelope at given position
  BoundingBox getEnvelopeAt(Position position) {
    final radius = diameter / 2;
    return BoundingBox(
      min: Position(
        x: position.x - radius,
        y: position.y - radius,
        z: position.z - length,
      ),
      max: Position(
        x: position.x + radius,
        y: position.y + radius,
        z: position.z,
      ),
    );
  }
}

/// Workpiece geometry and positioning
@freezed
class Workpiece with _$Workpiece {
  const factory Workpiece({
    required String name,
    required BoundingBox dimensions,
    required Position position,
    required Material material,
    
    // Coordinate system this workpiece is referenced to
    @Default(CoordinateSystem.g54) CoordinateSystem coordinateSystem,
  }) = _Workpiece;
  
  /// Get workpiece bounds in machine coordinates
  BoundingBox getMachineBounds(Map<CoordinateSystem, Position> workOffsets) {
    final workOffset = workOffsets[coordinateSystem] ?? Position.zero();
    final machinePosition = position + workOffset;
    
    return BoundingBox(
      min: machinePosition + dimensions.min,
      max: machinePosition + dimensions.max,
    );
  }
}

/// Safety zone definition for collision avoidance
@freezed
class SafetyZone with _$SafetyZone {
  const factory SafetyZone({
    required String name,
    required BoundingBox bounds,
    required SafetyZoneType type,
    @Default(true) bool enabled,
  }) = _SafetyZone;
}

enum SafetyZoneType {
  noGo,           // Absolute no-go zone
  slowDown,       // Reduce feed rate zone
  toolChangeOnly, // Only accessible during tool changes
  probeOnly,      // Only accessible during probing
}

/// Machine travel and capability limits from configuration
@freezed
class MachineLimits with _$MachineLimits {
  const factory MachineLimits({
    // Axis travel limits
    required Position minTravel,
    required Position maxTravel,
    
    // Maximum rates
    required Position maxVelocity,
    required Position maxAcceleration,
    
    // Tool constraints
    required double maxToolLength,
    required double maxToolDiameter,
    
    // Special positions that must remain accessible
    required List<Position> requiredAccessPoints,
  }) = _MachineLimits;
}

/// Simplified geometric primitive for collision detection
@freezed
class SimplifiedGeometry with _$SimplifiedGeometry {
  const factory SimplifiedGeometry({
    required String id,
    required String name,
    required GeometryType type,
    required Position position,
    required Map<String, double> dimensions,
    String? description,
  }) = _SimplifiedGeometry;
}

enum GeometryType {
  box,           // Simple bounding box
  cylinder,      // Height and diameter
  sphere,        // Radius only
  safetyEnvelope // Padded boundary around position
}
```

### 3.4 Collision Detection Engine

```dart
/// High-performance collision detection with spatial optimization
class CollisionDetector {
  final MachineContext _context;
  final SpatialHash _spatialHash;
  
  // Collision detection cache for performance
  final Map<String, CollisionResult> _resultCache = {};
  
  CollisionDetector(this._context) 
    : _spatialHash = SpatialHash(cellSize: 10.0) {
    _buildSpatialHash();
  }
  
  /// Check complete toolpath for collisions (pre-execution validation)
  Future<CollisionResult> validateToolpath(ToolPath toolpath) async {
    return await compute(_validateInIsolate, ValidationRequest(
      toolpath: toolpath,
      context: _context,
    ));
  }
  
  /// Real-time collision check for current segment (<50ms requirement)
  CollisionResult checkSegment(PathSegment segment) {
    final cacheKey = _generateCacheKey(segment);
    if (_resultCache.containsKey(cacheKey)) {
      return _resultCache[cacheKey]!;
    }
    
    final result = _performCollisionCheck(segment);
    _resultCache[cacheKey] = result;
    
    // Limit cache size for memory management
    if (_resultCache.length > 1000) {
      _resultCache.clear();
    }
    
    return result;
  }
  
  CollisionResult _performCollisionCheck(PathSegment segment) {
    final tool = _context.currentTool;
    if (tool == null) {
      return CollisionResult.error('No tool defined');
    }
    
    // Check machine envelope bounds
    final toolEnvelope = tool.getEnvelopeAt(segment.endPosition);
    if (!_context.machineEnvelope.contains(toolEnvelope)) {
      return CollisionResult.collision(
        type: CollisionType.machineEnvelope,
        segment: segment,
        details: 'Tool exceeds machine envelope',
      );
    }
    
    // Check workpiece collision
    if (_context.workpiece != null) {
      final workpieceBounds = _context.workpiece!.getMachineBounds(_getWorkOffsets());
      if (toolEnvelope.intersects(workpieceBounds)) {
        // This might be intentional cutting - additional logic needed
        if (!_isIntentionalCutting(segment, workpieceBounds)) {
          return CollisionResult.collision(
            type: CollisionType.workpiece,
            segment: segment,
            details: 'Unintentional workpiece collision',
          );
        }
      }
    }
    
    // Check fixtures and clamps using spatial hash
    final potentialCollisions = _spatialHash.query(toolEnvelope);
    for (final obstacle in potentialCollisions) {
      if (toolEnvelope.intersects(obstacle.bounds)) {
        return CollisionResult.collision(
          type: CollisionType.fixture,
          segment: segment,
          details: 'Collision with ${obstacle.name}',
        );
      }
    }
    
    // Check safety zones
    for (final zone in _context.safetyZones.where((z) => z.enabled)) {
      if (toolEnvelope.intersects(zone.bounds)) {
        switch (zone.type) {
          case SafetyZoneType.noGo:
            return CollisionResult.collision(
              type: CollisionType.safetyZone,
              segment: segment,
              details: 'Entry into no-go zone: ${zone.name}',
            );
          case SafetyZoneType.slowDown:
            return CollisionResult.warning(
              type: CollisionType.safetyZone,
              segment: segment,
              details: 'Slow down zone: ${zone.name}',
            );
          case SafetyZoneType.toolChangeOnly:
          case SafetyZoneType.probeOnly:
            // Check if current operation is allowed
            if (!_isOperationAllowedInZone(segment, zone)) {
              return CollisionResult.collision(
                type: CollisionType.safetyZone,
                segment: segment,
                details: 'Unauthorized operation in ${zone.name}',
              );
            }
            break;
        }
      }
    }
    
    return CollisionResult.clear();
  }
  
  void _buildSpatialHash() {
    _spatialHash.clear();
    
    // Add all fixtures to spatial hash
    for (final fixture in _context.fixtures) {
      _spatialHash.insert(SpatialObject(
        id: 'fixture_${fixture.id}',
        bounds: fixture.bounds,
        name: fixture.name,
      ));
    }
    
    // Add all clamps to spatial hash
    for (final clamp in _context.clamps) {
      _spatialHash.insert(SpatialObject(
        id: 'clamp_${clamp.id}',
        bounds: clamp.bounds,
        name: clamp.name,
      ));
    }
  }
  
  bool _isIntentionalCutting(PathSegment segment, BoundingBox workpieceBounds) {
    // Implement logic to determine if tool contact with workpiece is intentional
    // This could be based on feed rate, tool type, cutting direction, etc.
    return segment.feedRate > 0 && segment.feedRate < 2000; // Example logic
  }
  
  Map<CoordinateSystem, Position> _getWorkOffsets() {
    // Get current work offsets from machine state
    // This would be provided by the MachineStateSimulator
    return {};
  }
}

/// Collision detection result with detailed information
@freezed
class CollisionResult with _$CollisionResult {
  const factory CollisionResult({
    required CollisionType type,
    required bool hasCollision,
    required bool isWarning,
    PathSegment? segment,
    String? details,
    List<String>? suggestions,
  }) = _CollisionResult;
  
  factory CollisionResult.clear() => const CollisionResult(
    type: CollisionType.none,
    hasCollision: false,
    isWarning: false,
  );
  
  factory CollisionResult.collision({
    required CollisionType type,
    required PathSegment segment,
    required String details,
    List<String>? suggestions,
  }) => CollisionResult(
    type: type,
    hasCollision: true,
    isWarning: false,
    segment: segment,
    details: details,
    suggestions: suggestions,
  );
  
  factory CollisionResult.warning({
    required CollisionType type,
    required PathSegment segment,
    required String details,
    List<String>? suggestions,
  }) => CollisionResult(
    type: type,
    hasCollision: false,
    isWarning: true,
    segment: segment,
    details: details,
    suggestions: suggestions,
  );
  
  factory CollisionResult.error(String details) => CollisionResult(
    type: CollisionType.error,
    hasCollision: true,
    isWarning: false,
    details: details,
  );
}

enum CollisionType {
  none,
  machineEnvelope,
  workpiece,
  fixture,
  clamp,
  safetyZone,
  spoilBoard,
  error,
}
```

### 3.5 Toolpath Generator

```dart
/// High-performance toolpath generation with arc expansion and optimization
class ToolpathGenerator {
  final MachineStateSimulator _simulator;
  static const double _defaultTolerance = 0.01; // mm
  
  ToolpathGenerator(this._simulator);
  
  /// Generate complete toolpath from parsed commands
  Future<ToolPath> generateToolpath(List<ParsedCommand> commands) async {
    return await compute(_generateInIsolate, GenerationRequest(
      commands: commands,
      tolerance: _defaultTolerance,
    ));
  }
  
  /// Generate segments for a single command (real-time use)
  List<PathSegment> generateSegments(ParsedCommand command) {
    switch (command.runtimeType) {
      case RapidMoveCommand:
      case LinearMoveCommand:
        return [_generateLinearSegment(command as MoveCommand)];
        
      case ArcMoveCommand:
        return _generateArcSegments(command as ArcMoveCommand);
        
      case ProbeCommand:
        return [_generateProbeSegment(command as ProbeCommand)];
        
      default:
        return [];
    }
  }
  
  PathSegment _generateLinearSegment(MoveCommand command) {
    final startPos = _simulator.getCurrentPosition(CoordinateFrame.work);
    
    return PathSegment(
      type: command is RapidMoveCommand ? SegmentType.rapid : SegmentType.linear,
      startPosition: startPos,
      endPosition: command.endPosition,
      feedRate: command is LinearMoveCommand ? command.feedRate : 0,
      modalState: command.modalState,
    );
  }
  
  List<PathSegment> _generateArcSegments(ArcMoveCommand command) {
    final startPos = _simulator.getCurrentPosition(CoordinateFrame.work);
    
    // Calculate arc parameters
    final arcInfo = _calculateArcParameters(
      start: startPos,
      end: command.endPosition,
      centerOffset: command.centerOffset,
      plane: command.plane,
      clockwise: command.clockwise,
    );
    
    // Determine optimal segmentation based on arc size and tolerance
    final segmentCount = _calculateOptimalSegmentCount(
      radius: arcInfo.radius,
      totalAngle: arcInfo.totalAngle,
      tolerance: _defaultTolerance,
    );
    
    // Generate arc segments
    final segments = <PathSegment>[];
    final angleStep = arcInfo.totalAngle / segmentCount;
    
    Position currentPos = startPos;
    for (int i = 1; i <= segmentCount; i++) {
      final angle = arcInfo.startAngle + (angleStep * i);
      final nextPos = _calculateArcPoint(
        center: arcInfo.center,
        radius: arcInfo.radius,
        angle: angle,
        plane: command.plane,
      );
      
      segments.add(PathSegment(
        type: SegmentType.arc,
        startPosition: currentPos,
        endPosition: nextPos,
        feedRate: command.feedRate,
        modalState: command.modalState,
        arcInfo: ArcInfo(
          center: arcInfo.center,
          radius: arcInfo.radius,
          clockwise: command.clockwise,
        ),
      ));
      
      currentPos = nextPos;
    }
    
    return segments;
  }
  
  int _calculateOptimalSegmentCount(double radius, double totalAngle, double tolerance) {
    // Calculate chord error and determine segment count for given tolerance
    final chordError = radius * (1 - cos(totalAngle / 2));
    final minSegments = max(4, (chordError / tolerance).ceil());
    
    // Limit maximum segments for performance
    return min(minSegments, 100);
  }
  
  ArcParameters _calculateArcParameters({
    required Position start,
    required Position end,
    required Position centerOffset,
    required PlaneSelect plane,
    required bool clockwise,
  }) {
    // Calculate center point based on plane selection
    final center = start + centerOffset;
    
    // Calculate radius (should be same for start and end points)
    final radius = (start - center).length;
    
    // Calculate start and end angles
    final startAngle = _calculateAngle(start - center, plane);
    final endAngle = _calculateAngle(end - center, plane);
    
    // Calculate total angle considering direction
    double totalAngle;
    if (clockwise) {
      totalAngle = startAngle >= endAngle 
          ? startAngle - endAngle 
          : startAngle + (2 * pi) - endAngle;
    } else {
      totalAngle = endAngle >= startAngle 
          ? endAngle - startAngle 
          : endAngle + (2 * pi) - startAngle;
    }
    
    return ArcParameters(
      center: center,
      radius: radius,
      startAngle: startAngle,
      endAngle: endAngle,
      totalAngle: totalAngle,
    );
  }
  
  double _calculateAngle(Position vector, PlaneSelect plane) {
    switch (plane) {
      case PlaneSelect.xy:
        return atan2(vector.y, vector.x);
      case PlaneSelect.xz:
        return atan2(vector.z, vector.x);
      case PlaneSelect.yz:
        return atan2(vector.z, vector.y);
    }
  }
  
  Position _calculateArcPoint({
    required Position center,
    required double radius,
    required double angle,
    required PlaneSelect plane,
  }) {
    final x = cos(angle) * radius;
    final y = sin(angle) * radius;
    
    switch (plane) {
      case PlaneSelect.xy:
        return Position(x: center.x + x, y: center.y + y, z: center.z);
      case PlaneSelect.xz:
        return Position(x: center.x + x, y: center.y, z: center.z + y);
      case PlaneSelect.yz:
        return Position(x: center.x, y: center.y + x, z: center.z + y);
    }
  }
}

/// Complete toolpath representation with optimization
@freezed
class ToolPath with _$ToolPath {
  const factory ToolPath({
    required List<PathSegment> segments,
    required BoundingBox bounds,
    required ToolPathStats stats,
    required Map<CoordinateSystem, Position> workOffsets,
  }) = _ToolPath;
  
  /// Get segments within a specific region (for viewport culling)
  List<PathSegment> getSegmentsInRegion(BoundingBox region) {
    return segments.where((segment) {
      final segmentBounds = BoundingBox.fromSegment(segment);
      return region.intersects(segmentBounds);
    }).toList();
  }
  
  /// Get segments up to a specific command index (for progress visualization)
  List<PathSegment> getSegmentsUpTo(int commandIndex) {
    return segments.take(commandIndex).toList();
  }
}

@freezed
class ToolPathStats with _$ToolPathStats {
  const factory ToolPathStats({
    required int totalSegments,
    required int rapidMoves,
    required int linearMoves,
    required int arcMoves,
    required double totalDistance,
    required double cuttingDistance,
    required Duration estimatedTime,
  }) = _ToolPathStats;
}
```

## 4. Integration with Visualization System

### 4.1 Real-Time Visualization Updates

```dart
/// Optimized visualizer integration with collision detection
class VisualizerEngine {
  final ToolpathGenerator _generator;
  final CollisionDetector _collisionDetector;
  final StreamController<VisualizationUpdate> _updateController;
  
  late Timer _renderTimer;
  ToolPath? _currentToolpath;
  int _currentSegmentIndex = 0;
  
  VisualizerEngine(this._generator, this._collisionDetector)
    : _updateController = StreamController<VisualizationUpdate>.broadcast() {
    
    // 60fps render loop
    _renderTimer = Timer.periodic(Duration(milliseconds: 16), (_) {
      _updateVisualization();
    });
  }
  
  Stream<VisualizationUpdate> get updates => _updateController.stream;
  
  void setToolpath(ToolPath toolpath) {
    _currentToolpath = toolpath;
    _currentSegmentIndex = 0;
    
    // Emit full toolpath update
    _updateController.add(VisualizationUpdate.toolpathChanged(toolpath));
  }
  
  void updateProgress(int segmentIndex) {
    if (_currentToolpath == null) return;
    
    _currentSegmentIndex = segmentIndex;
    
    // Real-time collision check for current segment
    if (segmentIndex < _currentToolpath!.segments.length) {
      final currentSegment = _currentToolpath!.segments[segmentIndex];
      final collisionResult = _collisionDetector.checkSegment(currentSegment);
      
      if (collisionResult.hasCollision) {
        _updateController.add(VisualizationUpdate.collisionDetected(collisionResult));
      }
    }
    
    // Emit progress update
    _updateController.add(VisualizationUpdate.progressChanged(
      segmentIndex: segmentIndex,
      totalSegments: _currentToolpath!.segments.length,
    ));
  }
  
  void _updateVisualization() {
    if (_currentToolpath == null) return;
    
    // Emit regular visualization update for smooth animation
    _updateController.add(VisualizationUpdate.frameUpdate(
      timestamp: DateTime.now(),
      currentSegment: _currentSegmentIndex,
    ));
  }
}

@freezed
class VisualizationUpdate with _$VisualizationUpdate {
  const factory VisualizationUpdate.toolpathChanged(ToolPath toolpath) = ToolpathChanged;
  const factory VisualizationUpdate.progressChanged({
    required int segmentIndex,
    required int totalSegments,
  }) = ProgressChanged;
  const factory VisualizationUpdate.collisionDetected(CollisionResult collision) = CollisionDetected;
  const factory VisualizationUpdate.frameUpdate({
    required DateTime timestamp,
    required int currentSegment,
  }) = FrameUpdate;
}
```

## 5. Performance Optimization Strategies

### 5.1 Memory Management for Large Files

```dart
/// Streaming processor for large G-Code files
class StreamingGCodeProcessor {
  static const int _chunkSize = 10000; // Lines per chunk
  static const int _maxMemorySegments = 100000; // Segments in memory
  
  /// Process large G-Code file in chunks to manage memory
  Stream<ToolpathChunk> processLargeFile(String gcode) async* {
    final lines = gcode.split('\n');
    final chunks = _chunkLines(lines, _chunkSize);
    
    for (final chunk in chunks) {
      final result = await compute(_processChunk, ProcessingRequest(
        lines: chunk,
        startLineNumber: chunks.indexOf(chunk) * _chunkSize,
      ));
      
      yield ToolpathChunk(
        segments: result.segments,
        bounds: result.bounds,
        lineRange: result.lineRange,
      );
      
      // Allow UI updates between chunks
      await Future.delayed(Duration(milliseconds: 1));
    }
  }
  
  static List<List<String>> _chunkLines(List<String> lines, int chunkSize) {
    final chunks = <List<String>>[];
    for (int i = 0; i < lines.length; i += chunkSize) {
      final end = min(i + chunkSize, lines.length);
      chunks.add(lines.sublist(i, end));
    }
    return chunks;
  }
}

/// Level-of-detail management for visualization performance
class LODManager {
  static const double _detailThreshold = 0.1; // mm
  static const int _maxVisibleSegments = 50000;
  
  /// Simplify toolpath based on current zoom level and viewport
  ToolPath simplifyForVisualization(
    ToolPath originalPath,
    BoundingBox viewport,
    double scaleFactor,
  ) {
    final visibleSegments = originalPath.getSegmentsInRegion(viewport);
    
    if (visibleSegments.length <= _maxVisibleSegments) {
      return ToolPath(
        segments: visibleSegments,
        bounds: originalPath.bounds,
        stats: originalPath.stats,
        workOffsets: originalPath.workOffsets,
      );
    }
    
    // Apply level-of-detail simplification
    final tolerance = _detailThreshold / scaleFactor;
    final simplifiedSegments = _simplifySegments(visibleSegments, tolerance);
    
    return ToolPath(
      segments: simplifiedSegments,
      bounds: originalPath.bounds,
      stats: _recalculateStats(simplifiedSegments),
      workOffsets: originalPath.workOffsets,
    );
  }
  
  List<PathSegment> _simplifySegments(List<PathSegment> segments, double tolerance) {
    // Implement Douglas-Peucker algorithm or similar for line simplification
    // This is a simplified version - actual implementation would be more sophisticated
    final simplified = <PathSegment>[];
    
    for (int i = 0; i < segments.length; i += 2) {
      simplified.add(segments[i]);
    }
    
    return simplified;
  }
}
```

### 5.2 Spatial Optimization for Collision Detection

```dart
/// Spatial hash for O(1) collision queries
class SpatialHash {
  final double cellSize;
  final Map<String, List<SpatialObject>> _cells = {};
  
  SpatialHash({required this.cellSize});
  
  void insert(SpatialObject object) {
    final cells = _getCellsForBounds(object.bounds);
    for (final cellKey in cells) {
      _cells.putIfAbsent(cellKey, () => []).add(object);
    }
  }
  
  List<SpatialObject> query(BoundingBox bounds) {
    final result = <SpatialObject>{};
    final cells = _getCellsForBounds(bounds);
    
    for (final cellKey in cells) {
      final cellObjects = _cells[cellKey];
      if (cellObjects != null) {
        result.addAll(cellObjects);
      }
    }
    
    return result.toList();
  }
  
  void clear() {
    _cells.clear();
  }
  
  List<String> _getCellsForBounds(BoundingBox bounds) {
    final cells = <String>[];
    
    final minCellX = (bounds.min.x / cellSize).floor();
    final maxCellX = (bounds.max.x / cellSize).floor();
    final minCellY = (bounds.min.y / cellSize).floor();
    final maxCellY = (bounds.max.y / cellSize).floor();
    
    for (int x = minCellX; x <= maxCellX; x++) {
      for (int y = minCellY; y <= maxCellY; y++) {
        cells.add('${x}_${y}');
      }
    }
    
    return cells;
  }
}

@freezed
class SpatialObject with _$SpatialObject {
  const factory SpatialObject({
    required String id,
    required BoundingBox bounds,
    required String name,
  }) = _SpatialObject;
}
```

## 6. Integration Points with Architecture

### 6.1 BLoC Integration

```dart
/// G-Code processing state management
abstract class GCodeEvent {}

class ParseGCodeEvent extends GCodeEvent {
  final String gcode;
  final MachineContext context;
  ParseGCodeEvent(this.gcode, this.context);
}

class ValidateToolpathEvent extends GCodeEvent {
  final ToolPath toolpath;
  ValidateToolpathEvent(this.toolpath);
}

abstract class GCodeState {}

class GCodeBloc extends Bloc<GCodeEvent, GCodeState> {
  final GCodeInterpreter _interpreter;
  final ToolpathGenerator _generator;
  final CollisionDetector _collisionDetector;
  final VisualizerEngine _visualizer;
  
  GCodeBloc(
    this._interpreter,
    this._generator,
    this._collisionDetector,
    this._visualizer,
  ) : super(GCodeInitial()) {
    
    on<ParseGCodeEvent>((event, emit) async {
      emit(GCodeProcessing());
      
      try {
        // Parse G-Code in background isolate
        final parseResult = await _interpreter.parseProgram(event.gcode);
        
        if (!parseResult.isSuccess) {
          emit(GCodeError(parseResult.errorMessage));
          return;
        }
        
        // Generate toolpath
        final toolpath = await _generator.generateToolpath(parseResult.commands);
        
        // Update visualizer
        _visualizer.setToolpath(toolpath);
        
        emit(GCodeParsed(
          toolpath: toolpath,
          commands: parseResult.commands,
        ));
        
        // Trigger collision validation
        add(ValidateToolpathEvent(toolpath));
        
      } catch (e) {
        emit(GCodeError('Failed to process G-Code: $e'));
      }
    });
    
    on<ValidateToolpathEvent>((event, emit) async {
      emit(GCodeValidating());
      
      try {
        final collisionResult = await _collisionDetector.validateToolpath(event.toolpath);
        
        if (collisionResult.hasCollision) {
          emit(GCodeValidationFailed(collisionResult));
        } else {
          emit(GCodeValidationPassed(event.toolpath));
        }
      } catch (e) {
        emit(GCodeError('Validation failed: $e'));
      }
    });
  }
}
```

### 6.2 Service Layer Integration

```dart
/// Complete G-Code simulation service
class GCodeSimulationService {
  final GCodeInterpreter _interpreter;
  final MachineStateSimulator _stateSimulator;
  final ToolpathGenerator _toolpathGenerator;
  final CollisionDetector _collisionDetector;
  final VisualizerEngine _visualizerEngine;
  
  // Real-time streams
  late StreamSubscription _machinePositionSubscription;
  late StreamSubscription _visualizationSubscription;
  
  GCodeSimulationService({
    required CncService cncService,
    required MachineContext machineContext,
  }) : _interpreter = GCodeInterpreter(),
       _stateSimulator = MachineStateSimulator(),
       _toolpathGenerator = ToolpathGenerator(MachineStateSimulator()),
       _collisionDetector = CollisionDetector(machineContext),
       _visualizerEngine = VisualizerEngine(
         ToolpathGenerator(MachineStateSimulator()),
         CollisionDetector(machineContext),
       ) {
    
    // Subscribe to real-time machine position updates
    _machinePositionSubscription = cncService.positionStream.listen((position) {
      // Update simulator with real machine position
      _stateSimulator.updateMachinePosition(position);
      
      // Update visualization progress
      final currentSegment = _calculateCurrentSegment(position);
      _visualizerEngine.updateProgress(currentSegment);
    });
    
    // Subscribe to visualization updates
    _visualizationSubscription = _visualizerEngine.updates.listen((update) {
      // Handle collision detection and other visualization events
      update.when(
        toolpathChanged: (toolpath) => _handleToolpathChanged(toolpath),
        progressChanged: (index, total) => _handleProgressChanged(index, total),
        collisionDetected: (collision) => _handleCollisionDetected(collision),
        frameUpdate: (timestamp, segment) => _handleFrameUpdate(timestamp, segment),
      );
    });
  }
  
  /// Process G-Code and return complete simulation result
  Future<SimulationResult> processGCode(String gcode, MachineContext context) async {
    try {
      // Parse G-Code
      final parseResult = await _interpreter.parseProgram(gcode);
      if (!parseResult.isSuccess) {
        return SimulationResult.error(parseResult.errorMessage);
      }
      
      // Generate toolpath
      final toolpath = await _toolpathGenerator.generateToolpath(parseResult.commands);
      
      // Validate for collisions
      final collisionResult = await _collisionDetector.validateToolpath(toolpath);
      
      // Update visualizer
      _visualizerEngine.setToolpath(toolpath);
      
      return SimulationResult.success(
        toolpath: toolpath,
        commands: parseResult.commands,
        collisionResult: collisionResult,
      );
      
    } catch (e) {
      return SimulationResult.error('Simulation failed: $e');
    }
  }
  
  /// Real-time collision monitoring during execution
  void startRealTimeMonitoring() {
    // Enable real-time collision detection during job execution
    _collisionDetector.enableRealTimeMonitoring();
  }
  
  void stopRealTimeMonitoring() {
    _collisionDetector.disableRealTimeMonitoring();
  }
  
  void dispose() {
    _machinePositionSubscription.cancel();
    _visualizationSubscription.cancel();
    _visualizerEngine.dispose();
  }
  
  int _calculateCurrentSegment(Position currentPosition) {
    // Calculate which toolpath segment the machine is currently executing
    // This requires matching machine position to toolpath segments
    return 0; // Simplified implementation
  }
  
  void _handleCollisionDetected(CollisionResult collision) {
    // Implement emergency stop or collision response
    print('COLLISION DETECTED: ${collision.details}');
  }
}

@freezed
class SimulationResult with _$SimulationResult {
  const factory SimulationResult.success({
    required ToolPath toolpath,
    required List<ParsedCommand> commands,
    required CollisionResult collisionResult,
  }) = SimulationSuccess;
  
  const factory SimulationResult.error(String message) = SimulationError;
}
```

## 7. Testing Strategy

### 7.1 Unit Testing

```dart
/// Comprehensive testing for G-Code interpreter
class GCodeInterpreterTest {
  group('G-Code Interpreter Tests', () {
    late GCodeInterpreter interpreter;
    
    setUp(() {
      interpreter = GCodeInterpreter();
    });
    
    test('should parse basic linear move', () {
      final result = interpreter.parseCommand('G1 X10 Y20 F1000');
      
      expect(result.isSuccess, isTrue);
      expect(result.command.endPosition.x, equals(10.0));
      expect(result.command.endPosition.y, equals(20.0));
      expect(result.newState.feedRate, equals(1000.0));
    });
    
    test('should detect modal group conflicts', () {
      final result = interpreter.parseCommand('G0 G1 X10 Y20');
      
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Multiple motion commands'));
    });
    
    test('should handle coordinate system changes', () {
      interpreter.parseCommand('G55');
      final result = interpreter.parseCommand('G1 X10 Y20');
      
      expect(result.newState.coordinateSystem, equals(CoordinateSystem.g55));
    });
  });
}

/// Performance testing for collision detection
class CollisionDetectionPerformanceTest {
  test('collision detection should complete within 50ms', () async {
    final detector = CollisionDetector(testMachineContext);
    final toolpath = generateLargeTestToolpath(segments: 10000);
    
    final stopwatch = Stopwatch()..start();
    final result = await detector.validateToolpath(toolpath);
    stopwatch.stop();
    
    expect(stopwatch.elapsedMilliseconds, lessThan(50));
    expect(result, isNotNull);
  });
}
```

## 8. Documentation and Maintenance

### 8.1 API Documentation

All public interfaces include comprehensive documentation:

```dart
/// Interprets G-Code commands and maintains modal state.
/// 
/// This class provides the core G-Code interpretation functionality required
/// for both pre-execution validation and real-time simulation. It strictly
/// follows grblHAL modal group rules to ensure compatibility.
/// 
/// Example usage:
/// ```dart
/// final interpreter = GCodeInterpreter();
/// final result = interpreter.parseCommand('G1 X10 Y20 F1000');
/// 
/// if (result.isSuccess) {
///   print('Move to: ${result.command.endPosition}');
/// } else {
///   print('Parse error: ${result.errorMessage}');
/// }
/// ```
/// 
/// Performance characteristics:
/// - Single command parsing: <1ms
/// - Complete program parsing: Handled in background isolate
/// - Memory usage: O(n) where n is number of commands
class GCodeInterpreter {
  // Implementation...
}
```

This comprehensive G-Code interpreter and simulator architecture provides the foundation for safe, reliable CNC operation with real-time collision detection and high-performance visualization. The design prioritizes safety through comprehensive validation while maintaining the performance requirements for real-time operation.