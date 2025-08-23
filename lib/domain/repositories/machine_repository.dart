import '../entities/machine.dart';

/// Abstract repository interface for machine state and configuration operations
/// 
/// Provides data access layer for machine state, configuration persistence,
/// and real-time updates. Implementations wrap existing communication BLoCs
/// without changing their behavior.
abstract class MachineRepository {
  /// Get the current machine state
  /// 
  /// Returns the current machine entity with all state information
  /// including position, status, alarms, and configuration.
  Future<Machine> getCurrent();
  
  /// Save machine state and configuration
  /// 
  /// Persists machine configuration changes and state updates.
  /// Used for settings persistence and state recovery.
  Future<void> save(Machine machine);
  
  /// Watch machine state changes in real-time
  /// 
  /// Returns a stream of machine state updates for real-time UI updates
  /// and reactive programming patterns. Stream should emit immediately
  /// with current state when subscribed.
  Stream<Machine> watchMachine();
  
  /// Update machine position
  /// 
  /// Updates the current machine position, typically used during
  /// jog operations or after receiving position updates from controller.
  Future<void> updatePosition(Machine machine);
  
  /// Check if repository is connected and operational
  /// 
  /// Returns true if the underlying communication layer is connected
  /// and can provide reliable machine state information.
  bool get isConnected;
}