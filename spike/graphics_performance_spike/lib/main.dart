import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'; // Required for SystemNavigator
import 'dart:ui'; // For Color

// Custom class to hold line segment data
class LineSegmentData {
  Offset start;
  Offset end;
  final Color color;
  Offset targetStart;
  Offset targetEnd;

  LineSegmentData({
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
  Offset _currentPosition = Offset.zero; // For the single moving circle
  Offset _targetPosition = Offset.zero;
  final List<LineSegmentData> _lineSegments = []; // Changed type
  final Random _random = Random();
  int _frameCount = 0;
  DateTime _lastFrameTime = DateTime.now();
  double _fps = 0.0;
  Ticker? _ticker;

  static int _numberOfSegments = 10000; // Set to 10,000 2D line segments
  static const int _measurementDurationSeconds = 10; // Run for 10 seconds for measurement
  List<double> _fpsSamples = [];
  DateTime _startTime = DateTime.now();
  static const double _moveSpeedCircle = 5.0; // Pixels per frame for smooth movement of circle
  static const double _moveSpeedLine = 1.0; // Pixels per frame for smooth movement of lines

  @override
  void initState() {
    super.initState();
    _generateLineSegments();
    _startTime = DateTime.now();
    _currentPosition = Offset(_random.nextDouble() * 800, _random.nextDouble() * 600);
    _generateNewTargetPositionCircle();

    // Log the intended renderer
    print('--- Intended Renderer: Impeller (macOS) ---');

    _ticker = Ticker((_) {
      _frameCount++;
      final now = DateTime.now();
      final elapsed = now.difference(_lastFrameTime).inMilliseconds;

      // Update position smoothly towards target for the circle
      _updateSmoothPositionCircle();

      // Update positions smoothly towards targets for all line segments
      _updateSmoothPositionsLines();

      setState(() {}); // Trigger rebuild to update UI on every tick

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

  void _generateLineSegments() {
    _lineSegments.clear();
    for (int i = 0; i < _numberOfSegments; i++) {
      final startX = _random.nextDouble() * 800;
      final startY = _random.nextDouble() * 600;
      final endX = _random.nextDouble() * 800;
      final endY = _random.nextDouble() * 600;
      final color = Color.fromARGB(
        255,
        _random.nextInt(256),
        _random.nextInt(256),
        _random.nextInt(256),
      );
      _lineSegments.add(LineSegmentData(
        start: Offset(startX, startY),
        end: Offset(endX, endY),
        color: color,
        targetStart: Offset(_random.nextDouble() * 800, _random.nextDouble() * 600),
        targetEnd: Offset(_random.nextDouble() * 800, _random.nextDouble() * 600),
      ));
    }
  }

  void _generateNewTargetPositionCircle() {
    _targetPosition = Offset(
      _random.nextDouble() * 800,
      _random.nextDouble() * 600,
    );
  }

  void _updateSmoothPositionCircle() {
    final dx = _targetPosition.dx - _currentPosition.dx;
    final dy = _targetPosition.dy - _currentPosition.dy;
    final distance = sqrt(dx * dx + dy * dy);

    if (distance < _moveSpeedCircle) {
      _currentPosition = _targetPosition;
      _generateNewTargetPositionCircle();
    } else {
      _currentPosition = Offset(
        _currentPosition.dx + dx / distance * _moveSpeedCircle,
        _currentPosition.dy + dy / distance * _moveSpeedCircle,
      );
    }
  }

  void _updateSmoothPositionsLines() {
    for (int i = 0; i < _lineSegments.length; i++) {
      final segment = _lineSegments[i];

      // Update start point
      var dxStart = segment.targetStart.dx - segment.start.dx;
      var dyStart = segment.targetStart.dy - segment.start.dy;
      var distanceStart = sqrt(dxStart * dxStart + dyStart * dyStart);

      if (distanceStart < _moveSpeedLine) {
        segment.start = segment.targetStart;
        segment.targetStart = Offset(_random.nextDouble() * 800, _random.nextDouble() * 600);
      } else {
        segment.start = Offset(
          segment.start.dx + dxStart / distanceStart * _moveSpeedLine,
          segment.start.dy + dyStart / distanceStart * _moveSpeedLine,
        );
      }

      // Update end point
      var dxEnd = segment.targetEnd.dx - segment.end.dx;
      var dyEnd = segment.targetEnd.dy - segment.end.dy;
      var distanceEnd = sqrt(dxEnd * dxEnd + dyEnd * dyEnd);

      if (distanceEnd < _moveSpeedLine) {
        segment.end = segment.targetEnd;
        segment.targetEnd = Offset(_random.nextDouble() * 800, _random.nextDouble() * 600);
      } else {
        segment.end = Offset(
          segment.end.dx + dxEnd / distanceEnd * _moveSpeedLine,
          segment.end.dy + dyEnd / distanceEnd * _moveSpeedLine,
        );
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

  // The _updateRandomPosition method is no longer needed for manual testing.
  void _updateRandomPosition() {}

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
              '''FPS: ${_fps.toStringAsFixed(2)}
Renderer: Impeller (intended)''',
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
  final List<LineSegmentData> lineSegments; // Changed type
  final Offset currentPosition;
  final Paint _linePaint = Paint()
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
    // Draw all line segments with their individual colors
    for (final segmentData in lineSegments) {
      _linePaint.color = segmentData.color;
      canvas.drawLine(segmentData.start, segmentData.end, _linePaint);
    }

    // Draw the current position circle
    canvas.drawCircle(currentPosition, 10.0, _circlePaint);
  }

  @override
  bool shouldRepaint(covariant VisualizerPainter oldDelegate) {
    // Repaint if the circle's position changes or any line segment's position changes
    // For simplicity in this spike, we'll assume the list reference changes if any segment moves.
    // In a real app, you'd need a more granular check or use ValueNotifier/ChangeNotifier.
    return oldDelegate.currentPosition != currentPosition ||
           oldDelegate.lineSegments != lineSegments; // This will always be true if lines move
  }
}