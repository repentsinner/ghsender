import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/settings_metadata.dart';
import '../../utils/logger.dart';
import 'settings_event.dart';
import 'settings_state.dart';
import '../communication/cnc_communication_event.dart';

/// BLoC for managing grblHAL settings UI metadata from $ES and $EG commands
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  // Reference to communication bloc for sending commands
  dynamic _communicationBloc;

  // Stream subscription for real-time message processing
  StreamSubscription? _messageStreamSubscription;

  SettingsBloc() : super(const SettingsState()) {
    AppLogger.info('Settings BLoC initialized for UI metadata management');

    // Register event handlers
    on<SettingsInitialized>(_onInitialized);
    on<SettingsSetCommunicationBloc>(_onSetCommunicationBloc);
    on<SettingsRequestMetadata>(_onRequestMetadata);
    on<SettingsRequestGroups>(_onRequestGroups);
    on<SettingsMetadataReceived>(_onMetadataReceived);
    on<SettingsGroupsReceived>(_onGroupsReceived);
    on<SettingsClearMetadata>(_onClearMetadata);
    on<SettingsReset>(_onReset);

    // Initialize in the next tick
    Future.delayed(Duration.zero, () {
      if (!isClosed) {
        add(const SettingsInitialized());
      }
    });
  }

  /// Handle initialization
  void _onInitialized(
    SettingsInitialized event,
    Emitter<SettingsState> emit,
  ) {
    AppLogger.info('Settings BLoC marked as initialized');
    emit(state.copyWith(isInitialized: true));
  }

  /// Set reference to communication bloc for sending commands
  void _onSetCommunicationBloc(
    SettingsSetCommunicationBloc event,
    Emitter<SettingsState> emit,
  ) {
    _communicationBloc = event.communicationBloc;
    AppLogger.info('Settings BLoC: Communication bloc reference set');
    
    // Set up message stream subscription for processing $ES and $EG responses
    _setupMessageStreamSubscription();
  }

  /// Set up subscription to communication message stream
  void _setupMessageStreamSubscription() {
    // Cancel any existing subscription
    _messageStreamSubscription?.cancel();

    if (_communicationBloc?.messageStream != null) {
      _messageStreamSubscription = _communicationBloc.messageStream.listen(
        (message) => _processMessage(message),
        onError: (error) {
          AppLogger.error('Settings BLoC: Message stream error', error);
        },
      );
      AppLogger.info('Settings BLoC: Message stream subscription established');
    } else {
      AppLogger.warning('Settings BLoC: No message stream available');
    }
  }

  /// Process incoming messages for $ES and $EG responses
  void _processMessage(dynamic message) {
    final content = message.content as String;
    final timestamp = message.timestamp as DateTime;

    // Check for extended settings metadata response [SETTING:...]
    if (content.startsWith('[SETTING:') && content.endsWith(']')) {
      // Collect multiple metadata messages for batch processing
      _collectMetadataMessage(content, timestamp);
    }
    // Check for setting group response [SETTINGGROUP:...]
    else if (content.startsWith('[SETTINGGROUP:') && content.endsWith(']')) {
      // Collect multiple group messages for batch processing
      _collectGroupMessage(content, timestamp);
    }
    // Check for any error responses to \$ES or \$EG commands
    else if (content.toLowerCase().contains('error') && (content.contains('\$ES') || content.contains('\$EG'))) {
      AppLogger.warning('Settings BLoC: Error response to settings command: "$content"');
    }
  }

  // Temporary storage for collecting messages
  final List<String> _pendingMetadataMessages = [];
  final List<String> _pendingGroupMessages = [];
  Timer? _metadataCollectionTimer;
  Timer? _groupCollectionTimer;

  /// Collect metadata messages and process in batches
  void _collectMetadataMessage(String message, DateTime timestamp) {
    _pendingMetadataMessages.add(message);
    
    // Reset timer to allow for more messages
    _metadataCollectionTimer?.cancel();
    _metadataCollectionTimer = Timer(const Duration(milliseconds: 500), () {
      if (_pendingMetadataMessages.isNotEmpty) {
        add(SettingsMetadataReceived(
          messages: List.from(_pendingMetadataMessages),
          timestamp: timestamp,
        ));
        _pendingMetadataMessages.clear();
      }
    });
  }

  /// Collect group messages and process in batches
  void _collectGroupMessage(String message, DateTime timestamp) {
    _pendingGroupMessages.add(message);
    
    // Reset timer to allow for more messages
    _groupCollectionTimer?.cancel();
    _groupCollectionTimer = Timer(const Duration(milliseconds: 500), () {
      if (_pendingGroupMessages.isNotEmpty) {
        add(SettingsGroupsReceived(
          messages: List.from(_pendingGroupMessages),
          timestamp: timestamp,
        ));
        _pendingGroupMessages.clear();
      }
    });
  }

  /// Request extended settings metadata from grblHAL
  void _onRequestMetadata(
    SettingsRequestMetadata event,
    Emitter<SettingsState> emit,
  ) {
    if (_communicationBloc == null) {
      AppLogger.warning('Settings BLoC: Cannot request metadata - no communication bloc');
      emit(state.copyWith(errorMessage: 'No communication available'));
      return;
    }

    AppLogger.info('Settings BLoC: 🔍 SENDING \$ES COMMAND - Requesting extended settings metadata');
    _communicationBloc.add(CncCommunicationSendCommand('\$ES'));
  }

  /// Request setting groups from grblHAL
  void _onRequestGroups(
    SettingsRequestGroups event,
    Emitter<SettingsState> emit,
  ) {
    if (_communicationBloc == null) {
      AppLogger.warning('Settings BLoC: Cannot request groups - no communication bloc');
      emit(state.copyWith(errorMessage: 'No communication available'));
      return;
    }

    AppLogger.info('Settings BLoC: 🔍 SENDING \$EG COMMAND - Requesting setting groups');
    _communicationBloc.add(CncCommunicationSendCommand('\$EG'));
  }

  /// Handle extended settings metadata received from $ES command
  void _onMetadataReceived(
    SettingsMetadataReceived event,
    Emitter<SettingsState> emit,
  ) {
    final newMetadata = <int, SettingMetadata>{};
    int parsedCount = 0;

    for (final message in event.messages) {
      final metadata = SettingMetadata.parseFromExtendedLine(message, event.timestamp);
      if (metadata != null) {
        newMetadata[metadata.settingId] = metadata;
        parsedCount++;
      }
    }

    AppLogger.info('Settings BLoC: Loaded $parsedCount setting metadata entries');

    emit(state.copyWith(
      metadata: newMetadata,
      lastMetadataUpdate: event.timestamp,
      metadataLoaded: true,
      errorMessage: null,
    ));
  }

  /// Handle setting groups received from $EG command
  void _onGroupsReceived(
    SettingsGroupsReceived event,
    Emitter<SettingsState> emit,
  ) {
    final newGroups = <int, SettingGroup>{};
    int parsedCount = 0;

    for (final message in event.messages) {
      final group = SettingGroup.parseFromGroupLine(message, event.timestamp);
      if (group != null) {
        newGroups[group.id] = group;
        parsedCount++;
      }
    }

    AppLogger.info('Settings BLoC: Loaded $parsedCount setting groups');

    emit(state.copyWith(
      groups: newGroups,
      lastGroupsUpdate: event.timestamp,
      groupsLoaded: true,
      errorMessage: null,
    ));
  }

  /// Clear all metadata (on disconnect)
  void _onClearMetadata(
    SettingsClearMetadata event,
    Emitter<SettingsState> emit,
  ) {
    AppLogger.info('Settings BLoC: Clearing all metadata');
    emit(const SettingsState());
  }

  /// Reset to initial state
  void _onReset(
    SettingsReset event,
    Emitter<SettingsState> emit,
  ) {
    AppLogger.info('Settings BLoC: Reset to initial state');
    _communicationBloc = null;
    emit(const SettingsState());
  }

  /// Request both metadata and groups (convenience method)
  void requestAllMetadata() {
    add(const SettingsRequestMetadata());
    add(const SettingsRequestGroups());
  }

  /// Create an enriched setting by combining current value with metadata
  EnrichedSetting createEnrichedSetting(int settingId, String currentValue, DateTime valueUpdated) {
    final metadata = state.getMetadata(settingId);
    return EnrichedSetting(
      settingId: settingId,
      currentValue: currentValue,
      metadata: metadata,
      valueUpdated: valueUpdated,
    );
  }

  /// Get all settings for a group as enriched settings
  /// Requires external source of current values (from MachineConfiguration)
  List<EnrichedSetting> getEnrichedSettingsForGroup(
    int groupId,
    Map<int, String> currentValues,
    DateTime valuesUpdated,
  ) {
    final groupMetadata = state.getMetadataForGroup(groupId);
    return groupMetadata.map((metadata) {
      final currentValue = currentValues[metadata.settingId] ?? 'N/A';
      return EnrichedSetting(
        settingId: metadata.settingId,
        currentValue: currentValue,
        metadata: metadata,
        valueUpdated: valuesUpdated,
      );
    }).toList();
  }

  @override
  void onTransition(Transition<SettingsEvent, SettingsState> transition) {
    super.onTransition(transition);
    final fromType = transition.currentState.runtimeType.toString();
    final toType = transition.nextState.runtimeType.toString();
    if (fromType != toType || transition.event is SettingsMetadataReceived || transition.event is SettingsGroupsReceived) {
      AppLogger.debug('Settings: ${transition.event.runtimeType} -> ${transition.nextState.toString()}');
    }
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    super.onError(error, stackTrace);
    AppLogger.error('Settings BLoC error', error, stackTrace);
  }

  @override
  Future<void> close() {
    AppLogger.debug('Settings BLoC closing');
    
    // Cancel timers
    _metadataCollectionTimer?.cancel();
    _groupCollectionTimer?.cancel();
    
    // Cancel message stream subscription
    _messageStreamSubscription?.cancel();
    
    // Clear pending messages
    _pendingMetadataMessages.clear();
    _pendingGroupMessages.clear();
    
    _communicationBloc = null;
    return super.close();
  }
}