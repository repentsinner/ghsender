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





  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
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
                : SingleChildScrollView(
                    controller: _scrollController,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                      child: SelectableText(
                        AppLogger.logHistory.map((message) {
                          return '${message.formattedTime} ${message.name.padRight(8)} ${message.level.padRight(7)} ${message.message}';
                        }).join('\n'),
                        style: VSCodeTheme.loglineMessage.copyWith(
                          fontSize: 11,
                          color: VSCodeTheme.primaryText,
                        ),
                      ),
                    ),
                  );
          },
        ),
    );
  }
}
