import 'package:equatable/equatable.dart';

/// Feed rate information
class FeedState extends Equatable {
  final double rate; // units per minute
  final double targetRate; // units per minute
  final String units; // "mm/min" or "inch/min"
  final DateTime lastUpdated;

  const FeedState({
    required this.rate,
    required this.targetRate,
    this.units = 'mm/min',
    required this.lastUpdated,
  });

  @override
  List<Object?> get props => [rate, targetRate, units, lastUpdated];

  FeedState copyWith({
    double? rate,
    double? targetRate,
    String? units,
    DateTime? lastUpdated,
  }) {
    return FeedState(
      rate: rate ?? this.rate,
      targetRate: targetRate ?? this.targetRate,
      units: units ?? this.units,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}