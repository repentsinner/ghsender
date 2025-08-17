import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../themes/vscode_theme.dart';
import '../widgets/problem_item.dart';
import '../widgets/log_output_panel.dart';
import '../../bloc/bloc_exports.dart';
import '../../utils/logger.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: VSCodeTheme.panelTheme.copyWith(
        tabBarTheme: VSCodeTheme.panelTheme.tabBarTheme.copyWith(
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          labelStyle: VSCodeTheme.sidebarOrPanelHeading,
          unselectedLabelStyle: VSCodeTheme.sidebarOrPanelHeading.copyWith(
            color: VSCodeTheme.secondaryText,
          ),
        ),
      ),
      child: Container(
        color: VSCodeTheme.panelBackground,
        child: Column(
          children: [
            // Panel header with tabs and close button
            SizedBox(
              height: 35,
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
                                        style: GoogleFonts.inconsolata(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Tab(text: 'Console'.toUpperCase()),
                            Tab(text: 'Output'.toUpperCase()),
                          ],
                        );
                      },
                    ),
                  ),

                  // Output tab controls (only visible when Output tab is active)
                  if (_tabController.index == 2) ...[
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

            // Panel content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProblemsTab(),
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
                    ),
                  ),
                ] else ...[
                  // No problems message
                  Text(
                    'No problems detected',
                    style: GoogleFonts.inconsolata(
                      color: VSCodeTheme.secondaryText,
                      fontSize: 11,
                    ),
                  ),
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
                      style: GoogleFonts.inconsolata(
                        color: VSCodeTheme.secondaryText.withValues(alpha: 0.7),
                        fontSize: 9,
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
                    style: GoogleFonts.inconsolata(
                      color: VSCodeTheme.accentText,
                      fontSize: 11,
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
                    style: GoogleFonts.inconsolata(
                      color: VSCodeTheme.secondaryText,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOutputTab() {
    return LogOutputPanel(autoScroll: _autoScroll);
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
