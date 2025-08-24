import 'package:equatable/equatable.dart';

/// Represents a single grblHAL configuration setting (machine state only)
/// Contains only the setting value and basic identification - no UI metadata
class ConfigurationSetting extends Equatable {
  final int number;
  final String rawValue;
  final String? description;
  final DateTime lastUpdated;

  const ConfigurationSetting({
    required this.number,
    required this.rawValue,
    this.description,
    required this.lastUpdated,
  });

  /// Parse numeric value if possible
  double? get numericValue {
    try {
      return double.parse(rawValue);
    } catch (e) {
      return null;
    }
  }

  /// Parse boolean value (0/1 or true/false)
  bool? get booleanValue {
    final lower = rawValue.toLowerCase().trim();
    if (lower == '1' || lower == 'true') return true;
    if (lower == '0' || lower == 'false') return false;
    return null;
  }

  /// Get string value (trimmed)
  String get stringValue => rawValue.trim();

  @override
  List<Object?> get props => [number, rawValue, description, lastUpdated];

  ConfigurationSetting copyWith({
    int? number,
    String? rawValue,
    String? description,
    DateTime? lastUpdated,
  }) {
    return ConfigurationSetting(
      number: number ?? this.number,
      rawValue: rawValue ?? this.rawValue,
      description: description ?? this.description,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}