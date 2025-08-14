import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Graphics state for camera and rendering controls
abstract class GraphicsState extends Equatable {
  const GraphicsState();

  @override
  List<Object?> get props => [];
}

/// Initial graphics state
class GraphicsInitial extends GraphicsState {
  const GraphicsInitial();
}

/// Graphics state with camera and line control data
class GraphicsLoaded extends GraphicsState {
  final String cameraInfo;
  final bool isAutoMode;
  final VoidCallback? onCameraToggle;
  final double lineWeight;
  final double lineSmoothness;
  final double lineOpacity;
  final ValueChanged<double>? onLineWeightChanged;
  final ValueChanged<double>? onLineSmoothnessChanged;
  final ValueChanged<double>? onLineOpacityChanged;

  const GraphicsLoaded({
    required this.cameraInfo,
    required this.isAutoMode,
    this.onCameraToggle,
    required this.lineWeight,
    required this.lineSmoothness,
    required this.lineOpacity,
    this.onLineWeightChanged,
    this.onLineSmoothnessChanged,
    this.onLineOpacityChanged,
  });

  @override
  List<Object?> get props => [
    cameraInfo,
    isAutoMode,
    onCameraToggle,
    lineWeight,
    lineSmoothness,
    lineOpacity,
    onLineWeightChanged,
    onLineSmoothnessChanged,
    onLineOpacityChanged,
  ];

  GraphicsLoaded copyWith({
    String? cameraInfo,
    bool? isAutoMode,
    VoidCallback? onCameraToggle,
    double? lineWeight,
    double? lineSmoothness,
    double? lineOpacity,
    ValueChanged<double>? onLineWeightChanged,
    ValueChanged<double>? onLineSmoothnessChanged,
    ValueChanged<double>? onLineOpacityChanged,
  }) {
    return GraphicsLoaded(
      cameraInfo: cameraInfo ?? this.cameraInfo,
      isAutoMode: isAutoMode ?? this.isAutoMode,
      onCameraToggle: onCameraToggle ?? this.onCameraToggle,
      lineWeight: lineWeight ?? this.lineWeight,
      lineSmoothness: lineSmoothness ?? this.lineSmoothness,
      lineOpacity: lineOpacity ?? this.lineOpacity,
      onLineWeightChanged: onLineWeightChanged ?? this.onLineWeightChanged,
      onLineSmoothnessChanged: onLineSmoothnessChanged ?? this.onLineSmoothnessChanged,
      onLineOpacityChanged: onLineOpacityChanged ?? this.onLineOpacityChanged,
    );
  }
}