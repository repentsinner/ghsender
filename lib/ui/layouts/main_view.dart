import 'package:flutter/material.dart';
import '../themes/vscode_theme.dart';
import '../widgets/dro_display.dart';

/// Main View widget - central content area for graphics rendering
class MainView extends StatelessWidget {
  final Widget child;

  const MainView({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VSCodeTheme.editorBackground,
      child: Stack(
        children: [
          // Main graphics content
          ClipRect(child: child),

          // DRO positioned at top left - now automatically updates from machine controller
          const Positioned(
            top: 8,
            left: 8,
            child: DRODisplay(),
          ),
        ],
      ),
    );
  }

}
