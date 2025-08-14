import 'package:equatable/equatable.dart';

/// Performance state for graphics rendering metrics
abstract class PerformanceState extends Equatable {
  const PerformanceState();

  @override
  List<Object> get props => [];
}

/// Initial performance state
class PerformanceInitial extends PerformanceState {
  const PerformanceInitial();
}

/// Performance state with metrics
class PerformanceLoaded extends PerformanceState {
  final double fps;
  final int polygons;
  final int drawCalls;

  const PerformanceLoaded({
    required this.fps,
    required this.polygons,
    required this.drawCalls,
  });

  @override
  List<Object> get props => [fps, polygons, drawCalls];
}