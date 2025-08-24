import 'package:flutter/material.dart';
import '../themes/vscode_theme.dart';
import '../widgets/problem_item.dart';
import '../widgets/log_output_panel.dart';
import '../../bloc/bloc_exports.dart';
import '../../domain/enums/machine_status.dart';
import '../../domain/entities/machine_configuration.dart';
import '../../models/settings_metadata.dart';
import '../../utils/logger.dart';
import '../../domain/value_objects/configuration_setting.dart';
import '../../domain/value_objects/problem_action.dart';

/// Bottom Panel widget - tabbed interface for console, problems, output
class BottomPanel extends StatefulWidget {
  final VoidCallback onTogglePanel;

  const BottomPanel({super.key, required this.onTogglePanel});

  @override
  State<BottomPanel> createState() => _BottomPanelState();
}

class _BottomPanelState extends State<BottomPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Listen to tab changes to trigger UI updates for conditional controls
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Handle action button taps from problem items
  void _handleProblemAction(BuildContext context, ProblemAction action) {
    AppLogger.info('Problem action triggered: ${action.id} (${action.label})');
    
    switch (action.type) {
      case ProblemActionType.machineCommand:
        _executeMachineCommand(context, action);
        break;
      case ProblemActionType.rawCommand:
        _executeRawCommand(context, action);
        break;
      case ProblemActionType.navigate:
        _handleNavigationAction(context, action);
        break;
      case ProblemActionType.dismiss:
        _dismissProblem(context, action);
        break;
    }
  }

  /// Execute a machine command (like homing, unlock, etc.)
  void _executeMachineCommand(BuildContext context, ProblemAction action) {
    if (action.command == null) {
      AppLogger.warning('Machine command action has no command: ${action.id}');
      return;
    }

    final communicationBloc = context.read<CncCommunicationBloc>();
    communicationBloc.add(CncCommunicationSendCommand(action.command!));
    
    AppLogger.info('Executed machine command: ${action.command}');
    _showActionFeedback(context, 'Sent: ${action.label}');
  }

  /// Execute a raw command (like 0x18 soft reset)
  void _executeRawCommand(BuildContext context, ProblemAction action) {
    if (action.command == null) {
      AppLogger.warning('Raw command action has no command: ${action.id}');
      return;
    }

    final communicationBloc = context.read<CncCommunicationBloc>();
    
    // Handle hex commands like 0x18
    if (action.command!.startsWith('0x')) {
      final hexValue = action.command!.substring(2);
      final byteValue = int.parse(hexValue, radix: 16);
      communicationBloc.add(CncCommunicationSendRawBytes([byteValue]));
    } else {
      communicationBloc.add(CncCommunicationSendCommand(action.command!));
    }
    
    AppLogger.info('Executed raw command: ${action.command}');
    _showActionFeedback(context, 'Sent: ${action.label}');
  }

  /// Handle navigation actions
  void _handleNavigationAction(BuildContext context, ProblemAction action) {
    AppLogger.info('Navigation action not yet implemented: ${action.id}');
    _showActionFeedback(context, 'Navigation: ${action.label}');
  }

  /// Dismiss a problem
  void _dismissProblem(BuildContext context, ProblemAction action) {
    AppLogger.info('Problem dismissal not yet implemented: ${action.id}');
    _showActionFeedback(context, 'Dismissed: ${action.label}');
  }

  /// Show feedback to user after action execution
  void _showActionFeedback(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: VSCodeTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: VSCodeTheme.customPanelTheme,
      child: Container(
        color: VSCodeTheme.panelBackground,
        child: Column(
          children: [
            // Panel header with tabs and close button
            SizedBox(height: 6),
            SizedBox(
              height: 22,
              // decoration: const BoxDecoration(
              //   border: Border(bottom: BorderSide(color: VSCodeTheme.border)),
              // ),
              child: Row(
                children: [
                  // Tabs
                  Expanded(
                    child: BlocBuilder<ProblemsBloc, ProblemsState>(
                      builder: (context, problemsState) {
                        return TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          dividerColor: Colors.transparent,
                          tabAlignment: TabAlignment.start,
                          tabs: [
                            Tab(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Problems'.toUpperCase()),
                                  if (problemsState.hasProblems) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: problemsState.hasErrors
                                            ? VSCodeTheme.error
                                            : problemsState.hasWarnings
                                            ? VSCodeTheme.warning
                                            : VSCodeTheme.info,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${problemsState.totalCount}',
                                        style: VSCodeTheme.smallText.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Tab(text: 'Machine State'.toUpperCase()),
                            Tab(text: 'Console'.toUpperCase()),
                            Tab(text: 'Output'.toUpperCase()),
                          ],
                        );
                      },
                    ),
                  ),

                  // Output tab controls (only visible when Output tab is active)
                  if (_tabController.index == 3) ...[
                    // Auto-scroll toggle
                    IconButton(
                      onPressed: _toggleAutoScroll,
                      icon: Icon(
                        _autoScroll ? Icons.vertical_align_bottom : Icons.lock,
                        size: 16,
                      ),
                      color: _autoScroll
                          ? VSCodeTheme.info
                          : VSCodeTheme.secondaryText,
                      tooltip: _autoScroll
                          ? 'Disable auto-scroll'
                          : 'Enable auto-scroll',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                    ),
                    // Clear button
                    IconButton(
                      onPressed: _clearLogs,
                      icon: const Icon(Icons.clear_all, size: 16),
                      color: VSCodeTheme.secondaryText,
                      tooltip: 'Clear history',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                    ),
                  ],

                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    color: VSCodeTheme.secondaryText,
                    onPressed: widget.onTogglePanel,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 6),

            // Panel content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProblemsTab(),
                  _buildMachineStateTab(),
                  _buildConsoleTab(),
                  _buildOutputTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProblemsTab() {
    return BlocBuilder<ProblemsBloc, ProblemsState>(
      builder: (context, problemsState) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Problem list or status message
                if (problemsState.hasProblems) ...[
                  // Display all problems sorted by severity
                  ...problemsState.sortedProblems.map(
                    (problem) => ProblemItem(
                      problem: problem,
                      onTap: () {
                        // Could add problem-specific actions here
                        AppLogger.info('Problem tapped: ${problem.id}');
                      },
                      onActionTap: (action) => _handleProblemAction(context, action),
                    ),
                  ),
                ] else ...[
                  // No problems message
                  Text('No problems detected', style: VSCodeTheme.captionText),
                ],

                // Debug info for development
                if (problemsState.isInitialized) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: VSCodeTheme.inputBackground,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'Debug: ${problemsState.toString()}',
                      style: VSCodeTheme.smallText.copyWith(
                        color: VSCodeTheme.secondaryText.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConsoleTab() {
    return BlocBuilder<CncCommunicationBloc, CncCommunicationState>(
      builder: (context, commState) {
        // Build console content based on communication state
        String consoleContent = _buildConsoleContent(commState);

        return Column(
          children: [
            // Console header with connection status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: VSCodeTheme.panelBackground,
                border: Border(
                  bottom: BorderSide(
                    color: VSCodeTheme.border.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getConnectionIcon(commState),
                    color: _getConnectionColor(commState),
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Communication Console - ${_getConnectionStatus(commState)}',
                    style: VSCodeTheme.captionText.copyWith(
                      color: VSCodeTheme.accentText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // Note: Performance data display moved to MachineControllerBloc UI
                  // Performance metrics are now handled by machine controller state
                ],
              ),
            ),

            // Console content area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: SelectableText(
                    consoleContent,
                    style: VSCodeTheme.captionText.copyWith(height: 1.4),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMachineStateTab() {
    return BlocBuilder<MachineControllerBloc, MachineControllerState>(
      builder: (context, machineState) {
        return BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Parser State Section
                  _buildStateSection(
                    'Parser State',
                    machineState.hasController
                        ? _buildParserStateContent(machineState)
                        : [Text('No machine controller connected', style: VSCodeTheme.captionText)],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Configuration State Section  
                  _buildStateSection(
                    'Configuration (\$ Registers)',
                    machineState.configuration != null
                        ? _buildEnhancedConfigurationContent(machineState.configuration!, settingsState)
                        : [Text('No configuration data available', style: VSCodeTheme.captionText)],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOutputTab() {
    return LogOutputPanel(autoScroll: _autoScroll);
  }

  // Helper methods for machine state tab
  Widget _buildStateSection(String title, List<Widget> content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: VSCodeTheme.captionText.copyWith(
            fontWeight: FontWeight.w600,
            color: VSCodeTheme.accentText,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VSCodeTheme.inputBackground,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: VSCodeTheme.border.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: content,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildParserStateContent(MachineControllerState machineState) {
    final controller = machineState.controller!;
    final List<Widget> content = [];

    // Status information
    content.add(_buildStateRow('Status', '${controller.status.icon} ${controller.status.displayName}'));
    
    if (controller.firmwareVersion != null) {
      content.add(_buildStateRow('Firmware', controller.firmwareVersion!));
    }
    
    if (controller.hardwareVersion != null) {
      content.add(_buildStateRow('Hardware', controller.hardwareVersion!));
    }

    // Position information
    if (controller.workPosition != null) {
      content.add(_buildStateRow('Work Position', controller.workPosition.toString()));
    }
    
    if (controller.machinePosition != null) {
      content.add(_buildStateRow('Machine Position', controller.machinePosition.toString()));
    }

    // Feed and spindle state
    if (controller.feedState != null) {
      final feed = controller.feedState!;
      content.add(_buildStateRow('Feed Rate', '${feed.rate.toStringAsFixed(1)} ${feed.units}'));
    }
    
    if (controller.spindleState != null) {
      final spindle = controller.spindleState!;
      final status = spindle.isRunning ? 'Running' : 'Stopped';
      final direction = spindle.isClockwise ? 'CW' : 'CCW';
      content.add(_buildStateRow('Spindle', '$status @ ${spindle.speed.toStringAsFixed(0)} RPM $direction'));
    }

    // Active codes
    if (controller.activeCodes != null) {
      final codes = controller.activeCodes!;
      if (codes.gCodes.isNotEmpty) {
        content.add(_buildStateRow('Active G-Codes', codes.gCodes.join(', ')));
      }
      if (codes.mCodes.isNotEmpty) {
        content.add(_buildStateRow('Active M-Codes', codes.mCodes.join(', ')));
      }
    }

    // Buffer status
    if (machineState.plannerBlocksAvailable != null) {
      content.add(_buildStateRow('Planner Buffer', '${machineState.plannerBlocksAvailable} blocks available'));
    }
    
    if (machineState.rxBytesAvailable != null) {
      content.add(_buildStateRow('RX Buffer', '${machineState.rxBytesAvailable} bytes available'));
    }

    // Alarms and errors
    if (controller.alarms.isNotEmpty) {
      content.add(_buildStateRow('Alarms', controller.alarms.join(', '), isError: true));
    }
    
    if (controller.errors.isNotEmpty) {
      content.add(_buildStateRow('Errors', controller.errors.join(', '), isError: true));
    }

    return content.isNotEmpty 
        ? content 
        : [Text('Parser state information not available', style: VSCodeTheme.captionText)];
  }

  List<Widget> _buildEnhancedConfigurationContent(MachineConfiguration config, SettingsState settingsState) {
    final List<Widget> content = [];
    
    // Firmware info
    if (config.firmwareVersion != null) {
      content.add(_buildStateRow('Firmware Version', config.firmwareVersion!));
    }
    
    content.add(_buildStateRow('Settings Count', '${config.settings.length}'));
    content.add(_buildStateRow('Last Updated', config.lastUpdated.toLocal().toString().substring(0, 19)));
    
    // Show metadata loading status if settings are available
    if (settingsState.isInitialized) {
      content.add(_buildStateRow('UI Metadata', '${settingsState.metadataCount} descriptions, ${settingsState.groupsCount} groups'));
    }
    
    if (config.settings.isEmpty) {
      content.add(const SizedBox(height: 8));
      content.add(Text('No configuration settings available', style: VSCodeTheme.captionText));
      return content;
    }
    
    content.add(const SizedBox(height: 8));
    
    // Check if we have group information for hierarchical display
    if (settingsState.groupsLoaded && settingsState.getTopLevelGroups().isNotEmpty) {
      // Display settings organized by groups from $EG
      _addHierarchicalSettingsContent(content, config, settingsState);
    } else {
      // Display all settings in a flat list (fallback)
      _addFlatSettingsContent(content, config, settingsState);
    }

    return content;
  }

  /// Add hierarchical settings content organized by groups
  void _addHierarchicalSettingsContent(List<Widget> content, MachineConfiguration config, SettingsState settingsState) {
    final topLevelGroups = settingsState.getTopLevelGroups();
    
    for (final group in topLevelGroups) {
      // Get settings for this group
      final groupMetadata = settingsState.getMetadataForGroup(group.id);
      if (groupMetadata.isEmpty) continue;
      
      // Add group header
      content.add(const SizedBox(height: 8));
      content.add(Text(
        group.name,
        style: VSCodeTheme.smallText.copyWith(
          fontWeight: FontWeight.w600,
          color: VSCodeTheme.info,
        ),
      ));
      content.add(const SizedBox(height: 4));
      
      // Add settings in this group
      for (final metadata in groupMetadata) {
        final setting = config.getSetting(metadata.settingId);
        if (setting != null) {
          final enrichedSetting = EnrichedSetting(
            settingId: metadata.settingId,
            currentValue: setting.rawValue,
            metadata: metadata,
            valueUpdated: setting.lastUpdated,
          );
          
          content.add(_buildStateRow(
            '\$${metadata.settingId}',
            enrichedSetting.formattedValue,
          ));
        }
      }
    }
    
    // Show ungrouped settings
    _addUngroupedSettings(content, config, settingsState);
  }

  /// Add flat settings content (fallback when no groups available)
  void _addFlatSettingsContent(List<Widget> content, MachineConfiguration config, SettingsState settingsState) {
    final sortedSettings = config.settings.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    content.add(Text(
      'Configuration Registers',
      style: VSCodeTheme.smallText.copyWith(
        fontWeight: FontWeight.w600,
        color: VSCodeTheme.info,
      ),
    ));
    content.add(const SizedBox(height: 4));
    
    for (final settingEntry in sortedSettings) {
      final settingNumber = settingEntry.key;
      final setting = settingEntry.value;
      final metadata = settingsState.getMetadata(settingNumber);
      
      final enrichedSetting = EnrichedSetting(
        settingId: settingNumber,
        currentValue: setting.rawValue,
        metadata: metadata,
        valueUpdated: setting.lastUpdated,
      );
      
      content.add(_buildStateRow(
        '\$$settingNumber',
        enrichedSetting.formattedValue,
      ));
    }
  }

  /// Add settings that don't belong to any group
  void _addUngroupedSettings(List<Widget> content, MachineConfiguration config, SettingsState settingsState) {
    final ungroupedSettings = <ConfigurationSetting>[];
    
    for (final setting in config.settings.values) {
      final metadata = settingsState.getMetadata(setting.number);
      if (metadata == null || metadata.groupId == null) {
        ungroupedSettings.add(setting);
      }
    }
    
    if (ungroupedSettings.isNotEmpty) {
      content.add(const SizedBox(height: 8));
      content.add(Text(
        'Other Settings',
        style: VSCodeTheme.smallText.copyWith(
          fontWeight: FontWeight.w600,
          color: VSCodeTheme.info,
        ),
      ));
      content.add(const SizedBox(height: 4));
      
      ungroupedSettings.sort((a, b) => a.number.compareTo(b.number));
      
      for (final setting in ungroupedSettings) {
        final metadata = settingsState.getMetadata(setting.number);
        final enrichedSetting = EnrichedSetting(
          settingId: setting.number,
          currentValue: setting.rawValue,
          metadata: metadata,
          valueUpdated: setting.lastUpdated,
        );
        
        content.add(_buildStateRow(
          '\$${setting.number}',
          enrichedSetting.formattedValue,
        ));
      }
    }
  }


  Widget _buildStateRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: VSCodeTheme.smallText.copyWith(
                color: VSCodeTheme.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: VSCodeTheme.smallText.copyWith(
                color: isError ? VSCodeTheme.error : VSCodeTheme.primaryText,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }


  // Helper methods for console integration
  String _buildConsoleContent(CncCommunicationState state) {
    final buffer = StringBuffer();
    final timestamp = DateTime.now();

    // Application startup messages
    buffer.writeln(
      '[${timestamp.toIso8601String()}] ghSender Graphics Performance Spike',
    );
    buffer.writeln(
      '[${timestamp.toIso8601String()}] Communication system initializing...',
    );
    buffer.writeln('');

    // Connection state messages
    switch (state.runtimeType) {
      case const (CncCommunicationInitial):
        buffer.writeln('🔌 Communication Status: Ready to connect');
        buffer.writeln('💡 Use Settings panel to configure WebSocket URL');
        buffer.writeln('🎯 Test server available at: ws://localhost:8080');
        break;

      case const (CncCommunicationConnecting):
        buffer.writeln('🔄 Communication Status: Connecting...');
        buffer.writeln('⏳ Establishing WebSocket connection...');
        break;

      case const (CncCommunicationConnected):
        final connectedState = state as CncCommunicationConnected;
        buffer.writeln('✅ Communication Status: Connected');
        buffer.writeln('🌐 URL: ${connectedState.url}');
        buffer.writeln('📡 Device: ${connectedState.deviceInfo ?? 'Unknown'}');
        buffer.writeln('🕒 Connected at: ${connectedState.connectedAt}');
        break;

      case const (CncCommunicationWithData):
        final dataState = state as CncCommunicationWithData;
        buffer.writeln('✅ Communication Status: Active Connection');
        buffer.writeln('🌐 URL: ${dataState.url}');
        buffer.writeln('📊 Messages: ${dataState.messages.length}');

        // Note: Performance data display moved to MachineControllerBloc
        // Performance metrics are now tracked in machine controller state

        // Note: Machine state display moved to MachineControllerBloc
        // Will be shown via machine controller state instead of communication state

        // Note: Jog test status moved to MachineControllerBloc
        // Jog test information is now tracked in machine controller state

        buffer.writeln('');
        buffer.writeln('📨 Recent Communication:');
        buffer.writeln('─' * 50);

        // Show recent messages (last 20)
        final recentMessages = dataState.messages.length > 20
            ? dataState.messages.sublist(dataState.messages.length - 20)
            : dataState.messages;

        for (final message in recentMessages) {
          buffer.writeln(message);
        }
        break;

      case const (CncCommunicationError):
        final errorState = state as CncCommunicationError;
        buffer.writeln('❌ Communication Status: Error');
        buffer.writeln('💥 Error: ${errorState.errorMessage}');
        break;

      case const (CncCommunicationDisconnected):
        final disconnectedState = state as CncCommunicationDisconnected;
        buffer.writeln('🔌 Communication Status: Disconnected');
        buffer.writeln(
          '📝 Reason: ${disconnectedState.reason ?? 'User requested'}',
        );
        if (disconnectedState.disconnectedAt != null) {
          buffer.writeln(
            '🕒 Disconnected at: ${disconnectedState.disconnectedAt}',
          );
        }
        break;
    }

    return buffer.toString();
  }

  String _getConnectionStatus(CncCommunicationState state) {
    switch (state.runtimeType) {
      case const (CncCommunicationInitial):
        return 'Ready';
      case const (CncCommunicationConnecting):
        return 'Connecting';
      case const (CncCommunicationConnected):
      case const (CncCommunicationWithData):
        return 'Connected';
      case const (CncCommunicationError):
        return 'Error';
      case const (CncCommunicationDisconnected):
        return 'Disconnected';
      default:
        return 'Unknown';
    }
  }

  IconData _getConnectionIcon(CncCommunicationState state) {
    switch (state.runtimeType) {
      case const (CncCommunicationInitial):
        return Icons.radio_button_unchecked;
      case const (CncCommunicationConnecting):
        return Icons.sync;
      case const (CncCommunicationConnected):
      case const (CncCommunicationWithData):
        return Icons.wifi;
      case const (CncCommunicationError):
        return Icons.error;
      case const (CncCommunicationDisconnected):
        return Icons.wifi_off;
      default:
        return Icons.help;
    }
  }

  Color _getConnectionColor(CncCommunicationState state) {
    switch (state.runtimeType) {
      case const (CncCommunicationInitial):
        return VSCodeTheme.secondaryText;
      case const (CncCommunicationConnecting):
        return VSCodeTheme.warning;
      case const (CncCommunicationConnected):
      case const (CncCommunicationWithData):
        return VSCodeTheme.success;
      case const (CncCommunicationError):
        return VSCodeTheme.error;
      case const (CncCommunicationDisconnected):
        return VSCodeTheme.secondaryText;
      default:
        return VSCodeTheme.secondaryText;
    }
  }

  // Output tab control methods
  void _toggleAutoScroll() {
    setState(() {
      _autoScroll = !_autoScroll;
    });
    // Note: The actual auto-scroll logic is handled by LogOutputPanel
    // This just maintains the state for the UI toggle
  }

  void _clearLogs() {
    AppLogger.clearLogHistory();
  }
}
