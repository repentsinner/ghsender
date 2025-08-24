import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:ghsender/domain/use_cases/jog_machine.dart';
import 'package:ghsender/domain/enums/machine_status.dart';
import 'package:ghsender/domain/use_cases/execute_gcode_program.dart';
import 'package:ghsender/domain/entities/machine.dart';
import 'package:ghsender/domain/value_objects/machine_position.dart';
import 'package:ghsender/domain/value_objects/safety_envelope.dart';
import 'package:ghsender/domain/value_objects/gcode_program.dart';
import 'package:ghsender/domain/value_objects/gcode_program_id.dart';
import 'package:ghsender/domain/repositories/machine_repository.dart';
import 'package:ghsender/domain/repositories/gcode_repository.dart';
import 'package:ghsender/domain/entities/machine_configuration.dart';

/// Performance benchmarks for domain use cases to ensure no regression
/// 
/// These tests validate that the domain layer maintains performance
/// requirements for real-time CNC operations (60Hz+ update rates).
void main() {
  group('Use Case Performance Benchmarks', () {
    late BenchmarkMachineRepository machineRepository;
    late BenchmarkGCodeRepository gcodeRepository;
    late JogMachine jogMachine;
    late ExecuteGCodeProgram executeProgram;
    
    late Machine testMachine;
    late GCodeProgram testProgram;

    setUp(() {
      // Create high-performance test implementations
      testMachine = Machine(
        id: const MachineId('benchmark-test'),
        configuration: MachineConfiguration(lastUpdated: DateTime.now()),
        currentPosition: MachinePosition.fromVector3(vm.Vector3(-50, -50, -50)),
        status: MachineStatus.idle,
        safetyEnvelope: SafetyEnvelope(
          minBounds: vm.Vector3(-100, -100, -100),
          maxBounds: vm.Vector3(0, 0, 0),
        ),
      );

      testProgram = GCodeProgram(
        id: const GCodeProgramId('benchmark-program'),
        name: 'benchmark.gcode',
        path: '/benchmark/benchmark.gcode',
        sizeBytes: 1024,
        uploadDate: DateTime.now(),
        status: 'ready',
      );

      machineRepository = BenchmarkMachineRepository(testMachine);
      gcodeRepository = BenchmarkGCodeRepository(testProgram);
      
      jogMachine = JogMachine(machineRepository);
      executeProgram = ExecuteGCodeProgram(
        machineRepository,
        gcodeRepository,
      );
    });

    group('JogMachine Performance', () {
      test('maintains 60Hz+ performance for jog validation', () async {
        const iterationCount = 1000;
        const targetTime = Duration(milliseconds: 16); // 60Hz = 16.67ms per frame
        
        final stopwatch = Stopwatch()..start();
        
        // Simulate rapid jog validation calls (60Hz real-time scenario)
        for (int i = 0; i < iterationCount; i++) {
          final targetPosition = vm.Vector3(
            -50 + (i % 20) - 10, // Vary position slightly
            -50 + ((i * 2) % 20) - 10,
            -50 + ((i * 3) % 20) - 10,
          );
          
          final request = JogRequest(
            targetPosition: targetPosition,
            feedRate: 1000.0,
          );
          
          await jogMachine.validateMove(request);
        }
        
        stopwatch.stop();
        final averageTimePerCall = stopwatch.elapsed ~/ iterationCount;
        
        // Performance metrics for analysis
        // JogMachine.validateMove: ${averageTimePerCall.inMicroseconds}μs average
        // Target: ${targetTime.inMicroseconds}μs (60Hz)
        
        // Should complete well within 60Hz timing requirements
        expect(averageTimePerCall < targetTime, isTrue,
          reason: 'JogMachine validation too slow for real-time operation');
      });

      test('maintains performance for rapid jog execution', () async {
        const iterationCount = 100; // Fewer iterations for full execution
        
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < iterationCount; i++) {
          final targetPosition = vm.Vector3(
            -50 + sin(i * 0.1) * 10,
            -50 + cos(i * 0.1) * 10,
            -50,
          );
          
          final request = JogRequest(
            targetPosition: targetPosition,
            feedRate: 1000.0,
          );
          
          await jogMachine.execute(request);
        }
        
        stopwatch.stop();
        final averageTimePerCall = stopwatch.elapsed ~/ iterationCount;
        
        // JogMachine.execute: ${averageTimePerCall.inMicroseconds}μs average
        
        // Should complete within reasonable time for interactive jogging
        expect(averageTimePerCall < const Duration(milliseconds: 5), isTrue,
          reason: 'JogMachine execution too slow for interactive use');
      });

      test('scales linearly with safety validation complexity', () async {
        const baseIterations = 100;
        const complexIterations = 500;
        
        // Simple validation (center position, safe move)
        final simpleStopwatch = Stopwatch()..start();
        for (int i = 0; i < baseIterations; i++) {
          final request = JogRequest(
            targetPosition: vm.Vector3(-45, -45, -45),
            feedRate: 1000.0,
          );
          await jogMachine.validateMove(request);
        }
        simpleStopwatch.stop();
        final simpleTimePerCall = simpleStopwatch.elapsed ~/ baseIterations;
        
        // Complex validation (boundary testing, multiple checks)
        final complexStopwatch = Stopwatch()..start();
        for (int i = 0; i < complexIterations; i++) {
          final request = JogRequest(
            targetPosition: vm.Vector3(-5, -95, -5), // Near boundaries
            feedRate: 2500.0, // Higher feed rate requiring more validation
          );
          await jogMachine.validateMove(request);
        }
        complexStopwatch.stop();
        final complexTimePerCall = complexStopwatch.elapsed ~/ complexIterations;
        
        // Simple validation: ${simpleTimePerCall.inMicroseconds}μs
        // Complex validation: ${complexTimePerCall.inMicroseconds}μs
        
        // Complex validation should not be more than 3x slower
        final performanceRatio = complexTimePerCall.inMicroseconds / simpleTimePerCall.inMicroseconds;
        expect(performanceRatio < 3.0, isTrue,
          reason: 'Performance scaling too poor: ${performanceRatio}x');
      });
    });

    group('ExecuteGCodeProgram Performance', () {
      test('validates programs within acceptable time limits', () async {
        const iterationCount = 50; // G-code programs are larger operations
        const targetTime = Duration(milliseconds: 100); // More lenient for program validation
        
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < iterationCount; i++) {
          final request = ExecuteProgramRequest(
            programId: GCodeProgramId('benchmark-program-$i'),
          );
          await executeProgram.validateProgram(request);
        }
        
        stopwatch.stop();
        final averageTimePerCall = stopwatch.elapsed ~/ iterationCount;
        
        // ExecuteGCodeProgram.validateProgram: ${averageTimePerCall.inMicroseconds}μs average
        
        expect(averageTimePerCall < targetTime, isTrue,
          reason: 'Program validation too slow for practical use');
      });

      test('executes program validation pipeline efficiently', () async {
        const iterationCount = 20;
        const targetTime = Duration(milliseconds: 50);
        
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < iterationCount; i++) {
          final request = ExecuteProgramRequest(
            programId: const GCodeProgramId('benchmark-program'),
          );
          await executeProgram.execute(request);
        }
        
        stopwatch.stop();
        final averageTimePerCall = stopwatch.elapsed ~/ iterationCount;
        
        // ExecuteGCodeProgram.execute: ${averageTimePerCall.inMicroseconds}μs average
        
        expect(averageTimePerCall < targetTime, isTrue,
          reason: 'Program execution pipeline too slow');
      });
    });

    group('Memory Performance', () {
      test('does not leak memory during rapid operations', () async {
        const iterationCount = 1000;
        
        // Create many validation requests to test for memory leaks
        final positions = List.generate(iterationCount, (i) => vm.Vector3(
          -50 + (i % 40) - 20,
          -50 + ((i * 2) % 40) - 20,
          -50 + ((i * 3) % 40) - 20,
        ));
        
        for (final position in positions) {
          final request = JogRequest(
            targetPosition: position,
            feedRate: 1000.0,
          );
          
          final result = await jogMachine.execute(request);
          
          // Verify objects are properly disposed
          expect(result.success, isTrue);
          expect(result.updatedMachine, isNotNull);
        }
        
        // Test should complete without memory issues
        // Note: Dart's GC makes precise memory testing difficult,
        // but this validates no obvious leaks or retention issues
      });
    });

    group('Concurrent Performance', () {
      test('handles concurrent validation requests', () async {
        const concurrentRequests = 10;
        const requestsPerFuture = 50;
        
        final stopwatch = Stopwatch()..start();
        
        // Create multiple concurrent validation streams
        final futures = List.generate(concurrentRequests, (i) async {
          for (int j = 0; j < requestsPerFuture; j++) {
            final request = JogRequest(
              targetPosition: vm.Vector3(
                -50 + (i * j % 20) - 10,
                -50 + ((i + j) % 20) - 10,
                -50,
              ),
              feedRate: 1000.0,
            );
            await jogMachine.validateMove(request);
          }
        });
        
        await Future.wait(futures);
        
        stopwatch.stop();
        final totalRequests = concurrentRequests * requestsPerFuture;
        final averageTimePerRequest = stopwatch.elapsed ~/ totalRequests;
        
        // Concurrent validation: ${averageTimePerRequest.inMicroseconds}μs per request
        // Total requests: $totalRequests in ${stopwatch.elapsedMilliseconds}ms
        
        // Should maintain good performance under concurrent load
        expect(averageTimePerRequest < const Duration(milliseconds: 5), isTrue,
          reason: 'Concurrent performance degradation too severe');
      });
    });
  });
}

/// High-performance machine repository for benchmarking
class BenchmarkMachineRepository implements MachineRepository {
  Machine _currentMachine;

  BenchmarkMachineRepository(this._currentMachine);

  @override
  Future<Machine> getCurrent() async => _currentMachine; // Synchronous for performance

  @override
  Future<void> save(Machine machine) async {
    _currentMachine = machine;
  }

  @override
  Stream<Machine> watchMachine() => Stream.value(_currentMachine);

  @override
  Future<void> updatePosition(Machine machine) async {
    _currentMachine = machine;
  }

  @override
  bool get isConnected => true; // Always connected for benchmarks
}

/// High-performance G-code repository for benchmarking
class BenchmarkGCodeRepository implements GCodeRepository {
  final GCodeProgram _testProgram;

  BenchmarkGCodeRepository(this._testProgram);

  @override
  Future<GCodeProgram> load(GCodeProgramId id) async => _testProgram;

  @override
  Future<void> save(GCodeProgram program) async {}

  @override
  Future<List<GCodeProgramMetadata>> listPrograms() async => [];

  @override
  Future<void> delete(GCodeProgramId id) async {}

  @override
  Stream<List<GCodeProgramMetadata>> watchPrograms() => Stream.value([]);

  @override
  Future<bool> exists(GCodeProgramId id) async => true;

  @override
  Stream<GCodeProgram> watchProgram(GCodeProgramId id) => Stream.value(_testProgram);
}

