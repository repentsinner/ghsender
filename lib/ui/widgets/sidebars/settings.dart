import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../themes/vscode_theme.dart';
import '../sidebar_sections/sidebar_components.dart';
import '../../../bloc/profile/profile_bloc.dart';
import '../../../bloc/profile/profile_event.dart';
import '../../../bloc/profile/profile_state.dart';
import '../../../bloc/graphics/graphics_bloc.dart';
import '../../../bloc/graphics/graphics_state.dart';
import '../../../utils/logger.dart';

/// Settings section - Machine profiles, communication settings, and renderer settings
class SettingsSection extends StatefulWidget {
  const SettingsSection({super.key});

  @override
  State<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<SettingsSection> {
  // Text controllers for numerical inputs only
  late final TextEditingController _workAreaXController;
  late final TextEditingController _workAreaYController;
  late final TextEditingController _workAreaZController;
  late final TextEditingController _maxFeedRateController;
  late final TextEditingController _maxSpindleSpeedController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _workAreaXController = TextEditingController();
    _workAreaYController = TextEditingController();
    _workAreaZController = TextEditingController();
    _maxFeedRateController = TextEditingController();
    _maxSpindleSpeedController = TextEditingController();
  }


  @override
  void dispose() {
    _workAreaXController.dispose();
    _workAreaYController.dispose();
    _workAreaZController.dispose();
    _maxFeedRateController.dispose();
    _maxSpindleSpeedController.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileBloc, ProfileState>(
      listener: (context, state) {
        // Show snackbars for operations
        if (state is ProfileOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: VSCodeTheme.success,
            ),
          );
        } else if (state is ProfileError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage),
              backgroundColor: VSCodeTheme.error,
            ),
          );
        }
      },
      builder: (context, profileState) {
        if (profileState is ProfileLoading || profileState is ProfileInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (profileState is ProfileEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.precision_manufacturing,
                    size: 64,
                    color: VSCodeTheme.secondaryText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Machine Profiles',
                    style: GoogleFonts.inconsolata(
                      color: VSCodeTheme.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first machine profile to get started.\nYou\'ll need the WebSocket address of your CNC controller.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inconsolata(
                      color: VSCodeTheme.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showNewProfileDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VSCodeTheme.accent,
                      foregroundColor: VSCodeTheme.primaryText,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        if (profileState is ProfileError && profileState.currentProfile == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Failed to load profiles',
                  style: GoogleFonts.inconsolata(color: VSCodeTheme.error),
                ),
                ElevatedButton(
                  onPressed: () => context.read<ProfileBloc>().add(
                    const ProfileLoadRequested(),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Get current profile from state
        MachineProfile? currentProfile;
        List<MachineProfile> availableProfiles = [];
        
        if (profileState is ProfileLoaded) {
          currentProfile = profileState.currentProfile;
          availableProfiles = profileState.availableProfiles;
        } else if (profileState is ProfileOperationInProgress) {
          currentProfile = profileState.currentProfile;
          availableProfiles = profileState.availableProfiles;
        } else if (profileState is ProfileOperationSuccess) {
          currentProfile = profileState.currentProfile;
          availableProfiles = profileState.availableProfiles;
        } else if (profileState is ProfileError) {
          currentProfile = profileState.currentProfile;
          availableProfiles = profileState.availableProfiles ?? [];
        }

        if (currentProfile == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Machine Settings Header
              _buildSectionHeader('Machine Settings'),

              const SizedBox(height: 16),

              // Active Machine Profile Section
              _buildMachineProfileSection(currentProfile, availableProfiles),

              const SizedBox(height: 24),

              // Profile Configuration Section
              _buildProfileConfigurationSection(currentProfile),

              const SizedBox(height: 24),

              // Renderer Settings Section
              _buildRendererSettingsSection(),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Icon(Icons.settings, color: VSCodeTheme.primaryText, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inconsolata(
            color: VSCodeTheme.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(
            Icons.info_outline,
            color: VSCodeTheme.secondaryText,
            size: 16,
          ),
          onPressed: () => _showInfoDialog(context),
          tooltip: 'Machine settings help',
        ),
      ],
    );
  }

  Widget _buildMachineProfileSection(
    MachineProfile currentProfile,
    List<MachineProfile> availableProfiles,
  ) {
    return SidebarComponents.buildSectionWithInfo(
      title: 'Active Machine Profile',
      infoTooltip: 'Select and manage machine configuration profiles',
      child: Column(
        children: [
          // Profile Dropdown
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: VSCodeTheme.border),
              borderRadius: BorderRadius.circular(4),
              color: VSCodeTheme.inputBackground,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: availableProfiles.any((p) => p.id == currentProfile.id) 
                    ? currentProfile.id 
                    : availableProfiles.first.id,
                dropdownColor: VSCodeTheme.dropdownBackground,
                style: GoogleFonts.inconsolata(
                  color: VSCodeTheme.primaryText,
                  fontSize: 14,
                ),
                items: availableProfiles.map((MachineProfile profile) {
                  return DropdownMenuItem<String>(
                    value: profile.id,
                    child: Text(profile.name),
                  );
                }).toList(),
                onChanged: (profileId) {
                  if (profileId != null && profileId != currentProfile.id) {
                    context.read<ProfileBloc>().add(ProfileSwitched(profileId));
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Profile Management Buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.add,
                  label: 'New',
                  onPressed: () => _showNewProfileDialog(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.copy,
                  label: 'Copy',
                  onPressed: () => _copyCurrentProfile(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.delete,
                  label: 'Delete',
                  onPressed: () => _deleteCurrentProfile(currentProfile),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Import/Export Buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.download,
                  label: 'Export',
                  onPressed: () => _exportProfile(currentProfile.name),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.upload,
                  label: 'Import',
                  onPressed: () => _importProfile(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileConfigurationSection(MachineProfile currentProfile) {
    return SidebarComponents.buildSectionWithInfo(
      title: 'Profile Configuration',
      infoTooltip: 'Configure machine-specific parameters and limits',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Name
          _buildTextInput(
            label: 'Profile Name',
            value: currentProfile.name,
            onChanged: (value) => context.read<ProfileBloc>().add(
              ProfileNameChanged(value),
            ),
          ),

          const SizedBox(height: 16),

          // Controller Address
          _buildTextInput(
            label: 'Controller Address',
            value: currentProfile.controllerAddress,
            onChanged: (value) => context.read<ProfileBloc>().add(
              ProfileControllerAddressChanged(value),
            ),
            placeholder: 'ws://192.168.77.87:80',
          ),

          const SizedBox(height: 16),

          // Has Spindle Toggle (will be handled by MachineStateBloc)
          _buildToggle(
            label: 'Has Spindle',
            value: false, // Placeholder - will be from MachineStateBloc
            onChanged: (value) {
              // TODO: Connect to MachineStateBloc
              AppLogger.info('Spindle setting change - will be handled by MachineStateBloc');
            },
          ),

          const SizedBox(height: 20),

          // Work Area Settings
          _buildSubsectionHeader('Work Area (mm)'),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildNumberInput(
                  'X',
                  _workAreaXController,
                  (value) => _updateWorkArea(x: value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberInput(
                  'Y',
                  _workAreaYController,
                  (value) => _updateWorkArea(y: value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberInput(
                  'Z',
                  _workAreaZController,
                  (value) => _updateWorkArea(z: value),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Speed Limits
          _buildSubsectionHeader('Speed Limits'),
          const SizedBox(height: 12),

          _buildNumberInput(
            'Max Feed Rate (mm/min)',
            _maxFeedRateController,
            (value) => _updateSpeedLimits(maxFeedRate: value),
          ),

          const SizedBox(height: 12),

          _buildNumberInput(
            'Max Spindle Speed (RPM)',
            _maxSpindleSpeedController,
            (value) => _updateSpeedLimits(maxSpindleSpeed: value),
          ),

          const SizedBox(height: 20),

          // Safety Limits (will be handled by MachineStateBloc)
          _buildSubsectionHeader('Safety Limits'),
          const SizedBox(height: 12),

          _buildToggle(
            label: 'Enable Soft Limits',
            value: false, // Placeholder - will be from MachineStateBloc
            onChanged: (value) {
              // TODO: Connect to MachineStateBloc
              AppLogger.info('Soft limits setting change - will be handled by MachineStateBloc');
            },
          ),

          const SizedBox(height: 8),

          _buildToggle(
            label: 'Enable Hard Limits',
            value: false, // Placeholder - will be from MachineStateBloc
            onChanged: (value) {
              // TODO: Connect to MachineStateBloc
              AppLogger.info('Hard limits setting change - will be handled by MachineStateBloc');
            },
          ),
        ],
      ),
    );
  }


  Widget _buildRendererSettingsSection() {
    return BlocBuilder<GraphicsBloc, GraphicsState>(
      builder: (context, state) {
        final lineWeight = state is GraphicsLoaded ? state.lineWeight : 1.0;
        final lineSmoothness = state is GraphicsLoaded ? state.lineSmoothness : 0.5;
        final lineOpacity = state is GraphicsLoaded ? state.lineOpacity : 0.5;
        final onLineWeightChanged = state is GraphicsLoaded ? state.onLineWeightChanged : null;
        final onLineSmoothnessChanged = state is GraphicsLoaded ? state.onLineSmoothnessChanged : null;
        final onLineOpacityChanged = state is GraphicsLoaded ? state.onLineOpacityChanged : null;
        
        return SidebarComponents.buildSectionWithInfo(
          title: 'Renderer Settings',
          infoTooltip: 'Visual rendering parameters and line style settings',
          child: Column(
            children: [
              // Line Weight Control
              _buildSliderControl(
                label: 'Line Weight',
                value: lineWeight,
                min: 0.1,
                max: 5.0,
                divisions: 49,
                onChanged: onLineWeightChanged ?? (_) {},
                formatValue: (value) => value.toStringAsFixed(1),
                description: 'Controls the thickness of rendered G-code lines',
              ),

              const SizedBox(height: 20),

              // Line Smoothness Control
              _buildSliderControl(
                label: 'Line Smoothness',
                value: lineSmoothness,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: onLineSmoothnessChanged ?? (_) {},
                formatValue: (value) =>
                    '${value.toStringAsFixed(2)} ${_getSmoothnessSuffix(value)}',
                description: 'Adjusts line edge softness (0.0 = soft, 1.0 = sharp)',
              ),

              const SizedBox(height: 20),

              // Line Opacity Control
              _buildSliderControl(
                label: 'Line Opacity',
                value: lineOpacity,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: onLineOpacityChanged ?? (_) {},
                formatValue: (value) =>
                    '${value.toStringAsFixed(2)} ${_getOpacitySuffix(value)}',
                description:
                    'Controls line transparency (0.0 = transparent, 1.0 = solid)',
              ),

              const SizedBox(height: 20),

              // Renderer Info
              SidebarComponents.buildInfoCard(
                title: 'Active Renderer',
                content:
                    'Flutter Scene Lines Renderer\\nHardware-accelerated GPU rendering',
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper methods for machine state updates (will be connected to MachineStateBloc)
  void _updateWorkArea({double? x, double? y, double? z}) {
    AppLogger.info('Work area update requested - will be handled by MachineStateBloc');
  }

  void _updateSpeedLimits({double? maxFeedRate, double? maxSpindleSpeed}) {
    AppLogger.info('Speed limits update requested - will be handled by MachineStateBloc');
  }

  // UI Helper widgets (keeping existing implementation but simplified)
  Widget _buildSubsectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inconsolata(
        color: VSCodeTheme.primaryText,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextInput({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    String? placeholder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inconsolata(
            color: VSCodeTheme.primaryText,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value,
          onFieldSubmitted: onChanged,
          onChanged: onChanged,
          style: GoogleFonts.inconsolata(
            color: VSCodeTheme.primaryText,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: GoogleFonts.inconsolata(
              color: VSCodeTheme.secondaryText,
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: VSCodeTheme.border),
              borderRadius: BorderRadius.circular(4),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: VSCodeTheme.accent),
              borderRadius: BorderRadius.circular(4),
            ),
            filled: true,
            fillColor: VSCodeTheme.inputBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildNumberInput(
    String label,
    TextEditingController controller,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inconsolata(
            color: VSCodeTheme.primaryText,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\\d*\\.?\\d*')),
          ],
          onChanged: (value) {
            final doubleValue = double.tryParse(value);
            if (doubleValue != null) {
              onChanged(doubleValue);
            }
          },
          style: GoogleFonts.inconsolata(
            color: VSCodeTheme.primaryText,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderSide: BorderSide(color: VSCodeTheme.border),
              borderRadius: BorderRadius.circular(4),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: VSCodeTheme.accent),
              borderRadius: BorderRadius.circular(4),
            ),
            filled: true,
            fillColor: VSCodeTheme.inputBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inconsolata(
            color: VSCodeTheme.primaryText,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: VSCodeTheme.accent,
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? VSCodeTheme.accent
                : VSCodeTheme.secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: VSCodeTheme.sideBarBackground,
        foregroundColor: VSCodeTheme.primaryText,
        side: BorderSide(color: VSCodeTheme.border),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      ),
    );
  }


  Widget _buildSliderControl({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String Function(double) formatValue,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inconsolata(
                color: VSCodeTheme.primaryText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              formatValue(value),
              style: GoogleFonts.inconsolata(
                color: VSCodeTheme.accentText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: GoogleFonts.inconsolata(
            color: VSCodeTheme.secondaryText,
            fontSize: 10,
          ),
        ),
      ],
    );
  }


  void _showNewProfileDialog(BuildContext context) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSCodeTheme.dropdownBackground,
        title: Text(
          'Create New Profile',
          style: GoogleFonts.inconsolata(color: VSCodeTheme.primaryText),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Profile Name',
                  hintText: 'e.g., My CNC Router',
                ),
                style: GoogleFonts.inconsolata(color: VSCodeTheme.primaryText),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Controller Address',
                  hintText: 'ws://192.168.1.100:80',
                ),
                style: GoogleFonts.inconsolata(color: VSCodeTheme.primaryText),
              ),
              const SizedBox(height: 12),
              Text(
                'Enter the WebSocket address of your CNC controller.\nThis is usually ws://[IP_ADDRESS]:80',
                style: GoogleFonts.inconsolata(
                  color: VSCodeTheme.secondaryText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: GoogleFonts.inconsolata(color: VSCodeTheme.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final address = addressController.text.trim();
              
              if (name.isNotEmpty && address.isNotEmpty) {
                // Create profile with both name and address
                context.read<ProfileBloc>().add(ProfileCreated(name, address));
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: VSCodeTheme.accent,
              foregroundColor: VSCodeTheme.primaryText,
            ),
            child: Text('Create', style: GoogleFonts.inconsolata()),
          ),
        ],
      ),
    );
  }

  void _copyCurrentProfile() {
    final profileState = context.read<ProfileBloc>().state;
    if (profileState is! ProfileLoaded) return;
    
    final currentName = profileState.currentProfile.name;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSCodeTheme.dropdownBackground,
        title: Text(
          'Copy Profile',
          style: GoogleFonts.inconsolata(color: VSCodeTheme.primaryText),
        ),
        content: TextField(
          decoration: InputDecoration(hintText: 'Copy of $currentName'),
          style: GoogleFonts.inconsolata(color: VSCodeTheme.primaryText),
          onSubmitted: (name) {
            if (name.isNotEmpty) {
              context.read<ProfileBloc>().add(ProfileCopied(name));
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: GoogleFonts.inconsolata(color: VSCodeTheme.secondaryText)),
          ),
        ],
      ),
    );
  }

  void _deleteCurrentProfile(MachineProfile profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSCodeTheme.dropdownBackground,
        title: Text(
          'Delete Profile',
          style: GoogleFonts.inconsolata(color: VSCodeTheme.primaryText),
        ),
        content: Text(
          'Are you sure you want to delete "${profile.name}"?',
          style: GoogleFonts.inconsolata(color: VSCodeTheme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: GoogleFonts.inconsolata(color: VSCodeTheme.secondaryText)),
          ),
          TextButton(
            onPressed: () {
              context.read<ProfileBloc>().add(ProfileDeleted(profile.id));
              Navigator.of(context).pop();
            },
            child: Text('Delete', style: GoogleFonts.inconsolata(color: VSCodeTheme.error)),
          ),
        ],
      ),
    );
  }

  void _exportProfile(String profileName) {
    context.read<ProfileBloc>().add(ProfileExportRequested(profileName));
  }

  void _importProfile() {
    context.read<ProfileBloc>().add(const ProfileImportRequested(''));
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSCodeTheme.dropdownBackground,
        title: Text(
          'Machine Settings Help',
          style: GoogleFonts.inconsolata(color: VSCodeTheme.primaryText),
        ),
        content: Text(
          'Configure machine profiles with WebSocket communication settings, work area dimensions, and safety parameters.\\n\\n'
          'Profile changes are managed through the BLoC state system with automatic persistence.',
          style: GoogleFonts.inconsolata(
            color: VSCodeTheme.secondaryText,
            fontSize: 12,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: GoogleFonts.inconsolata(color: VSCodeTheme.accent),
            ),
          ),
        ],
      ),
    );
  }

  String _getSmoothnessSuffix(double smoothness) {
    if (smoothness < 0.3) return '(soft)';
    if (smoothness > 0.7) return '(sharp)';
    return '(medium)';
  }

  String _getOpacitySuffix(double opacity) {
    if (opacity < 0.3) return '(transparent)';
    if (opacity > 0.7) return '(solid)';
    return '(translucent)';
  }
}