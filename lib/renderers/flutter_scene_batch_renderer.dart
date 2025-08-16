import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:google_fonts/google_fonts.dart';
import '../scene/scene_manager.dart';
import 'renderer_interface.dart';
import 'line_mesh_factory.dart';
import 'line_style.dart';
import 'filled_square_renderer.dart';
import 'billboard_text_renderer.dart';

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

  // Coordinate system transformation matrix
  // Converts right-handed CNC coordinates to left-handed Metal/Impeller coordinates
  // Negates Y-axis to ensure proper display of CNC coordinate conventions
  //  (X=right, Y=away from operator, Z=up).
  // Note that Impeller creates a left-handed system regardless of whatever the
  // underlying GPU API (Vulkan, OpenGL ES) uses.
  // https://github.com/flutter/engine/blob/main/impeller/docs/coordinate_system.md
  static final vm.Matrix4 _cncToImpellerCoordinateTransform =
      vm.Matrix4.diagonal3(vm.Vector3(1, -1, 1));

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

    // Apply coordinate system transformation to convert CNC coordinates (right-handed)
    // to Impeller/(Metal) (left-handed) coordinates.
    _rootNode.localTransform = _cncToImpellerCoordinateTransform;

    AppLogger.info('Creating optimized geometry from SceneManager data...');

    // Process all lines (G-code paths + world axes)
    final lineObjects = sceneData.objects
        .where((obj) => obj.type == SceneObjectType.line)
        .toList();

    // Process filled squares
    final filledSquareObjects = sceneData.objects
        .where((obj) => obj.type == SceneObjectType.filledSquare)
        .toList();

    // Process text billboards
    final textBillboardObjects = sceneData.objects
        .where((obj) => obj.type == SceneObjectType.textBillboard)
        .toList();

    int actualLineTriangles = 0;
    if (lineObjects.isNotEmpty) {
      actualLineTriangles = await _processLinesWithLineMeshFactory(lineObjects);
    }

    int actualSquareTriangles = 0;
    if (filledSquareObjects.isNotEmpty) {
      actualSquareTriangles = await _processFilledSquares(filledSquareObjects);
    }

    int actualTextTriangles = 0;
    if (textBillboardObjects.isNotEmpty) {
      actualTextTriangles = await _processTextBillboards(textBillboardObjects);
    }

    // Performance metrics calculation using ACTUAL measured values
    _actualPolygons =
        actualLineTriangles + actualSquareTriangles + actualTextTriangles;

    // Draw calls: lines + filled squares (each square creates 2 draw calls: fill + edges) + text billboards
    _actualDrawCalls =
        (lineObjects.isNotEmpty ? 1 : 0) +
        (filledSquareObjects.length * 2) +
        textBillboardObjects.length;

    // Initial camera setup - will be overridden by CameraDirector
    _setupInitialCamera();

    _sceneInitialized = true;
    AppLogger.info(
      'FlutterScene renderer setup complete with ${sceneData.objects.length} scene objects',
    );
    AppLogger.info('Lines: ${lineObjects.length} (line tessellated)');
    AppLogger.info(
      'Filled squares: ${filledSquareObjects.length} (hybrid fill + edge rendering)',
    );
    AppLogger.info(
      'Text billboards: ${textBillboardObjects.length} (texture-based)',
    );
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
      Paint()..color = const Color.fromARGB(255, 26, 26, 26),
    );

    // Update billboard orientations before rendering (pass viewport size for view matrix)
    _updateBillboardOrientations(size);

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

    AppLogger.info(
      'Initial camera setup: position=$initialCameraPos, target=$initialTarget',
    );
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

  /// Process filled square objects using FilledSquareRenderer
  Future<int> _processFilledSquares(
    List<SceneObject> filledSquareObjects,
  ) async {
    try {
      AppLogger.info(
        'Processing ${filledSquareObjects.length} filled squares with FilledSquareRenderer',
      );

      // Get current viewport resolution for line edges
      final currentResolution = _lastViewportSize != null
          ? vm.Vector2(_lastViewportSize!.width, _lastViewportSize!.height)
          : vm.Vector2(1024, 768); // Default resolution

      int totalTriangles = 0;

      // Process each filled square individually
      for (final squareObject in filledSquareObjects) {
        try {
          // Create filled square with both fill and edge meshes
          final squareResult = FilledSquareRenderer.createFromSceneObject(
            squareObject,
            resolution: currentResolution,
          );

          // Add both fill and edge nodes to the scene
          final nodes = squareResult.toNodes();
          for (final node in nodes) {
            _rootNode.add(node);
          }

          // Count triangles: 2 for fill + variable for edges (depends on line tessellation)
          // For now, estimate 2 triangles for fill + 8 for edges (4 line segments * 2 triangles each)
          totalTriangles += 2 + 8; // Approximation

          AppLogger.info(
            'Filled square processed: ${squareResult.id} (fill + edges)',
          );
        } catch (e) {
          AppLogger.error(
            'Failed to process filled square ${squareObject.id}: $e',
          );
        }
      }

      AppLogger.info(
        'FilledSquareRenderer processing complete: ${filledSquareObjects.length} squares -> ~$totalTriangles triangles',
      );

      return totalTriangles;
    } catch (e) {
      AppLogger.error(
        'FilledSquareRenderer processing failed - filled squares will not be rendered: $e',
      );
      return 0;
    }
  }

  /// Process text billboard objects using BillboardTextRenderer
  Future<int> _processTextBillboards(
    List<SceneObject> textBillboardObjects,
  ) async {
    try {
      AppLogger.info(
        'Processing ${textBillboardObjects.length} text billboards with BillboardTextRenderer',
      );

      int totalTriangles = 0;

      // Process each text billboard individually
      for (final billboardObject in textBillboardObjects) {
        try {
          // Validate required properties
          if (billboardObject.text == null || billboardObject.center == null) {
            AppLogger.warning(
              'Skipping text billboard ${billboardObject.id}: missing text or position',
            );
            continue;
          }

          // Create text billboard node
          final billboardNode = await BillboardTextRenderer.createTextBillboard(
            text: billboardObject.text!,
            position: billboardObject.center!,
            textStyle:
                billboardObject.textStyle ??
                const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
            worldSize: billboardObject.worldSize ?? 10.0,
            backgroundColor:
                billboardObject.textBackgroundColor ?? Colors.transparent,
            opacity: billboardObject.opacity ?? 1.0,
            id: billboardObject.id,
          );

          // Add to scene
          _rootNode.add(billboardNode);

          // Each billboard uses 2 triangles (quad)
          totalTriangles += 2;

          AppLogger.info(
            'Text billboard processed: "${billboardObject.text}" at ${billboardObject.center}',
          );
        } catch (e) {
          AppLogger.error(
            'Failed to process text billboard ${billboardObject.id}: $e',
          );
        }
      }

      AppLogger.info(
        'BillboardTextRenderer processing complete: ${textBillboardObjects.length} billboards -> $totalTriangles triangles',
      );

      return totalTriangles;
    } catch (e) {
      AppLogger.error(
        'BillboardTextRenderer processing failed - text billboards will not be rendered: $e',
      );
      return 0;
    }
  }

  /// Update billboard orientations to face the camera
  void _updateBillboardOrientations(Size viewportSize) {
    if (!_sceneInitialized) return;

    final cameraPos = camera.position;

    // Recursively find and update billboard nodes
    _updateNodeBillboards(_rootNode, cameraPos, viewportSize);
  }

  /// Recursively update billboard orientations in a node hierarchy
  void _updateNodeBillboards(
    Node node,
    vm.Vector3 cameraPosition,
    Size viewportSize,
  ) {
    // Check if this node contains a billboard geometry
    if (_isBillboardNode(node)) {
      _updateBillboardTransform(node, cameraPosition, viewportSize);
    }

    // Recursively check children
    for (final child in node.children) {
      _updateNodeBillboards(child, cameraPosition, viewportSize);
    }
  }

  /// Check if a node contains billboard geometry
  bool _isBillboardNode(Node node) {
    // Check if node is marked as a billboard by name
    return node.name.startsWith('billboard_');
  }

  /// Calculate and apply billboard transform
  void _updateBillboardTransform(
    Node billboardNode,
    vm.Vector3 cameraPosition,
    Size viewportSize,
  ) {
    // Get the current position from the transform
    final currentTransform = billboardNode.localTransform;
    final billboardPosition = currentTransform.getTranslation();

    // Calculate look-at rotation using view matrix
    final lookAtMatrix = _calculateBillboardLookAt(
      billboardPosition,
      cameraPosition,
      viewportSize,
    );

    // Apply coordinate transformation to the billboard orientation to account for
    // the Y-axis negation transformation applied to the root node
    final transformedLookAtMatrix =
        _cncToImpellerCoordinateTransform * lookAtMatrix;

    // Apply look-at rotation while preserving position
    final finalTransform = transformedLookAtMatrix.clone();
    finalTransform.setTranslation(billboardPosition);

    billboardNode.localTransform = finalTransform;
  }

  /// Calculate look-at matrix for billboard facing camera
  /// Creates a rotation matrix that aligns the billboard with screen space axes
  vm.Matrix4 _calculateBillboardLookAt(
    vm.Vector3 billboardPos,
    vm.Vector3 cameraPos,
    Size viewportSize,
  ) {
    // Get the view matrix from the camera
    final viewMatrix = camera.getViewTransform(viewportSize);

    // Extract camera basis vectors from the view matrix
    // In column-major matrices, the camera's world-space orientation vectors
    // are in the ROWS of the upper-left 3x3 portion of the view matrix

    // Camera right vector (screen X-axis in world space) - Row 0
    final cameraRight = vm.Vector3(
      viewMatrix[0], // m[0]
      viewMatrix[4], // m[4]
      viewMatrix[8], // m[8]
    ).normalized();

    // Camera up vector (screen Y-axis in world space) - Row 1
    final cameraUp = vm.Vector3(
      viewMatrix[1], // m[1]
      viewMatrix[5], // m[5]
      viewMatrix[9], // m[9]
    ).normalized();

    // Camera forward vector (view direction) - Row 2

    // Calculate the view direction from billboard to camera
    final toCamera = (cameraPos - billboardPos).normalized();

    // Build the billboard rotation matrix
    // X axis: camera right (screen X)
    // Y axis: camera up (screen Y)
    // Z axis: opposite of view direction (so billboard faces camera)
    final rotationMatrix = vm.Matrix4.identity();
    rotationMatrix.setColumn(
      0,
      vm.Vector4(cameraRight.x, cameraRight.y, cameraRight.z, 0),
    );
    rotationMatrix.setColumn(
      1,
      vm.Vector4(cameraUp.x, cameraUp.y, cameraUp.z, 0),
    );
    rotationMatrix.setColumn(
      2,
      vm.Vector4(-toCamera.x, -toCamera.y, -toCamera.z, 0),
    );

    return rotationMatrix;
  }

  @override
  void dispose() {
    _rootNode.children.clear();
    _combinedMeshNode.mesh = null;
    // LineMeshFactory doesn't require disposal - it's a static factory
    _sceneData = null;
  }
}
