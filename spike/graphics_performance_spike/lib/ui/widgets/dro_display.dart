import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../themes/vscode_theme.dart';
import '../../bloc/bloc_exports.dart';
import '../../models/machine_controller.dart';

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
        
        // Show connection status if not connected
        if (!machineState.hasController || !machineState.isOnline) {
          return _buildDisconnectedState();
        }
        
        return Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection status indicator
              _buildConnectionIndicator(machineState),
              
              const SizedBox(height: 8),
              
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
  
  Widget _buildDisconnectedState() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.portable_wifi_off,
                color: VSCodeTheme.secondaryText,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'DRO',
                style: GoogleFonts.inconsolata(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: VSCodeTheme.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Not Connected',
            style: GoogleFonts.inconsolata(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: VSCodeTheme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildConnectionIndicator(MachineControllerState machineState) {
    final (IconData icon, Color color) = switch (machineState.status) {
      MachineStatus.idle => (Icons.circle, Colors.green),
      MachineStatus.running => (Icons.play_circle_filled, Colors.blue),
      MachineStatus.paused => (Icons.pause_circle_filled, Colors.orange),
      MachineStatus.alarm || MachineStatus.error => (Icons.error, Colors.red),
      MachineStatus.homing => (Icons.home, Colors.yellow),
      MachineStatus.jogging => (Icons.open_with, Colors.cyan),
      MachineStatus.hold => (Icons.pause, Colors.orange),
      MachineStatus.door => (Icons.door_front_door, Colors.purple),
      MachineStatus.check => (Icons.check_circle, Colors.teal),
      MachineStatus.sleep => (Icons.bedtime, Colors.grey),
      _ => (Icons.help, Colors.grey),
    };
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 6),
        Text(
          'DRO',
          style: GoogleFonts.inconsolata(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: VSCodeTheme.primaryText,
          ),
        ),
        const SizedBox(width: 8),
        if (machineState.grblHalDetected) ...[
          Icon(
            Icons.bolt,
            color: Colors.green,
            size: 12,
          ),
          const SizedBox(width: 2),
          Text(
            'grblHAL',
            style: GoogleFonts.inconsolata(
              fontSize: 9,
              fontWeight: FontWeight.w400,
              color: Colors.green,
            ),
          ),
        ],
      ],
    );
  }
}
