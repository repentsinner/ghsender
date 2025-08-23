# Testing Framework Guide

## Overview
The project now includes a comprehensive testing framework with the following capabilities:
- ✅ **Core Testing**: `test` package for unit tests
- ✅ **BLoC Testing**: `bloc_test` package for state management testing
- ✅ **Mocking**: Both `mockito` and `mocktail` for creating test doubles
- ✅ **Code Generation**: `build_runner` for auto-generating mocks

## Dependencies Added

```yaml
dev_dependencies:
  test: ^1.24.0          # Core test framework (resolves analyzer warnings)
  mocktail: ^1.0.4       # Mock object framework (alternative to mockito) 
  bloc_test: ^10.0.0     # BLoC testing utilities
  mockito: ^5.4.4        # Traditional mock framework
  build_runner: ^2.4.7   # Required for mockito code generation
```

## Key Features

### 1. BLoC Testing with `bloc_test`
Test state transitions and side effects easily:

```dart
blocTest<JogControllerBloc, JogControllerState>(
  'emits [processing] when joystick input received',
  build: () => JogControllerBloc(
    machineControllerBloc: mockMachineController,
    communicationBloc: mockCommunication,
  ),
  act: (bloc) => bloc.add(
    ProportionalJogInputReceived(inputEvent: testEvent),
  ),
  expect: () => [
    isA<JogControllerState>()
        .having((s) => s.joystickState.isActive, 'isActive', true),
  ],
);
```

### 2. Mock Generation with Mockito
Auto-generate mocks for complex dependencies:

```dart
// 1. Add annotation
@GenerateMocks([MachineControllerBloc, CncCommunicationBloc])
import 'my_test.mocks.dart';

// 2. Generate mocks
// Run: flutter packages pub run build_runner build

// 3. Use in tests
final mockMachine = MockMachineControllerBloc();
when(mockMachine.state).thenReturn(idleState);
```

### 3. Input Driver Testing
Test the new proportional jog system:

```dart
test('input driver processes events correctly', () async {
  final driver = FlutterJoystickDriver(instanceId: 'test');
  final events = <JogInputEvent>[];
  
  driver.inputStream.listen(events.add);
  await driver.initialize();
  
  driver.onJoystickInput(0.5, 0.8);
  
  expect(events, hasLength(1));
  expect(events.first.x, equals(0.5));
  expect(events.first.y, equals(0.8));
});
```

## Testing Patterns

### 1. Isolated Unit Tests
Test individual components without dependencies:

```dart
test('proportional controller processes input correctly', () {
  final result = ProportionalJogController.process2D(
    rawX: 0.6,
    rawY: 0.8,
    selectedFeedRate: 1000,
  );
  
  expect(result.isActive, isTrue);
  expect(result.magnitude, closeTo(1.0, 0.01));
});
```

### 2. BLoC Integration Tests
Test BLoC interactions with mocked dependencies:

```dart
blocTest<JogControllerBloc, JogControllerState>(
  'sends jog command when input received',
  setUp: () {
    when(mockMachineController.state).thenReturn(idleState);
  },
  build: () => jogBloc,
  act: (bloc) => bloc.add(JoystickInputReceived(x: 0.5, y: 0.8)),
  verify: (bloc) {
    verify(mockMachineController.add(any<MachineControllerJogRequested>()));
  },
);
```

### 3. Driver Management Tests
Test input driver lifecycle:

```dart
group('Input Driver Management', () {
  test('can add and remove drivers', () async {
    final driver = FlutterJoystickDriver();
    
    await jogBloc.addInputDriver(driver);
    expect(jogBloc.inputDrivers.length, equals(1));
    
    await jogBloc.removeInputDriver(driver.deviceId);
    expect(jogBloc.inputDrivers.length, equals(0));
  });
});
```

## Running Tests

### All Tests
```bash
flutter test --enable-flutter-gpu --enable-impeller
```

### Specific Test Categories
```bash
flutter test test/unit/            # Unit tests only
flutter test test/widget/          # Widget tests only  
flutter test test/integration/     # Integration tests only
```

### Single Test File
```bash
flutter test test/unit/jog_controller_bloc_test.dart
```

### Generate Mocks
```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

## Mock Generation Workflow

1. **Add Annotations**: Add `@GenerateMocks([YourClass])` to test file
2. **Import Generated File**: Add `import 'your_test.mocks.dart';`
3. **Generate**: Run `flutter packages pub run build_runner build`
4. **Use Mocks**: Create instances and set up with `when()` statements

## Best Practices

### 1. Setup and Teardown
```dart
group('JogControllerBloc', () {
  late JogControllerBloc bloc;
  late MockMachineControllerBloc mockMachine;
  
  setUp(() {
    mockMachine = MockMachineControllerBloc();
    bloc = JogControllerBloc(machineControllerBloc: mockMachine);
  });
  
  tearDown(() {
    bloc.close();
  });
});
```

### 2. Test Organization
```dart
group('Feature Name', () {
  group('Sub-feature', () {
    test('specific behavior', () {
      // Test implementation
    });
  });
});
```

### 3. Mock Setup
```dart
setUp(() {
  // Set up common mock behaviors
  when(mockMachine.state).thenReturn(idleState);
  when(mockCommunication.isConnected).thenReturn(true);
});
```

## Testing the Jog Refactor

The new proportional jog controller refactor is fully testable:

### Test ProportionalJogController
- ✅ Dead zone filtering
- ✅ Magnitude calculations  
- ✅ Soft limits integration
- ✅ 6DOF input processing

### Test Input Drivers
- ✅ Event generation
- ✅ Enable/disable functionality
- ✅ Lifecycle management

### Test JogControllerBloc
- ✅ Driver management
- ✅ Input processing
- ✅ State transitions
- ✅ Command generation

## Troubleshooting

### Mock Generation Issues
```bash
# Clean and rebuild
flutter clean
flutter packages pub run build_runner clean
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### Missing Stubs
```dart
// Add stub for mock method calls
when(mockObject.method()).thenReturn(value);

// Or use @GenerateNiceMocks for default returns
@GenerateNiceMocks([YourClass])
```

### Test Timeouts
```bash
flutter test --timeout=60s  # Extend timeout for complex tests
```

---
**The testing framework is now fully configured and ready for comprehensive BLoC and input driver testing!** 🚀