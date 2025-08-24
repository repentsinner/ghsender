import 'package:flutter/material.dart';
import '../../domain/enums/machine_status.dart';

/// Abstract interface for providing status colors
abstract class StatusColorProvider {
  /// Get the color for a given machine status
  Color getColorForStatus(MachineStatus status);
  
  /// Get a descriptive name for this color provider
  String get providerName;
}

/// Default status colors for general use
class DefaultStatusColorProvider implements StatusColorProvider {
  @override
  String get providerName => 'Default';

  @override
  Color getColorForStatus(MachineStatus status) {
    switch (status) {
      case MachineStatus.idle:
        return Colors.green;
      case MachineStatus.running:
        return Colors.blue;
      case MachineStatus.jogging:
        return Colors.lightBlue;
      case MachineStatus.homing:
        return Colors.purple;
      case MachineStatus.hold:
        return Colors.orange;
      case MachineStatus.door:
        return Colors.yellow;
      case MachineStatus.check:
        return Colors.cyan;
      case MachineStatus.alarm:
        return Colors.red;
      case MachineStatus.error:
        return Colors.red;
      case MachineStatus.sleep:
        return Colors.grey;
      case MachineStatus.paused:
        return Colors.orange;
      case MachineStatus.unknown:
        return Colors.grey;
    }
  }
}

/// Sienci Indicator Lights plugin color mapping
/// Based on the official Sienci LED color specifications
class SienciStatusColorProvider implements StatusColorProvider {
  @override
  String get providerName => 'Sienci LED';

  /// Sienci LED color mapping based on their official specifications
  static const Map<MachineStatus, Color> _statusColors = {
    MachineStatus.idle: Color.fromRGBO(255, 255, 255, 1.0),     // White
    MachineStatus.running: Color.fromRGBO(0, 255, 0, 1.0),      // Green
    MachineStatus.jogging: Color.fromRGBO(0, 255, 0, 1.0),      // Green
    MachineStatus.homing: Color.fromRGBO(0, 0, 255, 1.0),       // Blue
    MachineStatus.hold: Color.fromRGBO(255, 255, 0, 1.0),       // Yellow
    MachineStatus.door: Color.fromRGBO(255, 255, 0, 1.0),       // Yellow
    MachineStatus.check: Color.fromRGBO(0, 0, 255, 1.0),        // Blue
    MachineStatus.alarm: Color.fromRGBO(255, 0, 0, 1.0),        // Red
    MachineStatus.error: Color.fromRGBO(255, 0, 0, 1.0),        // Red
    MachineStatus.sleep: Color.fromRGBO(127, 127, 127, 1.0),    // Grey
    MachineStatus.paused: Color.fromRGBO(255, 255, 0, 1.0),     // Yellow (similar to hold)
    MachineStatus.unknown: Color.fromRGBO(127, 127, 127, 1.0),  // Grey
  };

  @override
  Color getColorForStatus(MachineStatus status) {
    return _statusColors[status] ?? _statusColors[MachineStatus.unknown]!;
  }
}

/// Factory for creating appropriate status color providers
class StatusColorProviders {
  /// Get the appropriate color provider based on detected plugins
  static StatusColorProvider getProviderForPlugins(List<String> plugins) {
    // Check for Sienci Indicator Lights plugin
    final hasSienciPlugin = plugins.any((plugin) => 
        plugin.toLowerCase().contains('sienci') && 
        plugin.toLowerCase().contains('indicator'));
        
    if (hasSienciPlugin) {
      return SienciStatusColorProvider();
    }
    
    // TODO: Add support for other RGB plugins here in the future
    // e.g., NeoPixel, FastLED, WS2812, etc.
    
    // Default fallback
    return DefaultStatusColorProvider();
  }
  
  /// Get all available providers (useful for settings/preferences UI)
  static List<StatusColorProvider> getAllProviders() {
    return [
      DefaultStatusColorProvider(),
      SienciStatusColorProvider(),
    ];
  }
}