import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../themes/vscode_theme.dart';

/// Shared components for sidebar sections to maintain consistency and reduce duplication
class SidebarComponents {
  /// Builds a section with title, info tooltip, and content
  static Widget buildSectionWithInfo({
    required String title,
    required String infoTooltip,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.inconsolata(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: VSCodeTheme.primaryText,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: infoTooltip,
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: VSCodeTheme.infoTooltip,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  /// Builds an info card with title and content
  static Widget buildInfoCard({
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VSCodeTheme.editorBackground,
        borderRadius: VSCodeTheme.containerRadius,
        border: Border.all(color: VSCodeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inconsolata(
              color: VSCodeTheme.accentText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: GoogleFonts.inconsolata(
              color: VSCodeTheme.secondaryText,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
