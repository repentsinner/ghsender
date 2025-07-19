import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'renderers/gpu_batch_renderer.dart';
import 'renderers/flutter_scene_batch_renderer.dart';

enum RendererType { gpu, flutterScene }

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
  
  // Renderers for independent performance testing
  late GpuBatchRenderer _gpuRenderer;
  late FlutterSceneBatchRenderer _flutterSceneRenderer;
  
  static const int _targetDrawCalls = 10000;
  static const int _targetPolygons = 120000;
  List<double> _fpsSamples = [];

  @override
  void initState() {
    super.initState();
    _initializeBothRenderers();
  }

  void _initializeBothRenderers() async {
    print('=== INITIALIZING RENDERERS ===');
    
    // Initialize GPU renderer
    _gpuRenderer = GpuBatchRenderer();
    final gpuSuccess = await _gpuRenderer.initialize();
    print('GPU renderer initialized: $gpuSuccess');
    
    // Initialize flutter_scene renderer
    _flutterSceneRenderer = FlutterSceneBatchRenderer();
    await _flutterSceneRenderer.initialize();
    print('flutter_scene renderer initialized');
    
    _renderersInitialized = true;
    print('=== RENDERERS READY - Starting with ${_currentRenderer.name.toUpperCase()} ===');

    _ticker = Ticker((_) {
      _frameCount++;
      final now = DateTime.now();
      final elapsed = now.difference(_lastFrameTime).inMilliseconds;

      // Update renderers with current rotation (no auto-rotation)
      if (_currentRenderer == RendererType.flutterScene) {
        _flutterSceneRenderer.updateRotation(_rotationX, _rotationY);
      }
      // GPU renderer gets rotation in render() method

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
    }
    super.dispose();
  }

  
  void _toggleRenderer() {
    setState(() {
      _currentRenderer = _currentRenderer == RendererType.gpu 
          ? RendererType.flutterScene 
          : RendererType.gpu;
      
      // Reset FPS samples when switching renderers
      _fpsSamples.clear();
      _frameCount = 0;
      _lastFrameTime = DateTime.now();
    });
    
    print('Switched to ${_currentRenderer.name.toUpperCase()} renderer');
  }

  @override
  Widget build(BuildContext context) {
    final isGpuActive = _currentRenderer == RendererType.gpu;
    final drawCalls = _renderersInitialized 
        ? (isGpuActive ? _gpuRenderer.actualDrawCalls : _flutterSceneRenderer.actualDrawCalls)
        : 0;
    final polygons = _renderersInitialized 
        ? (isGpuActive ? _gpuRenderer.actualPolygons : _flutterSceneRenderer.actualPolygons)
        : 0;
    final rendererName = isGpuActive ? 'GPU RENDERER' : 'FLUTTER_SCENE RENDERER';
    final rendererDetails = isGpuActive ? 'Custom batching' : 'MeshPrimitive batching';
    
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
              child: CustomPaint(
                painter: isGpuActive
                    ? GpuBatchPainter(
                        renderer: _renderersInitialized ? _gpuRenderer : null,
                        rotationX: _rotationX,
                        rotationY: _rotationY,
                      )
                    : FlutterSceneBatchPainter(
                        renderer: _renderersInitialized ? _flutterSceneRenderer : null,
                      ),
              ),
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
Click and drag to rotate the scene${isGpuActive ? '\nTop button toggles wireframe mode' : ''}''',
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
          if (isGpuActive && _renderersInitialized) ...[
            FloatingActionButton(
              heroTag: "wireframe",
              onPressed: () {
                setState(() {
                  _gpuRenderer.toggleWireframe();
                });
              },
              tooltip: _renderersInitialized && _gpuRenderer.wireframeMode 
                  ? 'Switch to Filled Mode' 
                  : 'Switch to Wireframe Mode',
              child: Icon(_renderersInitialized && _gpuRenderer.wireframeMode 
                  ? Icons.crop_square 
                  : Icons.grid_on),
            ),
            const SizedBox(height: 16),
          ],
          // Renderer toggle
          FloatingActionButton(
            heroTag: "renderer",
            onPressed: _toggleRenderer,
            tooltip: 'Switch to ${isGpuActive ? "Flutter Scene" : "GPU"} Renderer',
            child: Icon(isGpuActive ? Icons.swap_horiz : Icons.swap_horiz),
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
  
  FlutterSceneBatchPainter({required this.renderer});

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
    renderer!.render(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}