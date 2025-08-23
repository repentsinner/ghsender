import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:ghsender/bloc/jog_controller/jog_controller_bloc.dart';
import 'package:ghsender/bloc/jog_controller/jog_controller_event.dart';
import 'package:ghsender/bloc/jog_controller/jog_controller_state.dart';
import 'package:ghsender/bloc/machine_controller/machine_controller_bloc.dart';
import 'package:ghsender/bloc/communication/cnc_communication_bloc.dart';
import 'package:ghsender/services/jog_input_driver.dart';
import 'package:ghsender/services/flutter_joystick_driver.dart';

// Generate mocks for the dependencies
@GenerateMocks([MachineControllerBloc, CncCommunicationBloc])
import 'jog_controller_bloc_test.mocks.dart';

void main() {
  group('JogControllerBloc', () {
    late JogControllerBloc jogControllerBloc;
    late MockMachineControllerBloc mockMachineControllerBloc;
    late MockCncCommunicationBloc mockCommunicationBloc;

    setUp(() {
      mockMachineControllerBloc = MockMachineControllerBloc();
      mockCommunicationBloc = MockCncCommunicationBloc();
      
      jogControllerBloc = JogControllerBloc(
        machineControllerBloc: mockMachineControllerBloc,
        communicationBloc: mockCommunicationBloc,
      );
    });

    tearDown(() {
      jogControllerBloc.close();
    });

    group('Initialization', () {
      blocTest<JogControllerBloc, JogControllerState>(
        'emits initialized state when JogControllerInitialized is added',
        build: () => jogControllerBloc,
        act: (bloc) => bloc.add(const JogControllerInitialized()),
        expect: () => [
          isA<JogControllerState>()
              .having((state) => state.isInitialized, 'isInitialized', true),
        ],
      );
    });

    group('Input Driver Management', () {
      test('can add and remove input drivers', () async {
        final mockDriver = FlutterJoystickDriver(instanceId: 'test');
        
        // Add driver
        await jogControllerBloc.addInputDriver(mockDriver);
        expect(jogControllerBloc.inputDrivers.length, equals(1));
        expect(jogControllerBloc.inputDrivers.first.deviceId, 
               contains('test'));

        // Remove driver
        await jogControllerBloc.removeInputDriver(mockDriver.deviceId);
        expect(jogControllerBloc.inputDrivers.length, equals(0));
      });

      test('can enable and disable input drivers', () async {
        final mockDriver = FlutterJoystickDriver(instanceId: 'test');
        await jogControllerBloc.addInputDriver(mockDriver);
        
        // Initially enabled
        expect(mockDriver.isEnabled, isTrue);
        
        // Disable
        jogControllerBloc.setInputDriverEnabled(mockDriver.deviceId, false);
        expect(mockDriver.isEnabled, isFalse);
        
        // Re-enable
        jogControllerBloc.setInputDriverEnabled(mockDriver.deviceId, true);
        expect(mockDriver.isEnabled, isTrue);
      });
    });

    group('Proportional Input Processing', () {
      blocTest<JogControllerBloc, JogControllerState>(
        'processes proportional jog input correctly',
        build: () => jogControllerBloc,
        seed: () => JogControllerState.initial.copyWith(
          settings: JogControllerState.initial.settings.copyWith(
            mode: JogMode.joystick,
          ),
        ),
        act: (bloc) {
          // Create a test input event
          final inputEvent = JogInputEvent.xy(
            x: 0.5,
            y: 0.8,
            deviceId: 'test_driver',
          );
          
          bloc.add(ProportionalJogInputReceived(inputEvent: inputEvent));
        },
        expect: () => [
          // Should update joystick state with new input values
          isA<JogControllerState>().having(
            (state) => state.joystickState.x,
            'joystick x',
            closeTo(0.5, 0.1),
          ),
        ],
      );
    });

    group('Settings Updates', () {
      blocTest<JogControllerBloc, JogControllerState>(
        'updates jog settings correctly',
        build: () => jogControllerBloc,
        act: (bloc) => bloc.add(
          const JogSettingsUpdated(
            selectedFeedRate: 1500,
            selectedDistance: 5.0,
            mode: JogMode.discrete,
          ),
        ),
        expect: () => [
          isA<JogControllerState>().having(
            (state) => state.settings.selectedFeedRate,
            'selectedFeedRate',
            equals(1500),
          ).having(
            (state) => state.settings.selectedDistance,
            'selectedDistance',
            equals(5.0),
          ).having(
            (state) => state.settings.mode,
            'mode',
            equals(JogMode.discrete),
          ),
        ],
      );
    });
  });
}