import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../scene.dart';
import '../scene/scene_manager.dart';
import 'renderer_interface.dart';

class FlutterSceneBatchRenderer implements Renderer {
  Scene scene = Scene();
  PerspectiveCamera camera = PerspectiveCamera();
  bool _initialized = false;
  bool _sceneInitialized = false;
  int _actualPolygons = 0;
  int _actualDrawCalls = 0;
  
  // Scene data received from SceneManager
  SceneData? _sceneData;
  
  // Root node for applying interactive rotation to all cubes
  Node _rootNode = Node();
  
  // Interactive rotation state
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  
  @override
  Future<bool> initialize() async {
    try {
      await Scene.initializeStaticResources();
      
      // Add root node to scene for rotation control
      scene.add(_rootNode);
      
      _initialized = true;
      print('FlutterScene renderer initialized successfully');
      return true;
    } catch (e) {
      print('FlutterScene renderer initialization failed: $e');
      return false;
    }
  }
  
  @override
  Future<void> setupScene(SceneData sceneData) async {
    _sceneData = sceneData;
    
    // Clear any existing scene objects
    _rootNode.children.clear();
    
    print('Creating scene objects from SceneManager data...');
    
    int objectsCreated = 0;
    
    // Create individual nodes for each scene object
    for (final sceneObject in sceneData.objects) {
      // Convert scale to flutter_scene vector type
      final scale = vm.Vector3(sceneObject.scale.x, sceneObject.scale.y, sceneObject.scale.z);
      
      // Create cube geometry with the scale from scene data  
      final geometry = CuboidGeometry(scale);
      
      // Create material with the color from scene data
      final material = UnlitMaterial();
      material.baseColorFactor = vm.Vector4(
        sceneObject.color.red / 255.0,
        sceneObject.color.green / 255.0,
        sceneObject.color.blue / 255.0,
        sceneObject.color.alpha / 255.0,
      );
      
      // Create mesh primitive
      final primitive = MeshPrimitive(geometry, material);
      final mesh = Mesh.primitives(primitives: [primitive]);
      
      // Create node with proper positioning
      final node = Node();
      node.mesh = mesh;
      
      // Convert position to flutter_scene vector type  
      final position = vm.Vector3(sceneObject.position.x, sceneObject.position.y, sceneObject.position.z);
      
      node.localTransform = vm.Matrix4.identity()
        ..translate(position)
        ..scale(scale);
      
      // Add to root node for global rotation control
      _rootNode.add(node);
      
      objectsCreated++;
      if (objectsCreated % 100 == 0) {
        print('Created $objectsCreated/${sceneData.objects.length} scene objects...');
      }
    }
    
    // Performance metrics calculation
    _actualPolygons = sceneData.objects.length * 12; // 12 triangles per object
    _actualDrawCalls = sceneData.objects.length; // One draw call per object
    
    // Setup camera positioning from scene data
    _setupCamera();
    
    _sceneInitialized = true;
    print('FlutterScene renderer setup complete with ${sceneData.objects.length} scene objects');
    print('Performance: ${_actualPolygons} triangles in ${_actualDrawCalls} draw calls');
  }
  
  @override
  void updateRotation(double rotationX, double rotationY) {
    _rotationX = rotationX;
    _rotationY = rotationY;
    
    if (!_sceneInitialized) return;
    
    // Apply rotation to the root node (affects all objects)
    final rotationMatrix = vm.Matrix4.rotationY(_rotationY) * vm.Matrix4.rotationX(_rotationX);
    _rootNode.localTransform = rotationMatrix;
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
    
    // Use camera configuration from scene data
    camera.position = vm.Vector3(_sceneData!.camera.position.x, _sceneData!.camera.position.y, _sceneData!.camera.position.z);
    camera.target = vm.Vector3(_sceneData!.camera.target.x, _sceneData!.camera.target.y, _sceneData!.camera.target.z); 
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
  
  // Removed _add3DAxes and _addAxis - axes are now created from scene data like all other objects

  @override
  void dispose() {
    _rootNode.children.clear();
    _sceneData = null;
  }
}