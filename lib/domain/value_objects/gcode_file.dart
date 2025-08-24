import 'package:equatable/equatable.dart';

/// G-code file management data model
class GCodeFile extends Equatable {
  final String name;
  final String path;
  final int sizeBytes;
  final DateTime uploadDate;
  final String status; // 'ready', 'completed', 'processing'
  final Duration? estimatedTime;

  const GCodeFile({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.uploadDate,
    required this.status,
    this.estimatedTime,
  });

  String get formattedSize {
    if (sizeBytes < 1024) {
      return '$sizeBytes B';
    }
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    return '${uploadDate.year}-${uploadDate.month.toString().padLeft(2, '0')}-${uploadDate.day.toString().padLeft(2, '0')}';
  }

  String get formattedTime {
    if (estimatedTime == null) return 'Unknown';
    final minutes = estimatedTime!.inMinutes;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}min';
  }

  @override
  List<Object?> get props => [name, path, sizeBytes, uploadDate, status, estimatedTime];

  @override
  String toString() {
    return 'GCodeFile(name: $name, path: $path, size: $formattedSize, status: $status)';
  }
}