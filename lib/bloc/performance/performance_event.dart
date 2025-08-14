import 'package:equatable/equatable.dart';

/// Performance events for graphics rendering metrics
abstract class PerformanceEvent extends Equatable {
  const PerformanceEvent();

  @override
  List<Object> get props => [];
}

/// Event to update performance metrics
class PerformanceMetricsUpdated extends PerformanceEvent {
  final double fps;
  final int polygons;
  final int drawCalls;

  const PerformanceMetricsUpdated({
    required this.fps,
    required this.polygons,
    required this.drawCalls,
  });

  @override
  List<Object> get props => [fps, polygons, drawCalls];
}