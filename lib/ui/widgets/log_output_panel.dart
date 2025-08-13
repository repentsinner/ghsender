import 'package:flutter/material.dart';
import 'dart:async';
import '../../utils/logger.dart';
import '../themes/vscode_theme.dart';

/// Log output panel widget that displays real-time log messages
/// TODO: this widget has significant UI redraw performance impacts
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

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _onLogMessage(LogMessage message) {
    // Just trigger UI update - message is already stored in AppLogger
    setState(() {});

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

  Color _getLevelColor(String level) {
    switch (level.toUpperCase()) {
      case 'SEVERE':
        return VSCodeTheme.error;
      case 'WARNING':
        return VSCodeTheme.warning;
      case 'INFO':
        return VSCodeTheme.info;
      case 'FINE':
        return VSCodeTheme.secondaryText;
      default:
        return VSCodeTheme.primaryText;
    }
  }

  IconData _getLevelIcon(String level) {
    switch (level.toUpperCase()) {
      case 'SEVERE':
        return Icons.error;
      case 'WARNING':
        return Icons.warning;
      case 'INFO':
        return Icons.info;
      case 'FINE':
        return Icons.bug_report;
      default:
        return Icons.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Expanded(
        child: AppLogger.logHistory.isEmpty
            ? Center(
                child: Text(
                  'No log messages',
                  style: VSCodeTheme.loglineMessage,
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                itemCount: AppLogger.logHistory.length,
                itemBuilder: (context, index) {
                  final message = AppLogger.logHistory[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Time
                        Text(
                          message.formattedTime,
                          style: VSCodeTheme.loglineTime,
                        ),
                        const SizedBox(width: 8),
                        // Logger name
                        Container(
                          constraints: const BoxConstraints(minWidth: 60),
                          child: Text(
                            message.name,
                            style: VSCodeTheme.loglineName,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Level with icon
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getLevelIcon(message.level),
                              size: 12,
                              color: _getLevelColor(message.level),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              message.level.padRight(7),
                              style: VSCodeTheme.loglineLevel.copyWith(
                                color: _getLevelColor(message.level),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        // Message
                        Expanded(
                          child: Text(
                            message.message,
                            style: VSCodeTheme.loglineMessage,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
