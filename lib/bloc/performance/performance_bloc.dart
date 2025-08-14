import 'package:flutter_bloc/flutter_bloc.dart';
import 'performance_event.dart';
import 'performance_state.dart';

/// BLoC for managing graphics performance metrics
class PerformanceBloc extends Bloc<PerformanceEvent, PerformanceState> {
  PerformanceBloc() : super(const PerformanceInitial()) {
    on<PerformanceMetricsUpdated>(_onMetricsUpdated);
  }

  void _onMetricsUpdated(
    PerformanceMetricsUpdated event,
    Emitter<PerformanceState> emit,
  ) {
    emit(PerformanceLoaded(
      fps: event.fps,
      polygons: event.polygons,
      drawCalls: event.drawCalls,
    ));
  }
}