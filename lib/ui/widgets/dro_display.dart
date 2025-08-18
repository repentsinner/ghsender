import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../themes/vscode_theme.dart';
import '../../bloc/bloc_exports.dart';

/// Digital Read-Out (DRO) component for machine control information
/// Automatically updates from machine controller state
class DRODisplay extends StatelessWidget {
  const DRODisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MachineControllerBloc, MachineControllerState>(
      builder: (context, machineState) {
        // Get position data from machine controller
        final workPos = machineState.workPosition;
        final machinePos = machineState.machinePosition;

        // Default to 0.0 if no position data available
        final wPosX = workPos?.x ?? 0.0;
        final wPosY = workPos?.y ?? 0.0;
        final wPosZ = workPos?.z ?? 0.0;
        final mPosX = machinePos?.x ?? 0.0;
        final mPosY = machinePos?.y ?? 0.0;
        final mPosZ = machinePos?.z ?? 0.0;

        if (machineState.hasController && machineState.isOnline) {
          return Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // WPos (Work Position) - Primary display
                _buildPositionSection(
                  label: 'WPos',
                  x: wPosX,
                  y: wPosY,
                  z: wPosZ,
                  isPrimary: true,
                  lastUpdated: workPos?.lastUpdated,
                ),

                const SizedBox(height: 6),

                // MPos (Machine Position) - Muted display
                _buildPositionSection(
                  label: 'MPos',
                  x: mPosX,
                  y: mPosY,
                  z: mPosZ,
                  isPrimary: false,
                  lastUpdated: machinePos?.lastUpdated,
                ),
              ],
            ),
          );
        } else {
          // Return an empty container or a placeholder when controller is not online/available
          return Container();
        }
      },
    );
  }

  Widget _buildPositionSection({
    required String label,
    required double x,
    required double y,
    required double z,
    required bool isPrimary,
    DateTime? lastUpdated,
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
