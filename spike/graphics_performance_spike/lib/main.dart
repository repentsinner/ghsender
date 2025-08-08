import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'renderers/gpu_batch_renderer.dart';
import 'renderers/flutter_scene_batch_renderer.dart';
import 'renderers/filament_renderer.dart';
import 'scene/scene_manager.dart';
import 'renderers/renderer_interface.dart';

enum RendererType { gpu, flutterScene, filament }

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Graphics Performance Spike',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const GraphicsPerformanceScreen(),
    );
  }
}


class GraphicsPerformanceScreen extends StatefulWidget {
  const GraphicsPerformanceScreen({super.key});

  @override
  State<GraphicsPerformanceScreen> createState() => _GraphicsPerformanceScreenState();
}

class _GraphicsPerformanceScreenState extends State<GraphicsPerformanceScreen> {
  int _frameCount = 0;
  DateTime _lastFrameTime = DateTime.now();
  double _fps = 0.0;
  Ticker? _ticker;
  bool _renderersInitialized = false;
  
  // Interactive rotation control
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  Offset? _lastPanPosition;
  
  // Current active renderer
  RendererType _currentRenderer = RendererType.gpu;
  
  // Renderers implementing the common interface
  late Renderer _gpuRenderer;
  late Renderer _flutterSceneRenderer;
  late Renderer _filamentRenderer;
  
  static const int _targetDrawCalls = 10000;
  static const int _targetPolygons = 120000;
  List<double> _fpsSamples = [];

  @override
  void initState() {
    super.initState();
    _initializeBothRenderers();
  }

  void _initializeBothRenderers() async {
    print('=== INITIALIZING SCENE AND RENDERERS ===');
    
    // Initialize the shared scene first
    await SceneManager.instance.initialize();
    print('Shared scene initialized');
    
    // Initialize all renderers
    _gpuRenderer = GpuBatchRenderer();
    final gpuSuccess = await _gpuRenderer.initialize();
    if (gpuSuccess) {
      await _gpuRenderer.setupScene(SceneManager.instance.sceneData);
    }
    print('GPU renderer initialized: $gpuSuccess');
    
    _flutterSceneRenderer = FlutterSceneBatchRenderer();
    final flutterSceneSuccess = await _flutterSceneRenderer.initialize();
    if (flutterSceneSuccess) {
      await _flutterSceneRenderer.setupScene(SceneManager.instance.sceneData);
    }
    print('flutter_scene renderer initialized: $flutterSceneSuccess');
    
    _filamentRenderer = FilamentRenderer();
    final filamentSuccess = await _filamentRenderer.initialize();
    if (filamentSuccess) {
      await _filamentRenderer.setupScene(SceneManager.instance.sceneData);
    }
    print('filament renderer initialized: $filamentSuccess');
    
    _renderersInitialized = true;
    print('=== ALL RENDERERS READY - Starting with ${_currentRenderer.name.toUpperCase()} ===');

    _ticker = Ticker((_) {
      _frameCount++;
      final now = DateTime.now();
      final elapsed = now.difference(_lastFrameTime).inMilliseconds;

      // Update active renderer with current rotation
      switch (_currentRenderer) {
        case RendererType.gpu:
          _gpuRenderer.updateRotation(_rotationX, _rotationY);
          break;
        case RendererType.flutterScene:
          _flutterSceneRenderer.updateRotation(_rotationX, _rotationY);
          break;
        case RendererType.filament:
          _filamentRenderer.updateRotation(_rotationX, _rotationY);
          break;
      }

      setState(() {});

      if (elapsed >= 1000) {
        _fps = _frameCount * 1000 / elapsed;
        _fpsSamples.add(_fps);
        _frameCount = 0;
        _lastFrameTime = now;
      }
    });
    _ticker?.start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    if (_renderersInitialized) {
      _gpuRenderer.dispose();
      _flutterSceneRenderer.dispose();
      _filamentRenderer.dispose();
    }
    super.dispose();
  }
  
  Renderer? _getCurrentRenderer() {
    if (!_renderersInitialized) return null;
    switch (_currentRenderer) {
      case RendererType.gpu:
        return _gpuRenderer;
      case RendererType.flutterScene:
        return _flutterSceneRenderer;
      case RendererType.filament:
        return _filamentRenderer;
    }
  }
  
  String _getRendererDisplayName() {
    switch (_currentRenderer) {
      case RendererType.gpu:
        return 'GPU RENDERER';
      case RendererType.flutterScene:
        return 'FLUTTER_SCENE RENDERER';
      case RendererType.filament:
        return 'FILAMENT RENDERER';
    }
  }
  
  String _getRendererDetails() {
    switch (_currentRenderer) {
      case RendererType.gpu:
        return 'flutter_gpu batching';
      case RendererType.flutterScene:
        return 'MeshPrimitive batching';
      case RendererType.filament:
        return 'Filament PBR rendering';
    }
  }
  
  String _getNextRendererName() {
    switch (_currentRenderer) {
      case RendererType.gpu:
        return 'Flutter Scene';
      case RendererType.flutterScene:
        return 'Filament';
      case RendererType.filament:
        return 'GPU';
    }
  }
  
  Widget _buildRendererWidget() {
    if (!_renderersInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    switch (_currentRenderer) {
      case RendererType.gpu:
      case RendererType.flutterScene:
        // Canvas-based renderers use CustomPaint
        return CustomPaint(
          painter: _currentRenderer == RendererType.gpu
              ? GpuBatchPainter(
                  renderer: _gpuRenderer as GpuBatchRenderer,
                  rotationX: _rotationX,
                  rotationY: _rotationY,
                )
              : FlutterSceneBatchPainter(
                  renderer: _flutterSceneRenderer as FlutterSceneBatchRenderer,
                  rotationX: _rotationX,
                  rotationY: _rotationY,
                ),
        );
      case RendererType.filament:
        // Widget-based renderer returns its own widget
        return _filamentRenderer.createWidget();
    }
  }

  
  void _toggleRenderer() {
    setState(() {
      switch (_currentRenderer) {
        case RendererType.gpu:
          _currentRenderer = RendererType.flutterScene;
          break;
        case RendererType.flutterScene:
          _currentRenderer = RendererType.filament;
          break;
        case RendererType.filament:
          _currentRenderer = RendererType.gpu;
          break;
      }
      
      // Reset FPS samples when switching renderers
      _fpsSamples.clear();
      _frameCount = 0;
      _lastFrameTime = DateTime.now();
    });
    
    print('Switched to ${_currentRenderer.name.toUpperCase()} renderer');
  }

  @override
  Widget build(BuildContext context) {
    final currentRenderer = _getCurrentRenderer();
    final drawCalls = _renderersInitialized && currentRenderer != null
        ? currentRenderer.actualDrawCalls
        : 0;
    final polygons = _renderersInitialized && currentRenderer != null
        ? currentRenderer.actualPolygons
        : 0;
    final rendererName = _getRendererDisplayName();
    final rendererDetails = _getRendererDetails();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Graphics Performance Spike - $rendererName'),
      ),
      body: Stack(
        children: [
          // Active Renderer with Pan Gesture
          GestureDetector(
            onPanStart: (details) {
              _lastPanPosition = details.localPosition;
            },
            onPanUpdate: (details) {
              if (_lastPanPosition != null) {
                final delta = details.localPosition - _lastPanPosition!;
                setState(() {
                  _rotationY += delta.dx * 0.01; // Horizontal drag = Y rotation
                  _rotationX += delta.dy * 0.01; // Vertical drag = X rotation
                  _lastPanPosition = details.localPosition;
                });
              }
            },
            onPanEnd: (details) {
              _lastPanPosition = null;
            },
            child: SizedBox.expand(
              child: _buildRendererWidget(),
            ),
          ),
          // Performance Info
          Positioned(
            top: 16,
            left: 16,
            child: Text(
              '''$rendererName
FPS: ${_fps.toStringAsFixed(2)}
Polygons: ${(polygons / 1000).toStringAsFixed(1)}k
Draw Calls: $drawCalls
$rendererDetails

Use floating button to switch renderers
Click and drag to rotate the scene${_currentRenderer == RendererType.gpu ? '\nTop button toggles wireframe mode' : ''}''',
              style: const TextStyle(color: Colors.white, fontSize: 14, shadows: [
                Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Wireframe toggle (only show for GPU renderer)
          if (_currentRenderer == RendererType.gpu && _renderersInitialized && _gpuRenderer is GpuBatchRenderer) ...[
            FloatingActionButton(
              heroTag: "wireframe",
              onPressed: () {
                setState(() {
                  (_gpuRenderer as GpuBatchRenderer).toggleWireframe();
                });
              },
              tooltip: (_gpuRenderer as GpuBatchRenderer).wireframeMode 
                  ? 'Switch to Filled Mode' 
                  : 'Switch to Wireframe Mode',
              child: Icon((_gpuRenderer as GpuBatchRenderer).wireframeMode 
                  ? Icons.crop_square 
                  : Icons.grid_on),
            ),
            const SizedBox(height: 16),
          ],
          // Renderer toggle
          FloatingActionButton(
            heroTag: "renderer",
            onPressed: _toggleRenderer,
            tooltip: 'Switch to ${_getNextRendererName()}',
            child: const Icon(Icons.swap_horiz),
          ),
        ],
      ),
    );
  }
}

class GpuBatchPainter extends CustomPainter {
  final GpuBatchRenderer? renderer;
  final double rotationX;
  final double rotationY;
  
  GpuBatchPainter({
    required this.renderer, 
    this.rotationX = 0.0, 
    this.rotationY = 0.0
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (renderer == null) {
      // Draw black background while waiting for renderer to initialize
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.black,
      );
      return;
    }
    
    // Use custom GPU rendering with batching
    renderer!.render(canvas, size, rotationX, rotationY);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class FlutterSceneBatchPainter extends CustomPainter {
  final FlutterSceneBatchRenderer? renderer;
  final double rotationX;
  final double rotationY;
  
  FlutterSceneBatchPainter({
    required this.renderer, 
    this.rotationX = 0.0, 
    this.rotationY = 0.0
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (renderer == null || !renderer!.initialized) {
      // Draw black background while waiting for renderer to initialize
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.black,
      );
      return;
    }
    
    // Use flutter_scene rendering with batched MeshPrimitives
    renderer!.render(canvas, size, rotationX, rotationY);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}