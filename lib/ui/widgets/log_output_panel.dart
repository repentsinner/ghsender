import 'package:flutter/material.dart';
import 'dart:async';
import '../../utils/logger.dart';
import '../themes/vscode_theme.dart';

/// Log output panel widget that displays real-time log messages
class LogOutputPanel extends StatefulWidget {
  final double height;
  final bool autoScroll;

  const LogOutputPanel({
    super.key,
    this.height = 200.0,
    this.autoScroll = true,
  });

  @override
  State<LogOutputPanel> createState() => _LogOutputPanelState();
}

class _LogOutputPanelState extends State<LogOutputPanel> {
  late StreamSubscription<LogMessage> _logSubscription;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int> _logCountNotifier = ValueNotifier<int>(0);

  // Static color map for log levels
  static const Map<String, Color> _levelColors = {
    'SEVERE': VSCodeTheme.error,
    'WARNING': VSCodeTheme.warning,
    'INFO': VSCodeTheme.info,
    'FINE': VSCodeTheme.secondaryText,
  };


  @override
  void initState() {
    super.initState();
    // Initialize with current log count
    _logCountNotifier.value = AppLogger.logHistory.length;
    
    // Subscribe to new log messages for real-time updates
    _logSubscription = AppLogger.logStream.listen(_onLogMessage);

    // If there are existing logs, trigger initial auto-scroll
    if (AppLogger.logHistory.isNotEmpty && widget.autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  @override
  void dispose() {
    _logSubscription.cancel();
    _scrollController.dispose();
    _logCountNotifier.dispose();
    super.dispose();
  }

  void _onLogMessage(LogMessage message) {
    // Update log count notifier instead of setState for better performance
    _logCountNotifier.value = AppLogger.logHistory.length;

    // Auto-scroll to bottom if enabled
    if (widget.autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }


  // Create prototype item for optimal ListView performance
  Widget _buildPrototypeItem() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: Row(
        children: [
          // Time
          Text(
            '00:00:00.000 ',
            style: VSCodeTheme.loglineTime.copyWith(fontSize: 11),
          ),
          // Logger name
          Text(
            'AppLogger ',
            style: VSCodeTheme.loglineName.copyWith(fontSize: 11),
          ),
          // Level (colored)
          Text(
            'WARNING ',
            style: VSCodeTheme.loglineLevel.copyWith(
              fontSize: 11,
              color: _levelColors['WARNING'],
            ),
          ),
          // Message
          Expanded(
            child: Text(
              'Sample log message for prototype sizing',
              style: VSCodeTheme.loglineMessage.copyWith(fontSize: 11),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get color for log level
  Color _getLevelColor(String level) {
    return _levelColors[level.toUpperCase()] ?? VSCodeTheme.primaryText;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Expanded(
        child: ValueListenableBuilder<int>(
          valueListenable: _logCountNotifier,
          builder: (context, logCount, child) {
            return logCount == 0
                ? Center(
                    child: Text(
                      'No log messages',
                      style: VSCodeTheme.loglineMessage,
                    ),
                  )
                : SelectionArea(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: logCount,
                      prototypeItem: _buildPrototypeItem(), // Optimal performance
                      cacheExtent: 250, // Flutter default, proven optimal
                      addAutomaticKeepAlives: false, // Performance optimization
                      addRepaintBoundaries: true, // Optimal for visible items
                      itemBuilder: (context, index) {
                        final message = AppLogger.logHistory[index];
                        
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                          child: Row(
                            children: [
                              // Time
                              Text(
                                '${message.formattedTime} ',
                                style: VSCodeTheme.loglineTime.copyWith(fontSize: 11),
                              ),
                              // Logger name
                              Text(
                                '${message.name.padRight(8)} ',
                                style: VSCodeTheme.loglineName.copyWith(fontSize: 11),
                              ),
                              // Level (colored)
                              Text(
                                '${message.level.padRight(7)} ',
                                style: VSCodeTheme.loglineLevel.copyWith(
                                  fontSize: 11,
                                  color: _getLevelColor(message.level),
                                ),
                              ),
                              // Message
                              Expanded(
                                child: Text(
                                  message.message,
                                  style: VSCodeTheme.loglineMessage.copyWith(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
          },
        ),
      ),
    );
  }
}
