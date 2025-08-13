import 'dart:convert';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../utils/logger.dart';
import 'profile_event.dart';
import 'profile_state.dart';

/// BLoC for managing machine profile configuration state
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  static const _uuid = Uuid();
  
  ProfileBloc() : super(const ProfileInitial()) {
    on<ProfileLoadRequested>(_onProfileLoadRequested);
    on<ProfileNameChanged>(_onProfileNameChanged);
    on<ProfileControllerAddressChanged>(_onProfileControllerAddressChanged);
    on<ProfileSwitched>(_onProfileSwitched);
    on<ProfileCreated>(_onProfileCreated);
    on<ProfileCopied>(_onProfileCopied);
    on<ProfileDeleted>(_onProfileDeleted);
    on<ProfileExportRequested>(_onProfileExportRequested);
    on<ProfileImportRequested>(_onProfileImportRequested);
  }

  // Settings file name
  static const String _settingsFileName = 'settings.json';

  /// Load profile data from storage or initialize with defaults
  Future<void> _onProfileLoadRequested(
    ProfileLoadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      emit(const ProfileLoading());
      
      final settings = await _loadSettings();
      final profiles = settings['profiles'] as Map<String, dynamic>? ?? {};
      final profilesMap = <String, MachineProfile>{};
      
      // Convert JSON to MachineProfile objects
      for (final entry in profiles.entries) {
        profilesMap[entry.key] = MachineProfile.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
      
      // Check if no profiles exist - emit empty state
      if (profilesMap.isEmpty) {
        emit(const ProfileEmpty());
        AppLogger.info('No profiles found - user needs to create at least one profile');
        return;
      }
      
      // Load active profile by ID
      final activeProfileId = settings['activeProfileId'] as String? ?? profilesMap.keys.first;
      
      final currentProfile = profilesMap[activeProfileId] ?? profilesMap.values.first;
      
      final availableProfilesList = profilesMap.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      
      emit(ProfileLoaded(
        currentProfile: currentProfile,
        availableProfiles: availableProfilesList,
      ));
      
      AppLogger.info('Profile system loaded - active: ${currentProfile.name}');
    } catch (e) {
      AppLogger.error('Failed to load profiles', e);
      emit(ProfileError(
        errorMessage: 'Failed to load machine profiles: $e',
      ));
    }
  }

  /// Update profile name
  Future<void> _onProfileNameChanged(
    ProfileNameChanged event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is! ProfileLoaded) return;
      
      final updatedProfile = currentState.currentProfile.copyWith(name: event.name);
      
      // Automatically save changes to storage
      final settings = await _loadSettings();
      final profiles = await _loadProfilesFromSettings();
      profiles[updatedProfile.id] = updatedProfile;
      await _saveSettings(profiles, settings['activeProfileId'] as String);
      
      final updatedProfilesList = profiles.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      
      emit(ProfileLoaded(
        currentProfile: updatedProfile,
        availableProfiles: updatedProfilesList,
      ));
      
      AppLogger.info('Profile name updated to: ${event.name}');
    } catch (e) {
      AppLogger.error('Failed to update profile name', e);
      emit(ProfileError(
        errorMessage: 'Failed to update profile name: $e',
      ));
    }
  }

  /// Update controller address
  Future<void> _onProfileControllerAddressChanged(
    ProfileControllerAddressChanged event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is! ProfileLoaded) return;
      
      final updatedProfile = currentState.currentProfile.copyWith(
        controllerAddress: event.address,
      );
      
      // Automatically save changes to storage
      final settings = await _loadSettings();
      final profiles = await _loadProfilesFromSettings();
      profiles[updatedProfile.id] = updatedProfile;
      await _saveSettings(profiles, settings['activeProfileId'] as String);
      
      final updatedProfilesList = profiles.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      
      emit(ProfileLoaded(
        currentProfile: updatedProfile,
        availableProfiles: updatedProfilesList,
      ));
      
      AppLogger.info('Profile controller address updated to: ${event.address}');
    } catch (e) {
      AppLogger.error('Failed to update controller address', e);
      emit(ProfileError(
        errorMessage: 'Failed to update controller address: $e',
      ));
    }
  }

  /// Switch to a different profile
  Future<void> _onProfileSwitched(
    ProfileSwitched event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is! ProfileLoaded) return;
      
      // Load all profiles from storage
      final profiles = await _loadProfilesFromSettings();
      final newProfile = profiles[event.profileId];
      
      if (newProfile == null) {
        emit(ProfileError(
          errorMessage: 'Profile with ID "${event.profileId}" not found',
          currentProfile: currentState.currentProfile,
          availableProfiles: currentState.availableProfiles,
        ));
        return;
      }
      
      // Save active profile preference
      await _saveSettings(profiles, event.profileId);
      
      emit(ProfileLoaded(
        currentProfile: newProfile,
        availableProfiles: currentState.availableProfiles,
      ));
      
      AppLogger.info('Switched to profile: ${newProfile.name} (ID: ${event.profileId})');
    } catch (e) {
      AppLogger.error('Failed to switch profile', e);
      emit(ProfileError(
        errorMessage: 'Failed to switch profile: $e',
      ));
    }
  }

  /// Create a new profile
  Future<void> _onProfileCreated(
    ProfileCreated event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      emit(const ProfileLoading());
      
      // Create new profile with new UUID
      final newProfileId = _uuid.v4();
      final newProfile = MachineProfile(
        id: newProfileId,
        name: event.name,
        controllerAddress: event.controllerAddress,
      );
      
      // Load and update profiles
      final profiles = await _loadProfilesFromSettings();
      profiles[newProfileId] = newProfile;
      await _saveSettings(profiles, newProfileId);
      
      final updatedProfilesList = profiles.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      
      emit(ProfileLoaded(
        currentProfile: newProfile,
        availableProfiles: updatedProfilesList,
      ));
      
      AppLogger.info('Created new profile: ${event.name} (ID: $newProfileId)');
    } catch (e) {
      AppLogger.error('Failed to create profile', e);
      emit(ProfileError(
        errorMessage: 'Failed to create profile: $e',
      ));
    }
  }

  /// Copy current profile with new name
  Future<void> _onProfileCopied(
    ProfileCopied event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is! ProfileLoaded) return;
      
      emit(ProfileOperationInProgress(
        operation: 'Copying profile...',
        currentProfile: currentState.currentProfile,
        availableProfiles: currentState.availableProfiles,
      ));
      
      // Create copy of current profile with new UUID
      final newProfileId = _uuid.v4();
      final copiedProfile = currentState.currentProfile.copyWith(
        id: newProfileId,
        name: event.newName,
      );
      
      // Load and update profiles
      final profiles = await _loadProfilesFromSettings();
      profiles[newProfileId] = copiedProfile;
      await _saveSettings(profiles, (await _loadSettings())['activeProfileId'] as String);
      
      final updatedProfilesList = profiles.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      
      emit(ProfileOperationSuccess(
        message: 'Profile copied as "${event.newName}"',
        currentProfile: currentState.currentProfile,
        availableProfiles: updatedProfilesList,
      ));
      
      AppLogger.info('Copied profile to: ${event.newName} (ID: $newProfileId)');
    } catch (e) {
      AppLogger.error('Failed to copy profile', e);
      emit(ProfileError(
        errorMessage: 'Failed to copy profile: $e',
      ));
    }
  }

  /// Delete a profile
  Future<void> _onProfileDeleted(
    ProfileDeleted event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is! ProfileLoaded) return;
      
      // Load profiles for deletion
      final profiles = await _loadProfilesFromSettings();
      final profileToDelete = profiles[event.profileId];
      
      if (profileToDelete == null) {
        emit(ProfileError(
          errorMessage: 'Profile not found',
          currentProfile: currentState.currentProfile,
          availableProfiles: currentState.availableProfiles,
        ));
        return;
      }
      
      // All user-created profiles can be deleted
      
      emit(ProfileOperationInProgress(
        operation: 'Deleting profile...',
        currentProfile: currentState.currentProfile,
        availableProfiles: currentState.availableProfiles,
      ));
      
      // Update profiles
      profiles.remove(event.profileId);
      
      // Check if we have any profiles left
      if (profiles.isEmpty) {
        // Save empty settings and emit empty state
        await _saveSettings(profiles, '');
        emit(const ProfileEmpty());
        AppLogger.info('All profiles deleted - user needs to create a new profile');
        return;
      }
      
      // If deleted profile was active, switch to first remaining profile
      final settings = await _loadSettings();
      String activeProfileId = settings['activeProfileId'] as String;
      MachineProfile activeProfile = currentState.currentProfile;
      
      if (currentState.currentProfile.id == event.profileId) {
        // Switch to first available profile
        activeProfile = profiles.values.first;
        activeProfileId = activeProfile.id;
      }
      
      await _saveSettings(profiles, activeProfileId);
      
      final updatedProfilesList = profiles.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      
      emit(ProfileOperationSuccess(
        message: 'Profile "${profileToDelete.name}" deleted',
        currentProfile: activeProfile,
        availableProfiles: updatedProfilesList,
      ));
      
      AppLogger.info('Deleted profile: ${profileToDelete.name} (ID: ${event.profileId})');
    } catch (e) {
      AppLogger.error('Failed to delete profile', e);
      emit(ProfileError(
        errorMessage: 'Failed to delete profile: $e',
      ));
    }
  }

  /// Export profile (placeholder for future implementation)
  Future<void> _onProfileExportRequested(
    ProfileExportRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;
    
    // TODO: Implement file picker and JSON export
    AppLogger.info('Profile export requested for: ${event.profileName}');
    
    emit(ProfileError(
      errorMessage: 'Export functionality not yet implemented',
      currentProfile: currentState.currentProfile,
      availableProfiles: currentState.availableProfiles,
    ));
  }

  /// Import profile (placeholder for future implementation)
  Future<void> _onProfileImportRequested(
    ProfileImportRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;
    
    // TODO: Implement file picker and JSON import
    AppLogger.info('Profile import requested from: ${event.filePath}');
    
    emit(ProfileError(
      errorMessage: 'Import functionality not yet implemented',
      currentProfile: currentState.currentProfile,
      availableProfiles: currentState.availableProfiles,
    ));
  }


  /// Get settings file path
  Future<File> _getSettingsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_settingsFileName');
  }

  /// Load settings from JSON file
  Future<Map<String, dynamic>> _loadSettings() async {
    try {
      final file = await _getSettingsFile();
      if (!await file.exists()) {
        return {};
      }
      
      final contents = await file.readAsString();
      return json.decode(contents) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.error('Failed to load settings', e);
      return {};
    }
  }

  /// Load all profiles from settings
  Future<Map<String, MachineProfile>> _loadProfilesFromSettings() async {
    final settings = await _loadSettings();
    final profiles = settings['profiles'] as Map<String, dynamic>? ?? {};
    final profilesMap = <String, MachineProfile>{};
    
    for (final entry in profiles.entries) {
      profilesMap[entry.key] = MachineProfile.fromJson(
        entry.value as Map<String, dynamic>,
      );
    }
    
    return profilesMap;
  }

  /// Save settings to JSON file
  Future<void> _saveSettings(Map<String, MachineProfile> profiles, String activeProfileId) async {
    try {
      final file = await _getSettingsFile();
      final profilesJson = <String, dynamic>{};
      
      for (final entry in profiles.entries) {
        profilesJson[entry.key] = entry.value.toJson();
      }
      
      final settings = {
        'activeProfileId': activeProfileId,
        'profiles': profilesJson,
      };
      
      await file.writeAsString(json.encode(settings));
    } catch (e) {
      AppLogger.error('Failed to save settings', e);
      throw Exception('Failed to save settings: $e');
    }
  }
}