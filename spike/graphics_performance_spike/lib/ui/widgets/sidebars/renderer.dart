import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../themes/vscode_theme.dart';
import '../sidebar_sections/sidebar_components.dart';

/// Renderer section in the sidebar - line settings and rendering controls
class RendererSection extends StatelessWidget {
  final double lineWeight;
  final double lineSmoothness;
  final double lineOpacity;
  final ValueChanged<double> onLineWeightChanged;
  final ValueChanged<double> onLineSmoothnessChanged;
  final ValueChanged<double> onLineOpacityChanged;

  const RendererSection({
    super.key,
    required this.lineWeight,
    required this.lineSmoothness,
    required this.lineOpacity,
    required this.onLineWeightChanged,
    required this.onLineSmoothnessChanged,
    required this.onLineOpacityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line Settings Section
          SidebarComponents.buildSectionWithInfo(
            title: 'Line Settings',
            infoTooltip: 'Adjust visual properties of rendered lines including weight, smoothness, and opacity',
            child: Column(
              children: [
                // Line Weight Control
                _buildSliderControl(
                  label: 'Weight',
                  value: lineWeight,
                  min: 0.1,
                  max: 5.0,
                  divisions: 49,
                  onChanged: onLineWeightChanged,
                  formatValue: (value) => value.toStringAsFixed(1),
                  description: 'Controls the thickness of rendered lines',
                ),
                
                const SizedBox(height: 20),
                
                // Line Smoothness Control
                _buildSliderControl(
                  label: 'Smoothness',
                  value: lineSmoothness,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  onChanged: onLineSmoothnessChanged,
                  formatValue: (value) => '${value.toStringAsFixed(2)} ${_getSmoothnessSuffix(value)}',
                  description: 'Adjusts line edge softness (0.0 = soft, 1.0 = sharp)',
                ),
                
                const SizedBox(height: 20),
                
                // Line Opacity Control
                _buildSliderControl(
                  label: 'Opacity',
                  value: lineOpacity,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  onChanged: onLineOpacityChanged,
                  formatValue: (value) => '${value.toStringAsFixed(2)} ${_getOpacitySuffix(value)}',
                  description: 'Controls line transparency (0.0 = transparent, 1.0 = solid)',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Renderer Info Section
          SidebarComponents.buildSectionWithInfo(
            title: 'Renderer Information',
            infoTooltip: 'Details about the active rendering engine and its capabilities',
            child: Column(
              children: [
                SidebarComponents.buildInfoCard(
                  title: 'Active Renderer',
                  content: 'Flutter Scene Lines Renderer\nHardware-accelerated line rendering with custom shaders',
                ),
                
                const SizedBox(height: 16),
                
                SidebarComponents.buildInfoCard(
                  title: 'Features',
                  content: '• Variable line width\n• Anti-aliased edges\n• Transparency support\n• GPU-accelerated rendering',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  
  Widget _buildSliderControl({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String Function(double) formatValue,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label and value
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inconsolata(
                color: VSCodeTheme.primaryText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              formatValue(value),
              style: GoogleFonts.inconsolata(
                color: VSCodeTheme.accentText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Slider
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
        
        const SizedBox(height: 4),
        
        // Description
        Text(
          description,
          style: GoogleFonts.inconsolata(
            color: VSCodeTheme.secondaryText,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
  
  
  String _getSmoothnessSuffix(double smoothness) {
    if (smoothness < 0.3) return '(soft)';
    if (smoothness > 0.7) return '(sharp)';
    return '(medium)';
  }
  
  String _getOpacitySuffix(double opacity) {
    if (opacity < 0.3) return '(transparent)';
    if (opacity > 0.7) return '(solid)';
    return '(translucent)';
  }
}