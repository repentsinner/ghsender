import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../themes/vscode_theme.dart';
import '../widgets/dro_display.dart';

/// Main View widget - central content area for graphics rendering
class MainView extends StatelessWidget {
  final Widget child;
  final double wPosX;
  final double wPosY;
  final double wPosZ;
  final double mPosX;
  final double mPosY;
  final double mPosZ;
  final double fps;
  final int polygons;

  const MainView({
    super.key,
    required this.child,
    this.wPosX = 0.0,
    this.wPosY = 0.0,
    this.wPosZ = 0.0,
    this.mPosX = 0.0,
    this.mPosY = 0.0,
    this.mPosZ = 0.0,
    required this.fps,
    required this.polygons,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VSCodeTheme.editorBackground,
      child: Stack(
        children: [
          // Main graphics content
          ClipRect(child: child),

          // Debug performance overlay at top left
          Positioned(top: 8, left: 8, child: _buildDebugOverlay()),

          // DRO positioned at top right
          Positioned(
            top: 0,
            right: 0,
            child: DRODisplay(
              wPosX: wPosX,
              wPosY: wPosY,
              wPosZ: wPosZ,
              mPosX: mPosX,
              mPosY: mPosY,
              mPosZ: mPosZ,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugOverlay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.speed, color: Colors.white70, size: 12),
              const SizedBox(width: 4),
              Text(
                '${fps.toStringAsFixed(1)} FPS',
                style: GoogleFonts.inconsolata(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_tree, color: Colors.white70, size: 12),
              const SizedBox(width: 4),
              Text(
                '${(polygons / 1000).toStringAsFixed(1)}k polygons',
                style: GoogleFonts.inconsolata(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
