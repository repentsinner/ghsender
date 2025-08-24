import 'package:equatable/equatable.dart';

/// Spindle information
class SpindleState extends Equatable {
  final bool isRunning;
  final double speed; // RPM
  final double targetSpeed; // RPM
  final bool isClockwise;
  final DateTime lastUpdated;

  const SpindleState({
    required this.isRunning,
    required this.speed,
    required this.targetSpeed,
    this.isClockwise = true,
    required this.lastUpdated,
  });

  @override
  List<Object?> get props => [isRunning, speed, targetSpeed, isClockwise, lastUpdated];

  SpindleState copyWith({
    bool? isRunning,
    double? speed,
    double? targetSpeed,
    bool? isClockwise,
    DateTime? lastUpdated,
  }) {
    return SpindleState(
      isRunning: isRunning ?? this.isRunning,
      speed: speed ?? this.speed,
      targetSpeed: targetSpeed ?? this.targetSpeed,
      isClockwise: isClockwise ?? this.isClockwise,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}