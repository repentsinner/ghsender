import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../themes/vscode_theme.dart';

/// Performance section in the sidebar - FPS, polygons, draw calls metrics
class PerformanceSection extends StatelessWidget {
  final double fps;
  final int polygons;
  final int drawCalls;

  const PerformanceSection({
    super.key,
    required this.fps,
    required this.polygons,
    required this.drawCalls,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Real-time Metrics Section
          _buildSectionTitle('Real-time Metrics'),
          const SizedBox(height: 16),
          
          // FPS Metric
          _buildMetricCard(
            icon: Icons.speed,
            label: 'Frame Rate',
            value: '${fps.toStringAsFixed(2)} FPS',
            color: _getFpsColor(fps),
            status: _getFpsStatus(fps),
          ),
          
          const SizedBox(height: 12),
          
          // Polygons Metric
          _buildMetricCard(
            icon: Icons.account_tree,
            label: 'Polygons',
            value: '${(polygons / 1000).toStringAsFixed(1)}k',
            color: VSCodeTheme.info,
            status: '${polygons.toString()} triangles',
          ),
          
          const SizedBox(height: 12),
          
          // Draw Calls Metric
          _buildMetricCard(
            icon: Icons.call_split,
            label: 'Draw Calls',
            value: drawCalls.toString(),
            color: _getDrawCallColor(drawCalls),
            status: _getDrawCallStatus(drawCalls),
          ),
          
          const SizedBox(height: 24),
          
          // Performance Tips Section
          _buildSectionTitle('Performance Tips'),
          const SizedBox(height: 12),
          
          _buildTipCard(
            icon: Icons.lightbulb_outline,
            title: 'Optimal Frame Rate',
            description: 'Target 60 FPS for smooth interaction. Values below 30 FPS may feel sluggish.',
          ),
          
          const SizedBox(height: 12),
          
          _buildTipCard(
            icon: Icons.memory,
            title: 'Polygon Count',
            description: 'Current scene efficiently renders ${(polygons / 1000).toStringAsFixed(1)}k triangles in real-time.',
          ),
          
          const SizedBox(height: 12),
          
          _buildTipCard(
            icon: Icons.flash_on,
            title: 'Draw Call Efficiency',
            description: 'Lower draw calls indicate better batching. Current: $drawCalls calls.',
          ),
          
          const SizedBox(height: 24),
          
          // System Information Section
          _buildSectionTitle('System Information'),
          const SizedBox(height: 12),
          
          _buildInfoCard(
            title: 'Graphics Backend',
            content: 'Flutter Impeller (Metal)\nHardware-accelerated rendering',
          ),
          
          const SizedBox(height: 12),
          
          _buildInfoCard(
            title: 'Renderer',
            content: 'Flutter Scene Batch Renderer\nCustom shader-based line rendering',
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inconsolata(
        color: VSCodeTheme.primaryText,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
  
  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required String status,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VSCodeTheme.editorBackground,
        borderRadius: VSCodeTheme.containerRadius,
        border: Border.all(color: VSCodeTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inconsolata(
                    color: VSCodeTheme.secondaryText,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inconsolata(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: GoogleFonts.inconsolata(
                    color: VSCodeTheme.secondaryText,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTipCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VSCodeTheme.info.withValues(alpha: 0.05),
        borderRadius: VSCodeTheme.containerRadius,
        border: Border.all(color: VSCodeTheme.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: VSCodeTheme.info,
            size: 16,
          ),
          
          const SizedBox(width: 8),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inconsolata(
                    color: VSCodeTheme.info,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inconsolata(
                    color: VSCodeTheme.secondaryText,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoCard({required String title, required String content}) {
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
  
  Color _getFpsColor(double fps) {
    if (fps >= 50) return VSCodeTheme.success;
    if (fps >= 30) return VSCodeTheme.warning;
    return VSCodeTheme.error;
  }
  
  String _getFpsStatus(double fps) {
    if (fps >= 50) return 'Excellent performance';
    if (fps >= 30) return 'Good performance';
    return 'Performance issues';
  }
  
  Color _getDrawCallColor(int drawCalls) {
    if (drawCalls <= 10) return VSCodeTheme.success;
    if (drawCalls <= 50) return VSCodeTheme.warning;
    return VSCodeTheme.error;
  }
  
  String _getDrawCallStatus(int drawCalls) {
    if (drawCalls <= 10) return 'Excellent batching';
    if (drawCalls <= 50) return 'Good batching';
    return 'Poor batching';
  }
}