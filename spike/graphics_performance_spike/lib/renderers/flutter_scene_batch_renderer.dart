import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../scene.dart';

class FlutterSceneBatchRenderer {
  Scene scene = Scene();
  PerspectiveCamera camera = PerspectiveCamera();
  bool _sceneInitialized = false;
  int _actualPolygons = 0;
  int _actualDrawCalls = 0;
  
  // Root node for applying interactive rotation to all cubes
  Node _rootNode = Node();
  
  Future<void> initialize() async {
    await Scene.initializeStaticResources();
    
    // Add root node to scene for rotation control
    scene.add(_rootNode);
    
    // Add 3D coordinate axes to root node
    _add3DAxes();
    
    // Get all cube data from shared scene configuration
    final cubeDataList = SceneConfiguration.getAllCubeData();
    
    print('Creating ${SceneConfiguration.totalCubes} positioned and colored cubes...');
    
    // Create individual nodes for each cube with proper positioning and coloring
    for (final cubeData in cubeDataList) {
      // Create cube geometry with the size from scene config
      final geometry = CuboidGeometry(vm.Vector3(cubeData.size, cubeData.size, cubeData.size));
      
      // Create material with the color from scene config
      final material = UnlitMaterial();
      material.baseColorFactor = vm.Vector4(
        cubeData.color.red / 255.0,
        cubeData.color.green / 255.0,
        cubeData.color.blue / 255.0,
        cubeData.color.alpha / 255.0,
      );
      
      // Create mesh primitive
      final primitive = MeshPrimitive(geometry, material);
      final mesh = Mesh.primitives(primitives: [primitive]);
      
      // Create node with proper positioning
      final node = Node();
      node.mesh = mesh;
      node.localTransform = vm.Matrix4.translation(
        vm.Vector3(cubeData.position.x, cubeData.position.y, cubeData.position.z)
      );
      
      // Add to root node instead of scene directly
      _rootNode.add(node);
    }
    
    // Performance metrics
    _actualDrawCalls = SceneConfiguration.totalCubes; // One draw call per node
    _actualPolygons = SceneConfiguration.totalCubes * 12; // cubes × 12 triangles each
    
    print('=== FLUTTER_SCENE BATCHING RESULTS ===');
    print('Cubes created: ${SceneConfiguration.totalCubes}');
    print('Nodes created: ${SceneConfiguration.totalCubes}');
    print('Expected draw calls: $_actualDrawCalls');
    print('Total polygons: $_actualPolygons');
    print('=====================================');
    
    // Setup stationary camera
    camera.position = vm.Vector3(0, SceneConfiguration.cameraY, SceneConfiguration.cameraDistance);
    camera.target = vm.Vector3(0, 0, 0);
    
    _sceneInitialized = true;
  }
  
  void updateRotation(double rotationX, double rotationY) {
    // Apply interactive rotation to root node containing all cubes and axes
    final rotationMatrixX = vm.Matrix4.rotationX(rotationX);
    final rotationMatrixY = vm.Matrix4.rotationY(rotationY);
    final combinedRotation = rotationMatrixY * rotationMatrixX;
    
    _rootNode.localTransform = combinedRotation;
  }
  
  void render(Canvas canvas, Size size) {
    if (!_sceneInitialized) return;
    
    // Clear the canvas with black background to match GPU renderer
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );
    
    scene.render(camera, canvas, viewport: Offset.zero & size);
  }
  
  int get actualDrawCalls => _actualDrawCalls;
  int get actualPolygons => _actualPolygons;
  bool get initialized => _sceneInitialized;
  
  void _add3DAxes() {
    const axisLength = 100.0;
    const axisThickness = 1.0;
    
    // X-axis (Red)
    _addAxis(
      vm.Vector3(axisLength / 2, 0, 0), 
      vm.Vector3(axisLength, axisThickness, axisThickness),
      vm.Vector4(1.0, 0.0, 0.0, 1.0) // Red
    );
    
    // Y-axis (Green)  
    _addAxis(
      vm.Vector3(0, axisLength / 2, 0),
      vm.Vector3(axisThickness, axisLength, axisThickness),
      vm.Vector4(0.0, 1.0, 0.0, 1.0) // Green
    );
    
    // Z-axis (Blue)
    _addAxis(
      vm.Vector3(0, 0, axisLength / 2),
      vm.Vector3(axisThickness, axisThickness, axisLength),
      vm.Vector4(0.0, 0.0, 1.0, 1.0) // Blue
    );
    
    // Origin point (White)
    _addAxis(
      vm.Vector3(0, 0, 0),
      vm.Vector3(4.0, 4.0, 4.0),
      vm.Vector4(1.0, 1.0, 1.0, 1.0) // White
    );
  }
  
  void _addAxis(vm.Vector3 position, vm.Vector3 scale, vm.Vector4 color) {
    final axisGeometry = CuboidGeometry(vm.Vector3(1.0, 1.0, 1.0));
    final axisMaterial = UnlitMaterial();
    axisMaterial.baseColorFactor = color;
    
    final axisPrimitive = MeshPrimitive(axisGeometry, axisMaterial);
    final axisMesh = Mesh.primitives(primitives: [axisPrimitive]);
    
    final axisNode = Node();
    axisNode.mesh = axisMesh;
    axisNode.localTransform = vm.Matrix4.identity()
      ..translate(position)
      ..scale(scale);
    
    _rootNode.add(axisNode);
  }

  void dispose() {
    // flutter_scene handles cleanup
  }
}