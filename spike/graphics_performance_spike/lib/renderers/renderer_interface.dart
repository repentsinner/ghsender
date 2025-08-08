import 'package:flutter/material.dart';
import '../scene/scene_manager.dart';

/// Common interface that all renderers must implement
/// Renderers are pure rendering engines - they know nothing about scenes
abstract class Renderer {
  /// Initialize the renderer
  Future<bool> initialize();
  
  /// Set up the renderer to display the given scene
  Future<void> setupScene(SceneData sceneData);
  
  /// Update camera rotation (interactive control)
  void updateRotation(double rotationX, double rotationY);
  
  /// Render frame (for Canvas-based renderers)
  void render(Canvas canvas, Size size, double rotationX, double rotationY);
  
  /// Create widget for display (for widget-based renderers like Filament)
  Widget createWidget();
  
  /// Clean up resources
  void dispose();
  
  // Performance metrics
  bool get initialized;
  int get actualPolygons;
  int get actualDrawCalls;
}