import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'dart:ui';

// Custom class to hold 3D line segment data
class LineSegmentData3D {
  vm.Vector3 start;
  vm.Vector3 end;
  final Color color;
  vm.Vector3 targetStart;
  vm.Vector3 targetEnd;

  LineSegmentData3D({
    required this.start,
    required this.end,
    required this.color,
    required this.targetStart,
    required this.targetEnd,
  });
}

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
  final List<LineSegmentData3D> _lineSegments = [];
  final Random _random = Random();
  int _frameCount = 0;
  DateTime _lastFrameTime = DateTime.now();
  double _fps = 0.0;
  Ticker? _ticker;
  double _cameraAngle = 0.0;
  Scene scene = Scene();
  Camera camera = PerspectiveCamera();
  final List<Node> _lineNodes = [];
  bool _sceneInitialized = false;

  static int _numberOfSegments = 10000;
  static int _numberOfAnimatedSegments = 100;
  static const int _measurementDurationSeconds = 10;
  List<double> _fpsSamples = [];
  DateTime _startTime = DateTime.now();
  static const double _moveSpeedLine = 0.05;
  static const double _cameraSpeed = 0.02;
  static const double _sceneRadius = 100.0;

  @override
  void initState() {
    super.initState();
    _initializeScene();
  }

  void _initializeScene() async {
    // Initialize flutter_scene static resources
    await Scene.initializeStaticResources();
    
    _generateLineSegments();
    _startTime = DateTime.now();
    _sceneInitialized = true;

    print('--- Intended Renderer: flutter_scene with Impeller (macOS) ---');

    _ticker = Ticker((_) {
      _frameCount++;
      final now = DateTime.now();
      final elapsed = now.difference(_lastFrameTime).inMilliseconds;

      _updateSmoothPositionsLines();
      _updateCameraOrbit();

      setState(() {});

      if (elapsed >= 1000) {
        _fps = _frameCount * 1000 / elapsed;
        _fpsSamples.add(_fps);
        _frameCount = 0;
        _lastFrameTime = now;
      }

      if (now.difference(_startTime).inSeconds >= _measurementDurationSeconds) {
        _ticker?.dispose();
        _reportAndExit();
      }
    });
    _ticker?.start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }


  // Shared resources for performance
  Mesh? _sharedCubeMesh;
  
  void _generateLineSegments() {
    _lineSegments.clear();
    _lineNodes.clear();
    
    // Create shared mesh and material once (optimization from flutter-scene-example)
    if (_sharedCubeMesh == null) {
      final geometry = CuboidGeometry(vm.Vector3(2, 2, 2));
      final material = UnlitMaterial(); // Use UnlitMaterial for better performance
      _sharedCubeMesh = Mesh(geometry, material);
    }
    
    for (int i = 0; i < _numberOfSegments; i++) {
      // Generate 3D positions in a pile toward center
      final radius = _random.nextDouble() * _sceneRadius;
      final theta = _random.nextDouble() * 2 * pi;
      final phi = _random.nextDouble() * pi;
      
      final startX = radius * sin(phi) * cos(theta);
      final startY = radius * sin(phi) * sin(theta);
      final startZ = radius * cos(phi);
      
      final endRadius = _random.nextDouble() * _sceneRadius;
      final endTheta = _random.nextDouble() * 2 * pi;
      final endPhi = _random.nextDouble() * pi;
      
      final endX = endRadius * sin(endPhi) * cos(endTheta);
      final endY = endRadius * sin(endPhi) * sin(endTheta);
      final endZ = endRadius * cos(endPhi);
      
      final color = Color.fromARGB(
        255,
        _random.nextInt(256),
        _random.nextInt(256),
        _random.nextInt(256),
      );
      
      final lineData = LineSegmentData3D(
        start: vm.Vector3(startX, startY, startZ),
        end: vm.Vector3(endX, endY, endZ),
        color: color,
        targetStart: _generateRandomPosition(),
        targetEnd: _generateRandomPosition(),
      );
      
      _lineSegments.add(lineData);
      
      // Create a Node for each line segment - share mesh for performance
      final lineNode = Node();
      lineNode.localTransform = vm.Matrix4.translation(lineData.start);
      
      // Share the same mesh across all nodes (major optimization)
      lineNode.mesh = _sharedCubeMesh;
      
      _lineNodes.add(lineNode);
      scene.add(lineNode);
    }
  }

  vm.Vector3 _generateRandomPosition() {
    final radius = _random.nextDouble() * _sceneRadius;
    final theta = _random.nextDouble() * 2 * pi;
    final phi = _random.nextDouble() * pi;
    
    return vm.Vector3(
      radius * sin(phi) * cos(theta),
      radius * sin(phi) * sin(theta),
      radius * cos(phi),
    );
  }

  void _updateCameraOrbit() {
    _cameraAngle += _cameraSpeed;
    if (_cameraAngle > 2 * pi) {
      _cameraAngle -= 2 * pi;
    }
    
    // Update camera position for orbital motion
    final cameraRadius = _sceneRadius * 2.5;
    final cameraX = cameraRadius * cos(_cameraAngle);
    final cameraZ = cameraRadius * sin(_cameraAngle);
    final cameraY = _sceneRadius * 0.5;
    
    if (camera is PerspectiveCamera) {
      final perspectiveCamera = camera as PerspectiveCamera;
      perspectiveCamera.position = vm.Vector3(cameraX, cameraY, cameraZ);
      perspectiveCamera.target = vm.Vector3(0, 0, 0);
    }
  }


  void _updateSmoothPositionsLines() {
    // Only animate the first _numberOfAnimatedSegments cubes
    final animationLimit = min(_numberOfAnimatedSegments, _lineSegments.length);
    
    for (int i = 0; i < animationLimit; i++) {
      final segment = _lineSegments[i];

      // Update start point
      final startDiff = segment.targetStart - segment.start;
      final startDistance = startDiff.length;

      if (startDistance < _moveSpeedLine) {
        segment.start = segment.targetStart;
        segment.targetStart = _generateRandomPosition();
      } else {
        segment.start = segment.start + (startDiff.normalized() * _moveSpeedLine);
      }

      // Update end point
      final endDiff = segment.targetEnd - segment.end;
      final endDistance = endDiff.length;

      if (endDistance < _moveSpeedLine) {
        segment.end = segment.targetEnd;
        segment.targetEnd = _generateRandomPosition();
      } else {
        segment.end = segment.end + (endDiff.normalized() * _moveSpeedLine);
      }
      
      // Update the 3D node position
      if (i < _lineNodes.length) {
        _lineNodes[i].localTransform = vm.Matrix4.translation(segment.start);
      }
    }
  }

  void _reportAndExit() {
    double averageFps = _fpsSamples.isEmpty
        ? 0.0
        : _fpsSamples.reduce((a, b) => a + b) / _fpsSamples.length;
    print('--- Graphics Performance Spike Results ---');
    print('Number of Segments: $_numberOfSegments');
    print('Average FPS: ${averageFps.toStringAsFixed(2)}');
    print('----------------------------------------');
    SystemNavigator.pop(); // Exit the application
  }

  void _updateRandomPosition() {
    _generateLineSegments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Graphics Performance Spike - 3D flutter_scene'),
      ),
      body: Stack(
        children: [
          SizedBox.expand(
            child: CustomPaint(
              painter: ScenePainter(scene: scene, camera: camera, initialized: _sceneInitialized),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Text(
              '''FPS: ${_fps.toStringAsFixed(2)}
Renderer: flutter_scene + Impeller
Cubes: $_numberOfSegments (${_numberOfAnimatedSegments} animated)''',
              style: const TextStyle(color: Colors.white, fontSize: 18, shadows: [
                Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black),
              ]),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _updateRandomPosition,
              child: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
    );
  }
}

class ScenePainter extends CustomPainter {
  ScenePainter({required this.scene, required this.camera, required this.initialized});
  final Scene scene;
  final Camera camera;
  final bool initialized;

  @override
  void paint(Canvas canvas, Size size) {
    if (!initialized) {
      // Draw black background while waiting for scene to initialize
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.black,
      );
      return;
    }
    
    scene.render(camera, canvas, viewport: Offset.zero & size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

