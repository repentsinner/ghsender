import 'dart:math';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../gcode/gcode_parser.dart';
import '../gcode/gcode_scene.dart';
import '../gcode/gcode_processor.dart';
import '../ui/themes/visualizer_theme.dart';
import 'filled_square_factory.dart';
import 'axes_factory.dart';

/// Centralized scene manager that creates and manages the 3D scene
/// All renderers receive the same scene data from this manager
class SceneManager {
  static SceneManager? _instance;
  static SceneManager get instance => _instance ??= SceneManager._();

  SceneManager._() {
    // Listen to G-code processor events for automatic scene updates
    _processorSubscription = GCodeProcessor.instance.events.listen(
      _onGCodeProcessingEvent,
    );
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
      AppLogger.info(
        'Scene manager initialized - waiting for G-code file selection',
      );
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
      final worldAxes = AxesFactory.createWorldAxes();

      // Add example filled squares for testing
      final filledSquares = _createExampleFilledSquares(gcodePath);

      // Add example cube for demonstration
      final cubeSquares = _createExampleCube();

      final allObjects = [...gcodeObjects, ...worldAxes, ...filledSquares, ...cubeSquares];

      // Create camera configuration based on G-code content
      final cameraConfig = _createCameraConfiguration(gcodePath);

      // Create lighting configuration
      final lightConfig = LightingConfiguration(
        directionalLight: DirectionalLightData(
          direction: vm.Vector3(
            0,
            0,
            -1,
          ), // Top-down lighting for CNC visualization
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
      AppLogger.info(
        '- Bounds: ${gcodePath.minBounds} to ${gcodePath.maxBounds}',
      );
    } catch (e) {
      AppLogger.error('Failed to build scene from G-code data: $e');
      _initializeEmptyScene();
    }
  }

  /// Initialize scene with just world axes (no G-code)
  Future<void> _initializeEmptyScene() async {
    AppLogger.info('Initializing empty scene');

    // Create scene with just world origin axes
    final worldAxes = AxesFactory.createWorldAxes();

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

    // Add example cube for demonstration
    final cubeSquares = _createExampleCube();
    
    _sceneData = SceneData(
      objects: [...worldAxes, ...cubeSquares],
      camera: cameraConfig,
      lighting: lightConfig,
    );

    // Notify listeners of scene update
    _sceneUpdateController.add(_sceneData);

    AppLogger.info(
      'Empty scene initialized with ${worldAxes.length} world axes',
    );
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

  /// Create example filled squares for testing and demonstration
  List<SceneObject> _createExampleFilledSquares(GCodePath gcodePath) {
    final squares = <SceneObject>[];

    try {
      // Calculate scene bounds for positioning
      final center = (gcodePath.minBounds + gcodePath.maxBounds) * 0.5;
      final size = gcodePath.maxBounds - gcodePath.minBounds;
      final maxDimension = math.max(math.max(size.x, size.y), size.z);

      // Work area boundary - semi-transparent square in XY plane (themed)
      final theme = VisualizerTheme.createTheme(VisualizerThemeVariant.classic);
      squares.add(
        FilledSquareFactory.createWorkAreaBoundary(
          width: maxDimension * 1.2,
          height: maxDimension * 1.2,
          center: vm.Vector3(center.x, center.y, gcodePath.minBounds.z - 0.1),
          fillColor: theme.workAreaFillColor,
          opacity: theme.workAreaOpacity,
          edgeWidth: VisualizerTheme.workAreaEdgeWidth,
          id: 'work_area_boundary',
        ),
      );

      // Tool path boundary - themed outline
      squares.add(
        FilledSquareFactory.createToolPathBoundary(
          center: center,
          size: maxDimension * 1.05,
          plane: SquarePlane.xy,
          color: VisualizerTheme.toolPathBoundaryColor,
          id: 'toolpath_boundary',
        ),
      );

      // Coordinate system indicator at origin
      squares.add(
        FilledSquareFactory.createCoordinateIndicator(
          origin: vm.Vector3(0, 0, 0),
          size: maxDimension * 0.05,
          plane: SquarePlane.xy,
          color: VisualizerTheme.originIndicatorColor,
          id: 'origin_indicator',
        ),
      );

      // Safety zone example (if there's space) - themed
      if (maxDimension > 10) {
        squares.add(
          FilledSquareFactory.createSafetyZone(
            center: vm.Vector3(
              center.x + maxDimension * 0.6,
              center.y,
              center.z,
            ),
            size: maxDimension * 0.2,
            plane: SquarePlane.xy,
            id: 'example_safety_zone',
          ),
        );
      }

      AppLogger.info('Created ${squares.length} example filled squares');
    } catch (e) {
      AppLogger.warning('Failed to create example filled squares: $e');
      // Return empty list if creation fails
      return [];
    }

    return squares;
  }

  /// Create a 30x30x30 cube from origin to (-30, -30, -30) using filled squares
  /// Demonstrates how to use FilledSquareRenderer to create 3D geometry
  List<SceneObject> _createExampleCube() {
    final cubeSquares = <SceneObject>[];
    const double cubeSize = 30.0;
    const double halfSize = cubeSize / 2.0;
    
    // Cube center is at (-15, -15, -15) since it extends from 0 to -30 in each axis
    final cubeCenter = vm.Vector3(-halfSize, -halfSize, -halfSize);
    
    // Semi-transparent cube with distinct themed colors for each face pair
    const double opacity = VisualizerTheme.cubeOpacity;
    const double edgeWidth = VisualizerTheme.cubeEdgeWidth;

    // XY plane faces (top and bottom)
    cubeSquares.addAll([
      // Top face (Z = 0)
      SceneObject(
        type: SceneObjectType.filledSquare,
        center: vm.Vector3(cubeCenter.x, cubeCenter.y, 0.0),
        size: cubeSize,
        plane: SquarePlane.xy,
        fillColor: VisualizerTheme.cubeXYFaceColor,
        edgeColor: VisualizerTheme.cubeXYFaceColor.withValues(alpha: 0.8),
        opacity: opacity,
        edgeWidth: edgeWidth,
        color: VisualizerTheme.cubeXYFaceColor,
        id: 'cube_face_top_xy',
      ),
      // Bottom face (Z = -30)
      SceneObject(
        type: SceneObjectType.filledSquare,
        center: vm.Vector3(cubeCenter.x, cubeCenter.y, -cubeSize),
        size: cubeSize,
        plane: SquarePlane.xy,
        fillColor: VisualizerTheme.cubeXYFaceColor.withValues(alpha: 0.5),
        edgeColor: VisualizerTheme.cubeXYFaceColor.withValues(alpha: 0.8),
        opacity: opacity,
        edgeWidth: edgeWidth,
        color: VisualizerTheme.cubeXYFaceColor,
        id: 'cube_face_bottom_xy',
      ),
    ]);

    // XZ plane faces (front and back)
    cubeSquares.addAll([
      // Front face (Y = 0)
      SceneObject(
        type: SceneObjectType.filledSquare,
        center: vm.Vector3(cubeCenter.x, 0.0, cubeCenter.z),
        size: cubeSize,
        plane: SquarePlane.xz,
        fillColor: VisualizerTheme.cubeXZFaceColor,
        edgeColor: VisualizerTheme.cubeXZFaceColor.withValues(alpha: 0.8),
        opacity: opacity,
        edgeWidth: edgeWidth,
        color: VisualizerTheme.cubeXZFaceColor,
        id: 'cube_face_front_xz',
      ),
      // Back face (Y = -30)
      SceneObject(
        type: SceneObjectType.filledSquare,
        center: vm.Vector3(cubeCenter.x, -cubeSize, cubeCenter.z),
        size: cubeSize,
        plane: SquarePlane.xz,
        fillColor: VisualizerTheme.cubeXZFaceColor.withValues(alpha: 0.5),
        edgeColor: VisualizerTheme.cubeXZFaceColor.withValues(alpha: 0.8),
        opacity: opacity,
        edgeWidth: edgeWidth,
        color: VisualizerTheme.cubeXZFaceColor,
        id: 'cube_face_back_xz',
      ),
    ]);

    // YZ plane faces (left and right)
    cubeSquares.addAll([
      // Right face (X = 0)
      SceneObject(
        type: SceneObjectType.filledSquare,
        center: vm.Vector3(0.0, cubeCenter.y, cubeCenter.z),
        size: cubeSize,
        plane: SquarePlane.yz,
        fillColor: VisualizerTheme.cubeYZFaceColor,
        edgeColor: VisualizerTheme.cubeYZFaceColor.withValues(alpha: 0.8),
        opacity: opacity,
        edgeWidth: edgeWidth,
        color: VisualizerTheme.cubeYZFaceColor,
        id: 'cube_face_right_yz',
      ),
      // Left face (X = -30)
      SceneObject(
        type: SceneObjectType.filledSquare,
        center: vm.Vector3(-cubeSize, cubeCenter.y, cubeCenter.z),
        size: cubeSize,
        plane: SquarePlane.yz,
        fillColor: VisualizerTheme.cubeYZFaceColor.withValues(alpha: 0.5),
        edgeColor: VisualizerTheme.cubeYZFaceColor.withValues(alpha: 0.8),
        opacity: opacity,
        edgeWidth: edgeWidth,
        color: VisualizerTheme.cubeYZFaceColor,
        id: 'cube_face_left_yz',
      ),
    ]);

    AppLogger.info('Created cube with 6 faces: ${cubeSquares.length} filled squares from origin to (-30, -30, -30)');
    return cubeSquares;
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

  // Filled square properties (for SceneObjectType.filledSquare)
  final vm.Vector3? center; // Square center point
  final double? size; // Square side length
  final SquarePlane? plane; // Which plane (XY, XZ, YZ)
  final double? rotation; // Rotation around plane normal (radians)
  final Color? fillColor; // Interior fill color
  final Color? edgeColor; // Edge outline color
  final double? edgeWidth; // Edge line width
  final double? opacity; // Overall opacity (0.0-1.0)

  // Text billboard properties (for SceneObjectType.textBillboard)
  final String? text; // Text content to display
  final TextStyle? textStyle; // Flutter text style
  final double? worldSize; // Size in world units
  final Color? textBackgroundColor; // Background color for text

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
    this.center,
    this.size,
    this.plane,
    this.rotation,
    this.fillColor,
    this.edgeColor,
    this.edgeWidth,
    this.opacity,
    this.text,
    this.textStyle,
    this.worldSize,
    this.textBackgroundColor,
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
  filledSquare, // For filled squares with outlined edges
  textBillboard, // For 3D-positioned, screen-aligned text
}

enum SquarePlane {
  xy, // Square in XY plane (normal = Z axis)
  xz, // Square in XZ plane (normal = Y axis)
  yz, // Square in YZ plane (normal = X axis)
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
