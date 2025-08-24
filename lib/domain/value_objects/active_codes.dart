import 'package:equatable/equatable.dart';

/// Active G/M codes on the machine
class ActiveCodes extends Equatable {
  final List<String> gCodes; // Active G codes (e.g., "G90", "G54")
  final List<String> mCodes; // Active M codes (e.g., "M3", "M8")
  final DateTime lastUpdated;

  const ActiveCodes({
    this.gCodes = const [],
    this.mCodes = const [],
    required this.lastUpdated,
  });

  @override
  List<Object?> get props => [gCodes, mCodes, lastUpdated];

  ActiveCodes copyWith({
    List<String>? gCodes,
    List<String>? mCodes,
    DateTime? lastUpdated,
  }) {
    return ActiveCodes(
      gCodes: gCodes ?? this.gCodes,
      mCodes: mCodes ?? this.mCodes,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}