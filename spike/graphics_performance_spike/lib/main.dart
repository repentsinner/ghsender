import 'package:flutter/material.dart';
import 'utils/logger.dart';
import 'package:flutter/scheduler.dart';
import 'renderers/flutter_scene_batch_renderer.dart';
import 'scene/scene_manager.dart';
import 'renderers/renderer_interface.dart';
import 'renderers/line_style.dart';

enum RendererType { flutterSceneLines }

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Graphics Performance Spike',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const GraphicsPerformanceScreen(),
    );
  }
}

class GraphicsPerformanceScreen extends StatefulWidget {
  const GraphicsPerformanceScreen({super.key});

  @override
  State<GraphicsPerformanceScreen> createState() =>
      _GraphicsPerformanceScreenState();
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
  RendererType _currentRenderer = RendererType.flutterSceneLines;

  // Renderers implementing the common interface
  late Renderer _flutterSceneRenderer;

  final List<double> _fpsSamples = [];

  // Line rendering controls
  double _lineWeight = 1.0; // Default line weight
  double _lineSmoothness = 0.5; // Default smoothness (0.0 = very smooth, 1.0 = very sharp)

  @override
  void initState() {
    super.initState();
    _initializeBothRenderers();
  }

  void _initializeBothRenderers() async {
    AppLogger.info('Initializing scene and renderers');

    // Initialize the shared scene first
    await SceneManager.instance.initialize();
    AppLogger.info('Scene manager initialized');

    // Initialize renderer
    _flutterSceneRenderer = FlutterSceneBatchRenderer();
    final flutterSceneSuccess = await _flutterSceneRenderer.initialize();
    if (flutterSceneSuccess) {
      await _flutterSceneRenderer.setupScene(SceneManager.instance.sceneData);
    }
    AppLogger.info('FlutterScene renderer initialized: $flutterSceneSuccess');

    _renderersInitialized = true;
    AppLogger.info(
      'All renderers ready - starting with ${_currentRenderer.name}',
    );

    _ticker = Ticker((_) {
      _frameCount++;
      final now = DateTime.now();
      final elapsed = now.difference(_lastFrameTime).inMilliseconds;

      // Update active renderer with current rotation
      _flutterSceneRenderer.updateRotation(_rotationX, _rotationY);

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
      _flutterSceneRenderer.dispose();
    }
    super.dispose();
  }

  Renderer? _getCurrentRenderer() {
    if (!_renderersInitialized) return null;
    return _flutterSceneRenderer;
  }

  String _getRendererDisplayName() {
    return 'FLUTTER_SCENE LINES RENDERER';
  }

  String _getRendererDetails() {
    return 'flutter_scene_lines';
  }


  Widget _buildRendererWidget() {
    if (!_renderersInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // Canvas-based renderer uses CustomPaint
    return CustomPaint(
      painter: FlutterSceneBatchPainter(
        renderer: _flutterSceneRenderer as FlutterSceneBatchRenderer,
        rotationX: _rotationX,
        rotationY: _rotationY,
      ),
    );
  }


  void _updateLineWeight(double weight) {
    setState(() {
      _lineWeight = weight;
    });
    _refreshRenderers();
    AppLogger.info('Line weight updated to: ${weight.toStringAsFixed(2)}');
  }

  void _updateLineSmoothness(double smoothness) {
    setState(() {
      _lineSmoothness = smoothness;
    });
    _refreshRenderers();
    AppLogger.info('Line smoothness updated to: ${smoothness.toStringAsFixed(2)}');
  }

  LineStyle _getCurrentLineStyle() {
    return LineStyle(
      color: Colors.white,
      width: _lineWeight,
      sharpness: _lineSmoothness,
      opacity: 1.0,
      smoothed: true,
    );
  }

  void _refreshRenderers() async {
    if (!_renderersInitialized) return;

    // Update line styles in renderer
    final currentStyle = _getCurrentLineStyle();
    
    if (_flutterSceneRenderer is FlutterSceneBatchRenderer) {
      (_flutterSceneRenderer as FlutterSceneBatchRenderer).updateLineStyle(currentStyle);
    }

    // Refresh renderer with updated line styles
    await _flutterSceneRenderer.setupScene(SceneManager.instance.sceneData);
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
      appBar: AppBar(title: Text('Graphics Performance Spike - $rendererName')),
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
            child: SizedBox.expand(child: _buildRendererWidget()),
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

Click and drag to rotate the scene''',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                shadows: [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 2,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),
          // Line Controls
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              width: 250,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Line Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Line Weight Control
                  Text(
                    'Weight: ${_lineWeight.toStringAsFixed(1)}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Slider(
                    value: _lineWeight,
                    min: 0.1,
                    max: 5.0,
                    divisions: 49,
                    onChanged: _updateLineWeight,
                    activeColor: Colors.blue,
                    inactiveColor: Colors.white30,
                  ),
                  const SizedBox(height: 8),
                  // Line Smoothness Control
                  Text(
                    'Smoothness: ${_lineSmoothness.toStringAsFixed(2)} ${_lineSmoothness < 0.3 ? '(soft)' : _lineSmoothness > 0.7 ? '(sharp)' : '(medium)'}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Slider(
                    value: _lineSmoothness,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: _updateLineSmoothness,
                    activeColor: Colors.green,
                    inactiveColor: Colors.white30,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // No floating action button needed since we only have one renderer
    );
  }
}


class FlutterSceneBatchPainter extends CustomPainter {
  final FlutterSceneBatchRenderer? renderer;
  final double rotationX;
  final double rotationY;

  FlutterSceneBatchPainter({
    required this.renderer,
    this.rotationX = 0.0,
    this.rotationY = 0.0,
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
