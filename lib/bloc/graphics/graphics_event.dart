import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Graphics events for camera and rendering controls
abstract class GraphicsEvent extends Equatable {
  const GraphicsEvent();

  @override
  List<Object?> get props => [];
}

/// Event to update camera state
class GraphicsCameraStateUpdated extends GraphicsEvent {
  final String cameraInfo;
  final bool isAutoMode;
  final VoidCallback? onCameraToggle;

  const GraphicsCameraStateUpdated({
    required this.cameraInfo,
    required this.isAutoMode,
    this.onCameraToggle,
  });

  @override
  List<Object?> get props => [cameraInfo, isAutoMode, onCameraToggle];
}

/// Event to update line control state
class GraphicsLineControlsUpdated extends GraphicsEvent {
  final double lineWeight;
  final double lineSmoothness;
  final double lineOpacity;
  final ValueChanged<double>? onLineWeightChanged;
  final ValueChanged<double>? onLineSmoothnessChanged;
  final ValueChanged<double>? onLineOpacityChanged;

  const GraphicsLineControlsUpdated({
    required this.lineWeight,
    required this.lineSmoothness,
    required this.lineOpacity,
    this.onLineWeightChanged,
    this.onLineSmoothnessChanged,
    this.onLineOpacityChanged,
  });

  @override
  List<Object?> get props => [
    lineWeight,
    lineSmoothness,
    lineOpacity,
    onLineWeightChanged,
    onLineSmoothnessChanged,
    onLineOpacityChanged,
  ];
}