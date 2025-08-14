import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../themes/vscode_theme.dart';
import '../widgets/dro_display.dart';
import '../../bloc/performance/performance_bloc.dart';
import '../../bloc/performance/performance_state.dart';

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

          // Debug performance overlay at top left
          Positioned(top: 8, left: 8, child: _buildDebugOverlay()),

          // DRO positioned at top right - now automatically updates from machine controller
          const Positioned(
            top: 0,
            right: 0,
            child: DRODisplay(),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugOverlay() {
    return BlocBuilder<PerformanceBloc, PerformanceState>(
      builder: (context, state) {
        final fps = state is PerformanceLoaded ? state.fps : 0.0;
        final polygons = state is PerformanceLoaded ? state.polygons : 0;
        
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
      },
    );
  }
}
