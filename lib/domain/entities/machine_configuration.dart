import 'package:equatable/equatable.dart';
import '../value_objects/configuration_setting.dart';

/// Complete grblHAL machine configuration parsed from $ command responses
class MachineConfiguration extends Equatable {
  final Map<int, ConfigurationSetting> settings;
  final DateTime lastUpdated;
  final bool isComplete;
  
  // Firmware information (realistic scope for grblHAL)
  final String? firmwareVersion;

  const MachineConfiguration({
    this.settings = const {},
    required this.lastUpdated,
    this.isComplete = false,
    this.firmwareVersion,
  });

  /// Get setting by number
  ConfigurationSetting? getSetting(int number) => settings[number];

  /// Get numeric value for setting
  double? getNumeric(int number) => getSetting(number)?.numericValue;

  /// Get boolean value for setting
  bool? getBoolean(int number) => getSetting(number)?.booleanValue;

  /// Get string value for setting
  String? getString(int number) => getSetting(number)?.stringValue;

  // Common grblHAL settings with typed accessors
  // Steps per millimeter settings
  double? get xStepsPerMm => getNumeric(100);
  double? get yStepsPerMm => getNumeric(101);
  double? get zStepsPerMm => getNumeric(102);
  double? get aStepsPerMm => getNumeric(103);
  double? get bStepsPerMm => getNumeric(104);
  double? get cStepsPerMm => getNumeric(105);

  // Maximum rate settings (mm/min)
  double? get xMaxRate => getNumeric(110);
  double? get yMaxRate => getNumeric(111);
  double? get zMaxRate => getNumeric(112);
  double? get aMaxRate => getNumeric(113);
  double? get bMaxRate => getNumeric(114);
  double? get cMaxRate => getNumeric(115);

  // Acceleration settings (mm/sec^2)
  double? get xAcceleration => getNumeric(120);
  double? get yAcceleration => getNumeric(121);
  double? get zAcceleration => getNumeric(122);
  double? get aAcceleration => getNumeric(123);
  double? get bAcceleration => getNumeric(124);
  double? get cAcceleration => getNumeric(125);

  // Maximum travel settings (mm)
  double? get xMaxTravel => getNumeric(130);
  double? get yMaxTravel => getNumeric(131);
  double? get zMaxTravel => getNumeric(132);
  double? get aMaxTravel => getNumeric(133);
  double? get bMaxTravel => getNumeric(134);
  double? get cMaxTravel => getNumeric(135);

  // Common configuration settings
  double? get stepPulseTime => getNumeric(0);       // Step pulse time (microseconds)
  double? get stepIdleDelay => getNumeric(1);       // Step idle delay (milliseconds)
  int? get stepPortInvert => getNumeric(2)?.toInt(); // Step pulse invert (bitmask)
  int? get dirPortInvert => getNumeric(3)?.toInt();  // Direction port invert (bitmask)
  bool? get stepEnableInvert => getBoolean(4);      // Step enable invert
  bool? get limitPinsInvert => getBoolean(5);       // Limit pins invert
  bool? get probePinInvert => getBoolean(6);        // Probe pin invert
  int? get statusReport => getNumeric(10)?.toInt(); // Status report options (bitmask)
  double? get junctionDeviation => getNumeric(11);  // Junction deviation (mm)
  double? get arcTolerance => getNumeric(12);       // Arc tolerance (mm)
  bool? get reportInches => getBoolean(13);         // Report in inches
  int? get controlInvert => getNumeric(14)?.toInt(); // Control signals invert (bitmask)
  int? get coolantInvert => getNumeric(15)?.toInt(); // Coolant pins invert (bitmask)
  int? get spindleInvert => getNumeric(16)?.toInt(); // Spindle pins invert (bitmask)
  int? get controlPullUp => getNumeric(17)?.toInt(); // Control pull-up resistors (bitmask)
  int? get limitPullUp => getNumeric(18)?.toInt();   // Limit pull-up resistors (bitmask)
  int? get probePullUp => getNumeric(19)?.toInt();   // Probe pull-up resistor (bitmask)

  // Soft limits and homing
  bool? get softLimitsEnable => getBoolean(20);     // Soft limits enable
  bool? get hardLimitsEnable => getBoolean(21);     // Hard limits enable
  bool? get homingEnable => getBoolean(22);         // Homing cycle enable
  int? get homingDirInvert => getNumeric(23)?.toInt(); // Homing direction invert (bitmask)
  double? get homingFeed => getNumeric(24);         // Homing feed rate (mm/min)
  double? get homingSeek => getNumeric(25);         // Homing seek rate (mm/min)
  double? get homingDebounce => getNumeric(26);     // Homing debounce delay (ms)
  double? get homingPullOff => getNumeric(27);      // Homing pull-off distance (mm)

  // Spindle settings
  double? get spindleMaxRpm => getNumeric(30);      // Maximum spindle speed (RPM)
  double? get spindleMinRpm => getNumeric(31);      // Minimum spindle speed (RPM)
  int? get laserMode => getNumeric(32)?.toInt();    // Laser mode enable

  @override
  List<Object?> get props => [settings, lastUpdated, isComplete, firmwareVersion];

  MachineConfiguration copyWith({
    Map<int, ConfigurationSetting>? settings,
    DateTime? lastUpdated,
    bool? isComplete,
    String? firmwareVersion,
  }) {
    return MachineConfiguration(
      settings: settings ?? this.settings,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isComplete: isComplete ?? this.isComplete,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
    );
  }

  /// Add or update a setting
  MachineConfiguration withSetting(ConfigurationSetting setting) {
    final newSettings = Map<int, ConfigurationSetting>.from(settings);
    newSettings[setting.number] = setting;
    
    return copyWith(
      settings: newSettings,
      lastUpdated: DateTime.now(),
    );
  }

  /// Add multiple settings
  MachineConfiguration withSettings(List<ConfigurationSetting> newSettings) {
    final updatedSettings = Map<int, ConfigurationSetting>.from(settings);
    
    for (final setting in newSettings) {
      updatedSettings[setting.number] = setting;
    }
    
    return copyWith(
      settings: updatedSettings,
      lastUpdated: DateTime.now(),
    );
  }

  /// Factory method to parse configuration from raw message lines (basic $$ format only)
  static MachineConfiguration parseFromMessages(List<String> messages) {
    final settings = <int, ConfigurationSetting>{};
    final parseTime = DateTime.now();
    String? firmwareVersion;
    
    for (final message in messages) {
      final trimmed = message.trim();
      
      // Parse basic setting line ($100=250.000 format)
      final setting = _parseSettingLine(trimmed, parseTime);
      if (setting != null) {
        settings[setting.number] = setting;
        continue;
      }
      
      // Try to parse firmware version from grblHAL welcome message
      final detectedVersion = _parseFirmwareVersion(trimmed);
      if (detectedVersion != null) {
        firmwareVersion = detectedVersion;
      }
    }
    
    return MachineConfiguration(
      settings: settings,
      lastUpdated: parseTime,
      isComplete: settings.isNotEmpty,
      firmwareVersion: firmwareVersion,
    );
  }

  /// Parse a single setting line like "$100=250.000" or "$100=250.000 (X steps/mm)"
  static ConfigurationSetting? _parseSettingLine(String line, DateTime parseTime) {
    // Pattern: $<number>=<value> with optional description
    final settingPattern = RegExp(r'^\$(\d+)=([^\s\(]+)(?:\s*\((.+)\))?');
    final match = settingPattern.firstMatch(line);
    
    if (match != null) {
      try {
        final number = int.parse(match.group(1)!);
        final value = match.group(2)!;
        final description = match.group(3); // Optional description in parentheses
        
        return ConfigurationSetting(
          number: number,
          rawValue: value,
          description: description,
          lastUpdated: parseTime,
        );
      } catch (e) {
        // Ignore malformed lines
        return null;
      }
    }
    
    return null;
  }

  /// Parse firmware version from grblHAL welcome message
  /// Supports formats like "GrblHAL 1.1f" or "Grbl 1.1f [grblHAL"
  static String? _parseFirmwareVersion(String line) {
    // Pattern to match grblHAL version formats
    final grblHalPatterns = [
      // Match "GrblHAL 1.1f" format (most common)
      RegExp(r'grblhal\s+([0-9]+\.[0-9]+[a-z]*)', caseSensitive: false),
      // Match "Grbl 1.1f [grblHAL" format  
      RegExp(r'grbl\s+([0-9]+\.[0-9]+[a-z]*).*\[.*grblhal', caseSensitive: false),
    ];
    
    for (final pattern in grblHalPatterns) {
      final match = pattern.firstMatch(line);
      if (match != null && match.groupCount >= 1) {
        final version = match.group(1);
        if (version != null) {
          return 'GrblHAL $version';
        }
      }
    }
    
    // Fallback: if we see "grblhal" anywhere, try to extract any version number
    if (line.toLowerCase().contains('grblhal')) {
      final versionMatch = RegExp(r'([0-9]+\.[0-9]+[a-z]*)', caseSensitive: false).firstMatch(line);
      if (versionMatch != null) {
        return 'GrblHAL ${versionMatch.group(0)}';
      }
      return 'GrblHAL (version unknown)';
    }
    
    return null;
  }


  @override
  String toString() {
    return 'MachineConfiguration(${settings.length} settings, updated: $lastUpdated)';
  }
}