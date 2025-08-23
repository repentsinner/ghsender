import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'dart:async';

import '../../utils/logger.dart';
import '../../utils/coordinate_converter.dart';
import '../../renderers/flutter_scene_batch_renderer.dart';
import '../../scene/scene_manager.dart';
import '../../renderers/renderer_interface.dart';
import '../../renderers/line_style.dart';
import '../../camera_director.dart';
import '../../bloc/performance/performance_bloc.dart';
import '../../bloc/performance/performance_event.dart';
import '../../bloc/graphics/graphics_bloc.dart';
import '../../bloc/graphics/graphics_event.dart';
import '../layouts/vscode_layout.dart';
import '../../bloc/machine_controller/machine_controller_bloc.dart';
import '../../bloc/machine_controller/machine_controller_state.dart';
import '../../models/machine_controller.dart';

enum RendererType { flutterSceneLines }

/// GrblHAL Visualizer Screen - 3D visualization and interaction with CNC machine data
/// Handles graphics rendering, camera control, and line style management
class GrblHalVisualizerScreen extends StatefulWidget {
  const GrblHalVisualizerScreen({super.key});

  @override
  State<GrblHalVisualizerScreen> createState() => _GrblHalVisualizerScreenState();
}

class _GrblHalVisualizerScreenState extends State<GrblHalVisualizerScreen> {
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
  
  // Machine controller subscription for position updates
  StreamSubscription<MachineControllerState>? _machineControllerSubscription;
  
  // Work envelope retry timer
  Timer? _workEnvelopeRetryTimer;

  // Current active renderer
  final RendererType _currentRenderer = RendererType.flutterSceneLines;

  // Renderers implementing the common interface
  late Renderer _flutterSceneRenderer;

  final List<double> _fpsSamples = [];

  // Line rendering controls
  double _lineWeight = 1.0; // Default line weight
  double _lineSmoothness = 0.5; // Default smoothness (0.0 = very smooth, 1.0 = very sharp)
  double _lineOpacity = 0.5; // Default opacity (0.0 = transparent, 1.0 = opaque)

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
      final cncTarget = renderer.getOrbitTarget();
      // Transform from CNC coordinates to display coordinates
      final displayTarget = CoordinateConverter.cncCameraTargetToDisplay(cncTarget);
      _cameraDirector.initializeFromSceneData(displayTarget);
    }
    AppLogger.info('FlutterScene renderer initialized: $flutterSceneSuccess');

    // Set up scene update subscription
    _sceneUpdateSubscription = SceneManager.instance.sceneUpdates.listen(
      _onSceneUpdated,
    );
    AppLogger.info('Scene update listener established');

    // Set up machine controller subscription for position updates
    _setupMachineControllerListener();

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

  /// Set up machine controller listener for position updates
  void _setupMachineControllerListener() {
    final machineControllerBloc = context.read<MachineControllerBloc>();
    _machineControllerSubscription = machineControllerBloc.stream.listen((state) {
      // Update scene manager with current machine position
      // The renderer will pick this up on the next frame
      SceneManager.instance.updateMachinePosition(state.machinePosition);
      
      // Update work envelope when machine configuration is available
      // Only render work envelope when we have real machine data
      WorkEnvelope? workEnvelope;
      if (state.isOnline && 
          state.grblHalDetected && 
          state.configuration != null) {
        
        workEnvelope = WorkEnvelope.fromConfiguration(state.configuration!);
        
        if (workEnvelope == null) {
          // Schedule a retry in case settings arrive later (only if no retry is already scheduled)
          if (_workEnvelopeRetryTimer == null || !_workEnvelopeRetryTimer!.isActive) {
            _scheduleWorkEnvelopeRetry();
          }
        }
      }
      SceneManager.instance.updateWorkEnvelope(workEnvelope);
      
      // Update camera target based on job envelope and machine position
      _updateCameraTarget(state.machinePosition);
    });
    AppLogger.info('Machine controller listener established for position updates');
  }

  /// Update camera target based on job envelope (G-code bounds) and machine position
  /// Note: Camera should focus on G-code geometry, not machine soft limits
  void _updateCameraTarget(MachineCoordinates? machinePosition) {
    // Convert machine coordinates to Vector3 if available
    vm.Vector3? machinePositionVector;
    if (machinePosition != null) {
      machinePositionVector = vm.Vector3(
        machinePosition.x,
        machinePosition.y,
        machinePosition.z,
      );
    }
    
    // Get job envelope centroid if available (use G-code bounds for camera focus)
    vm.Vector3? jobEnvelopeCentroid;
    final currentJobEnvelope = SceneManager.instance.currentJobEnvelope;
    if (currentJobEnvelope != null && !currentJobEnvelope.isEmpty) {
      jobEnvelopeCentroid = currentJobEnvelope.center;
    }
    
    // Update camera director with the new target using job envelope
    _cameraDirector.updateDynamicTarget(
      jobEnvelopeCentroid: jobEnvelopeCentroid,
      machinePosition: machinePositionVector,
    );
  }

  /// Schedule a retry for work envelope creation
  void _scheduleWorkEnvelopeRetry() {
    // Cancel any existing retry timer
    _workEnvelopeRetryTimer?.cancel();
    
    _workEnvelopeRetryTimer = Timer(const Duration(seconds: 3), () {
      // Get current machine controller state
      final machineBloc = context.read<MachineControllerBloc>();
      final currentState = machineBloc.state;
      
      // Check if we now have the required settings
      if (currentState.isOnline && 
          currentState.grblHalDetected && 
          currentState.configuration != null) {
        
        final workEnvelope = WorkEnvelope.fromConfiguration(currentState.configuration!);
        if (workEnvelope != null) {
          SceneManager.instance.updateWorkEnvelope(workEnvelope);
        }
        // Don't log anything - if it still fails, the original warning is sufficient
      }
    });
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
      final cncTarget = renderer.getOrbitTarget();
      // Transform from CNC coordinates to display coordinates
      final displayTarget = CoordinateConverter.cncCameraTargetToDisplay(cncTarget);
      _cameraDirector.initializeFromSceneData(displayTarget);

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
    _machineControllerSubscription?.cancel();
    _workEnvelopeRetryTimer?.cancel();
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
    return Builder(
      builder: (context) {
        final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
        return CustomPaint(
          painter: GrblHalVisualizerPainter(
            renderer: _flutterSceneRenderer as FlutterSceneBatchRenderer,
            rotationX: 0.0, // Not used - renderer manages rotation internally
            rotationY: 0.0, // Not used - renderer manages rotation internally
            devicePixelRatio: devicePixelRatio,
          ),
        );
      },
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

    // Update BLoCs with current data
    context.read<PerformanceBloc>().add(PerformanceMetricsUpdated(
      fps: _fps,
      polygons: polygons,
      drawCalls: drawCalls,
    ));
    
    context.read<GraphicsBloc>().add(GraphicsCameraStateUpdated(
      cameraInfo: _getCameraInfo(),
      isAutoMode: _cameraDirector.isAutoMode,
      onCameraToggle: _toggleCameraAnimation,
    ));
    
    context.read<GraphicsBloc>().add(GraphicsLineControlsUpdated(
      lineWeight: _lineWeight,
      lineSmoothness: _lineSmoothness,
      lineOpacity: _lineOpacity,
      onLineWeightChanged: _updateLineWeight,
      onLineSmoothnessChanged: _updateLineSmoothness,
      onLineOpacityChanged: _updateLineOpacity,
    ));

    return VSCodeLayout(
      graphicsRenderer: graphicsRenderer,
    );
  }
}

/// Custom painter for GrblHAL visualizer rendering
class GrblHalVisualizerPainter extends CustomPainter {
  final FlutterSceneBatchRenderer? renderer;
  final double rotationX;
  final double rotationY;
  final double devicePixelRatio;

  GrblHalVisualizerPainter({
    required this.renderer,
    this.rotationX = 0.0,
    this.rotationY = 0.0,
    this.devicePixelRatio = 1.0,
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
    renderer!.render(canvas, size, 0.0, 0.0, devicePixelRatio: devicePixelRatio);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}