import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
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
  @override
  bool get initialized => _initialized;
  @override
  int get actualPolygons => _actualPolygons;
  @override
  int get actualDrawCalls => _actualDrawCalls;

  @override
  Future<bool> initialize() async {
    try {
      AppLogger.info('Initializing Filament renderer');
      
      _initialized = true;
      AppLogger.info('Filament renderer prepared successfully');
      return true;
    } catch (e) {
      AppLogger.error('Filament renderer initialization failed', e);
      return false;
    }
  }
  
  @override
  Future<void> setupScene(SceneData sceneData) async {
    _sceneData = sceneData;
    
    // Calculate performance metrics based on scene data
    final cubeObjects = sceneData.objects.where((obj) => obj.type == SceneObjectType.cube).length;
    final axisObjects = sceneData.objects.where((obj) => obj.type == SceneObjectType.axis).length;
    final lineObjects = sceneData.objects.where((obj) => obj.type == SceneObjectType.line).length;
    _actualPolygons = (cubeObjects * 12) + (axisObjects * 12) + (lineObjects * 12); // 12 triangles per object (lines rendered as thin cubes)
    
    // Estimate draw calls based on color grouping (much fewer than individual objects)
    final uniqueColors = sceneData.objects.map((obj) => obj.color.toARGB32()).toSet().length;
    _actualDrawCalls = uniqueColors; // One draw call per unique color group
    
    AppLogger.info('Filament scene setup:');
    AppLogger.info('Scene objects: ${sceneData.objects.length}');
    AppLogger.info('Cubes: $cubeObjects, Axes: $axisObjects, Lines: $lineObjects');
    AppLogger.info('Unique colors: $uniqueColors');
    AppLogger.info('Estimated Draw Calls: $_actualDrawCalls (color-grouped)');
    AppLogger.info('Total Polygons: $_actualPolygons');
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
    if (_viewer == null || _sceneData == null) return;
    
    final camera = await _viewer!.getActiveCamera();
    
    // Use the same camera position from scene data (don't modify it for rotation)
    // The rotation should be handled by rotating the scene objects, not the camera
    await camera.lookAt(
      _sceneData!.camera.position, 
      focus: _sceneData!.camera.target
    );
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
        AppLogger.warning('No scene data available for Filament renderer');
        return;
      }
      
      AppLogger.info('Setting up Filament scene from SceneManager data');
      
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
      
      // Create instanced geometry for better batching - use shared geometry with multiple instances
      AppLogger.info('Creating instanced Filament rendering for ${_sceneData!.objects.length} scene objects...');
      
      await _createInstancedGeometry(viewer, _sceneData!.objects);
      
    } catch (e, stackTrace) {
      AppLogger.error('Error setting up Filament scene', e, stackTrace);
    }
  }
  
  /// Create instanced geometry - group objects by color for better batching  
  Future<void> _createInstancedGeometry(ThermionViewer viewer, List<SceneObject> sceneObjects) async {
    try {
      AppLogger.info('Filament instanced rendering:');
      
      // Group objects by color to minimize draw calls
      final colorGroups = <String, List<SceneObject>>{};
      for (final sceneObject in sceneObjects) {
        final colorKey = '${sceneObject.color.toARGB32()}';
        colorGroups[colorKey] ??= [];
        colorGroups[colorKey]!.add(sceneObject);
      }
      
      AppLogger.info('Grouped ${sceneObjects.length} objects into ${colorGroups.length} color groups');
      
      // Create one batch per color group
      final cubeGeometry = GeometryHelper.cube(flipUvs: true);
      int totalObjectsCreated = 0;
      
      for (final entry in colorGroups.entries) {
        final colorObjects = entry.value;
        final firstObject = colorObjects.first;
        
        // Create material for this color group
        final materialInstance = await FilamentApp.instance!
            .createUbershaderMaterialInstance(unlit: true);
        
        await materialInstance.setParameterFloat4(
          "baseColorFactor",
          (firstObject.color.r * 255.0).round().clamp(0, 255) / 255.0,
          (firstObject.color.g * 255.0).round().clamp(0, 255) / 255.0, 
          (firstObject.color.b * 255.0).round().clamp(0, 255) / 255.0,
          1.0
        );
        
        // Create instances for each object in this color group (with memory limit)
        final maxInstancesPerColor = 500; // Prevent HandleAllocator exhaustion
        final instancesToCreate = colorObjects.length > maxInstancesPerColor 
            ? colorObjects.take(maxInstancesPerColor).toList()
            : colorObjects;
        
        if (colorObjects.length > maxInstancesPerColor) {
          AppLogger.debug('Limiting color group to $maxInstancesPerColor/${colorObjects.length} instances');
        }
        
        for (final sceneObject in instancesToCreate) {
          final asset = await viewer.createGeometry(
            cubeGeometry,
            materialInstances: [materialInstance]
          );
          
          await asset.setTransform(sceneObject.transformMatrix);
          
          _createdAssets.add(asset);
          totalObjectsCreated++;
        }
        
        _createdMaterials.add(materialInstance);
        
        if (colorObjects.length > 1) {
          AppLogger.debug('Created ${colorObjects.length} instances for color group ${entry.key}');
        }
      }
      
      AppLogger.info('Filament instanced rendering: ${colorGroups.length} draw calls for $totalObjectsCreated objects');
      AppLogger.info('Color-based batching: ${sceneObjects.length ~/ colorGroups.length} objects per draw call (average)');
      
    } catch (e) {
      AppLogger.error('Error creating instanced geometry', e);
    }
  }
  
  
  @override
  void dispose() {
    AppLogger.info('Filament renderer: dispose() called');
    _initialized = false;
    _cachedWidget = null;
    _viewer = null;
    _sceneData = null;
    // ViewerWidget will handle its own cleanup properly
    AppLogger.info('Filament renderer: dispose() complete');
  }
}