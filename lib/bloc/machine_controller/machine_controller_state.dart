import 'package:equatable/equatable.dart';
import '../../models/machine_controller.dart';
import '../../models/machine_configuration.dart';
import '../communication/cnc_communication_state.dart';

/// State for the Machine Controller BLoC
class MachineControllerState extends Equatable {
  final MachineController? controller;
  final bool isInitialized;
  final String? lastRawMessage;
  final DateTime? lastUpdateTime;
  
  // Performance tracking (moved from CommunicationBloc)
  final PerformanceData? performanceData;
  
  // Jog testing state (moved from CommunicationBloc)
  final bool jogTestRunning;
  final DateTime? jogTestStartTime;
  final int jogTestDurationSeconds;
  final int jogCount;
  final double jogDistance;
  final int jogFeedRate;
  final List<String> stateTransitions;
  
  // grblHAL detection and configuration state
  final bool grblHalDetected;
  final String? grblHalVersion;
  final DateTime? grblHalDetectedAt;
  
  // Machine configuration from $ command responses
  final MachineConfiguration? configuration;
  
  // Buffer status tracking for adaptive jog control
  final int? plannerBlocksAvailable;
  final int? rxBytesAvailable;
  final int? maxObservedBufferBlocks; // Set to first idle buffer value seen
  
  const MachineControllerState({
    this.controller,
    this.isInitialized = false,
    this.lastRawMessage,
    this.lastUpdateTime,
    this.performanceData,
    this.jogTestRunning = false,
    this.jogTestStartTime,
    this.jogTestDurationSeconds = 0,
    this.jogCount = 0,
    this.jogDistance = 0.0,
    this.jogFeedRate = 0,
    this.stateTransitions = const [],
    this.grblHalDetected = false,
    this.grblHalVersion,
    this.grblHalDetectedAt,
    this.configuration,
    this.plannerBlocksAvailable,
    this.rxBytesAvailable,
    this.maxObservedBufferBlocks,
  });
  
  /// Create a copy with updated fields
  MachineControllerState copyWith({
    MachineController? controller,
    bool? isInitialized,
    String? lastRawMessage,
    DateTime? lastUpdateTime,
    PerformanceData? performanceData,
    bool? jogTestRunning,
    DateTime? jogTestStartTime,
    int? jogTestDurationSeconds,
    int? jogCount,
    double? jogDistance,
    int? jogFeedRate,
    List<String>? stateTransitions,
    bool? grblHalDetected,
    String? grblHalVersion,
    DateTime? grblHalDetectedAt,
    MachineConfiguration? configuration,
    int? plannerBlocksAvailable,
    int? rxBytesAvailable,
    int? maxObservedBufferBlocks,
    bool clearLastMessage = false,
    bool clearPerformanceData = false,
    bool clearJogTestStartTime = false,
    bool clearGrblHalVersion = false,
    bool clearGrblHalDetectedAt = false,
    bool clearConfiguration = false,
  }) {
    return MachineControllerState(
      controller: controller ?? this.controller,
      isInitialized: isInitialized ?? this.isInitialized,
      lastRawMessage: clearLastMessage ? null : lastRawMessage ?? this.lastRawMessage,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      performanceData: clearPerformanceData ? null : performanceData ?? this.performanceData,
      jogTestRunning: jogTestRunning ?? this.jogTestRunning,
      jogTestStartTime: clearJogTestStartTime ? null : jogTestStartTime ?? this.jogTestStartTime,
      jogTestDurationSeconds: jogTestDurationSeconds ?? this.jogTestDurationSeconds,
      jogCount: jogCount ?? this.jogCount,
      jogDistance: jogDistance ?? this.jogDistance,
      jogFeedRate: jogFeedRate ?? this.jogFeedRate,
      stateTransitions: stateTransitions ?? this.stateTransitions,
      grblHalDetected: grblHalDetected ?? this.grblHalDetected,
      grblHalVersion: clearGrblHalVersion ? null : grblHalVersion ?? this.grblHalVersion,
      grblHalDetectedAt: clearGrblHalDetectedAt ? null : grblHalDetectedAt ?? this.grblHalDetectedAt,
      configuration: clearConfiguration ? null : configuration ?? this.configuration,
      plannerBlocksAvailable: plannerBlocksAvailable ?? this.plannerBlocksAvailable,
      rxBytesAvailable: rxBytesAvailable ?? this.rxBytesAvailable,
      maxObservedBufferBlocks: maxObservedBufferBlocks ?? this.maxObservedBufferBlocks,
    );
  }
  
  /// Whether a machine controller is connected
  bool get hasController => controller != null;
  
  /// Whether the machine is online and responding
  bool get isOnline => controller?.isOnline ?? false;
  
  /// Current machine status
  MachineStatus get status => controller?.status ?? MachineStatus.unknown;
  
  /// Whether the machine is ready to accept commands
  bool get isReady => status.isReady;
  
  /// Whether the machine is actively processing
  bool get isActive => status.isActive;
  
  /// Whether the machine has any errors or alarms
  bool get hasErrors => status.hasError || (controller?.errors.isNotEmpty ?? false);
  
  /// Whether the machine has any alarms
  bool get hasAlarms => controller?.alarms.isNotEmpty ?? false;
  
  /// Current work position
  MachineCoordinates? get workPosition => controller?.workPosition;
  
  /// Current machine position
  MachineCoordinates? get machinePosition => controller?.machinePosition;
  
  /// Current spindle state
  SpindleState? get spindleState => controller?.spindleState;
  
  /// Current feed state
  FeedState? get feedState => controller?.feedState;
  
  /// Active G/M codes
  ActiveCodes? get activeCodes => controller?.activeCodes;
  
  /// List of active alarms
  List<String> get alarms => controller?.alarms ?? [];
  
  /// List of active errors
  List<String> get errors => controller?.errors ?? [];
  
  /// Controller firmware version
  String? get firmwareVersion => controller?.firmwareVersion;
  
  /// Controller hardware version
  String? get hardwareVersion => controller?.hardwareVersion;
  
  /// Status summary for display
  String get statusSummary {
    if (!hasController) return 'No Controller';
    if (!isOnline) return 'Offline';
    
    final status = this.status.displayName;
    if (hasAlarms) return '$status (Alarms)';
    if (hasErrors) return '$status (Errors)';
    
    return status;
  }
  
  /// Status icon for display
  String get statusIcon {
    if (!hasController) return '❓';
    if (!isOnline) return '⚫';
    
    return status.icon;
  }
  
  /// Detailed status information for debugging
  Map<String, dynamic> get debugInfo {
    return {
      'hasController': hasController,
      'isOnline': isOnline,
      'status': status.name,
      'hasErrors': hasErrors,
      'hasAlarms': hasAlarms,
      'errorCount': errors.length,
      'alarmCount': alarms.length,
      'lastUpdate': lastUpdateTime?.toIso8601String(),
      'firmwareVersion': firmwareVersion,
      'grblHalDetected': grblHalDetected,
      'grblHalVersion': grblHalVersion,
      'grblHalDetectedAt': grblHalDetectedAt?.toIso8601String(),
      'workPosition': workPosition?.toString(),
      'machinePosition': machinePosition?.toString(),
      'spindleState': spindleState != null ? {
        'running': spindleState!.isRunning,
        'speed': spindleState!.speed,
        'target': spindleState!.targetSpeed,
      } : null,
      'feedState': feedState != null ? {
        'rate': feedState!.rate,
        'target': feedState!.targetRate,
        'units': feedState!.units,
      } : null,
    };
  }
  
  @override
  List<Object?> get props => [
    controller,
    isInitialized,
    lastRawMessage,
    lastUpdateTime,
    performanceData,
    jogTestRunning,
    jogTestStartTime,
    jogTestDurationSeconds,
    jogCount,
    jogDistance,
    jogFeedRate,
    stateTransitions,
    grblHalDetected,
    grblHalVersion,
    grblHalDetectedAt,
    configuration,
    plannerBlocksAvailable,
    rxBytesAvailable,
    maxObservedBufferBlocks,
  ];
  
  @override
  String toString() {
    return 'MachineControllerState{'
        'hasController: $hasController, '
        'isOnline: $isOnline, '
        'status: ${status.name}, '
        'hasErrors: $hasErrors, '
        'hasAlarms: $hasAlarms, '
        'initialized: $isInitialized'
        '}';
  }
}