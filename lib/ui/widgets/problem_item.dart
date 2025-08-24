import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../themes/vscode_theme.dart';
import '../../domain/entities/problem.dart';
import '../../domain/value_objects/problem_action.dart';

/// Widget to display a single problem item in the Problems panel
class ProblemItem extends StatelessWidget {
  final Problem problem;
  final VoidCallback? onTap;
  final Function(ProblemAction)? onActionTap;
  
  const ProblemItem({
    super.key,
    required this.problem,
    this.onTap,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VSCodeTheme.panelBackground,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _getBorderColor(),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon, title, and source
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Severity icon
                Text(
                  problem.severity.icon,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 8),
                
                // Title and source
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${problem.source}: ${problem.title}',
                        style: GoogleFonts.inconsolata(
                          color: _getTitleColor(),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        problem.description,
                        style: GoogleFonts.inconsolata(
                          color: VSCodeTheme.secondaryText,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Timestamp
                Text(
                  _formatTimestamp(problem.timestamp),
                  style: GoogleFonts.inconsolata(
                    color: VSCodeTheme.secondaryText,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            
            // Metadata if available
            if (problem.metadata != null && problem.metadata!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: VSCodeTheme.inputBackground,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  _formatMetadata(problem.metadata!),
                  style: GoogleFonts.inconsolata(
                    color: VSCodeTheme.secondaryText,
                    fontSize: 10,
                  ),
                ),
              ),
            ],

            // Action buttons if available
            if (problem.actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: problem.actions.map((action) => _buildActionButton(action)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build an action button for a problem action
  Widget _buildActionButton(ProblemAction action) {
    return SizedBox(
      height: 28,
      child: ElevatedButton(
        onPressed: () => onActionTap?.call(action),
        style: ElevatedButton.styleFrom(
          backgroundColor: _getActionButtonColor(action.type),
          foregroundColor: VSCodeTheme.primaryText,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(
              color: _getActionButtonBorderColor(action.type),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (action.icon != null) ...[
              Text(
                action.icon!,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              action.label,
              style: GoogleFonts.inconsolata(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get action button background color based on action type
  Color _getActionButtonColor(ProblemActionType type) {
    switch (type) {
      case ProblemActionType.machineCommand:
        return VSCodeTheme.focus.withValues(alpha: 0.1);
      case ProblemActionType.rawCommand:
        return VSCodeTheme.warning.withValues(alpha: 0.1);
      case ProblemActionType.navigate:
        return VSCodeTheme.info.withValues(alpha: 0.1);
      case ProblemActionType.dismiss:
        return VSCodeTheme.inputBackground;
    }
  }

  /// Get action button border color based on action type
  Color _getActionButtonBorderColor(ProblemActionType type) {
    switch (type) {
      case ProblemActionType.machineCommand:
        return VSCodeTheme.focus.withValues(alpha: 0.3);
      case ProblemActionType.rawCommand:
        return VSCodeTheme.warning.withValues(alpha: 0.3);
      case ProblemActionType.navigate:
        return VSCodeTheme.info.withValues(alpha: 0.3);
      case ProblemActionType.dismiss:
        return VSCodeTheme.border;
    }
  }
  
  /// Get border color based on severity
  Color _getBorderColor() {
    switch (problem.severity) {
      case ProblemSeverity.error:
        return VSCodeTheme.error.withValues(alpha: 0.3);
      case ProblemSeverity.warning:
        return VSCodeTheme.warning.withValues(alpha: 0.3);
      case ProblemSeverity.info:
        return VSCodeTheme.info.withValues(alpha: 0.3);
    }
  }
  
  /// Get title color based on severity
  Color _getTitleColor() {
    switch (problem.severity) {
      case ProblemSeverity.error:
        return VSCodeTheme.error;
      case ProblemSeverity.warning:
        return VSCodeTheme.warning;
      case ProblemSeverity.info:
        return VSCodeTheme.info;
    }
  }
  
  /// Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
  
  /// Format metadata for display
  String _formatMetadata(Map<String, dynamic> metadata) {
    return metadata.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
  }
}

/// Compact version of problem item for status bar
class ProblemSummary extends StatelessWidget {
  final int errorCount;
  final int warningCount;
  final int infoCount;
  final VoidCallback? onTap;
  
  const ProblemSummary({
    super.key,
    required this.errorCount,
    required this.warningCount,
    required this.infoCount,
    this.onTap,
  });
  
  bool get hasProblems => errorCount > 0 || warningCount > 0 || infoCount > 0;
  
  @override
  Widget build(BuildContext context) {
    if (!hasProblems) {
      return GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✅', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              'No problems',
              style: GoogleFonts.inconsolata(
                color: VSCodeTheme.success,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }
    
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show most severe problem icon
          if (errorCount > 0) ...[
            const Text('❌', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              '$errorCount',
              style: GoogleFonts.inconsolata(
                color: VSCodeTheme.error,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (warningCount > 0) ...[
            const Text('⚠️', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              '$warningCount',
              style: GoogleFonts.inconsolata(
                color: VSCodeTheme.warning,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (infoCount > 0) ...[
            const Text('ℹ️', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              '$infoCount',
              style: GoogleFonts.inconsolata(
                color: VSCodeTheme.info,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}