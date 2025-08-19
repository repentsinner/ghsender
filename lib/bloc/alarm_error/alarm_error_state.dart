import 'package:equatable/equatable.dart';
import '../../models/alarm_error_metadata.dart';

/// State for AlarmError BLoC
class AlarmErrorState extends Equatable {
  final bool isInitialized;
  final Map<int, AlarmMetadata> alarmMetadata;
  final Map<int, ErrorMetadata> errorMetadata;
  final Map<int, ConditionGroup> alarmGroups;
  final Map<int, ConditionGroup> errorGroups;
  final bool alarmMetadataLoaded;
  final bool errorMetadataLoaded;
  final bool alarmGroupsLoaded;
  final bool errorGroupsLoaded;
  final DateTime? lastAlarmMetadataUpdate;
  final DateTime? lastErrorMetadataUpdate;
  final DateTime? lastAlarmGroupsUpdate;
  final DateTime? lastErrorGroupsUpdate;
  final String? errorMessage;

  const AlarmErrorState({
    this.isInitialized = false,
    this.alarmMetadata = const {},
    this.errorMetadata = const {},
    this.alarmGroups = const {},
    this.errorGroups = const {},
    this.alarmMetadataLoaded = false,
    this.errorMetadataLoaded = false,
    this.alarmGroupsLoaded = false,
    this.errorGroupsLoaded = false,
    this.lastAlarmMetadataUpdate,
    this.lastErrorMetadataUpdate,
    this.lastAlarmGroupsUpdate,
    this.lastErrorGroupsUpdate,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [
        isInitialized,
        alarmMetadata,
        errorMetadata,
        alarmGroups,
        errorGroups,
        alarmMetadataLoaded,
        errorMetadataLoaded,
        alarmGroupsLoaded,
        errorGroupsLoaded,
        lastAlarmMetadataUpdate,
        lastErrorMetadataUpdate,
        lastAlarmGroupsUpdate,
        lastErrorGroupsUpdate,
        errorMessage,
      ];

  /// Whether all metadata has been fully loaded
  bool get isFullyLoaded {
    return alarmMetadataLoaded && errorMetadataLoaded;
  }

  /// Count of alarm metadata entries
  int get alarmMetadataCount => alarmMetadata.length;

  /// Count of error metadata entries  
  int get errorMetadataCount => errorMetadata.length;

  /// Count of alarm groups
  int get alarmGroupsCount => alarmGroups.length;

  /// Count of error groups
  int get errorGroupsCount => errorGroups.length;

  /// Get alarm metadata by code
  AlarmMetadata? getAlarmMetadata(int code) {
    return alarmMetadata[code];
  }

  /// Get error metadata by code
  ErrorMetadata? getErrorMetadata(int code) {
    return errorMetadata[code];
  }

  /// Get alarm group by ID
  ConditionGroup? getAlarmGroup(int groupId) {
    return alarmGroups[groupId];
  }

  /// Get error group by ID
  ConditionGroup? getErrorGroup(int groupId) {
    return errorGroups[groupId];
  }

  /// Get all alarm metadata for a specific group
  List<AlarmMetadata> getAlarmMetadataForGroup(int groupId) {
    return alarmMetadata.values
        .where((metadata) => metadata.groupId == groupId)
        .toList();
  }

  /// Get all error metadata for a specific group
  List<ErrorMetadata> getErrorMetadataForGroup(int groupId) {
    return errorMetadata.values
        .where((metadata) => metadata.groupId == groupId)
        .toList();
  }

  /// Get top-level alarm groups (those without parent)
  List<ConditionGroup> getTopLevelAlarmGroups() {
    return alarmGroups.values
        .where((group) => group.parentId == null)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  /// Get top-level error groups (those without parent)
  List<ConditionGroup> getTopLevelErrorGroups() {
    return errorGroups.values
        .where((group) => group.parentId == null)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  /// Create an active alarm condition
  ActiveCondition createActiveAlarm(int code, DateTime detectedAt) {
    return ActiveCondition(
      code: code,
      isAlarm: true,
      alarmMetadata: getAlarmMetadata(code),
      detectedAt: detectedAt,
    );
  }

  /// Create an active error condition
  ActiveCondition createActiveError(int code, DateTime detectedAt) {
    return ActiveCondition(
      code: code,
      isAlarm: false,
      errorMetadata: getErrorMetadata(code),
      detectedAt: detectedAt,
    );
  }

  AlarmErrorState copyWith({
    bool? isInitialized,
    Map<int, AlarmMetadata>? alarmMetadata,
    Map<int, ErrorMetadata>? errorMetadata,
    Map<int, ConditionGroup>? alarmGroups,
    Map<int, ConditionGroup>? errorGroups,
    bool? alarmMetadataLoaded,
    bool? errorMetadataLoaded,
    bool? alarmGroupsLoaded,
    bool? errorGroupsLoaded,
    DateTime? lastAlarmMetadataUpdate,
    DateTime? lastErrorMetadataUpdate,
    DateTime? lastAlarmGroupsUpdate,
    DateTime? lastErrorGroupsUpdate,
    String? errorMessage,
  }) {
    return AlarmErrorState(
      isInitialized: isInitialized ?? this.isInitialized,
      alarmMetadata: alarmMetadata ?? this.alarmMetadata,
      errorMetadata: errorMetadata ?? this.errorMetadata,
      alarmGroups: alarmGroups ?? this.alarmGroups,
      errorGroups: errorGroups ?? this.errorGroups,
      alarmMetadataLoaded: alarmMetadataLoaded ?? this.alarmMetadataLoaded,
      errorMetadataLoaded: errorMetadataLoaded ?? this.errorMetadataLoaded,
      alarmGroupsLoaded: alarmGroupsLoaded ?? this.alarmGroupsLoaded,
      errorGroupsLoaded: errorGroupsLoaded ?? this.errorGroupsLoaded,
      lastAlarmMetadataUpdate: lastAlarmMetadataUpdate ?? this.lastAlarmMetadataUpdate,
      lastErrorMetadataUpdate: lastErrorMetadataUpdate ?? this.lastErrorMetadataUpdate,
      lastAlarmGroupsUpdate: lastAlarmGroupsUpdate ?? this.lastAlarmGroupsUpdate,
      lastErrorGroupsUpdate: lastErrorGroupsUpdate ?? this.lastErrorGroupsUpdate,
      errorMessage: errorMessage,
    );
  }

  @override
  String toString() {
    return 'AlarmErrorState('
        'isInitialized: $isInitialized, '
        'alarmMetadataCount: $alarmMetadataCount, '
        'errorMetadataCount: $errorMetadataCount, '
        'alarmGroupsCount: $alarmGroupsCount, '
        'errorGroupsCount: $errorGroupsCount, '
        'isFullyLoaded: $isFullyLoaded'
        ')';
  }
}