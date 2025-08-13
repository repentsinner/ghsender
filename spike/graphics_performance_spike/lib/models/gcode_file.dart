/// G-code file management data model
class GCodeFile {
  final String name;
  final String path;
  final int sizeBytes;
  final DateTime uploadDate;
  final String status; // 'ready', 'completed', 'processing'
  final Duration? estimatedTime;

  GCodeFile({
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
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GCodeFile &&
        other.name == name &&
        other.path == path &&
        other.sizeBytes == sizeBytes;
  }

  @override
  int get hashCode {
    return name.hashCode ^ path.hashCode ^ sizeBytes.hashCode;
  }

  @override
  String toString() {
    return 'GCodeFile(name: $name, path: $path, size: $formattedSize, status: $status)';
  }
}