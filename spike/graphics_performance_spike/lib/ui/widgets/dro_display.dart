import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../themes/vscode_theme.dart';

/// Digital Read-Out (DRO) component for machine control information
class DRODisplay extends StatelessWidget {
  final double wPosX;
  final double wPosY;
  final double wPosZ;
  final double mPosX;
  final double mPosY;
  final double mPosZ;

  const DRODisplay({
    super.key,
    required this.wPosX,
    required this.wPosY,
    required this.wPosZ,
    required this.mPosX,
    required this.mPosY,
    required this.mPosZ,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: VSCodeTheme.sideBarBackground.withValues(alpha: 0.9),
        border: Border.all(
          color: VSCodeTheme.border,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'DRO',
            style: GoogleFonts.inconsolata(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: VSCodeTheme.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          
          // WPos (Work Position) - Primary display
          _buildPositionSection(
            label: 'WPos',
            x: wPosX,
            y: wPosY,
            z: wPosZ,
            isPrimary: true,
          ),
          
          const SizedBox(height: 6),
          
          // MPos (Machine Position) - Muted display
          _buildPositionSection(
            label: 'MPos',
            x: mPosX,
            y: mPosY,
            z: mPosZ,
            isPrimary: false,
          ),
        ],
      ),
    );
  }

  Widget _buildPositionSection({
    required String label,
    required double x,
    required double y,
    required double z,
    required bool isPrimary,
  }) {
    final textColor = isPrimary 
        ? VSCodeTheme.primaryText 
        : VSCodeTheme.secondaryText;
    final fontSize = isPrimary ? 14.0 : 12.0;
    final fontWeight = isPrimary ? FontWeight.w500 : FontWeight.w400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inconsolata(
            fontSize: fontSize - 2,
            fontWeight: fontWeight,
            color: textColor,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            _buildAxisValue('X', x, textColor, fontSize, fontWeight),
            const SizedBox(width: 12),
            _buildAxisValue('Y', y, textColor, fontSize, fontWeight),
            const SizedBox(width: 12),
            _buildAxisValue('Z', z, textColor, fontSize, fontWeight),
          ],
        ),
      ],
    );
  }

  Widget _buildAxisValue(
    String axis,
    double value,
    Color textColor,
    double fontSize,
    FontWeight fontWeight,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          axis,
          style: GoogleFonts.inconsolata(
            fontSize: fontSize - 3,
            fontWeight: FontWeight.w600,
            color: textColor.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value.toStringAsFixed(3),
          style: GoogleFonts.inconsolata(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: textColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}