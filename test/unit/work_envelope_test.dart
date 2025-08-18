import 'package:flutter_test/flutter_test.dart';
import 'package:ghsender/models/machine_controller.dart';
import 'package:ghsender/models/machine_configuration.dart';

void main() {
  group('WorkEnvelope', () {
    late MachineConfiguration testConfig;
    
    setUp(() {
      testConfig = MachineConfiguration(
        settings: {
          130: ConfigurationSetting(
            number: 130,
            rawValue: '-200.0',
            description: 'X max travel',
            lastUpdated: DateTime.now(),
          ),
          131: ConfigurationSetting(
            number: 131,
            rawValue: '-300.0',
            description: 'Y max travel',
            lastUpdated: DateTime.now(),
          ),
          132: ConfigurationSetting(
            number: 132,
            rawValue: '-150.0',
            description: 'Z max travel',
            lastUpdated: DateTime.now(),
          ),
        },
        lastUpdated: DateTime.now(),
      );
    });

    test('should create work envelope from configuration with travel limits', () {
      final workEnvelope = WorkEnvelope.fromConfiguration(testConfig);
      
      expect(workEnvelope, isNotNull);
      expect(workEnvelope!.minBounds.x, equals(-200.0));
      expect(workEnvelope.minBounds.y, equals(-300.0));
      expect(workEnvelope.minBounds.z, equals(-150.0));
      expect(workEnvelope.maxBounds.x, equals(0.0));
      expect(workEnvelope.maxBounds.y, equals(0.0));
      expect(workEnvelope.maxBounds.z, equals(0.0));
      expect(workEnvelope.units, equals('mm'));
    });

    test('should return null when missing required travel settings', () {
      final incompleteConfig = MachineConfiguration(
        settings: {
          130: ConfigurationSetting(
            number: 130,
            rawValue: '-200.0',
            description: 'X max travel',
            lastUpdated: DateTime.now(),
          ),
          // Missing Y and Z travel settings
        },
        lastUpdated: DateTime.now(),
      );

      final workEnvelope = WorkEnvelope.fromConfiguration(incompleteConfig);
      expect(workEnvelope, isNull);
    });

    test('should calculate dimensions correctly', () {
      final workEnvelope = WorkEnvelope.fromConfiguration(testConfig)!;
      final dimensions = workEnvelope.dimensions;
      
      expect(dimensions.x, equals(200.0));
      expect(dimensions.y, equals(300.0));
      expect(dimensions.z, equals(150.0));
    });

    test('should calculate center point correctly', () {
      final workEnvelope = WorkEnvelope.fromConfiguration(testConfig)!;
      final center = workEnvelope.center;
      
      expect(center.x, equals(-100.0));
      expect(center.y, equals(-150.0));
      expect(center.z, equals(-75.0));
    });

    test('should use inches when reportInches is true', () {
      final configWithInches = testConfig.copyWith(
        settings: {
          ...testConfig.settings,
          13: ConfigurationSetting(
            number: 13,
            rawValue: '1',
            description: 'Report in inches',
            lastUpdated: DateTime.now(),
          ),
        },
      );

      final workEnvelope = WorkEnvelope.fromConfiguration(configWithInches);
      expect(workEnvelope!.units, equals('inch'));
    });

    test('should handle absolute values for travel settings', () {
      // Test with positive values (should be converted to absolute)
      final configWithPositive = MachineConfiguration(
        settings: {
          130: ConfigurationSetting(
            number: 130,
            rawValue: '200.0',
            description: 'X max travel',
            lastUpdated: DateTime.now(),
          ),
          131: ConfigurationSetting(
            number: 131,
            rawValue: '300.0',
            description: 'Y max travel',
            lastUpdated: DateTime.now(),
          ),
          132: ConfigurationSetting(
            number: 132,
            rawValue: '150.0',
            description: 'Z max travel',
            lastUpdated: DateTime.now(),
          ),
        },
        lastUpdated: DateTime.now(),
      );

      final workEnvelope = WorkEnvelope.fromConfiguration(configWithPositive);
      
      expect(workEnvelope, isNotNull);
      expect(workEnvelope!.minBounds.x, equals(-200.0));
      expect(workEnvelope.minBounds.y, equals(-300.0));
      expect(workEnvelope.minBounds.z, equals(-150.0));
    });
  });
}