import 'package:equatable/equatable.dart';
import '../../models/settings_metadata.dart';

/// State for the SettingsBloc that manages UI metadata from grblHAL
class SettingsState extends Equatable {
  final bool isInitialized;
  final Map<int, SettingMetadata> metadata;
  final Map<int, SettingGroup> groups;
  final DateTime? lastMetadataUpdate;
  final DateTime? lastGroupsUpdate;
  final bool metadataLoaded;
  final bool groupsLoaded;
  final String? errorMessage;

  const SettingsState({
    this.isInitialized = false,
    this.metadata = const {},
    this.groups = const {},
    this.lastMetadataUpdate,
    this.lastGroupsUpdate,
    this.metadataLoaded = false,
    this.groupsLoaded = false,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [
    isInitialized,
    metadata,
    groups,
    lastMetadataUpdate,
    lastGroupsUpdate,
    metadataLoaded,
    groupsLoaded,
    errorMessage,
  ];

  SettingsState copyWith({
    bool? isInitialized,
    Map<int, SettingMetadata>? metadata,
    Map<int, SettingGroup>? groups,
    DateTime? lastMetadataUpdate,
    DateTime? lastGroupsUpdate,
    bool? metadataLoaded,
    bool? groupsLoaded,
    String? errorMessage,
  }) {
    return SettingsState(
      isInitialized: isInitialized ?? this.isInitialized,
      metadata: metadata ?? this.metadata,
      groups: groups ?? this.groups,
      lastMetadataUpdate: lastMetadataUpdate ?? this.lastMetadataUpdate,
      lastGroupsUpdate: lastGroupsUpdate ?? this.lastGroupsUpdate,
      metadataLoaded: metadataLoaded ?? this.metadataLoaded,
      groupsLoaded: groupsLoaded ?? this.groupsLoaded,
      errorMessage: errorMessage,
    );
  }

  /// Get metadata for a specific setting
  SettingMetadata? getMetadata(int settingId) => metadata[settingId];

  /// Get group information for a specific group ID
  SettingGroup? getGroup(int groupId) => groups[groupId];

  /// Get all top-level groups (parent ID = 0)
  List<SettingGroup> getTopLevelGroups() {
    return groups.values
        .where((group) => group.parentId == 0)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  /// Get child groups for a specific parent group ID
  List<SettingGroup> getChildGroups(int parentId) {
    return groups.values
        .where((group) => group.parentId == parentId)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  /// Get all settings metadata for a specific group
  List<SettingMetadata> getMetadataForGroup(int groupId) {
    return metadata.values
        .where((meta) => meta.groupId == groupId)
        .toList()
      ..sort((a, b) => a.settingId.compareTo(b.settingId));
  }

  /// Check if both metadata and groups are loaded
  bool get isFullyLoaded => metadataLoaded && groupsLoaded;

  /// Get total number of settings with metadata
  int get metadataCount => metadata.length;

  /// Get total number of groups
  int get groupsCount => groups.length;

  @override
  String toString() {
    return 'SettingsState(initialized: $isInitialized, metadata: ${metadata.length}, groups: ${groups.length}, metadataLoaded: $metadataLoaded, groupsLoaded: $groupsLoaded)';
  }
}