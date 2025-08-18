# Architecture Refactoring Plan

**Target**: Domain-Driven Design + Focused BLoC Architecture  
**Timeline**: 6-8 weeks  
**Priority**: High - Foundation for safety features and extensibility

## Overview

This document provides detailed implementation guidance for refactoring the current monolithic BLoC architecture into a domain-driven design with focused, testable components.

## Current Architecture Issues

### 1. **Monolithic BLoCs**
- `MachineControllerBloc`: 500+ lines handling status, position, alarms, configuration
- Mixed concerns make testing difficult
- Single point of failure for machine operations
- Difficult to extend with new features

### 2. **Business Logic in Presentation Layer**
- Safety validation scattered across BLoCs
- Domain rules mixed with UI state management
- No clear separation between "what" and "how"
- Difficult to unit test without Flutter dependencies

### 3. **Tight Coupling**
- Direct dependencies between BLoCs and infrastructure
- Hard to mock for testing
- Difficult to swap implementations
- No clear interfaces for extensibility

## Refactoring Strategy

### Phase 1: Domain Layer Foundation (2-3 weeks)

#### Week 1: Core Entities and Value Objects

**Create Domain Entities:**

```dart
// lib/domain/entities/machine.dart
class Machine {
  final MachineId id;
  final MachineConfiguration configuration;
  final MachinePosition currentPosition;
  final MachineStatus status;
  final SafetyEnvelope safetyEnvelope;
  final List<Alarm> activeAlarms;

  const Machine({
    required this.id,
    required this.configuration,
    required this.currentPosition,
    required this.status,
    required this.safetyEnvelope,
    this.activeAlarms = const [],
  });

  // Business logic methods
  ValidationResult validateMove(Vector3 targetPosition) {
    // Safety envelope check
    if (!safetyEnvelope.contains(targetPosition)) {
      return ValidationResult.failure(
        'Target position ${targetPosition} exceeds work envelope',
        ViolationType.workEnvelopeExceeded,
      );
    }
    
    // Machine state check
    if (status.isAlarmed) {
      return ValidationResult.failure(
        'Cannot move while machine is in alarm state: ${activeAlarms.first.message}',
        ViolationType.machineAlarmed,
      );
    }
    
    if (status.isMoving) {
      return ValidationResult.failure(
        'Cannot start new move while machine is already moving',
        ViolationType.machineMoving,
      );
    }
    
    return ValidationResult.success();
  }

  Machine executeMove(Vector3 targetPosition) {
    final validation = validateMove(targetPosition);
    if (!validation.isValid) {
      throw MachineOperationException(validation.error, validation.violationType);
    }
    
    return copyWith(
      currentPosition: MachinePosition(targetPosition),
      status: MachineStatus.moving,
    );
  }

  Machine updateStatus(MachineStatus newStatus) {
    return copyWith(status: newStatus);
  }

  Machine addAlarm(Alarm alarm) {
    return copyWith(
      activeAlarms: [...activeAlarms, alarm],
      status: MachineStatus.alarm,
    );
  }

  Machine clearAlarms() {
    return copyWith(
      activeAlarms: [],
      status: MachineStatus.idle,
    );
  }
}
```

**Create Value Objects:**

```dart
// lib/domain/value_objects/machine_position.dart
class MachinePosition extends Equatable {
  final Vector3 workCoordinates;
  final Vector3 machineCoordinates;
  final CoordinateSystem activeSystem;

  const MachinePosition(
    this.workCoordinates, {
    required this.machineCoordinates,
    this.activeSystem = CoordinateSystem.g54,
  });

  // Validation in constructor
  MachinePosition.fromVector3(Vector3 position) 
    : workCoordinates = position,
      machineCoordinates = position, // Simplified for now
      activeSystem = CoordinateSystem.g54;

  @override
  List<Object?> get props => [workCoordinates, machineCoordinates, activeSystem];
}

// lib/domain/value_objects/safety_envelope.dart
class SafetyEnvelope extends Equatable {
  final Vector3 minBounds;
  final Vector3 maxBounds;
  final double safetyMargin;

  const SafetyEnvelope({
    required this.minBounds,
    required this.maxBounds,
    this.safetyMargin = 1.0, // 1mm safety margin
  });

  bool contains(Vector3 position) {
    final adjustedMin = Vector3(
      minBounds.x + safetyMargin,
      minBounds.y + safetyMargin,
      minBounds.z + safetyMargin,
    );
    final adjustedMax = Vector3(
      maxBounds.x - safetyMargin,
      maxBounds.y - safetyMargin,
      maxBounds.z - safetyMargin,
    );

    return position.x >= adjustedMin.x && position.x <= adjustedMax.x &&
           position.y >= adjustedMin.y && position.y <= adjustedMax.y &&
           position.z >= adjustedMin.z && position.z <= adjustedMax.z;
  }

  double distanceToEdge(Vector3 position) {
    // Calculate minimum distance to any envelope boundary
    final distances = [
      position.x - minBounds.x,
      maxBounds.x - position.x,
      position.y - minBounds.y,
      maxBounds.y - position.y,
      position.z - minBounds.z,
      maxBounds.z - position.z,
    ];
    
    return distances.reduce(math.min);
  }

  @override
  List<Object?> get props => [minBounds, maxBounds, safetyMargin];
}
```

#### Week 2: Repository Interfaces and Use Cases

**Create Repository Interfaces:**

```dart
// lib/domain/repositories/machine_repository.dart
abstract class MachineRepository {
  Future<Machine> getCurrent();
  Future<void> save(Machine machine);
  Stream<Machine> watchMachine();
  Future<MachineConfiguration> getConfiguration();
  Future<void> updateConfiguration(MachineConfiguration config);
}

// lib/domain/repositories/gcode_repository.dart
abstract class GCodeRepository {
  Future<GCodeProgram> load(GCodeProgramId id);
  Future<void> save(GCodeProgram program);
  Future<List<GCodeProgramInfo>> listPrograms();
  Future<void> delete(GCodeProgramId id);
  Stream<GCodeProgram> watchProgram(GCodeProgramId id);
}
```

**Create Core Use Cases:**

```dart
// lib/domain/use_cases/jog_machine.dart
class JogMachine {
  final MachineRepository _machineRepository;
  final SafetyValidator _safetyValidator;

  JogMachine(this._machineRepository, this._safetyValidator);

  Future<JogResult> execute(JogRequest request) async {
    try {
      // 1. Get current machine state
      final machine = await _machineRepository.getCurrent();
      
      // 2. Calculate target position
      final targetPosition = _calculateTargetPosition(
        machine.currentPosition.workCoordinates,
        request,
      );
      
      // 3. Validate move (domain logic)
      final validation = machine.validateMove(targetPosition);
      if (!validation.isValid) {
        return JogResult.failure(validation.error, validation.violationType);
      }
      
      // 4. Additional safety validation
      final safetyCheck = await _safetyValidator.validateJogMove(
        machine,
        targetPosition,
        request.feedRate,
      );
      if (!safetyCheck.isValid) {
        return JogResult.failure(safetyCheck.error, safetyCheck.violationType);
      }
      
      // 5. Execute move (update domain state)
      final updatedMachine = machine.executeMove(targetPosition);
      await _machineRepository.save(updatedMachine);
      
      return JogResult.success(updatedMachine.currentPosition);
      
    } catch (e) {
      return JogResult.failure(
        'Unexpected error during jog operation: $e',
        ViolationType.systemError,
      );
    }
  }

  Vector3 _calculateTargetPosition(Vector3 currentPosition, JogRequest request) {
    switch (request.mode) {
      case JogMode.incremental:
        return currentPosition + request.distance;
      case JogMode.absolute:
        return request.distance;
    }
  }
}
```

#### Week 3: Safety Validation Service

```dart
// lib/domain/services/safety_validator.dart
class SafetyValidator {
  final MachineRepository _machineRepository;

  SafetyValidator(this._machineRepository);

  Future<ValidationResult> validateJogMove(
    Machine machine,
    Vector3 targetPosition,
    double feedRate,
  ) async {
    // 1. Work envelope validation (already done in Machine entity)
    
    // 2. Feed rate validation
    final config = machine.configuration;
    if (feedRate > config.maxFeedRate) {
      return ValidationResult.failure(
        'Feed rate ${feedRate} exceeds maximum ${config.maxFeedRate}',
        ViolationType.feedRateExceeded,
      );
    }
    
    // 3. Acceleration validation
    final currentPos = machine.currentPosition.workCoordinates;
    final distance = (targetPosition - currentPos).length;
    final estimatedTime = distance / feedRate;
    
    if (estimatedTime < config.minMoveTime) {
      return ValidationResult.failure(
        'Move too fast for safe acceleration',
        ViolationType.accelerationExceeded,
      );
    }
    
    // 4. Tool collision check (if tool is defined)
    if (machine.currentTool != null) {
      final toolTipPosition = targetPosition + Vector3(0, 0, machine.currentTool!.length);
      if (!machine.safetyEnvelope.contains(toolTipPosition)) {
        return ValidationResult.failure(
          'Tool tip would exceed work envelope',
          ViolationType.toolCollision,
        );
      }
    }
    
    return ValidationResult.success();
  }

  Future<ValidationResult> validateGCodeProgram(
    GCodeProgram program,
    Machine machine,
  ) async {
    // Validate entire G-code program against machine capabilities
    final violations = <String>[];
    
    for (final command in program.commands) {
      final result = await _validateGCodeCommand(command, machine);
      if (!result.isValid) {
        violations.add('Line ${command.lineNumber}: ${result.error}');
      }
    }
    
    if (violations.isNotEmpty) {
      return ValidationResult.failure(
        'Program validation failed:\n${violations.join('\n')}',
        ViolationType.programValidation,
      );
    }
    
    return ValidationResult.success();
  }

  Future<ValidationResult> _validateGCodeCommand(
    GCodeCommand command,
    Machine machine,
  ) async {
    // Validate individual G-code command
    switch (command.type) {
      case GCodeCommandType.rapidMove:
      case GCodeCommandType.linearMove:
        return machine.validateMove(command.position);
      
      case GCodeCommandType.clockwiseArc:
      case GCodeCommandType.counterClockwiseArc:
        return _validateArcMove(command, machine);
      
      default:
        return ValidationResult.success();
    }
  }

  ValidationResult _validateArcMove(GCodeCommand command, Machine machine) {
    // Validate arc moves by checking multiple points along the arc
    final arcPoints = _generateArcPoints(command);
    
    for (final point in arcPoints) {
      final validation = machine.validateMove(point);
      if (!validation.isValid) {
        return validation;
      }
    }
    
    return ValidationResult.success();
  }

  List<Vector3> _generateArcPoints(GCodeCommand command) {
    // Generate points along arc for validation
    // Implementation depends on arc interpolation algorithm
    return [];
  }
}
```

### Phase 2: BLoC Refactoring (2-3 weeks)

#### Week 4: Split MachineControllerBloc

**Create Focused BLoCs:**

```dart
// lib/application/blocs/machine_status_cubit.dart
class MachineStatusCubit extends Cubit<MachineStatus> {
  final MachineRepository _repository;
  StreamSubscription<Machine>? _machineSubscription;

  MachineStatusCubit(this._repository) : super(MachineStatus.unknown) {
    _watchMachineStatus();
  }

  void _watchMachineStatus() {
    _machineSubscription = _repository.watchMachine().listen(
      (machine) => emit(machine.status),
      onError: (error) => emit(MachineStatus.error),
    );
  }

  @override
  Future<void> close() {
    _machineSubscription?.cancel();
    return super.close();
  }
}

// lib/application/blocs/machine_position_bloc.dart
class MachinePositionBloc extends Bloc<PositionEvent, PositionState> {
  final JogMachine _jogUseCase;
  final MachineRepository _repository;

  MachinePositionBloc(this._jogUseCase, this._repository) 
    : super(PositionState.initial()) {
    on<JogRequested>(_onJogRequested);
    on<PositionUpdated>(_onPositionUpdated);
    
    // Watch for position updates from repository
    _repository.watchMachine().listen((machine) {
      add(PositionUpdated(machine.currentPosition));
    });
  }

  Future<void> _onJogRequested(
    JogRequested event,
    Emitter<PositionState> emit,
  ) async {
    emit(state.copyWith(
      status: PositionStatus.moving,
      error: null,
    ));

    try {
      final result = await _jogUseCase.execute(event.request);
      
      if (result.isSuccess) {
        emit(state.copyWith(
          position: result.position,
          status: PositionStatus.idle,
        ));
      } else {
        emit(state.copyWith(
          status: PositionStatus.error,
          error: result.error,
          violationType: result.violationType,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: PositionStatus.error,
        error: 'Unexpected error: $e',
        violationType: ViolationType.systemError,
      ));
    }
  }

  void _onPositionUpdated(
    PositionUpdated event,
    Emitter<PositionState> emit,
  ) {
    emit(state.copyWith(
      position: event.position,
      status: PositionStatus.idle,
    ));
  }
}
```

#### Week 5: Create Use Case Handlers

```dart
// lib/application/use_case_handlers/machine_control_handler.dart
class MachineControlHandler {
  final JogMachine _jogUseCase;
  final ExecuteGCodeProgram _executeGCodeUseCase;
  final PerformToolChange _toolChangeUseCase;
  final HandleEmergencyStop _emergencyStopUseCase;

  MachineControlHandler(
    this._jogUseCase,
    this._executeGCodeUseCase,
    this._toolChangeUseCase,
    this._emergencyStopUseCase,
  );

  Future<JogResult> handleJogRequest(JogRequest request) async {
    return await _jogUseCase.execute(request);
  }

  Future<ExecutionResult> handleProgramExecution(GCodeProgramId programId) async {
    return await _executeGCodeUseCase.execute(programId);
  }

  Future<ToolChangeResult> handleToolChange(ToolChangeRequest request) async {
    return await _toolChangeUseCase.execute(request);
  }

  Future<void> handleEmergencyStop() async {
    await _emergencyStopUseCase.execute();
  }
}
```

#### Week 6: Update UI Integration

**Update Widget Integration:**

```dart
// lib/ui/screens/machine_control_screen.dart
class MachineControlScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<MachineStatusCubit>(
          create: (context) => GetIt.instance<MachineStatusCubit>(),
        ),
        BlocProvider<MachinePositionBloc>(
          create: (context) => GetIt.instance<MachinePositionBloc>(),
        ),
        BlocProvider<MachineAlarmsBloc>(
          create: (context) => GetIt.instance<MachineAlarmsBloc>(),
        ),
      ],
      child: Column(
        children: [
          // Status display
          BlocBuilder<MachineStatusCubit, MachineStatus>(
            builder: (context, status) {
              return MachineStatusWidget(status: status);
            },
          ),
          
          // Position display and jog controls
          BlocBuilder<MachinePositionBloc, PositionState>(
            builder: (context, state) {
              return Column(
                children: [
                  PositionDisplayWidget(
                    position: state.position,
                    isMoving: state.status == PositionStatus.moving,
                  ),
                  if (state.error != null)
                    ErrorDisplayWidget(
                      error: state.error!,
                      violationType: state.violationType,
                    ),
                  JogControlsWidget(
                    onJogRequested: (request) {
                      context.read<MachinePositionBloc>().add(
                        JogRequested(request),
                      );
                    },
                    enabled: state.status != PositionStatus.moving,
                  ),
                ],
              );
            },
          ),
          
          // Alarm display
          BlocBuilder<MachineAlarmsBloc, AlarmState>(
            builder: (context, state) {
              if (state.alarms.isEmpty) return SizedBox.shrink();
              
              return AlarmDisplayWidget(
                alarms: state.alarms,
                onClearAlarms: () {
                  context.read<MachineAlarmsBloc>().add(ClearAlarmsRequested());
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
```

### Phase 3: Infrastructure Separation (1-2 weeks)

#### Week 7: Repository Implementations

```dart
// lib/infrastructure/persistence/machine_repository_impl.dart
class MachineRepositoryImpl implements MachineRepository {
  final CncCommunicationBloc _communicationBloc;
  final SharedPreferences _prefs;
  
  Machine? _currentMachine;
  final StreamController<Machine> _machineController = StreamController.broadcast();

  MachineRepositoryImpl(this._communicationBloc, this._prefs) {
    _listenToCommunication();
  }

  void _listenToCommunication() {
    _communicationBloc.stream.listen((commState) {
      if (commState is CncCommunicationStatusReceived) {
        _updateMachineFromStatus(commState.status);
      }
    });
  }

  void _updateMachineFromStatus(MachineStatusMessage status) {
    if (_currentMachine == null) {
      _currentMachine = _createInitialMachine(status);
    } else {
      _currentMachine = _currentMachine!.copyWith(
        currentPosition: MachinePosition.fromVector3(status.position),
        status: _mapStatus(status.state),
      );
    }
    
    _machineController.add(_currentMachine!);
  }

  @override
  Future<Machine> getCurrent() async {
    if (_currentMachine == null) {
      // Load from preferences or create default
      _currentMachine = await _loadMachineFromPrefs();
    }
    return _currentMachine!;
  }

  @override
  Future<void> save(Machine machine) async {
    _currentMachine = machine;
    await _saveMachineToPrefs(machine);
    _machineController.add(machine);
  }

  @override
  Stream<Machine> watchMachine() {
    return _machineController.stream;
  }

  // Implementation details...
}
```

#### Week 8: Dependency Injection Setup

```dart
// lib/infrastructure/dependency_injection.dart
class DependencyInjection {
  static Future<void> setup() async {
    final getIt = GetIt.instance;
    
    // External dependencies
    final prefs = await SharedPreferences.getInstance();
    getIt.registerSingleton<SharedPreferences>(prefs);
    
    // Infrastructure layer
    getIt.registerSingleton<CncCommunicationBloc>(CncCommunicationBloc());
    getIt.registerSingleton<MachineRepository>(
      MachineRepositoryImpl(getIt<CncCommunicationBloc>(), prefs),
    );
    getIt.registerSingleton<GCodeRepository>(
      FileGCodeRepositoryImpl(),
    );
    
    // Domain services
    getIt.registerSingleton<SafetyValidator>(
      SafetyValidator(getIt<MachineRepository>()),
    );
    
    // Use cases
    getIt.registerFactory<JogMachine>(
      () => JogMachine(
        getIt<MachineRepository>(),
        getIt<SafetyValidator>(),
      ),
    );
    
    // Application layer
    getIt.registerFactory<MachineControlHandler>(
      () => MachineControlHandler(
        getIt<JogMachine>(),
        getIt<ExecuteGCodeProgram>(),
        getIt<PerformToolChange>(),
        getIt<HandleEmergencyStop>(),
      ),
    );
    
    // BLoCs
    getIt.registerFactory<MachineStatusCubit>(
      () => MachineStatusCubit(getIt<MachineRepository>()),
    );
    getIt.registerFactory<MachinePositionBloc>(
      () => MachinePositionBloc(
        getIt<JogMachine>(),
        getIt<MachineRepository>(),
      ),
    );
  }
}
```

## Testing Strategy

### Unit Tests for Domain Layer

```dart
// test/domain/entities/machine_test.dart
void main() {
  group('Machine', () {
    late Machine machine;
    
    setUp(() {
      machine = Machine(
        id: MachineId('test-machine'),
        configuration: MachineConfiguration.defaults(),
        currentPosition: MachinePosition.fromVector3(Vector3.zero()),
        status: MachineStatus.idle,
        safetyEnvelope: SafetyEnvelope(
          minBounds: Vector3(-100, -100, -100),
          maxBounds: Vector3(100, 100, 100),
        ),
      );
    });

    test('validateMove should succeed for position within envelope', () {
      final result = machine.validateMove(Vector3(50, 50, 50));
      expect(result.isValid, isTrue);
    });

    test('validateMove should fail for position outside envelope', () {
      final result = machine.validateMove(Vector3(150, 150, 150));
      expect(result.isValid, isFalse);
      expect(result.violationType, ViolationType.workEnvelopeExceeded);
    });

    test('validateMove should fail when machine is alarmed', () {
      final alarmedMachine = machine.addAlarm(
        Alarm(message: 'Test alarm', code: 1),
      );
      
      final result = alarmedMachine.validateMove(Vector3(50, 50, 50));
      expect(result.isValid, isFalse);
      expect(result.violationType, ViolationType.machineAlarmed);
    });
  });
}
```

### Integration Tests for Use Cases

```dart
// test/domain/use_cases/jog_machine_test.dart
void main() {
  group('JogMachine', () {
    late JogMachine jogMachine;
    late MockMachineRepository mockRepository;
    late MockSafetyValidator mockValidator;

    setUp(() {
      mockRepository = MockMachineRepository();
      mockValidator = MockSafetyValidator();
      jogMachine = JogMachine(mockRepository, mockValidator);
    });

    test('should successfully execute valid jog request', () async {
      // Arrange
      final machine = createTestMachine();
      when(mockRepository.getCurrent()).thenAnswer((_) async => machine);
      when(mockValidator.validateJogMove(any, any, any))
          .thenAnswer((_) async => ValidationResult.success());

      final request = JogRequest(
        distance: Vector3(10, 0, 0),
        mode: JogMode.incremental,
        feedRate: 1000,
      );

      // Act
      final result = await jogMachine.execute(request);

      // Assert
      expect(result.isSuccess, isTrue);
      verify(mockRepository.save(any)).called(1);
    });
  });
}
```

## Migration Checklist

### Phase 1 Completion Criteria
- [ ] Domain entities created and tested
- [ ] Repository interfaces defined
- [ ] Core use cases implemented
- [ ] Safety validation service operational
- [ ] Unit tests passing for domain layer

### Phase 2 Completion Criteria
- [ ] Monolithic BLoCs split into focused components
- [ ] Use case handlers bridge domain and presentation
- [ ] UI updated to use new BLoCs
- [ ] Integration tests passing
- [ ] Performance benchmarks maintained

### Phase 3 Completion Criteria
- [ ] Repository implementations moved to infrastructure
- [ ] Dependency injection configured
- [ ] All tests passing
- [ ] Documentation updated
- [ ] Performance validation complete

## Success Metrics

1. **Maintainability**: Reduced cyclomatic complexity in BLoCs
2. **Testability**: >90% unit test coverage for domain layer
3. **Performance**: Maintain 125Hz communication and 120fps rendering
4. **Safety**: All machine operations validated through domain layer
5. **Extensibility**: Clear interfaces for adding new features

This refactoring will provide a solid foundation for implementing safety features, workflows, and the adaptive learning system while maintaining the exceptional performance already achieved.