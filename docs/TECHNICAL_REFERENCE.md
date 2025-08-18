# Technical Reference

**Last Updated**: January 18, 2025  
**Status**: Living document - Updated with implementation progress

## Architecture Overview

ghSender uses a **layered Flutter architecture** with **domain-driven design principles** and **reactive state management** to achieve industry-leading performance while maintaining safety and reliability.

### Core Architecture Principles

1. **Performance First** - 125Hz communication, 120fps rendering
2. **Safety by Design** - Validation at domain layer, not presentation
3. **Reactive State Management** - BLoC pattern with high-frequency updates
4. **Cross-Platform Consistency** - Single Flutter codebase
5. **Domain-Driven Design** - Business logic separated from infrastructure

## Current Implementation Architecture

### **Technology Stack**
- **Framework**: Flutter/Dart for cross-platform native performance
- **Graphics**: Flutter Scene with custom GLSL shaders
- **Communication**: WebSocket for grblHAL integration
- **State Management**: BLoC pattern with reactive streams
- **Architecture**: Layered with domain-driven design (in progress)

### **Performance Achievements**
- **125Hz Status Updates** - 8ms intervals from grblHAL controllers
- **120fps 3D Rendering** - Smooth visualization on high-refresh displays
- **Non-buffered Commands** - Direct WebSocket for maximum responsiveness
- **Zero Frame Drops** - Maintains performance during high-frequency updates

## Current Directory Structure

```
lib/
├── main.dart                    # Application entry point
│
├── bloc/                        # BLoC state management layer
│   ├── communication/           # CNC communication BLoC
│   ├── file_manager/           # G-code file management BLoC
│   ├── graphics/               # 3D visualization BLoC
│   ├── machine_controller/     # Machine state BLoC
│   ├── performance/            # Performance monitoring BLoC
│   ├── problems/               # Error handling BLoC
│   ├── profile/                # User profile BLoC
│   └── bloc_exports.dart       # Centralized BLoC exports
│
├── models/                      # Data models and structures
│   ├── machine_controller.dart # Machine state definitions
│   ├── machine_configuration.dart # Controller configuration
│   ├── gcode_file.dart         # G-code file models
│   └── problem.dart            # Error/problem models
│
├── gcode/                       # G-code processing layer
│   ├── gcode_parser.dart       # G0/G1/G2/G3 command parser
│   ├── gcode_processor.dart    # File processing pipeline
│   └── gcode_scene.dart        # Scene generation from G-code
│
├── renderers/                   # 3D rendering layer
│   ├── flutter_scene_batch_renderer.dart # Main renderer
│   ├── line_mesh_factory.dart  # High-performance line rendering
│   ├── filled_square_renderer.dart # Filled geometry rendering
│   ├── billboard_text_renderer.dart # 3D text rendering
│   └── renderer_interface.dart # Renderer abstraction
│
├── scene/                       # 3D scene management
│   ├── scene_manager.dart      # Scene state management
│   ├── axes_factory.dart       # Coordinate axes generation
│   └── filled_square_factory.dart # Geometry factories
│
├── ui/                          # User interface layer
│   ├── app/                    # Application integration
│   ├── screens/                # Main application screens
│   ├── layouts/                # Layout components
│   ├── themes/                 # Visual themes and styling
│   └── widgets/                # Reusable UI components
│
├── utils/                       # Utility functions
│   └── logger.dart             # Application logging
│
└── camera_director.dart         # 3D camera control
```

## Planned Architecture (Domain-Driven Design)

### **Target Structure**
```
lib/
├── domain/                      # Pure business logic
│   ├── entities/               # Core business objects
│   ├── value_objects/          # Immutable value types
│   ├── repositories/           # Data access abstractions
│   ├── services/               # Domain services
│   └── use_cases/              # Application business rules
│
├── infrastructure/             # External concerns
│   ├── communication/          # grblHAL protocol implementation
│   ├── persistence/            # Data storage implementations
│   └── rendering/              # 3D visualization engine
│
└── application/                # Thin application layer
    ├── blocs/                  # UI state management only
    └── use_case_handlers/      # Bridge between UI and domain
```

## Key Components

### **3D Visualization Engine**

**Flutter Scene Renderer:**
- Custom GLSL shaders for anti-aliased line rendering
- Instanced geometry for efficient GPU utilization
- Real-time camera controls with smooth interaction
- 120fps performance with complex toolpaths

**Scene Management:**
- Converts G-code data into renderable 3D objects
- Manages coordinate system transformations
- Handles dynamic scene updates efficiently
- Optimized for large G-code files

### **Communication System**

**WebSocket Protocol:**
- 125Hz bidirectional communication with grblHAL
- Non-buffered command execution for maximum speed
- Automatic reconnection and error recovery
- Real-time status parsing and processing

**Message Processing:**
- High-frequency status updates without performance impact
- Command queue management with priority handling
- Error detection and recovery procedures
- Performance monitoring and metrics collection

### **G-code Processing**

**Advanced Parser:**
- Support for G0/G1/G2/G3 commands with arc interpolation
- Bounds calculation and toolpath analysis
- Efficient processing of large files
- Real-time scene generation from parsed data

**File Management:**
- Native file picker integration
- Background processing for large files
- Progress tracking and cancellation support
- Memory-efficient streaming for huge files

### **State Management**

**BLoC Architecture:**
- Reactive state management with event-driven design
- Handles 125Hz updates without performance degradation
- Clear separation between UI and business logic
- Coordinated state across application components

**High-Frequency Handling:**
- Optimized for real-time CNC communication
- No UI jank during rapid state updates
- Efficient memory usage with object pooling
- Predictable performance characteristics

## Performance Specifications

### **Communication Performance**
- **Response Time**: 8ms average (125Hz update rate)
- **Latency Target**: <50ms from user input to CNC command
- **Throughput**: 1000+ commands per minute sustainable
- **Reliability**: Zero message drops during normal operation

### **Rendering Performance**
- **Frame Rate**: 120fps on high-refresh displays
- **Geometry Capacity**: 35,000+ line segments without degradation
- **Memory Usage**: <200MB for complex visualizations
- **GPU Utilization**: Efficient batching and instanced rendering

### **File Processing Performance**
- **Large Files**: >10MB G-code files processed smoothly
- **Parse Speed**: Real-time processing during file loading
- **Memory Efficiency**: Streaming processing for huge files
- **Background Processing**: Non-blocking UI during file operations

## Safety Architecture (Planned)

### **Validation Layer**
```dart
abstract class SafetyValidator {
  ValidationResult validateCommand(CncCommand command, MachineState state);
  bool isWithinWorkEnvelope(Vector3 position);
  List<SafetyWarning> checkPreFlight(GCodeProgram program);
}
```

### **Domain Entities with Safety**
```dart
class Machine {
  ValidationResult validateMove(Vector3 targetPosition) {
    if (!safetyEnvelope.contains(targetPosition)) {
      return ValidationResult.failure('Move exceeds work envelope');
    }
    return ValidationResult.success();
  }
}
```

### **Use Case Pattern**
```dart
class JogMachine {
  Future<JogResult> execute(JogRequest request) async {
    final machine = await _repository.getCurrent();
    final validation = machine.validateMove(request.targetPosition);
    
    if (!validation.isValid) {
      return JogResult.failure(validation.error);
    }
    
    // Execute validated move
    return JogResult.success();
  }
}
```

## Development Patterns

### **BLoC Pattern Implementation**
```dart
class MachinePositionBloc extends Bloc<PositionEvent, PositionState> {
  final JogMachine _jogUseCase;
  
  Future<void> _onJogRequested(JogRequested event, Emitter<PositionState> emit) async {
    emit(state.copyWith(status: PositionStatus.moving));
    
    final result = await _jogUseCase.execute(event.request);
    
    if (result.isSuccess) {
      emit(state.copyWith(position: result.position, status: PositionStatus.idle));
    } else {
      emit(state.copyWith(error: result.error, status: PositionStatus.error));
    }
  }
}
```

### **Repository Pattern**
```dart
abstract class MachineRepository {
  Future<Machine> getCurrent();
  Future<void> save(Machine machine);
  Stream<Machine> watchMachine();
}

class MachineRepositoryImpl implements MachineRepository {
  final CncCommunicationBloc _communicationBloc;
  
  @override
  Stream<Machine> watchMachine() {
    return _communicationBloc.stream
        .where((state) => state is CncCommunicationStatusReceived)
        .map((state) => _mapToMachine(state));
  }
}
```

### **Dependency Injection**
```dart
class DependencyInjection {
  static Future<void> setup() async {
    final getIt = GetIt.instance;
    
    // Infrastructure
    getIt.registerSingleton<MachineRepository>(MachineRepositoryImpl());
    
    // Domain services
    getIt.registerSingleton<SafetyValidator>(SafetyValidator());
    
    // Use cases
    getIt.registerFactory<JogMachine>(() => JogMachine(
      getIt<MachineRepository>(),
      getIt<SafetyValidator>(),
    ));
    
    // BLoCs
    getIt.registerFactory<MachinePositionBloc>(() => MachinePositionBloc(
      getIt<JogMachine>(),
    ));
  }
}
```

## Testing Strategy

### **Unit Testing**
```dart
// Domain logic testing without Flutter dependencies
void main() {
  group('Machine', () {
    test('validateMove should fail for position outside envelope', () {
      final machine = createTestMachine();
      final result = machine.validateMove(Vector3(150, 150, 150));
      
      expect(result.isValid, isFalse);
      expect(result.violationType, ViolationType.workEnvelopeExceeded);
    });
  });
}
```

### **Integration Testing**
```dart
// Use case testing with mocked dependencies
void main() {
  group('JogMachine', () {
    test('should successfully execute valid jog request', () async {
      final mockRepository = MockMachineRepository();
      final mockValidator = MockSafetyValidator();
      final jogMachine = JogMachine(mockRepository, mockValidator);
      
      when(mockRepository.getCurrent()).thenAnswer((_) async => createTestMachine());
      when(mockValidator.validateJogMove(any, any, any))
          .thenAnswer((_) async => ValidationResult.success());
      
      final result = await jogMachine.execute(createJogRequest());
      
      expect(result.isSuccess, isTrue);
    });
  });
}
```

### **Performance Testing**
```dart
// Benchmark critical performance paths
void main() {
  group('Performance Tests', () {
    test('should handle 125Hz status updates without drops', () async {
      final bloc = MachineControllerBloc();
      final stopwatch = Stopwatch()..start();
      
      // Send 125 updates per second for 10 seconds
      for (int i = 0; i < 1250; i++) {
        bloc.add(StatusUpdateReceived(createStatusUpdate()));
        await Future.delayed(Duration(milliseconds: 8));
      }
      
      expect(stopwatch.elapsedMilliseconds, lessThan(11000)); // Allow 1s tolerance
    });
  });
}
```

## Architectural Decisions

### **ADR-001: Flutter/Dart Technology Choice**
- **Decision**: Use Flutter/Dart for cross-platform development
- **Rationale**: Native performance, single codebase, excellent state management
- **Status**: ✅ Validated with 125Hz/120fps performance

### **ADR-002: BLoC State Management**
- **Decision**: Use BLoC pattern for reactive state management
- **Rationale**: Predictable state changes, testable, handles high-frequency updates
- **Status**: ✅ Proven with real-time CNC communication

### **ADR-003: Domain-Driven Design**
- **Decision**: Refactor to domain-driven architecture
- **Rationale**: Separate business logic, improve testability, enable safety features
- **Status**: 🚧 In progress - architecture documented, implementation starting

### **ADR-004: WebSocket Communication**
- **Decision**: Use WebSocket for grblHAL communication
- **Rationale**: Bidirectional, low-latency, standard protocol
- **Status**: ✅ Validated with 8ms response times

## Migration and Refactoring

### **Current Refactoring Priority**
1. **Domain Layer Implementation** - Separate business logic from presentation
2. **BLoC Decomposition** - Split monolithic components into focused units
3. **Safety Architecture** - Add validation layer for all operations
4. **Repository Pattern** - Abstract data access for better testing

### **Migration Strategy**
- **Parallel Implementation** - Build new architecture alongside existing
- **Gradual Migration** - Move one feature at a time
- **Backward Compatibility** - Maintain existing interfaces during transition
- **Performance Validation** - Ensure benchmarks maintained throughout

## Development Guidelines

### **Code Quality Standards**
- **Static Analysis**: `flutter analyze` must pass
- **Formatting**: `dart format` enforced
- **Documentation**: All public APIs documented
- **Testing**: Unit tests for domain logic, integration tests for use cases

### **Performance Requirements**
- **Communication**: Maintain 125Hz update capability
- **Rendering**: Sustain 120fps during complex operations
- **Memory**: Efficient usage with large G-code files
- **Responsiveness**: No UI blocking during background operations

### **Safety Requirements**
- **Validation**: All machine operations must pass through domain validation
- **Error Handling**: Graceful degradation and recovery procedures
- **State Consistency**: UI and machine state must remain synchronized
- **Emergency Procedures**: Immediate stop capability in all operational modes

---

*This technical reference is updated as the architecture evolves. For implementation details, see the source code and inline documentation.*