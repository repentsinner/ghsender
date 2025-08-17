import 'package:flutter/material.dart';
import '../../themes/vscode_theme.dart';
import '../sidebar_sections/sidebar_components.dart';

/// Scene section in the sidebar - G-code file info and scene hierarchy
class SceneSection extends StatelessWidget {
  const SceneSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scene Information Section
          SidebarComponents.buildSectionWithInfo(
            title: 'Scene Information',
            infoTooltip: 'Basic information about the loaded G-code file and scene setup',
            child: Column(
              children: [
                SidebarComponents.buildInfoCard(
                  title: 'G-code File',
                  content: 'Loaded: Sample CNC toolpath\n7,612 operations processed\n5,412 optimized segments',
                ),
                
                const SizedBox(height: 12),
                
                SidebarComponents.buildInfoCard(
                  title: 'Scene Bounds',
                  content: 'X: 0.0 → 179.9mm\nY: 0.0 → 171.7mm\nZ: -1.0 → 25.0mm',
                ),
                
                const SizedBox(height: 12),
                
                SidebarComponents.buildInfoCard(
                  title: 'Camera Target',
                  content: 'Center: [89.96, 85.83, 12.0]\nOptimal viewing distance calculated',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Scene Objects Section
          SidebarComponents.buildSectionWithInfo(
            title: 'Scene Objects',
            infoTooltip: 'All objects currently loaded and rendered in the 3D scene',
            child: Column(
              children: [
                _buildObjectItem(
                  icon: Icons.timeline,
                  name: 'G-code Paths',
                  count: '5,412 segments',
                  color: VSCodeTheme.success,
                ),
                
                const SizedBox(height: 8),
                
                _buildObjectItem(
                  icon: Icons.navigation,
                  name: 'Rapid Moves',
                  count: '22 segments',
                  color: VSCodeTheme.info,
                ),
                
                const SizedBox(height: 8),
                
                _buildObjectItem(
                  icon: Icons.control_camera,
                  name: 'World Axes',
                  count: '3 axes',
                  color: VSCodeTheme.warning,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Processing Information Section
          SidebarComponents.buildSectionWithInfo(
            title: 'Processing Stats',
            infoTooltip: 'Performance metrics from G-code processing and optimization',
            child: Column(
              children: [
                _buildStatCard(
                  icon: Icons.compress,
                  label: 'Segment Optimization',
                  value: '29% reduction',
                  description: '7,611 → 5,412 segments',
                ),
                
                const SizedBox(height: 12),
                
                _buildStatCard(
                  icon: Icons.memory,
                  label: 'Tessellation',
                  value: '10.8k triangles',
                  description: '21,660 vertices generated',
                ),
                
                const SizedBox(height: 12),
                
                _buildStatCard(
                  icon: Icons.batch_prediction,
                  label: 'Batching Efficiency',
                  value: '24 mesh nodes',
                  description: 'Optimized for GPU rendering',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildObjectItem({
    required IconData icon,
    required String name,
    required String count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: VSCodeTheme.editorBackground,
        borderRadius: VSCodeTheme.containerRadius,
        border: Border.all(color: VSCodeTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),
          
          const SizedBox(width: 10),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: VSCodeTheme.labelText,
                ),
                Text(
                  count,
                  style: VSCodeTheme.smallText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String description,
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
          Icon(
            icon,
            color: VSCodeTheme.accentText,
            size: 16,
          ),
          
          const SizedBox(width: 10),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: VSCodeTheme.smallText,
                ),
                Text(
                  value,
                  style: VSCodeTheme.labelText.copyWith(
                    color: VSCodeTheme.accentText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: VSCodeTheme.smallText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}