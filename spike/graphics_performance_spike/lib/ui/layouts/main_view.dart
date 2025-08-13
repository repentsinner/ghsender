import 'package:flutter/material.dart';
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

  const MainView({
    super.key,
    required this.child,
    this.wPosX = 0.0,
    this.wPosY = 0.0,
    this.wPosZ = 0.0,
    this.mPosX = 0.0,
    this.mPosY = 0.0,
    this.mPosZ = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VSCodeTheme.editorBackground,
      child: Stack(
        children: [
          // Main graphics content
          ClipRect(child: child),
          
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
}