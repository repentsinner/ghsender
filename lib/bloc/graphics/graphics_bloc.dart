import 'package:flutter_bloc/flutter_bloc.dart';
import 'graphics_event.dart';
import 'graphics_state.dart';

/// BLoC for managing graphics camera and line control state
class GraphicsBloc extends Bloc<GraphicsEvent, GraphicsState> {
  GraphicsBloc() : super(const GraphicsInitial()) {
    on<GraphicsCameraStateUpdated>(_onCameraStateUpdated);
    on<GraphicsLineControlsUpdated>(_onLineControlsUpdated);
  }

  void _onCameraStateUpdated(
    GraphicsCameraStateUpdated event,
    Emitter<GraphicsState> emit,
  ) {
    if (state is GraphicsLoaded) {
      final currentState = state as GraphicsLoaded;
      emit(currentState.copyWith(
        cameraInfo: event.cameraInfo,
        isAutoMode: event.isAutoMode,
        onCameraToggle: event.onCameraToggle,
      ));
    } else {
      emit(GraphicsLoaded(
        cameraInfo: event.cameraInfo,
        isAutoMode: event.isAutoMode,
        onCameraToggle: event.onCameraToggle,
        lineWeight: 1.0,
        lineSmoothness: 0.5,
        lineOpacity: 0.5,
      ));
    }
  }

  void _onLineControlsUpdated(
    GraphicsLineControlsUpdated event,
    Emitter<GraphicsState> emit,
  ) {
    if (state is GraphicsLoaded) {
      final currentState = state as GraphicsLoaded;
      emit(currentState.copyWith(
        lineWeight: event.lineWeight,
        lineSmoothness: event.lineSmoothness,
        lineOpacity: event.lineOpacity,
        onLineWeightChanged: event.onLineWeightChanged,
        onLineSmoothnessChanged: event.onLineSmoothnessChanged,
        onLineOpacityChanged: event.onLineOpacityChanged,
      ));
    } else {
      emit(GraphicsLoaded(
        cameraInfo: '',
        isAutoMode: false,
        lineWeight: event.lineWeight,
        lineSmoothness: event.lineSmoothness,
        lineOpacity: event.lineOpacity,
        onLineWeightChanged: event.onLineWeightChanged,
        onLineSmoothnessChanged: event.onLineSmoothnessChanged,
        onLineOpacityChanged: event.onLineOpacityChanged,
      ));
    }
  }
}