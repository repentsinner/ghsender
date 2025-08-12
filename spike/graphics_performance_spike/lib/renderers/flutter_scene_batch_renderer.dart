import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../scene/scene_manager.dart';
import 'renderer_interface.dart';
import 'line_mesh_factory.dart';
import 'line_style.dart';

class FlutterSceneBatchRenderer implements Renderer {
  Scene scene = Scene();
  PerspectiveCamera camera = PerspectiveCamera();
  bool _initialized = false;
  bool _sceneInitialized = false;
  int _actualPolygons = 0;
  int _actualDrawCalls = 0;

  // Scene data received from SceneManager
  SceneData? _sceneData;

  // Root node for applying interactive rotation to all scenes
  final Node _rootNode = Node();

  // Single combined mesh node for all geometry
  final Node _combinedMeshNode = Node();

  // No longer need the old GPU line primitive - using LineMeshFactory directly

  // Dynamic line style settings
  LineStyle _currentLineStyle = LineStyles.technical;

  // Interactive rotation state (now used for camera orbit)
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  
  // Camera orbit parameters
  double _orbitRadius = 100.0; // Distance from target
  vm.Vector3 _orbitTarget = vm.Vector3.zero(); // Point the camera orbits around

  @override
  Future<bool> initialize() async {
    try {
      await Scene.initializeStaticResources();

      // LineMeshFactory doesn't require initialization - it's a static factory

      // Add root node to scene for rotation control
      scene.add(_rootNode);

      _initialized = true;
      AppLogger.info('FlutterScene renderer initialized successfully');
      return true;
    } catch (e) {
      AppLogger.error('FlutterScene renderer initialization failed', e);
      return false;
    }
  }

  @override
  Future<void> setupScene(SceneData sceneData) async {
    _sceneData = sceneData;

    // Clear any existing scene objects
    _rootNode.children.clear();

    AppLogger.info('Creating optimized geometry from SceneManager data...');

    // Process all lines (G-code paths + world axes)
    final lineObjects = sceneData.objects
        .where((obj) => obj.type == SceneObjectType.line)
        .toList();

    int actualLineTriangles = 0;
    if (lineObjects.isNotEmpty) {
      actualLineTriangles = await _processLinesWithLineMeshFactory(lineObjects);
    }

    // Performance metrics calculation using ACTUAL measured values
    _actualPolygons = actualLineTriangles;

    // Draw calls: 1 for all lines
    _actualDrawCalls = lineObjects.isNotEmpty ? 1 : 0;

    // Setup camera positioning from scene data
    _setupCamera();

    _sceneInitialized = true;
    AppLogger.info(
      'FlutterScene renderer setup complete with ${sceneData.objects.length} scene objects',
    );
    AppLogger.info('Lines: ${lineObjects.length} (line tessellated)');
    AppLogger.info(
      'ACTUAL performance metrics: $_actualPolygons triangles in $_actualDrawCalls draw calls',
    );
  }

  @override
  void updateRotation(double rotationX, double rotationY) {
    _rotationX = rotationX;
    _rotationY = rotationY;

    if (!_sceneInitialized) return;

    // Update camera position using spherical coordinates (orbit around target)
    _updateCameraOrbit();
  }
  
  /// Calculate and update camera position to orbit around the target point
  void _updateCameraOrbit() {
    // Convert rotation inputs to spherical coordinates for Z-up system
    // rotationY controls horizontal rotation around Z-axis (azimuth)
    final azimuth = _rotationY;  // Horizontal rotation around Z axis
    
    // rotationX controls elevation angle from XY plane
    // Invert Y-axis: positive mouse Y = look up, negative = look down
    // Constrain elevation to prevent camera from going underground or flipping
    final elevation = math.max(-math.pi * 0.4, math.min(math.pi * 0.4, _rotationX));
    
    // Convert to spherical coordinates in Z-up system:
    // - azimuth: rotation around Z axis (0 = +X direction)  
    // - elevation: angle from XY plane (positive = above horizon)
    final x = _orbitRadius * math.cos(elevation) * math.cos(azimuth);
    final y = _orbitRadius * math.cos(elevation) * math.sin(azimuth);  
    final z = _orbitRadius * math.sin(elevation);
    
    // Set camera position relative to orbit target
    camera.position = _orbitTarget + vm.Vector3(x, y, z);
    
    // Always look at the target point
    camera.target = _orbitTarget;
    
    // Ensure Z-up orientation is maintained during orbit
    try {
      (camera as dynamic).up = vm.Vector3(0, 0, 1);  // Z-up
    } catch (e) {
      // Silently ignore if up vector can't be set
    }
  }

  @override
  void render(Canvas canvas, Size size, double rotationX, double rotationY) {
    // Update rotation state
    updateRotation(rotationX, rotationY);
    if (!_sceneInitialized) return;

    // Clear the canvas with black background to match GPU renderer
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );

    scene.render(camera, canvas, viewport: Offset.zero & size);
  }

  @override
  int get actualDrawCalls => _actualDrawCalls;
  @override
  int get actualPolygons => _actualPolygons;
  @override
  bool get initialized => _initialized;

  void _setupCamera() {
    if (_sceneData == null) return;

    // Initialize orbit parameters from scene data
    final initialCameraPos = vm.Vector3(
      _sceneData!.camera.position.x,
      _sceneData!.camera.position.y,
      _sceneData!.camera.position.z,
    );
    _orbitTarget = vm.Vector3(
      _sceneData!.camera.target.x,
      _sceneData!.camera.target.y,
      _sceneData!.camera.target.z,
    );
    
    // Calculate initial orbit radius from camera to target distance
    _orbitRadius = (initialCameraPos - _orbitTarget).length;
    
    // Set initial camera position and target
    camera.position = initialCameraPos;
    camera.target = _orbitTarget;
    
    // Explicitly set Z-up orientation for CNC coordinate system
    // This should ensure Z points up regardless of Flutter Scene's default
    final upVector = vm.Vector3(0, 0, 1);  // Z-up
    try {
      // Try to set up vector if the property exists
      (camera as dynamic).up = upVector;
    } catch (e) {
      AppLogger.warning('Camera up vector not settable: $e');
    }
    
    AppLogger.info('Camera orbit initialized: radius=${_orbitRadius.toStringAsFixed(1)}, target=$_orbitTarget');
  }

  @override
  Widget createWidget() {
    // FlutterScene renderer uses CustomPaint, not its own widget
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text(
          'FlutterScene Renderer uses CustomPaint',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  /// Update the line style for dynamic line settings control
  void updateLineStyle(LineStyle newStyle) {
    _currentLineStyle = newStyle;
  }

  /// Process line objects using LineMeshFactory for Three.js Line2/LineSegments2 rendering
  Future<int> _processLinesWithLineMeshFactory(
    List<SceneObject> lineObjects,
  ) async {
    try {
      AppLogger.info(
        'Processing ${lineObjects.length} lines with LineMeshFactory (Three.js Line2/LineSegments2)',
      );

      // Use LineMeshFactory to create line meshes with proper Three.js-style rendering
      final lineMeshResult = LineMeshFactory.createLinesFromSceneData(
        SceneData(
          objects: lineObjects,
          camera: _sceneData!.camera,
          lighting: _sceneData!.lighting,
        ),
        lineWidth: _currentLineStyle.width,
        defaultColor: _currentLineStyle.color,
      );

      // Add all line nodes to the scene
      for (final node in lineMeshResult.nodes) {
        _rootNode.add(node);
      }

      AppLogger.info(
        'LineMeshFactory line processing complete: ${lineMeshResult.nodes.length} line mesh nodes created',
      );
      AppLogger.info(
        'Actual line tessellation: ${lineMeshResult.lineSegments} segments -> ${lineMeshResult.actualTriangles} triangles, ${lineMeshResult.actualVertices} vertices',
      );

      return lineMeshResult.actualTriangles;
    } catch (e) {
      AppLogger.error(
        'LineMeshFactory line processing failed - lines will not be rendered: $e',
      );
      return 0;
    }
  }

  @override
  void dispose() {
    _rootNode.children.clear();
    _combinedMeshNode.mesh = null;
    // LineMeshFactory doesn't require disposal - it's a static factory
    _sceneData = null;
  }
}
