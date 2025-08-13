import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:google_fonts/google_fonts.dart';
import '../scene/scene_manager.dart';
import 'renderer_interface.dart';
import 'line_mesh_factory.dart';
import 'line_style.dart';

/// Custom UnlitMaterial that supports transparency
class TransparentUnlitMaterial extends UnlitMaterial {
  @override
  bool isOpaque() {
    // Enable alpha blending for transparent cubes
    return baseColorFactor.w >= 1.0; // Only opaque if alpha is 1.0
  }
}

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

  // Public getters for camera information (for UI display)
  double get cameraAzimuth => 0.0; // Will be provided by CameraDirector
  double get cameraElevation => 0.0; // Will be provided by CameraDirector  
  double get cameraDistance => 0.0; // Will be provided by CameraDirector
  vm.Vector3 get cameraTarget => camera.target;
  vm.Vector3 get cameraPosition => camera.position;

  // Viewport resolution tracking for pixel-perfect line rendering
  Size? _lastViewportSize;

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
    // Default implementation - use 0.5 opacity for backwards compatibility
    await setupSceneWithOpacity(sceneData, 0.5);
  }

  /// Setup scene with dynamic opacity
  Future<void> setupSceneWithOpacity(
    SceneData sceneData,
    double opacity,
  ) async {
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

    // Initial camera setup - will be overridden by CameraDirector
    _setupInitialCamera();

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
    // Legacy method - no longer used, camera state comes from CameraDirector
    // This is kept for interface compatibility but does nothing
  }

  /// Set camera position and target directly from CameraDirector
  void setCameraState(vm.Vector3 position, vm.Vector3 target) {
    if (!_sceneInitialized) return;
    
    camera.position = position;
    camera.target = target;
    
    // Ensure Z-up orientation is maintained
    try {
      (camera as dynamic).up = vm.Vector3(0, 0, 1); // Z-up
    } catch (e) {
      // Silently ignore if up vector can't be set
    }
  }

  @override
  void render(Canvas canvas, Size size, double rotationX, double rotationY) {
    // Camera state is now managed by CameraDirector and set via setCameraState()
    // rotationX and rotationY parameters are ignored
    
    // Update resolution for pixel-perfect line rendering if viewport size changed
    if (_sceneData != null &&
        (size.width != _lastViewportSize?.width ||
            size.height != _lastViewportSize?.height)) {
      _updateViewportResolution(size);
    }

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

  void _setupInitialCamera() {
    if (_sceneData == null) return;

    // Set initial camera position and target from scene data
    // This will be overridden by CameraDirector
    final initialCameraPos = vm.Vector3(
      _sceneData!.camera.position.x,
      _sceneData!.camera.position.y,
      _sceneData!.camera.position.z,
    );
    final initialTarget = vm.Vector3(
      _sceneData!.camera.target.x,
      _sceneData!.camera.target.y,
      _sceneData!.camera.target.z,
    );

    camera.position = initialCameraPos;
    camera.target = initialTarget;

    // Explicitly set Z-up orientation for CNC coordinate system
    final upVector = vm.Vector3(0, 0, 1); // Z-up
    try {
      (camera as dynamic).up = upVector;
    } catch (e) {
      AppLogger.warning('Camera up vector not settable: $e');
    }

    AppLogger.info('Initial camera setup: position=$initialCameraPos, target=$initialTarget');
  }
  
  /// Get the orbit target for CameraDirector initialization
  vm.Vector3 getOrbitTarget() {
    if (_sceneData == null) return vm.Vector3.zero();
    return vm.Vector3(
      _sceneData!.camera.target.x,
      _sceneData!.camera.target.y,
      _sceneData!.camera.target.z,
    );
  }

  /// Update viewport resolution for pixel-perfect line rendering when window size changes
  void _updateViewportResolution(Size newSize) {
    _lastViewportSize = newSize;

    // Update all existing line meshes with new resolution
    // This requires regenerating the geometry since resolution is baked into vertex data
    if (_sceneData != null) {
      // Regenerate scene with new resolution
      setupScene(_sceneData!);
    }

    AppLogger.info(
      'Viewport resolution updated: ${newSize.width.toInt()}x${newSize.height.toInt()}',
    );
  }

  @override
  Widget createWidget() {
    // FlutterScene renderer uses CustomPaint, not its own widget
    return Container(
      color: Colors.black,
      child: Center(
        child: Text(
          'FlutterScene Renderer uses CustomPaint',
          style: GoogleFonts.inconsolata(color: Colors.white),
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

      // Get current viewport resolution for pixel-perfect line rendering
      final currentResolution = _lastViewportSize != null
          ? vm.Vector2(_lastViewportSize!.width, _lastViewportSize!.height)
          : vm.Vector2(1024, 768); // Default resolution

      // Use LineMeshFactory to create line meshes with proper Three.js-style rendering
      final lineMeshResult = LineMeshFactory.createLinesFromSceneData(
        SceneData(
          objects: lineObjects,
          camera: _sceneData!.camera,
          lighting: _sceneData!.lighting,
        ),
        lineWidth: _currentLineStyle.width,
        opacity: _currentLineStyle.opacity,
        sharpness: _currentLineStyle.sharpness,
        resolution: currentResolution,
        // Don't override individual line colors - let each line use its own color
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
