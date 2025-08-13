import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'utils/logger.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'renderers/flutter_scene_batch_renderer.dart';
import 'scene/scene_manager.dart';
import 'renderers/renderer_interface.dart';
import 'renderers/line_style.dart';
import 'camera_director.dart';
import 'ui/layouts/vscode_layout.dart';
import 'bloc/bloc_exports.dart';
import 'dart:async';

enum RendererType { flutterSceneLines }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure window manager for desktop platforms
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1400, 900),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Inconsolata fonts are now loaded from local assets
  GoogleFonts.config.allowRuntimeFetching = false;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => CncConnectionBloc()),
        BlocProvider(create: (context) => FileManagerBloc()),
      ],
      child: MaterialApp(
        title: 'Graphics Performance Spike',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const GraphicsPerformanceScreen(),
      ),
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

  // Scene update subscription
  StreamSubscription<SceneData?>? _sceneUpdateSubscription;

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
    if (flutterSceneSuccess && SceneManager.instance.sceneData != null) {
      await _flutterSceneRenderer.setupScene(SceneManager.instance.sceneData!);

      // Initialize CameraDirector with scene data
      final renderer = _flutterSceneRenderer as FlutterSceneBatchRenderer;
      _cameraDirector.initializeFromSceneData(renderer.getOrbitTarget());
    }
    AppLogger.info('FlutterScene renderer initialized: $flutterSceneSuccess');

    // Set up scene update subscription
    _sceneUpdateSubscription = SceneManager.instance.sceneUpdates.listen(
      _onSceneUpdated,
    );
    AppLogger.info('Scene update listener established');

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

  /// Handle scene updates from SceneManager
  void _onSceneUpdated(SceneData? newSceneData) async {
    if (!_renderersInitialized || newSceneData == null) {
      AppLogger.info(
        'Ignoring scene update - renderer not ready or no scene data',
      );
      return;
    }

    AppLogger.info('Scene updated, refreshing renderer');

    try {
      // Update the renderer with new scene data
      await (_flutterSceneRenderer as FlutterSceneBatchRenderer)
          .setupSceneWithOpacity(newSceneData, LineStyles.technical.opacity);

      // Update camera if needed
      final renderer = _flutterSceneRenderer as FlutterSceneBatchRenderer;
      _cameraDirector.initializeFromSceneData(renderer.getOrbitTarget());

      AppLogger.info('Renderer updated with new scene data');

      // Trigger a rebuild
      setState(() {});
    } catch (e) {
      AppLogger.error('Failed to update renderer with new scene data', e);
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _sceneUpdateSubscription?.cancel();
    if (_renderersInitialized) {
      _flutterSceneRenderer.dispose();
    }
    super.dispose();
  }

  Renderer? _getCurrentRenderer() {
    if (!_renderersInitialized) return null;
    return _flutterSceneRenderer;
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
    if (SceneManager.instance.sceneData != null) {
      await (_flutterSceneRenderer as FlutterSceneBatchRenderer)
          .setupSceneWithOpacity(
            SceneManager.instance.sceneData!,
            currentStyle.opacity,
          );
    }
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

    // Create the graphics renderer widget with gesture controls
    final graphicsRenderer = Listener(
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
    );

    return VSCodeLayout(
      graphicsRenderer: graphicsRenderer,
      fps: _fps,
      polygons: polygons,
      drawCalls: drawCalls,
      cameraInfo: _getCameraInfo(),
      onLineWeightChanged: _updateLineWeight,
      onLineSmoothnessChanged: _updateLineSmoothness,
      onLineOpacityChanged: _updateLineOpacity,
      onCameraToggle: _toggleCameraAnimation,
      lineWeight: _lineWeight,
      lineSmoothness: _lineSmoothness,
      lineOpacity: _lineOpacity,
      isAutoMode: _cameraDirector.isAutoMode,
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
