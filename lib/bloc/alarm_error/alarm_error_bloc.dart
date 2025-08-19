import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/alarm_error_metadata.dart';
import '../../utils/logger.dart';
import 'alarm_error_event.dart';
import 'alarm_error_state.dart';
import '../communication/cnc_communication_event.dart';

/// BLoC for managing grblHAL alarm and error metadata from $EA, $EE, $EAG, $EEG commands
class AlarmErrorBloc extends Bloc<AlarmErrorEvent, AlarmErrorState> {
  // Reference to communication bloc for sending commands
  dynamic _communicationBloc;

  // Stream subscription for real-time message processing
  StreamSubscription? _messageStreamSubscription;

  // Temporary storage for collecting messages
  final List<String> _pendingAlarmMetadataMessages = [];
  final List<String> _pendingErrorMetadataMessages = [];
  final List<String> _pendingAlarmGroupMessages = [];
  final List<String> _pendingErrorGroupMessages = [];
  Timer? _alarmMetadataCollectionTimer;
  Timer? _errorMetadataCollectionTimer;
  Timer? _alarmGroupCollectionTimer;
  Timer? _errorGroupCollectionTimer;

  AlarmErrorBloc() : super(const AlarmErrorState()) {
    AppLogger.info('AlarmError BLoC initialized for metadata management');

    // Register event handlers
    on<AlarmErrorInitialized>(_onInitialized);
    on<AlarmErrorSetCommunicationBloc>(_onSetCommunicationBloc);
    on<AlarmErrorRequestAlarmMetadata>(_onRequestAlarmMetadata);
    on<AlarmErrorRequestErrorMetadata>(_onRequestErrorMetadata);
    on<AlarmErrorRequestAlarmGroups>(_onRequestAlarmGroups);
    on<AlarmErrorRequestErrorGroups>(_onRequestErrorGroups);
    on<AlarmErrorAlarmMetadataReceived>(_onAlarmMetadataReceived);
    on<AlarmErrorErrorMetadataReceived>(_onErrorMetadataReceived);
    on<AlarmErrorAlarmGroupsReceived>(_onAlarmGroupsReceived);
    on<AlarmErrorErrorGroupsReceived>(_onErrorGroupsReceived);
    on<AlarmErrorClearMetadata>(_onClearMetadata);
    on<AlarmErrorReset>(_onReset);

    // Initialize in the next tick
    Future.delayed(Duration.zero, () {
      if (!isClosed) {
        add(const AlarmErrorInitialized());
      }
    });
  }

  /// Handle initialization
  void _onInitialized(
    AlarmErrorInitialized event,
    Emitter<AlarmErrorState> emit,
  ) {
    AppLogger.info('AlarmError BLoC marked as initialized');
    emit(state.copyWith(isInitialized: true));
  }

  /// Set reference to communication bloc for sending commands
  void _onSetCommunicationBloc(
    AlarmErrorSetCommunicationBloc event,
    Emitter<AlarmErrorState> emit,
  ) {
    _communicationBloc = event.communicationBloc;
    AppLogger.info('AlarmError BLoC: Communication bloc reference set');
    
    // Set up message stream subscription for processing responses
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
          AppLogger.error('AlarmError BLoC: Message stream error', error);
        },
      );
      AppLogger.info('AlarmError BLoC: Message stream subscription established');
    } else {
      AppLogger.warning('AlarmError BLoC: No message stream available');
    }
  }

  /// Process incoming messages for alarm/error metadata responses
  void _processMessage(dynamic message) {
    final content = message.content as String;
    final timestamp = message.timestamp as DateTime;

    // Check for alarm metadata response [ALARMCODE:...]
    if (content.startsWith('[ALARMCODE:') && content.endsWith(']')) {
      _collectAlarmMetadataMessage(content, timestamp);
    }
    // Check for error metadata response [ERRORCODE:...]
    else if (content.startsWith('[ERRORCODE:') && content.endsWith(']')) {
      _collectErrorMetadataMessage(content, timestamp);
    }
    // Check for any error responses to alarm/error commands
    else if (content.toLowerCase().contains('error') && 
             (content.contains('\$EA') || content.contains('\$EE') || 
              content.contains('\$EAG') || content.contains('\$EEG'))) {
      AppLogger.warning('AlarmError BLoC: Error response to metadata command: "$content"');
    }
    // Check for unknown command responses
    else if (content.toLowerCase().contains('unknown') || content.toLowerCase().contains('invalid')) {
      if (content.contains('\$EA') || content.contains('\$EE') || 
          content.contains('\$EAG') || content.contains('\$EEG')) {
        AppLogger.info('AlarmError BLoC: Possible unknown metadata command response: "$content"');
      }
    }
  }

  /// Collect alarm metadata messages and process in batches
  void _collectAlarmMetadataMessage(String message, DateTime timestamp) {
    _pendingAlarmMetadataMessages.add(message);
    
    // Reset timer to allow for more messages
    _alarmMetadataCollectionTimer?.cancel();
    _alarmMetadataCollectionTimer = Timer(const Duration(milliseconds: 500), () {
      if (_pendingAlarmMetadataMessages.isNotEmpty) {
        add(AlarmErrorAlarmMetadataReceived(
          messages: List.from(_pendingAlarmMetadataMessages),
          timestamp: timestamp,
        ));
        _pendingAlarmMetadataMessages.clear();
      }
    });
  }

  /// Collect error metadata messages and process in batches
  void _collectErrorMetadataMessage(String message, DateTime timestamp) {
    _pendingErrorMetadataMessages.add(message);
    
    // Reset timer to allow for more messages
    _errorMetadataCollectionTimer?.cancel();
    _errorMetadataCollectionTimer = Timer(const Duration(milliseconds: 500), () {
      if (_pendingErrorMetadataMessages.isNotEmpty) {
        add(AlarmErrorErrorMetadataReceived(
          messages: List.from(_pendingErrorMetadataMessages),
          timestamp: timestamp,
        ));
        _pendingErrorMetadataMessages.clear();
      }
    });
  }

  /// Request alarm metadata from grblHAL
  void _onRequestAlarmMetadata(
    AlarmErrorRequestAlarmMetadata event,
    Emitter<AlarmErrorState> emit,
  ) {
    if (_communicationBloc == null) {
      AppLogger.warning('AlarmError BLoC: Cannot request alarm metadata - no communication bloc');
      emit(state.copyWith(errorMessage: 'No communication available'));
      return;
    }

    AppLogger.info('AlarmError BLoC: 🔍 SENDING \$EA COMMAND - Requesting alarm metadata');
    _communicationBloc.add(CncCommunicationSendCommand('\$EA'));
  }

  /// Request error metadata from grblHAL
  void _onRequestErrorMetadata(
    AlarmErrorRequestErrorMetadata event,
    Emitter<AlarmErrorState> emit,
  ) {
    if (_communicationBloc == null) {
      AppLogger.warning('AlarmError BLoC: Cannot request error metadata - no communication bloc');
      emit(state.copyWith(errorMessage: 'No communication available'));
      return;
    }

    AppLogger.info('AlarmError BLoC: 🔍 SENDING \$EE COMMAND - Requesting error metadata');
    _communicationBloc.add(CncCommunicationSendCommand('\$EE'));
  }

  /// Request alarm groups from grblHAL
  void _onRequestAlarmGroups(
    AlarmErrorRequestAlarmGroups event,
    Emitter<AlarmErrorState> emit,
  ) {
    if (_communicationBloc == null) {
      AppLogger.warning('AlarmError BLoC: Cannot request alarm groups - no communication bloc');
      emit(state.copyWith(errorMessage: 'No communication available'));
      return;
    }

    AppLogger.info('AlarmError BLoC: 🔍 SENDING \$EAG COMMAND - Requesting alarm groups');
    _communicationBloc.add(CncCommunicationSendCommand('\$EAG'));
  }

  /// Request error groups from grblHAL
  void _onRequestErrorGroups(
    AlarmErrorRequestErrorGroups event,
    Emitter<AlarmErrorState> emit,
  ) {
    if (_communicationBloc == null) {
      AppLogger.warning('AlarmError BLoC: Cannot request error groups - no communication bloc');
      emit(state.copyWith(errorMessage: 'No communication available'));
      return;
    }

    AppLogger.info('AlarmError BLoC: 🔍 SENDING \$EEG COMMAND - Requesting error groups');
    _communicationBloc.add(CncCommunicationSendCommand('\$EEG'));
  }

  /// Handle alarm metadata received from $EA command
  void _onAlarmMetadataReceived(
    AlarmErrorAlarmMetadataReceived event,
    Emitter<AlarmErrorState> emit,
  ) {
    final newAlarmMetadata = <int, AlarmMetadata>{};
    int parsedCount = 0;

    for (final message in event.messages) {
      final metadata = AlarmMetadata.parseFromExtendedLine(message, event.timestamp);
      if (metadata != null) {
        newAlarmMetadata[metadata.code] = metadata;
        parsedCount++;
      }
    }

    AppLogger.info('AlarmError BLoC: Loaded $parsedCount alarm metadata entries');

    emit(state.copyWith(
      alarmMetadata: newAlarmMetadata,
      lastAlarmMetadataUpdate: event.timestamp,
      alarmMetadataLoaded: true,
      errorMessage: null,
    ));
  }

  /// Handle error metadata received from $EE command
  void _onErrorMetadataReceived(
    AlarmErrorErrorMetadataReceived event,
    Emitter<AlarmErrorState> emit,
  ) {
    final newErrorMetadata = <int, ErrorMetadata>{};
    int parsedCount = 0;

    for (final message in event.messages) {
      final metadata = ErrorMetadata.parseFromExtendedLine(message, event.timestamp);
      if (metadata != null) {
        newErrorMetadata[metadata.code] = metadata;
        parsedCount++;
      }
    }

    AppLogger.info('AlarmError BLoC: Loaded $parsedCount error metadata entries');

    emit(state.copyWith(
      errorMetadata: newErrorMetadata,
      lastErrorMetadataUpdate: event.timestamp,
      errorMetadataLoaded: true,
      errorMessage: null,
    ));
  }

  /// Handle alarm groups received from $EAG command
  void _onAlarmGroupsReceived(
    AlarmErrorAlarmGroupsReceived event,
    Emitter<AlarmErrorState> emit,
  ) {
    AppLogger.info('AlarmError BLoC: Loaded ${event.messages.length} alarm group entries');
    // TODO: Implement when we understand the group format
    emit(state.copyWith(
      alarmGroupsLoaded: true,
      lastAlarmGroupsUpdate: event.timestamp,
    ));
  }

  /// Handle error groups received from $EEG command  
  void _onErrorGroupsReceived(
    AlarmErrorErrorGroupsReceived event,
    Emitter<AlarmErrorState> emit,
  ) {
    AppLogger.info('AlarmError BLoC: Loaded ${event.messages.length} error group entries');
    // TODO: Implement when we understand the group format
    emit(state.copyWith(
      errorGroupsLoaded: true,
      lastErrorGroupsUpdate: event.timestamp,
    ));
  }

  /// Clear all metadata (on disconnect)
  void _onClearMetadata(
    AlarmErrorClearMetadata event,
    Emitter<AlarmErrorState> emit,
  ) {
    AppLogger.info('AlarmError BLoC: Clearing all metadata');
    emit(const AlarmErrorState());
  }

  /// Reset to initial state
  void _onReset(
    AlarmErrorReset event,
    Emitter<AlarmErrorState> emit,
  ) {
    AppLogger.info('AlarmError BLoC: Reset to initial state');
    _communicationBloc = null;
    emit(const AlarmErrorState());
  }

  /// Request all metadata (convenience method)
  void requestAllMetadata() {
    add(const AlarmErrorRequestAlarmMetadata());
    add(const AlarmErrorRequestErrorMetadata());
    add(const AlarmErrorRequestAlarmGroups());
    add(const AlarmErrorRequestErrorGroups());
  }

  @override
  void onTransition(Transition<AlarmErrorEvent, AlarmErrorState> transition) {
    super.onTransition(transition);
    final fromType = transition.currentState.runtimeType.toString();
    final toType = transition.nextState.runtimeType.toString();
    if (fromType != toType || 
        transition.event is AlarmErrorAlarmMetadataReceived || 
        transition.event is AlarmErrorErrorMetadataReceived) {
      AppLogger.debug('AlarmError: ${transition.event.runtimeType} -> ${transition.nextState.toString()}');
    }
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    super.onError(error, stackTrace);
    AppLogger.error('AlarmError BLoC error', error, stackTrace);
  }

  @override
  Future<void> close() {
    AppLogger.debug('AlarmError BLoC closing');
    
    // Cancel timers
    _alarmMetadataCollectionTimer?.cancel();
    _errorMetadataCollectionTimer?.cancel();
    _alarmGroupCollectionTimer?.cancel();
    _errorGroupCollectionTimer?.cancel();
    
    // Cancel message stream subscription
    _messageStreamSubscription?.cancel();
    
    // Clear pending messages
    _pendingAlarmMetadataMessages.clear();
    _pendingErrorMetadataMessages.clear();
    _pendingAlarmGroupMessages.clear();
    _pendingErrorGroupMessages.clear();
    
    _communicationBloc = null;
    return super.close();
  }
}