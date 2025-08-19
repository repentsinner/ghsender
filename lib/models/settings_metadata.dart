import 'package:equatable/equatable.dart';

/// grblHAL setting data types as defined in the extended report format
enum SettingDataType {
  boolean,
  bitfield,
  radioButton,
  integer,
  float,
  string,
  ipAddress,
  unknown,
}

/// Represents metadata for a grblHAL setting from $ES command
/// Contains display information but not the actual setting value
class SettingMetadata extends Equatable {
  final int settingId;
  final int? groupId;
  final String? name;
  final String? unit;
  final SettingDataType dataType;
  final String? format;
  final double? minValue;
  final double? maxValue;
  final bool allowsNegative;
  final DateTime lastUpdated;

  const SettingMetadata({
    required this.settingId,
    this.groupId,
    this.name,
    this.unit,
    this.dataType = SettingDataType.unknown,
    this.format,
    this.minValue,
    this.maxValue,
    this.allowsNegative = true,
    required this.lastUpdated,
  });

  @override
  List<Object?> get props => [
    settingId, groupId, name, unit, dataType, format, 
    minValue, maxValue, allowsNegative, lastUpdated
  ];

  SettingMetadata copyWith({
    int? settingId,
    int? groupId,
    String? name,
    String? unit,
    SettingDataType? dataType,
    String? format,
    double? minValue,
    double? maxValue,
    bool? allowsNegative,
    DateTime? lastUpdated,
  }) {
    return SettingMetadata(
      settingId: settingId ?? this.settingId,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      dataType: dataType ?? this.dataType,
      format: format ?? this.format,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      allowsNegative: allowsNegative ?? this.allowsNegative,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Parse metadata from grblHAL $ES command format
  /// Format: `[SETTING:<id>|<group_id>|<name>|<unit>|<datatype>|<format>|<min>|<max>|<allow_negative>]`
  static SettingMetadata? parseFromExtendedLine(String line, DateTime parseTime) {
    // Pattern: [SETTING:<id>|<group_id>|<name>|<unit>|<datatype>|<format>|<min>|<max>|<allow_negative>]
    final settingPattern = RegExp(r'^\[SETTING:(\d+)\|(.+)\]$');
    final match = settingPattern.firstMatch(line);
    
    if (match != null) {
      try {
        final settingId = int.parse(match.group(1)!);
        final extendedInfo = match.group(2)!;
        
        // Parse pipe-separated extended information
        final parts = extendedInfo.split('|');
        
        int? groupId;
        String? name;
        String? unit;
        SettingDataType dataType = SettingDataType.unknown;
        String? format;
        double? minValue;
        double? maxValue;
        bool allowsNegative = true;
        
        // Parse each component (be flexible about missing fields)
        if (parts.isNotEmpty && parts[0].isNotEmpty) {
          groupId = int.tryParse(parts[0]);
        }
        if (parts.length > 1 && parts[1].isNotEmpty) {
          name = parts[1];
        }
        if (parts.length > 2 && parts[2].isNotEmpty) {
          unit = parts[2];
        }
        if (parts.length > 3 && parts[3].isNotEmpty) {
          dataType = _parseDataType(parts[3]);
        }
        if (parts.length > 4 && parts[4].isNotEmpty) {
          format = parts[4];
        }
        if (parts.length > 5 && parts[5].isNotEmpty) {
          minValue = double.tryParse(parts[5]);
        }
        if (parts.length > 6 && parts[6].isNotEmpty) {
          maxValue = double.tryParse(parts[6]);
        }
        if (parts.length > 7 && parts[7].isNotEmpty) {
          allowsNegative = parts[7] == '1' || parts[7].toLowerCase() == 'true';
        }
        
        return SettingMetadata(
          settingId: settingId,
          groupId: groupId,
          name: name,
          unit: unit,
          dataType: dataType,
          format: format,
          minValue: minValue,
          maxValue: maxValue,
          allowsNegative: allowsNegative,
          lastUpdated: parseTime,
        );
      } catch (e) {
        // Ignore malformed lines
        return null;
      }
    }
    
    return null;
  }

  /// Parse data type from grblHAL extended format
  static SettingDataType _parseDataType(String typeStr) {
    switch (typeStr.toLowerCase()) {
      case 'bool':
      case 'boolean':
        return SettingDataType.boolean;
      case 'bitfield':
      case 'bitmask':
        return SettingDataType.bitfield;
      case 'radio':
      case 'radiobutton':
        return SettingDataType.radioButton;
      case 'int':
      case 'integer':
        return SettingDataType.integer;
      case 'float':
      case 'double':
      case 'number':
        return SettingDataType.float;
      case 'string':
      case 'text':
        return SettingDataType.string;
      case 'ip':
      case 'ipaddress':
        return SettingDataType.ipAddress;
      default:
        return SettingDataType.unknown;
    }
  }
}

/// Represents a grblHAL setting group for hierarchical organization from $EG command
class SettingGroup extends Equatable {
  final int id;
  final int parentId;
  final String name;
  final DateTime lastUpdated;

  const SettingGroup({
    required this.id,
    required this.parentId,
    required this.name,
    required this.lastUpdated,
  });

  @override
  List<Object?> get props => [id, parentId, name, lastUpdated];

  SettingGroup copyWith({
    int? id,
    int? parentId,
    String? name,
    DateTime? lastUpdated,
  }) {
    return SettingGroup(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Parse setting group from grblHAL $EG command format
  /// Format: `[SETTINGGROUP:<id>|<parent id>|<name>]`
  static SettingGroup? parseFromGroupLine(String line, DateTime parseTime) {
    // Pattern: [SETTINGGROUP:<id>|<parent_id>|<name>]
    final groupPattern = RegExp(r'^\[SETTINGGROUP:(\d+)\|(\d+)\|(.+)\]$');
    final match = groupPattern.firstMatch(line);
    
    if (match != null) {
      try {
        final id = int.parse(match.group(1)!);
        final parentId = int.parse(match.group(2)!);
        final name = match.group(3)!;
        
        return SettingGroup(
          id: id,
          parentId: parentId,
          name: name,
          lastUpdated: parseTime,
        );
      } catch (e) {
        // Ignore malformed lines
        return null;
      }
    }
    
    return null;
  }
}

/// Enriched setting that combines current value with metadata for UI display
class EnrichedSetting extends Equatable {
  final int settingId;
  final String currentValue;
  final SettingMetadata? metadata;
  final DateTime valueUpdated;

  const EnrichedSetting({
    required this.settingId,
    required this.currentValue,
    this.metadata,
    required this.valueUpdated,
  });

  @override
  List<Object?> get props => [settingId, currentValue, metadata, valueUpdated];

  /// Get display-friendly setting name
  String get displayName {
    if (metadata?.name != null && metadata!.name!.isNotEmpty) {
      return metadata!.name!;
    }
    return 'Setting $settingId';
  }

  /// Get formatted value with units and type information
  String get formattedValue {
    final parts = <String>[currentValue];
    
    // Add data type indicator for non-unknown types
    if (metadata?.dataType != null && metadata!.dataType != SettingDataType.unknown) {
      parts.add(_formatDataType(metadata!.dataType));
    }
    
    // Add unit if available
    if (metadata?.unit != null && metadata!.unit!.isNotEmpty) {
      parts.add(metadata!.unit!);
    }
    
    // Add range information if available
    if (metadata?.minValue != null || metadata?.maxValue != null) {
      final rangeStr = _formatRange(metadata!.minValue, metadata!.maxValue);
      if (rangeStr.isNotEmpty) {
        parts.add('range: $rangeStr');
      }
    }
    
    // Join parts appropriately
    if (parts.length == 1) {
      return parts[0];
    } else {
      final value = parts[0];
      final info = parts.skip(1).join(', ');
      return '$value ($info)';
    }
  }

  /// Format data type for display
  String _formatDataType(SettingDataType dataType) {
    switch (dataType) {
      case SettingDataType.boolean:
        return 'bool';
      case SettingDataType.bitfield:
        return 'bitfield';
      case SettingDataType.radioButton:
        return 'radio';
      case SettingDataType.integer:
        return 'int';
      case SettingDataType.float:
        return 'float';
      case SettingDataType.string:
        return 'string';
      case SettingDataType.ipAddress:
        return 'IP';
      case SettingDataType.unknown:
        return '';
    }
  }

  /// Format min/max range for display
  String _formatRange(double? minValue, double? maxValue) {
    if (minValue != null && maxValue != null) {
      return '${minValue.toStringAsFixed(minValue == minValue.toInt() ? 0 : 1)}-${maxValue.toStringAsFixed(maxValue == maxValue.toInt() ? 0 : 1)}';
    } else if (minValue != null) {
      return '≥${minValue.toStringAsFixed(minValue == minValue.toInt() ? 0 : 1)}';
    } else if (maxValue != null) {
      return '≤${maxValue.toStringAsFixed(maxValue == maxValue.toInt() ? 0 : 1)}';
    }
    return '';
  }
}