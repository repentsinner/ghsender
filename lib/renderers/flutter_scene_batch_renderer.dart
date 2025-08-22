import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:google_fonts/google_fonts.dart';
import '../scene/scene_manager.dart';
import '../utils/coordinate_converter.dart';
import 'renderer_interface.dart';
import 'line_mesh_factory.dart';
import 'line_style.dart';
import 'filled_rectangle_renderer.dart';
import 'billboard_shader_renderer.dart';
import 'screen_space_utils.dart';
import 'text_texture_factory.dart';

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

  // Device pixel ratio for proper text scaling
  double _devicePixelRatio = 1.0;

  // Root node for applying interactive rotation to all scenes
  final Node _rootNode = Node();

  // Single combined mesh node for all geometry
  final Node _combinedMeshNode = Node();

  // Dedicated node for machine position debug cube (updated via transform only)
  Node? _machinePositionCubeNode;

  // Coordinate system transformation matrix from centralized converter
  // Converts right-handed CNC coordinates to left-handed Metal/Impeller coordinates
  // Negates Y-axis to ensure proper display of CNC coordinate conventions
  //  (X=right, Y=away from operator, Z=up).
  // Note that Impeller creates a left-handed system regardless of whatever the
  // underlying GPU API (Vulkan, OpenGL ES) uses.
  // https://github.com/flutter/engine/blob/main/impeller/docs/coordinate_system.md
  static vm.Matrix4 get _cncToImpellerCoordinateTransform =>
      CoordinateConverter.cncToDisplayMatrix;

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

    // Process filled rectangles
    final filledRectangleObjects = sceneData.objects
        .where((obj) => obj.type == SceneObjectType.filledRectangle)
        .toList();

    // Process text billboards
    final textBillboardObjects = sceneData.objects
        .where((obj) => obj.type == SceneObjectType.textBillboard)
        .toList();

    // Process machine position indicators
    final machinePositionObjects = sceneData.objects
        .where((obj) => obj.type == SceneObjectType.machinePosition)
        .toList();

    int actualLineTriangles = 0;
    if (lineObjects.isNotEmpty) {
      actualLineTriangles = await _processLinesWithLineMeshFactory(lineObjects);
    }

    int actualRectangleTriangles = 0;
    if (filledRectangleObjects.isNotEmpty) {
      actualRectangleTriangles = await _processFilledRectangles(
        filledRectangleObjects,
      );
    }

    // Process machine position indicators separately for efficient updates
    await _setupMachinePositionIndicators(machinePositionObjects);

    int actualTextTriangles = 0;
    if (textBillboardObjects.isNotEmpty) {
      actualTextTriangles = await _processTextBillboards(textBillboardObjects);
    }

    // Performance metrics calculation using ACTUAL measured values
    _actualPolygons =
        actualLineTriangles + actualRectangleTriangles + actualTextTriangles;

    // Draw calls: lines + filled rectangles (each rectangle creates 2 draw calls: fill + edges) + text billboards + machine position (6 faces * 2 draw calls each)
    _actualDrawCalls =
        (lineObjects.isNotEmpty ? 1 : 0) +
        (filledRectangleObjects.length * 2) +
        textBillboardObjects.length +
        (machinePositionObjects.isNotEmpty
            ? 12
            : 0); // 6 faces * 2 draw calls each

    // Initial camera setup - will be overridden by CameraDirector
    _setupInitialCamera();

    _sceneInitialized = true;
    AppLogger.info(
      'FlutterScene renderer setup complete with ${sceneData.objects.length} scene objects',
    );
    AppLogger.info('Lines: ${lineObjects.length} (line tessellated)');
    AppLogger.info(
      'Filled rectangles: ${filledRectangleObjects.length} (hybrid fill + edge rendering)',
    );
    AppLogger.info(
      'Text billboards: ${textBillboardObjects.length} (texture-based)',
    );
    AppLogger.info(
      'Machine position indicators: ${machinePositionObjects.length} (rendered as cubes)',
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
  void render(Canvas canvas, Size size, double rotationX, double rotationY, {double devicePixelRatio = 1.0}) {
    // Store device pixel ratio for billboard text scaling
    _devicePixelRatio = devicePixelRatio;
    
    // Camera state is now managed by CameraDirector and set via setCameraState()
    // rotationX and rotationY parameters are ignored

    // Update resolution for pixel-perfect line rendering if viewport size changed
    if (_sceneData != null &&
        (size.width != _lastViewportSize?.width ||
            size.height != _lastViewportSize?.height)) {
      _updateViewportResolution(size);
    }

    if (!_sceneInitialized) return;

    // High-performance machine position update from SceneManager
    final machinePosition = SceneManager.instance.currentMachinePosition;
    if (machinePosition != null) {
      // Add cube to scene if not present and position is available
      if (_machinePositionCubeNode == null) {
        _setupMachinePositionCubeFromPosition();
      }

      // Update cube position via transform
      if (_machinePositionCubeNode != null) {
        final transform = vm.Matrix4.identity();
        transform.setTranslation(machinePosition);
        _machinePositionCubeNode!.localTransform = transform;
      }
    } else {
      // Remove cube from scene if position is null
      if (_machinePositionCubeNode != null) {
        _rootNode.children.remove(_machinePositionCubeNode!);
        _machinePositionCubeNode = null;
      }
    }

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

  /// Create cube visualization for machine position indicator
  /// This is where the renderer decides HOW to visualize the logical machine position
  List<Node> _createMachinePositionCubeVisualization(SceneObject indicator) {
    final nodes = <Node>[];

    // Get current viewport resolution for line edges
    final currentResolution = _lastViewportSize != null
        ? vm.Vector2(_lastViewportSize!.width, _lastViewportSize!.height)
        : vm.Vector2(1024, 768); // Default resolution

    // Renderer decides the visual representation: 3x3x3 cube with themed colors
    const double cubeSize = 3.0;
    const double halfSize = cubeSize / 2.0;

    // Import theme colors here in the renderer where they belong
    const double opacity = 0.7; // VisualizerTheme.machinePositionCubeOpacity
    const double edgeWidth =
        2.0; // VisualizerTheme.machinePositionCubeEdgeWidth

    // Define colors in renderer (could be moved to a renderer theme later)
    const xyFaceColor = Color(0xFF4CAF50); // Green for XY faces
    const xzFaceColor = Color(0xFF2196F3); // Blue for XZ faces
    const yzFaceColor = Color(0xFFF44336); // Red for YZ faces

    // Create cube faces as filled rectangles (squares with equal width/height)
    final cubeRectangles = <SceneObject>[
      // XY plane faces (top and bottom)
      SceneObject(
        type: SceneObjectType.filledRectangle,
        center: vm.Vector3(0, 0, halfSize), // Top face
        width: cubeSize,
        height: cubeSize,
        plane: RectanglePlane.xy,
        fillColor: xyFaceColor,
        edgeColor: xyFaceColor.withValues(alpha: 1.0),
        opacity: opacity,
        edgeWidth: edgeWidth,
        color: xyFaceColor,
        id: '${indicator.id}_face_top_xy',
      ),
      SceneObject(
        type: SceneObjectType.filledRectangle,
        center: vm.Vector3(0, 0, -halfSize), // Bottom face
        width: cubeSize,
        height: cubeSize,
        plane: RectanglePlane.xy,
        fillColor: xyFaceColor.withValues(alpha: 0.6),
        edgeColor: xyFaceColor.withValues(alpha: 1.0),
        opacity: opacity,
        edgeWidth: edgeWidth,
        color: xyFaceColor,
        id: '${indicator.id}_face_bottom_xy',
      ),

      // XZ plane faces (front and back)
      SceneObject(
        type: SceneObjectType.filledRectangle,
        center: vm.Vector3(0, halfSize, 0), // Front face
        width: cubeSize,
        height: cubeSize,
        plane: RectanglePlane.xz,
        fillColor: xzFaceColor,
        edgeColor: xzFaceColor.withValues(alpha: 1.0),
        opacity: opacity,
        edgeWidth: edgeWidth,
        color: xzFaceColor,
        id: '${indicator.id}_face_front_xz',
      ),
      SceneObject(
        type: SceneObjectType.filledRectangle,
        center: vm.Vector3(0, -halfSize, 0), // Back face
        width: cubeSize,
        height: cubeSize,
        plane: RectanglePlane.xz,
        fillColor: xzFaceColor.withValues(alpha: 0.6),
        edgeColor: xzFaceColor.withValues(alpha: 1.0),
        opacity: opacity,
        edgeWidth: edgeWidth,
        color: xzFaceColor,
        id: '${indicator.id}_face_back_xz',
      ),

      // YZ plane faces (left and right)
      SceneObject(
        type: SceneObjectType.filledRectangle,
        center: vm.Vector3(halfSize, 0, 0), // Right face
        width: cubeSize,
        height: cubeSize,
        plane: RectanglePlane.yz,
        fillColor: yzFaceColor,
        edgeColor: yzFaceColor.withValues(alpha: 1.0),
        opacity: opacity,
        edgeWidth: edgeWidth,
        color: yzFaceColor,
        id: '${indicator.id}_face_right_yz',
      ),
      SceneObject(
        type: SceneObjectType.filledRectangle,
        center: vm.Vector3(-halfSize, 0, 0), // Left face
        width: cubeSize,
        height: cubeSize,
        plane: RectanglePlane.yz,
        fillColor: yzFaceColor.withValues(alpha: 0.6),
        edgeColor: yzFaceColor.withValues(alpha: 1.0),
        opacity: opacity,
        edgeWidth: edgeWidth,
        color: yzFaceColor,
        id: '${indicator.id}_face_left_yz',
      ),
    ];

    // Process each filled rectangle into render nodes
    for (final rectangleObject in cubeRectangles) {
      try {
        final rectangleResult = FilledRectangleRenderer.createFromSceneObject(
          rectangleObject,
          resolution: currentResolution,
        );
        final rectangleNodes = rectangleResult.toNodes();
        nodes.addAll(rectangleNodes);
      } catch (e) {
        AppLogger.error(
          'Failed to process machine position cube face ${rectangleObject.id}: $e',
        );
      }
    }

    AppLogger.info(
      'Created machine position cube visualization with ${nodes.length} face nodes',
    );
    return nodes;
  }

  /// Set up machine position cube from current position (called dynamically from render loop)
  void _setupMachinePositionCubeFromPosition() {
    try {
      // Create a default machine position indicator
      final indicator = SceneObject(
        type: SceneObjectType.machinePosition,
        position: vm.Vector3.zero(),
        color: Colors.red,
        id: 'machine_position_indicator',
      );

      // Create a parent node for the cube visualization
      _machinePositionCubeNode = Node();
      _machinePositionCubeNode!.name = 'machine_position_indicator';

      // Create cube visualization for the machine position
      final cubeNodes = _createMachinePositionCubeVisualization(indicator);
      for (final node in cubeNodes) {
        _machinePositionCubeNode!.add(node);
      }

      // Add to root node
      _rootNode.add(_machinePositionCubeNode!);

      AppLogger.info(
        'Machine position cube created dynamically with ${cubeNodes.length} face nodes',
      );
    } catch (e) {
      AppLogger.error('Failed to setup machine position cube dynamically: $e');
      _machinePositionCubeNode = null;
    }
  }

  /// Set up machine position indicators for efficient transform updates
  Future<void> _setupMachinePositionIndicators(
    List<SceneObject> machinePositionObjects,
  ) async {
    try {
      if (machinePositionObjects.isEmpty) {
        AppLogger.debug('No machine position indicators found in scene');
        return;
      }

      // Clear any existing machine position cube node
      if (_machinePositionCubeNode != null) {
        _rootNode.children.remove(_machinePositionCubeNode!);
        _machinePositionCubeNode = null;
      }

      // For now, we only handle the first machine position indicator
      final indicator = machinePositionObjects.first;

      // Create a parent node for the cube visualization
      _machinePositionCubeNode = Node();
      _machinePositionCubeNode!.name = 'machine_position_indicator';

      // Create cube visualization for the machine position
      final cubeNodes = _createMachinePositionCubeVisualization(indicator);
      for (final node in cubeNodes) {
        _machinePositionCubeNode!.add(node);
      }

      // Add to root node
      _rootNode.add(_machinePositionCubeNode!);

      AppLogger.info(
        'Machine position indicator setup with ${cubeNodes.length} cube face nodes',
      );
    } catch (e) {
      AppLogger.error('Failed to setup machine position indicators: $e');
      _machinePositionCubeNode = null;
    }
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

  /// Process filled rectangle objects using FilledRectangleRenderer
  Future<int> _processFilledRectangles(
    List<SceneObject> filledRectangleObjects,
  ) async {
    try {
      // Filter out machine position cube objects (they're handled separately)
      final regularRectangleObjects = filledRectangleObjects
          .where((obj) => !obj.id.startsWith('machine_position_cube_'))
          .toList();

      AppLogger.info(
        'Processing ${regularRectangleObjects.length} filled rectangles with FilledRectangleRenderer (${filledRectangleObjects.length - regularRectangleObjects.length} machine position cube objects excluded)',
      );

      // Get current viewport resolution for line edges
      final currentResolution = _lastViewportSize != null
          ? vm.Vector2(_lastViewportSize!.width, _lastViewportSize!.height)
          : vm.Vector2(1024, 768); // Default resolution

      int totalTriangles = 0;

      // Process each filled rectangle individually
      for (final rectangleObject in regularRectangleObjects) {
        try {
          // Create filled rectangle with both fill and edge meshes
          final rectangleResult = FilledRectangleRenderer.createFromSceneObject(
            rectangleObject,
            resolution: currentResolution,
          );

          // Add both fill and edge nodes to the scene
          final nodes = rectangleResult.toNodes();
          for (final node in nodes) {
            _rootNode.add(node);
          }

          // Count triangles: 2 for fill + variable for edges (depends on line tessellation)
          // For now, estimate 2 triangles for fill + 8 for edges (4 line segments * 2 triangles each)
          totalTriangles += 2 + 8; // Approximation

          AppLogger.info(
            'Filled rectangle processed: ${rectangleResult.id} (fill + edges)',
          );
        } catch (e) {
          AppLogger.error(
            'Failed to process filled rectangle ${rectangleObject.id}: $e',
          );
        }
      }

      AppLogger.info(
        'FilledRectangleRenderer processing complete: ${regularRectangleObjects.length} rectangles -> ~$totalTriangles triangles',
      );

      return totalTriangles;
    } catch (e) {
      AppLogger.error(
        'FilledRectangleRenderer processing failed - filled rectangles will not be rendered: $e',
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

          // Create text texture from the billboard text
          final textTexture = await TextTextureFactory.createTextTexture(
            text: billboardObject.text ?? '?', // Use '?' as fallback if no text
            textStyle:
                billboardObject.textStyle ??
                const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
            backgroundColor: Colors.transparent,
            renderScale: _devicePixelRatio, // Match texture resolution to display resolution
          );

          final billboardSize = vm.Vector2(
            textTexture.textWidth * _devicePixelRatio,
            textTexture.textHeight * _devicePixelRatio,
          );
          
          // Debug logging for device pixel ratio scaling
          AppLogger.debug('Billboard text scaling: textWidth=${textTexture.textWidth}, textHeight=${textTexture.textHeight}, devicePixelRatio=$_devicePixelRatio, renderScale=$_devicePixelRatio, scaledSize=(${billboardSize.x}, ${billboardSize.y})');

          // Get current viewport resolution for pixel-perfect billboard rendering
          final currentResolution = _lastViewportSize != null
              ? vm.Vector2(_lastViewportSize!.width, _lastViewportSize!.height)
              : vm.Vector2(1024, 768); // Default resolution

          // Create textured billboard node with the text texture
          final billboardNode = BillboardRenderer.createTexturedBillboard(
            position: billboardObject.center!,
            size: billboardSize,
            texture: textTexture.texture,
            viewportWidth: currentResolution.x,
            viewportHeight: currentResolution.y,
            tintColor: billboardObject.color,
            opacity: billboardObject.opacity ?? 1.0,
            id: billboardObject.id,
          );

          // Add to scene
          _rootNode.add(billboardNode);

          // Each billboard uses 2 triangles (quad)
          totalTriangles += 2;
        } catch (e) {
          AppLogger.error(
            'Failed to process text billboard ${billboardObject.id}: $e',
          );
        }
      }

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
  ///
  /// Transforms a billboard to face the camera while maintaining its world position.
  /// Applies transformations in the correct order: Position * CoordinateTransform * (Rotation * Scale)
  void _updateBillboardTransform(
    Node billboardNode,
    vm.Vector3 cameraPosition,
    Size viewportSize,
  ) {
    // Get the current position from the transform
    final currentTransform = billboardNode.localTransform;
    final billboardPosition = currentTransform.getTranslation();

    // Parse billboard metadata to determine if screen-space scaling is needed
    final billboardInfo = _parseBillboardMetadata(billboardNode.name);

    // Step 1: Calculate camera-facing rotation in billboard's local coordinate system
    final billboardRotation = _calculateBillboardRotation(
      billboardPosition,
      cameraPosition,
      viewportSize,
    );

    // Step 2: Apply screen-space scaling to the rotation matrix if needed
    // This must be done BEFORE coordinate transformation to avoid Y-axis issues
    final scaledBillboardRotation = _applyScreenSpaceScaling(
      rotation: billboardRotation,
      billboardInfo: billboardInfo,
      billboardPosition: billboardPosition,
      cameraPosition: cameraPosition,
      viewportSize: viewportSize,
    );

    // Step 3: Apply coordinate system transformation for CNC->Impeller conversion
    // This ensures the billboard orientation works correctly with the Y-negated root transform
    final coordinateTransformedRotation = _applyCoordinateTransformToBillboard(
      scaledBillboardRotation,
    );

    // Step 4: Compose final transform with proper position
    final finalTransform = _composeBillboardTransform(
      rotation: coordinateTransformedRotation,
      position: billboardPosition,
      scale: 1.0, // Scale is already applied to rotation matrix
    );

    billboardNode.localTransform = finalTransform;
  }

  /// Calculate billboard rotation matrix to face the camera
  ///
  /// Returns a rotation matrix in billboard's local coordinate system
  vm.Matrix4 _calculateBillboardRotation(
    vm.Vector3 billboardPosition,
    vm.Vector3 cameraPosition,
    Size viewportSize,
  ) {
    return _calculateBillboardLookAt(
      billboardPosition,
      cameraPosition,
      viewportSize,
    );
  }

  /// Apply screen-space scaling to billboard rotation matrix
  ///
  /// If billboard uses screen-space sizing, scales the rotation matrix to maintain constant pixel size.
  /// This must be applied BEFORE coordinate transformation to avoid Y-axis scaling issues.
  vm.Matrix4 _applyScreenSpaceScaling({
    required vm.Matrix4 rotation,
    required _BillboardMetadata? billboardInfo,
    required vm.Vector3 billboardPosition,
    required vm.Vector3 cameraPosition,
    required Size viewportSize,
  }) {
    // All billboards now use pixel-accurate sizing, so always apply rotation
    if (billboardInfo == null) {
      return rotation;
    }

    // Calculate screen-space scale factor
    final scale = _calculateScreenSpaceScale(
      billboardPosition,
      cameraPosition,
      billboardInfo.pixelSize,
      viewportSize,
    );

    // Apply scale to rotation matrix by post-multiplying with scale matrix
    // This scales the billboard in its local coordinate system
    final scaleMatrix = vm.Matrix4.identity()
      ..scaleByDouble(scale, scale, 1.0, 1.0);
    return rotation * scaleMatrix;
  }

  /// Apply coordinate system transformation to billboard rotation
  ///
  /// Transforms the billboard rotation from CNC coordinates to Impeller coordinates
  vm.Matrix4 _applyCoordinateTransformToBillboard(
    vm.Matrix4 billboardRotation,
  ) {
    return _cncToImpellerCoordinateTransform * billboardRotation;
  }

  /// Compose final billboard transform from components
  ///
  /// Combines rotation, scale, and position into final transformation matrix
  vm.Matrix4 _composeBillboardTransform({
    required vm.Matrix4 rotation,
    required vm.Vector3 position,
    required double scale,
  }) {
    // For now, just apply rotation and position (scale will be added later)
    final finalTransform = rotation.clone();
    finalTransform.setTranslation(position);
    return finalTransform;
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

  /// Parse billboard metadata from node name
  ///
  /// Node names are encoded as: 'billboard_{id}_{sizeMode}_{pixelSize}'
  /// Example: 'billboard_axis_label_x_screenSpace_24.0'
  /// Returns null if name doesn't contain metadata (preserves backward compatibility)
  _BillboardMetadata? _parseBillboardMetadata(String nodeName) {
    final parts = nodeName.split('_');

    // Expected format: billboard_{id}_{sizeMode}_{pixelSize}
    // Minimum parts: ['billboard', id, sizeMode, pixelSize]
    if (parts.length < 4) {
      return null; // Old format or invalid name - use default behavior
    }

    try {
      // Size mode is no longer used - all billboards use pixel sizing

      // Extract pixel size (last part)
      final pixelSizeStr = parts[parts.length - 1];
      final pixelSize = double.tryParse(pixelSizeStr) ?? 24.0;

      return _BillboardMetadata(pixelSize: pixelSize);
    } catch (e) {
      // Failed to parse - return null to use default behavior
      return null;
    }
  }

  /// Calculate screen-space scale factor for a billboard
  ///
  /// This calculates the scale needed to maintain constant pixel size
  /// regardless of camera distance.
  double _calculateScreenSpaceScale(
    vm.Vector3 billboardPosition,
    vm.Vector3 cameraPosition,
    double targetPixelSize,
    Size viewportSize,
  ) {
    // Calculate camera distance to billboard
    // Both positions are already in transformed (display) coordinate space
    final cameraDistance = ScreenSpaceUtils.calculateCameraDistance(
      cameraPosition,
      billboardPosition,
    );

    // Get camera field of view
    final fovRadians = camera.fovRadiansY;

    // Calculate required world size for target pixel size
    final requiredWorldSize = ScreenSpaceUtils.pixelSizeToWorldSize(
      targetPixelSize,
      cameraDistance,
      fovRadians,
      vm.Vector2(viewportSize.width, viewportSize.height),
    );

    // The original billboard was created with worldSize = 10.0 (default in createTextBillboard)
    const double originalWorldSize = 10.0;
    final scale = requiredWorldSize / originalWorldSize;

    return scale;
  }

  @override
  void dispose() {
    _rootNode.children.clear();
    _combinedMeshNode.mesh = null;
    _machinePositionCubeNode = null; // Clear machine position cube reference
    // LineMeshFactory doesn't require disposal - it's a static factory
    _sceneData = null;
  }
}

/// Helper class to store billboard metadata parsed from node names
class _BillboardMetadata {
  final double pixelSize;

  const _BillboardMetadata({required this.pixelSize});
}
