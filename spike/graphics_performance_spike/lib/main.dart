
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'; // Required for SystemNavigator

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
  Offset _currentPosition = Offset.zero;
  final List<List<Offset>> _lineSegments = [];
  final Random _random = Random();
  int _frameCount = 0;
  DateTime _lastFrameTime = DateTime.now();
  double _fps = 0.0;
  Ticker? _ticker;

  static int _numberOfSegments = 36000; // Trying 36,000 2D line segments
  static const int _measurementDurationSeconds = 10; // Run for 10 seconds for measurement
  List<double> _fpsSamples = [];
  DateTime _startTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _generateLineSegments();
    _startTime = DateTime.now();

    _ticker = Ticker((_) {
      _frameCount++;
      final now = DateTime.now();
      final elapsed = now.difference(_lastFrameTime).inMilliseconds;

      if (elapsed >= 1000) {
        _fps = _frameCount * 1000 / elapsed;
        _fpsSamples.add(_fps);
        setState(() {}); // Trigger rebuild to update FPS display
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

  void _generateLineSegments() {
    _lineSegments.clear(); // Clear previous segments if hot-reloaded
    for (int i = 0; i < _numberOfSegments; i++) {
      final startX = _random.nextDouble() * 800;
      final startY = _random.nextDouble() * 600;
      final endX = _random.nextDouble() * 800;
      final endY = _random.nextDouble() * 600;
      _lineSegments.add([Offset(startX, startY), Offset(endX, endY)]);
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
    // This button will now trigger a hot-reload with updated segments
    // For automated testing, this method won't be directly used.
    setState(() {
      _currentPosition = Offset(
        _random.nextDouble() * 800,
        _random.nextDouble() * 600,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Graphics Performance Spike'),
      ),
      body: Stack(
        children: [
          CustomPaint(
            painter: VisualizerPainter(
              lineSegments: _lineSegments,
              currentPosition: _currentPosition,
            ),
            child: Container(),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Text(
              'FPS: ${_fps.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.black, fontSize: 24),
            ),
          ),
          // The refresh button is now primarily for manual testing/hot-reloads
          // For automated runs, we'll modify _numberOfSegments directly.
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

class VisualizerPainter extends CustomPainter {
  final List<List<Offset>> lineSegments;
  final Offset currentPosition;
  final Paint _linePaint = Paint()
    ..color = Colors.blue
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;
  final Paint _circlePaint = Paint()
    ..color = Colors.red
    ..style = PaintingStyle.fill;

  VisualizerPainter({
    required this.lineSegments,
    required this.currentPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw all line segments
    for (final segment in lineSegments) {
      canvas.drawLine(segment[0], segment[1], _linePaint);
    }

    // Draw the current position circle
    canvas.drawCircle(currentPosition, 10.0, _circlePaint);
  }

  @override
  bool shouldRepaint(covariant VisualizerPainter oldDelegate) {
    return oldDelegate.currentPosition != currentPosition;
  }
}
