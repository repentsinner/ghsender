import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../gcode/gcode_parser.dart';
import '../gcode/gcode_scene.dart';
import '../gcode/gcode_processor.dart';

/// Centralized scene manager that creates and manages the 3D scene
/// All renderers receive the same scene data from this manager
class SceneManager {
  static SceneManager? _instance;
  static SceneManager get instance => _instance ??= SceneManager._();

  SceneManager._() {
    // Listen to G-code processor events for automatic scene updates
    _processorSubscription = GCodeProcessor.instance.events.listen(_onGCodeProcessingEvent);
  }

  // Scene data - created dynamically based on selected G-code file
  SceneData? _sceneData;
  bool _initialized = false;
  StreamSubscription<GCodeProcessingEvent>? _processorSubscription;

  // Stream controller for scene updates
  final StreamController<SceneData?> _sceneUpdateController = 
      StreamController<SceneData?>.broadcast();

  bool get initialized => _initialized;
  SceneData? get sceneData => _sceneData;
  Stream<SceneData?> get sceneUpdates => _sceneUpdateController.stream;

  /// Initialize the scene manager (sets up processor listening)
  Future<void> initialize() async {
    if (_initialized) return;

    AppLogger.info('Initializing scene manager');
    _initialized = true;

    // Check if processor already has a file to load
    if (GCodeProcessor.instance.hasValidFile) {
      await _buildSceneFromProcessor();
    } else {
      AppLogger.info('Scene manager initialized - waiting for G-code file selection');
      // Initialize with empty scene (just world axes)
      await _initializeEmptyScene();
    }
  }

  /// Handle G-code processor events
  void _onGCodeProcessingEvent(GCodeProcessingEvent event) {
    switch (event) {
      case GCodeProcessingCompleted completedEvent:
        AppLogger.info('G-code processing completed, updating scene');
        _buildSceneFromParsedData(completedEvent.parsedData);
        break;
      case GCodeProcessingCleared _:
        AppLogger.info('G-code file cleared, resetting to empty scene');
        _initializeEmptyScene();
        break;
      case GCodeProcessingFailed failedEvent:
        AppLogger.error('G-code processing failed: ${failedEvent.error}');
        _initializeEmptyScene();
        break;
      default:
        // Other events (started, parsing) don't require scene updates
        break;
    }
  }

  /// Build scene from current processor state
  Future<void> _buildSceneFromProcessor() async {
    final processor = GCodeProcessor.instance;
    if (processor.currentParsedData != null) {
      _buildSceneFromParsedData(processor.currentParsedData!);
    } else {
      await _initializeEmptyScene();
    }
  }

  /// Build scene from parsed G-code data
  void _buildSceneFromParsedData(GCodePath gcodePath) {
    try {
      AppLogger.info('Building scene from G-code data');

      // Generate scene objects from G-code
      final gcodeObjects = GCodeSceneGenerator.generateSceneObjects(gcodePath);

      // Add world origin axes for debugging
      final worldAxes = _createWorldOriginAxes();
      final allObjects = [...gcodeObjects, ...worldAxes];

      // Create camera configuration based on G-code content
      final cameraConfig = _createCameraConfiguration(gcodePath);

      // Create lighting configuration
      final lightConfig = LightingConfiguration(
        directionalLight: DirectionalLightData(
          direction: vm.Vector3(0, 0, -1), // Top-down lighting for CNC visualization
          color: Colors.white,
          intensity: 1.0,
        ),
      );

      _sceneData = SceneData(
        objects: allObjects,
        camera: cameraConfig,
        lighting: lightConfig,
      );

      // Notify listeners of scene update
      _sceneUpdateController.add(_sceneData);

      AppLogger.info('G-code scene built:');
      AppLogger.info('- ${gcodePath.totalOperations} G-code operations');
      AppLogger.info(
        '- ${gcodeObjects.length} G-code objects + ${worldAxes.length} world axes = ${allObjects.length} total objects',
      );
      AppLogger.info('- Camera at ${cameraConfig.position}');
      AppLogger.info('- Bounds: ${gcodePath.minBounds} to ${gcodePath.maxBounds}');

    } catch (e) {
      AppLogger.error('Failed to build scene from G-code data: $e');
      _initializeEmptyScene();
    }
  }

  /// Initialize scene with just world axes (no G-code)
  Future<void> _initializeEmptyScene() async {
    AppLogger.info('Initializing empty scene');

    // Create scene with just world origin axes
    final worldAxes = _createWorldOriginAxes();

    // Default camera position for empty scene
    final cameraConfig = CameraConfiguration(
      position: vm.Vector3(100, 100, 80),
      target: vm.Vector3.zero(),
      up: vm.Vector3(0, 0, 1), // Z-up for CNC coordinate system
      fov: 45.0,
    );

    // Create lighting configuration
    final lightConfig = LightingConfiguration(
      directionalLight: DirectionalLightData(
        direction: vm.Vector3(0, 0, -1),
        color: Colors.white,
        intensity: 1.0,
      ),
    );

    _sceneData = SceneData(
      objects: worldAxes,
      camera: cameraConfig,
      lighting: lightConfig,
    );

    // Notify listeners of scene update
    _sceneUpdateController.add(_sceneData);

    AppLogger.info('Empty scene initialized with ${worldAxes.length} world axes');
  }

  /// Get scene objects filtered by type
  List<SceneObject> getObjectsByType(SceneObjectType type) {
    if (_sceneData == null) return [];
    return _sceneData!.objects.where((obj) => obj.type == type).toList();
  }

  /// Get all lines in the scene (includes coordinate axes)
  List<SceneObject> get lines => getObjectsByType(SceneObjectType.line);

  /// Dispose of resources
  void dispose() {
    _processorSubscription?.cancel();
    _sceneUpdateController.close();
  }

  /// Create camera configuration optimized for the scene bounds
  CameraConfiguration _createCameraConfiguration(GCodePath gcodePath) {
    // Calculate scene bounds and center
    final center = (gcodePath.minBounds + gcodePath.maxBounds) * 0.5;
    final size = gcodePath.maxBounds - gcodePath.minBounds;
    final maxDimension = max(max(size.x, size.y), size.z);

    // Position camera to view the entire part with some margin
    final cameraDistance = maxDimension * 2.0;
    final cameraHeight = maxDimension * 0.8;

    // Standard CNC viewing angle - elevated and diagonal for good visibility
    return CameraConfiguration(
      position: vm.Vector3(
        center.x + cameraDistance * 0.7,
        center.y + cameraDistance * 0.7,
        center.z + cameraHeight,
      ),
      target: center,
      up: vm.Vector3(0, 0, 1), // Z-up for CNC coordinate system
      fov: 45.0,
    );
  }

  /// Create world origin coordinate axes for debugging
  List<SceneObject> _createWorldOriginAxes() {
    const double axisLength = 50.0;

    return [
      // X-axis (Red) - from origin to +X
      SceneObject(
        type: SceneObjectType.line,
        startPoint: vm.Vector3(0.0, 0.0, 0.0),
        endPoint: vm.Vector3(axisLength, 0.0, 0.0),
        color: Colors.red,
        id: 'world_axis_x',
      ),
      // Y-axis (Green) - from origin to +Y
      SceneObject(
        type: SceneObjectType.line,
        startPoint: vm.Vector3(0.0, 0.0, 0.0),
        endPoint: vm.Vector3(0.0, axisLength, 0.0),
        color: Colors.green,
        id: 'world_axis_y',
      ),
      // Z-axis (Blue) - from origin to +Z
      SceneObject(
        type: SceneObjectType.line,
        startPoint: vm.Vector3(0.0, 0.0, 0.0),
        endPoint: vm.Vector3(0.0, 0.0, axisLength),
        color: Colors.blue,
        id: 'world_axis_z',
      ),
    ];
  }
}

/// Complete scene data that all renderers receive
class SceneData {
  final List<SceneObject> objects;
  final CameraConfiguration camera;
  final LightingConfiguration lighting;

  const SceneData({
    required this.objects,
    required this.camera,
    required this.lighting,
  });
}

/// Individual object in the 3D scene
class SceneObject {
  final SceneObjectType type;
  final Color color;
  final String id;

  // Line segment properties (for SceneObjectType.line)
  final vm.Vector3? startPoint; // Start point for line segments
  final vm.Vector3? endPoint; // End point for line segments

  // G-code specific properties
  final int? operationIndex; // Index in the G-code operation sequence
  final double?
  estimatedTime; // Estimated time to complete this operation (seconds)
  final bool isRapidMove; // True for G0 (rapid positioning)
  final bool isCuttingMove; // True for G1 (linear interpolation)
  final bool isArcMove; // True for G2/G3 (circular interpolation)

  const SceneObject({
    required this.type,
    required this.color,
    required this.id,
    this.startPoint,
    this.endPoint,
    this.operationIndex,
    this.estimatedTime,
    this.isRapidMove = false,
    this.isCuttingMove = false,
    this.isArcMove = false,
  });
}

enum SceneObjectType {
  line, // For G-code path segments and coordinate axes
  cube, // For 3D cube objects
}

/// Camera configuration for the scene
class CameraConfiguration {
  final vm.Vector3 position;
  final vm.Vector3 target;
  final vm.Vector3 up;
  final double fov;

  const CameraConfiguration({
    required this.position,
    required this.target,
    required this.up,
    required this.fov,
  });
}

/// Lighting configuration for the scene
class LightingConfiguration {
  final DirectionalLightData? directionalLight;

  const LightingConfiguration({this.directionalLight});
}

class DirectionalLightData {
  final vm.Vector3 direction;
  final Color color;
  final double intensity;

  const DirectionalLightData({
    required this.direction,
    required this.color,
    required this.intensity,
  });
}
