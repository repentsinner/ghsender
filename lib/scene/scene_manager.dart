import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../gcode/gcode_parser.dart';
import '../gcode/gcode_scene.dart';
import '../gcode/gcode_processor.dart';
import '../ui/themes/visualizer_theme.dart';
import 'axes_factory.dart';
import '../models/machine_controller.dart';

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

  // Current machine position for debug cube
  vm.Vector3? _currentMachinePosition;

  // Current work envelope for machine boundaries
  WorkEnvelope? _currentWorkEnvelope;

  // Stream controller for scene updates
  final StreamController<SceneData?> _sceneUpdateController =
      StreamController<SceneData?>.broadcast();

  bool get initialized => _initialized;
  SceneData? get sceneData => _sceneData;
  Stream<SceneData?> get sceneUpdates => _sceneUpdateController.stream;

  /// Update the machine position using efficient transform-only updates
  /// This method provides high-performance position updates without rebuilding the scene
  void updateMachinePosition(MachineCoordinates? machineCoords) {
    if (machineCoords != null) {
      // Reuse the existing Vector3 object to avoid memory allocation
      if (_currentMachinePosition == null) {
        _currentMachinePosition = vm.Vector3(
          machineCoords.x,
          machineCoords.y,
          machineCoords.z,
        );
      } else {
        _currentMachinePosition!.setValues(
          machineCoords.x,
          machineCoords.y,
          machineCoords.z,
        );
      }
    } else {
      _currentMachinePosition = null;
    }
  }

  /// Get current machine position for renderer updates
  vm.Vector3? get currentMachinePosition => _currentMachinePosition;

  /// Update the work envelope from machine configuration changes
  /// This method provides reactive updates when machine settings change
  void updateWorkEnvelope(WorkEnvelope? workEnvelope) {
    if (_currentWorkEnvelope != workEnvelope) {
      _currentWorkEnvelope = workEnvelope;
      AppLogger.info(
        workEnvelope != null
            ? 'Work envelope updated: $workEnvelope'
            : 'Work envelope cleared',
      );
      
      // Rebuild scene when work envelope changes (geometry rebuild needed)
      if (_initialized) {
        if (GCodeProcessor.instance.hasValidFile) {
          _buildSceneFromProcessor();
        } else {
          _initializeEmptyScene();
        }
      }
    }
  }

  /// Get current work envelope for renderer access
  WorkEnvelope? get currentWorkEnvelope => _currentWorkEnvelope;

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
      final toolpathVisualization = _createToolpathVisualization(gcodePath);

      // Add work envelope if machine configuration is available
      final workEnvelopeSquares = _createWorkEnvelopeIfAvailable();

      // Add machine position indicator (will be positioned via renderer transform updates)
      final machinePositionIndicator = _createMachinePositionIndicator();

      final allObjects = [
        ...gcodeObjects,
        ...worldAxes,
        ...toolpathVisualization,
        ...workEnvelopeSquares,
        machinePositionIndicator,
      ];

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

    // Add work envelope if machine configuration is available
    final workEnvelopeSquares = _createWorkEnvelopeIfAvailable();

    // Add machine position indicator (will be positioned via renderer transform updates)
    final machinePositionIndicator = _createMachinePositionIndicator();

    _sceneData = SceneData(
      objects: [...worldAxes, ...workEnvelopeSquares, machinePositionIndicator],
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

  /// Create toolpath visualization elements (bounding box, etc.)
  List<SceneObject> _createToolpathVisualization(GCodePath gcodePath) {
    final visualizationElements = <SceneObject>[];

    try {
      // TODO: Work area boundary should be based on machine controller limits (3D volume)
      // not derived from G-code bounds. Will be implemented in machine controller system.

      // Tool path bounding box - 3D wireframe cube encompassing all G-code
      visualizationElements.addAll(_createToolPathBoundingBox(gcodePath));

      // Origin indication handled by axes visualizer

      // TODO: Safety zones will be implemented in machine controller system
      // based on actual sensor positions and physical obstacles

      AppLogger.info(
        'Created ${visualizationElements.length} toolpath visualization elements',
      );
    } catch (e) {
      AppLogger.warning('Failed to create toolpath visualization elements: $e');
      // Return empty list if creation fails
      return [];
    }

    return visualizationElements;
  }

  /// Create a logical machine position indicator
  /// The renderer will decide how to visualize this (e.g., as a cube)
  SceneObject _createMachinePositionIndicator() {
    return SceneObject(
      type: SceneObjectType.machinePosition,
      position: vm.Vector3.zero(), // Will be updated via transform
      color: Colors.red, // Default color, renderer may override
      id: 'machine_position_indicator',
    );
  }

  /// Create work envelope visualization if machine configuration is available
  /// Returns empty list if no work envelope is configured
  List<SceneObject> _createWorkEnvelopeIfAvailable() {
    if (_currentWorkEnvelope == null) {
      return []; // No work envelope to render
    }
    return _createWorkEnvelopeCube(_currentWorkEnvelope!);
  }

  /// Create work envelope cube visualization from actual machine configuration
  /// Uses real machine travel limits to create accurate boundary representation
  List<SceneObject> _createWorkEnvelopeCube(WorkEnvelope workEnvelope) {
    final cubeSquares = <SceneObject>[];
    
    // Use actual work envelope dimensions from machine configuration
    final minBounds = workEnvelope.minBounds;
    final maxBounds = workEnvelope.maxBounds;
    final center = workEnvelope.center;
    final dimensions = workEnvelope.dimensions;

    // Semi-transparent cube with distinct themed colors for each face pair
    const double opacity = VisualizerTheme.cubeOpacity;
    const double edgeWidth = VisualizerTheme.cubeEdgeWidth;

    // XY plane faces (top and bottom) - use actual dimensions for rectangles
    cubeSquares.addAll([
      // Top face (Z = maxBounds.z)
      SceneObject(
        type: SceneObjectType.filledRectangle,
        center: vm.Vector3(center.x, center.y, maxBounds.z),
        width: dimensions.x.abs(),
        height: dimensions.y.abs(),
        plane: RectanglePlane.xy,
        fillColor: VisualizerTheme.cubeXYFaceColor,
        edgeColor: VisualizerTheme.cubeXYFaceColor.withValues(alpha: 0.8),
        opacity: opacity,
        edgeWidth: edgeWidth,
        color: VisualizerTheme.cubeXYFaceColor,
        id: 'work_envelope_face_top_xy',
      ),
      // Bottom face (Z = minBounds.z)
      SceneObject(
        type: SceneObjectType.filledRectangle,
        center: vm.Vector3(center.x, center.y, minBounds.z),
        width: dimensions.x.abs(),
        height: dimensions.y.abs(),
        plane: RectanglePlane.xy,
        fillColor: VisualizerTheme.cubeXYFaceColor.withValues(alpha: 0.5),
        edgeColor: VisualizerTheme.cubeXYFaceColor.withValues(alpha: 0.8),
        opacity: opacity,
        edgeWidth: edgeWidth,
        color: VisualizerTheme.cubeXYFaceColor,
        id: 'work_envelope_face_bottom_xy',
      ),
    ]);

    // XZ plane faces (front and back) - use actual dimensions for rectangles
    cubeSquares.addAll([
      // Front face (Y = maxBounds.y)
      SceneObject(
        type: SceneObjectType.filledRectangle,
        center: vm.Vector3(center.x, maxBounds.y, center.z),
        width: dimensions.x.abs(),
        height: dimensions.z.abs(),
        plane: RectanglePlane.xz,
        fillColor: VisualizerTheme.cubeXZFaceColor,
        edgeColor: VisualizerTheme.cubeXZFaceColor.withValues(alpha: 0.8),
        opacity: opacity,
        edgeWidth: edgeWidth,
        color: VisualizerTheme.cubeXZFaceColor,
        id: 'work_envelope_face_front_xz',
      ),
      // Back face (Y = minBounds.y)
      SceneObject(
        type: SceneObjectType.filledRectangle,
        center: vm.Vector3(center.x, minBounds.y, center.z),
        width: dimensions.x.abs(),
        height: dimensions.z.abs(),
        plane: RectanglePlane.xz,
        fillColor: VisualizerTheme.cubeXZFaceColor.withValues(alpha: 0.5),
        edgeColor: VisualizerTheme.cubeXZFaceColor.withValues(alpha: 0.8),
        opacity: opacity,
        edgeWidth: edgeWidth,
        color: VisualizerTheme.cubeXZFaceColor,
        id: 'work_envelope_face_back_xz',
      ),
    ]);

    // YZ plane faces (left and right) - use actual dimensions for rectangles
    cubeSquares.addAll([
      // Right face (X = maxBounds.x)
      SceneObject(
        type: SceneObjectType.filledRectangle,
        center: vm.Vector3(maxBounds.x, center.y, center.z),
        width: dimensions.y.abs(),
        height: dimensions.z.abs(),
        plane: RectanglePlane.yz,
        fillColor: VisualizerTheme.cubeYZFaceColor,
        edgeColor: VisualizerTheme.cubeYZFaceColor.withValues(alpha: 0.8),
        opacity: opacity,
        edgeWidth: edgeWidth,
        color: VisualizerTheme.cubeYZFaceColor,
        id: 'work_envelope_face_right_yz',
      ),
      // Left face (X = minBounds.x)
      SceneObject(
        type: SceneObjectType.filledRectangle,
        center: vm.Vector3(minBounds.x, center.y, center.z),
        width: dimensions.y.abs(),
        height: dimensions.z.abs(),
        plane: RectanglePlane.yz,
        fillColor: VisualizerTheme.cubeYZFaceColor.withValues(alpha: 0.5),
        edgeColor: VisualizerTheme.cubeYZFaceColor.withValues(alpha: 0.8),
        opacity: opacity,
        edgeWidth: edgeWidth,
        color: VisualizerTheme.cubeYZFaceColor,
        id: 'work_envelope_face_left_yz',
      ),
    ]);

    AppLogger.info(
      'Created work envelope with ${cubeSquares.length} faces: $minBounds to $maxBounds ${workEnvelope.units}',
    );
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

  /// Create a 3D wireframe bounding box that encompasses all G-code movements
  /// Includes feeds, rapids, and any other movements in the G-code file
  List<SceneObject> _createToolPathBoundingBox(GCodePath gcodePath) {
    final lines = <SceneObject>[];

    try {
      // Get the actual G-code bounds (not derived size)
      final minBounds = gcodePath.minBounds;
      final maxBounds = gcodePath.maxBounds;

      // Use the actual G-code bounds for the cube, not a derived square
      final color = VisualizerTheme.toolPathBoundaryColor;
      const double thickness = VisualizerTheme.boundaryLineThickness;

      // Bottom face (Z = minBounds.z)
      lines.addAll([
        // Bottom edges
        SceneObject(
          type: SceneObjectType.line,
          startPoint: vm.Vector3(minBounds.x, minBounds.y, minBounds.z),
          endPoint: vm.Vector3(maxBounds.x, minBounds.y, minBounds.z),
          color: color,
          thickness: thickness,
          id: 'toolpath_bbox_bottom_front',
        ),
        SceneObject(
          type: SceneObjectType.line,
          startPoint: vm.Vector3(maxBounds.x, minBounds.y, minBounds.z),
          endPoint: vm.Vector3(maxBounds.x, maxBounds.y, minBounds.z),
          color: color,
          thickness: thickness,
          id: 'toolpath_bbox_bottom_right',
        ),
        SceneObject(
          type: SceneObjectType.line,
          startPoint: vm.Vector3(maxBounds.x, maxBounds.y, minBounds.z),
          endPoint: vm.Vector3(minBounds.x, maxBounds.y, minBounds.z),
          color: color,
          thickness: thickness,
          id: 'toolpath_bbox_bottom_back',
        ),
        SceneObject(
          type: SceneObjectType.line,
          startPoint: vm.Vector3(minBounds.x, maxBounds.y, minBounds.z),
          endPoint: vm.Vector3(minBounds.x, minBounds.y, minBounds.z),
          color: color,
          thickness: thickness,
          id: 'toolpath_bbox_bottom_left',
        ),
      ]);

      // Top face (Z = maxBounds.z)
      lines.addAll([
        SceneObject(
          type: SceneObjectType.line,
          startPoint: vm.Vector3(minBounds.x, minBounds.y, maxBounds.z),
          endPoint: vm.Vector3(maxBounds.x, minBounds.y, maxBounds.z),
          color: color,
          thickness: thickness,
          id: 'toolpath_bbox_top_front',
        ),
        SceneObject(
          type: SceneObjectType.line,
          startPoint: vm.Vector3(maxBounds.x, minBounds.y, maxBounds.z),
          endPoint: vm.Vector3(maxBounds.x, maxBounds.y, maxBounds.z),
          color: color,
          thickness: thickness,
          id: 'toolpath_bbox_top_right',
        ),
        SceneObject(
          type: SceneObjectType.line,
          startPoint: vm.Vector3(maxBounds.x, maxBounds.y, maxBounds.z),
          endPoint: vm.Vector3(minBounds.x, maxBounds.y, maxBounds.z),
          color: color,
          thickness: thickness,
          id: 'toolpath_bbox_top_back',
        ),
        SceneObject(
          type: SceneObjectType.line,
          startPoint: vm.Vector3(minBounds.x, maxBounds.y, maxBounds.z),
          endPoint: vm.Vector3(minBounds.x, minBounds.y, maxBounds.z),
          color: color,
          thickness: thickness,
          id: 'toolpath_bbox_top_left',
        ),
      ]);

      // Vertical edges connecting bottom to top
      lines.addAll([
        SceneObject(
          type: SceneObjectType.line,
          startPoint: vm.Vector3(minBounds.x, minBounds.y, minBounds.z),
          endPoint: vm.Vector3(minBounds.x, minBounds.y, maxBounds.z),
          color: color,
          thickness: thickness,
          id: 'toolpath_bbox_vertical_front_left',
        ),
        SceneObject(
          type: SceneObjectType.line,
          startPoint: vm.Vector3(maxBounds.x, minBounds.y, minBounds.z),
          endPoint: vm.Vector3(maxBounds.x, minBounds.y, maxBounds.z),
          color: color,
          thickness: thickness,
          id: 'toolpath_bbox_vertical_front_right',
        ),
        SceneObject(
          type: SceneObjectType.line,
          startPoint: vm.Vector3(maxBounds.x, maxBounds.y, minBounds.z),
          endPoint: vm.Vector3(maxBounds.x, maxBounds.y, maxBounds.z),
          color: color,
          thickness: thickness,
          id: 'toolpath_bbox_vertical_back_right',
        ),
        SceneObject(
          type: SceneObjectType.line,
          startPoint: vm.Vector3(minBounds.x, maxBounds.y, minBounds.z),
          endPoint: vm.Vector3(minBounds.x, maxBounds.y, maxBounds.z),
          color: color,
          thickness: thickness,
          id: 'toolpath_bbox_vertical_back_left',
        ),
      ]);

      AppLogger.info('Created ${lines.length} toolpath bounding box edges');
    } catch (e) {
      AppLogger.warning('Failed to create toolpath bounding box: $e');
    }

    return lines;
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
  final double? thickness; // Line thickness for rendering

  // Filled rectangle properties (for SceneObjectType.filledRectangle)
  final vm.Vector3? center; // Rectangle center point
  final double? width; // Rectangle width
  final double? height; // Rectangle height
  final RectanglePlane? plane; // Which plane (XY, XZ, YZ)
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

  // Machine position properties (for SceneObjectType.machinePosition)
  final vm.Vector3? position; // Machine position in world coordinates

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
    this.thickness,
    this.center,
    this.width,
    this.height,
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
    this.position,
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
  filledRectangle, // For filled rectangles with outlined edges
  textBillboard, // For 3D-positioned, screen-aligned text
  machinePosition, // For current machine position indicator
}

enum RectanglePlane {
  xy, // Rectangle in XY plane (normal = Z axis)
  xz, // Rectangle in XZ plane (normal = Y axis)
  yz, // Rectangle in YZ plane (normal = X axis)
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
