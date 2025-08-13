import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'utils/logger.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'renderers/flutter_scene_batch_renderer.dart';
import 'scene/scene_manager.dart';
import 'renderers/renderer_interface.dart';
import 'renderers/line_style.dart';
import 'camera_director.dart';

enum RendererType { flutterSceneLines }

void main() {
  // Configure Google Fonts to use local assets only (no network requests)
  GoogleFonts.config.allowRuntimeFetching = false;
  
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

  // Camera control system
  late CameraDirector _cameraDirector;
  Offset? _lastPanPosition;
  double _lastScale = 1.0;

  // Current active renderer
  final RendererType _currentRenderer = RendererType.flutterSceneLines;

  // Renderers implementing the common interface
  late Renderer _flutterSceneRenderer;

  final List<double> _fpsSamples = [];

  // Line rendering controls
  double _lineWeight = 1.0; // Default line weight
  double _lineSmoothness =
      0.5; // Default smoothness (0.0 = very smooth, 1.0 = very sharp)
  double _lineOpacity =
      0.5; // Default opacity (0.0 = transparent, 1.0 = opaque)

  @override
  void initState() {
    super.initState();
    _cameraDirector = CameraDirector();
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

      // Initialize CameraDirector with scene data
      final renderer = _flutterSceneRenderer as FlutterSceneBatchRenderer;
      _cameraDirector.initializeFromSceneData(renderer.getOrbitTarget());
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

      // Get complete camera state from CameraDirector
      final cameraState = _cameraDirector.getCameraState(now);

      // Update renderer with complete camera state
      if (_flutterSceneRenderer is FlutterSceneBatchRenderer) {
        final renderer = _flutterSceneRenderer as FlutterSceneBatchRenderer;
        renderer.setCameraState(cameraState.position, cameraState.target);
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

  String _getCameraInfo() {
    if (!_renderersInitialized || !_flutterSceneRenderer.initialized) {
      return '';
    }

    // Get camera info from CameraDirector
    final cameraState = _cameraDirector.getCameraState(DateTime.now());
    final modeIcon = _cameraDirector.isAutoMode ? '🎬' : '🕹️';

    return '''
🎥 $modeIcon 🧭: ${cameraState.azimuthDegrees.toStringAsFixed(1)}° 📐: ${cameraState.elevationDegrees.toStringAsFixed(1)}° 📏: ${cameraState.distance.toStringAsFixed(1)}''';
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
        rotationX: 0.0, // Not used - renderer manages rotation internally
        rotationY: 0.0, // Not used - renderer manages rotation internally
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
    AppLogger.info(
      'Line smoothness updated to: ${smoothness.toStringAsFixed(2)}',
    );
  }

  void _updateLineOpacity(double opacity) {
    setState(() {
      _lineOpacity = opacity;
    });
    _refreshRenderers();
    AppLogger.info('Line opacity updated to: ${opacity.toStringAsFixed(2)}');
  }

  LineStyle _getCurrentLineStyle() {
    return LineStyle(
      color: Colors.white,
      width: _lineWeight,
      sharpness: _lineSmoothness,
      opacity: _lineOpacity,
      smoothed: true,
    );
  }

  /// Toggle camera animation mode through CameraDirector
  void _toggleCameraAnimation() {
    setState(() {
      _cameraDirector.toggleMode();
      AppLogger.info('Camera mode toggled to: ${_cameraDirector.currentMode}');
    });
  }

  void _refreshRenderers() async {
    if (!_renderersInitialized) return;

    // Update line styles in renderer
    final currentStyle = _getCurrentLineStyle();

    if (_flutterSceneRenderer is FlutterSceneBatchRenderer) {
      (_flutterSceneRenderer as FlutterSceneBatchRenderer).updateLineStyle(
        currentStyle,
      );
    }

    // Refresh renderer with updated line styles and pass current opacity
    await (_flutterSceneRenderer as FlutterSceneBatchRenderer)
        .setupSceneWithOpacity(
          SceneManager.instance.sceneData,
          currentStyle.opacity,
        );
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

    return Scaffold(
      //appBar: AppBar(title: Text('Graphics Performance Spike - $rendererName')),
      body: Stack(
        children: [
          // Active Renderer with Pan Gesture, Pinch Zoom, and Mouse Scroll
          Listener(
            // Mouse scroll wheel zoom
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                // Delegate scroll zoom to CameraDirector
                _cameraDirector.processScrollZoom(event.scrollDelta.dy);
                setState(() {});
              }
            },
            child: GestureDetector(
              // Use scale gesture only (handles both pan and pinch)
              onScaleStart: (details) {
                _lastPanPosition = details.localFocalPoint;
                _lastScale = 1.0;
              },
              onScaleUpdate: (details) {
                if (_lastPanPosition != null) {
                  final scaleDelta = (details.scale - _lastScale).abs();
                  
                  // If scale changed significantly, treat as zoom gesture
                  if (scaleDelta > 0.05) {
                    _cameraDirector.processPinchZoom(details.scale / _lastScale);
                    _lastScale = details.scale;
                  } else {
                    // Otherwise treat as pan gesture
                    final delta = details.localFocalPoint - _lastPanPosition!;
                    _cameraDirector.processPanGesture(delta.dx, delta.dy);
                    _lastPanPosition = details.localFocalPoint;
                  }
                  
                  setState(() {});
                }
              },
              onScaleEnd: (details) {
                _lastPanPosition = null;
                _lastScale = 1.0;
              },
              child: SizedBox.expand(child: _buildRendererWidget()),
            ),
          ),
          // Performance Info
          Positioned(
            top: 16,
            left: 16,
            child: Opacity(
              opacity: 0.4,
              child: Text(
                '''FPS: ${_fps.toStringAsFixed(2)}
Polygons: ${(polygons / 1000).toStringAsFixed(1)}k
Draw Calls: $drawCalls
${_getCameraInfo()}''',
                style: GoogleFonts.inconsolata(
                  color: Colors.white,
                  fontSize: 14,
                  shadows: const [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 2,
                      color: Colors.black,
                    ),
                  ],
                ),
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
                  Text(
                    'Line Settings',
                    style: GoogleFonts.inconsolata(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Line Weight Control
                  Text(
                    'Weight: ${_lineWeight.toStringAsFixed(1)}',
                    style: GoogleFonts.inconsolata(color: Colors.white, fontSize: 12),
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
                    'Smoothness: ${_lineSmoothness.toStringAsFixed(2)} ${_lineSmoothness < 0.3
                        ? '(soft)'
                        : _lineSmoothness > 0.7
                        ? '(sharp)'
                        : '(medium)'}',
                    style: GoogleFonts.inconsolata(color: Colors.white, fontSize: 12),
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
                  const SizedBox(height: 8),
                  // Line Opacity Control
                  Text(
                    'Opacity: ${_lineOpacity.toStringAsFixed(2)} ${_lineOpacity < 0.3
                        ? '(transparent)'
                        : _lineOpacity > 0.7
                        ? '(solid)'
                        : '(translucent)'}',
                    style: GoogleFonts.inconsolata(color: Colors.white, fontSize: 12),
                  ),
                  Slider(
                    value: _lineOpacity,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: _updateLineOpacity,
                    activeColor: Colors.orange,
                    inactiveColor: Colors.white30,
                  ),
                  const SizedBox(height: 12),
                  // Camera Animation Toggle
                  ElevatedButton(
                    onPressed: _toggleCameraAnimation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _cameraDirector.isAutoMode
                          ? Colors.orange
                          : Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(36),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _cameraDirector.isAutoMode ? '⏸️ ' : '▶️ ',
                          style: GoogleFonts.inconsolata(fontSize: 16),
                        ),
                        Text(
                          _cameraDirector.isAutoMode ? 'Manual' : 'Auto',
                          style: GoogleFonts.inconsolata(),
                        ),
                      ],
                    ),
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

    // Use flutter_scene rendering - rotation is already managed by ticker updates
    renderer!.render(canvas, size, 0.0, 0.0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
