import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import '../scene.dart';
import '../scene/scene_manager.dart';
import 'renderer_interface.dart';

class FilamentRenderer implements Renderer {
  bool _initialized = false;
  
  // Performance metrics to match other renderers
  int _actualPolygons = 0;
  int _actualDrawCalls = 0;
  
  // Camera and interaction state
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  
  // Scene data received from SceneManager
  SceneData? _sceneData;
  
  // Cache the widget to prevent recreation
  Widget? _cachedWidget;
  ThermionViewer? _viewer;
  
  // Resource tracking for cleanup
  final List<ThermionAsset> _createdAssets = [];
  final List<MaterialInstance> _createdMaterials = [];
  
  // Getter methods to match other renderer interfaces
  bool get initialized => _initialized;
  int get actualPolygons => _actualPolygons;
  int get actualDrawCalls => _actualDrawCalls;

  @override
  Future<bool> initialize() async {
    try {
      print('=== INITIALIZING FILAMENT RENDERER ===');
      
      _initialized = true;
      print('Filament renderer prepared successfully');
      return true;
    } catch (e) {
      print('Filament renderer initialization failed: $e');
      return false;
    }
  }
  
  @override
  Future<void> setupScene(SceneData sceneData) async {
    _sceneData = sceneData;
    
    // Calculate performance metrics based on scene data
    final cubeObjects = sceneData.objects.where((obj) => obj.type == SceneObjectType.cube).length;
    final axisObjects = sceneData.objects.where((obj) => obj.type == SceneObjectType.axis).length;
    _actualPolygons = (cubeObjects * 12) + (axisObjects * 12); // 12 triangles per cube/axis
    _actualDrawCalls = sceneData.objects.length; // One draw call per object
    
    print('=== FILAMENT SCENE SETUP ===');
    print('Scene objects: ${sceneData.objects.length}');
    print('Cubes: $cubeObjects, Axes: $axisObjects');
    print('Estimated Draw Calls: $_actualDrawCalls');
    print('Total Polygons: $_actualPolygons');
    print('===========================');
  }
  
  @override
  void updateRotation(double rotationX, double rotationY) {
    _rotationX = rotationX;
    _rotationY = rotationY;
    // Update camera if viewer exists
    if (_viewer != null) {
      _updateCamera();
    }
  }
  
  Future<void> _updateCamera() async {
    if (_viewer == null) return;
    final camera = await _viewer!.getActiveCamera();
    final distance = 50.0;
    final x = distance * math.sin(_rotationY) * math.cos(_rotationX);
    final y = distance * math.sin(_rotationX);
    final z = distance * math.cos(_rotationY) * math.cos(_rotationX);
    await camera.lookAt(vm.Vector3(x, y, z), focus: vm.Vector3.zero());
  }
  
  @override
  void render(Canvas canvas, Size size, double rotationX, double rotationY) {
    // Not used for Filament - widget handles its own rendering
    if (_rotationX != rotationX || _rotationY != rotationY) {
      updateRotation(rotationX, rotationY);
    }
  }
  
  @override
  Widget createWidget() {
    if (!_initialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Create ViewerWidget only once and cache it - this is the key to preventing crashes
    _cachedWidget ??= ViewerWidget(
      initial: Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Loading Filament Scene...',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
      showFpsCounter: false,
      transformToUnitCube: false,
      postProcessing: true,
      background: Colors.black,
      destroyEngineOnUnload: false, // Critical: keep engine alive
      manipulatorType: ManipulatorType.NONE, // We handle rotation manually
      onViewerAvailable: (viewer) async {
        _viewer = viewer;
        await _setupScene(viewer);
      },
    );
    
    return _cachedWidget!;
  }
  
  Future<void> _setupScene(ThermionViewer viewer) async {
    try {
      if (_sceneData == null) {
        print('No scene data available for Filament renderer');
        return;
      }
      
      print('=== Setting up Filament scene from SceneManager data ===');
      
      // Add lighting using scene configuration
      if (_sceneData!.lighting.directionalLight != null) {
        final lightData = _sceneData!.lighting.directionalLight!;
        final directLight = DirectLight.sun(
          color: 6500,
          intensity: 100000,
          direction: lightData.direction,
          castShadows: false,
        );
        await viewer.addDirectLight(directLight);
      }
      
      // Setup camera using scene configuration
      final camera = await viewer.getActiveCamera();
      await camera.lookAt(
        _sceneData!.camera.position, 
        focus: _sceneData!.camera.target
      );
      
      // Create geometry for cubes and axes
      final cubeGeometry = GeometryHelper.cube(flipUvs: true);
      
      int objectsCreated = 0;
      
      // Create all scene objects
      for (final sceneObject in _sceneData!.objects) {
        if (!_initialized) {
          print('Renderer disposed during scene creation, stopping at $objectsCreated objects');
          break;
        }
        
        try {
          // Create material
          final materialInstance = await FilamentApp.instance!
              .createUbershaderMaterialInstance(unlit: true);
          
          // Set color
          await materialInstance.setParameterFloat4(
            "baseColorFactor", 
            sceneObject.color.red / 255.0, 
            sceneObject.color.green / 255.0, 
            sceneObject.color.blue / 255.0, 
            1.0
          );
          
          // Create asset
          final asset = await viewer.createGeometry(
            cubeGeometry, 
            materialInstances: [materialInstance]
          );
          
          // Track resources for cleanup
          _createdAssets.add(asset);
          _createdMaterials.add(materialInstance);
          
          // Position and scale object using its transform matrix
          await asset.setTransform(sceneObject.transformMatrix);
          
          objectsCreated++;
          
          if (objectsCreated % 100 == 0 && objectsCreated > 0) {
            print('Created $objectsCreated/${_sceneData!.objects.length} scene objects...');
          }
          
        } catch (e) {
          print('Error creating scene object ${sceneObject.id}: $e');
        }
      }
      
      print('Filament scene creation complete: $objectsCreated objects created');
      print('Scene matches other renderers exactly (unified scene data)');
      
    } catch (e, stackTrace) {
      print('Error setting up Filament scene: $e');
      print('Stack trace: $stackTrace');
    }
  }
  
  // Removed _add3DAxes - axes are now created from scene data like all other objects
  
  // Removed _addAxis - axes are now created from scene data like all other objects
  
  @override
  void dispose() {
    print('=== FILAMENT RENDERER: dispose() called ===');
    _initialized = false;
    _cachedWidget = null;
    _viewer = null;
    _sceneData = null;
    // ViewerWidget will handle its own cleanup properly
    print('=== FILAMENT RENDERER: dispose() complete ===');
  }
}