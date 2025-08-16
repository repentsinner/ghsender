import 'package:flutter/material.dart';

/// Centralized theme system for 3D visualization colors and settings
/// Provides consistent styling for G-code paths, coordinate axes, and 3D objects
class VisualizerTheme {
  // ==================== G-CODE PATH COLORS ====================

  /// Colors for different G-code move types
  static const Color rapidMoveColor = Color.fromARGB(
    255,
    33,
    212,
    243,
  ); // G0 rapid positioning
  static const Color linearMoveColor = Colors.green; // G1 linear cutting moves
  static const Color clockwiseArcColor = Colors.red; // G2 clockwise arcs
  static const Color counterClockwiseArcColor =
      Colors.orange; // G3 counter-clockwise arcs

  /// Alternative high-contrast color scheme
  static const Color rapidMoveColorHighContrast = Color(
    0xFF00BFFF,
  ); // Deep sky blue
  static const Color linearMoveColorHighContrast = Color(
    0xFF00FF7F,
  ); // Spring green
  static const Color clockwiseArcColorHighContrast = Color(
    0xFFFF4500,
  ); // Orange red
  static const Color counterClockwiseArcColorHighContrast = Color(
    0xFFFFD700,
  ); // Gold

  /// Colorblind-safe color scheme (protanopia/deuteranopia friendly)
  static const Color rapidMoveColorColorblind = Color(0xFF0077BE); // Blue
  static const Color linearMoveColorColorblind = Color(0xFFFFA500); // Orange
  static const Color clockwiseArcColorColorblind = Color(0xFF8E44AD); // Purple
  static const Color counterClockwiseArcColorColorblind = Color(
    0xFFE74C3C,
  ); // Red-orange

  // ==================== COORDINATE SYSTEM COLORS ====================

  /// Standard CNC coordinate axis colors
  static const Color xAxisColor = Colors.red; // X-axis (right)
  static const Color yAxisColor = Colors.green; // Y-axis (away from operator)
  static const Color zAxisColor = Colors.blue; // Z-axis (up)

  /// Grayscale coordinate axis colors
  static const Color xAxisColorGrayscale = Color(0xFF999999); // Light gray
  static const Color yAxisColorGrayscale = Color(0xFF666666); // Medium gray
  static const Color zAxisColorGrayscale = Color(0xFF333333); // Dark gray

  // ==================== WORK AREA & BOUNDARIES ====================

  /// Work area visualization colors
  static const Color workAreaFillColor = Colors.blue;
  static const double workAreaOpacity = 0.15;
  static const Color workAreaEdgeColor = Colors.blue;
  static const double workAreaEdgeWidth = 1.5;

  /// Tool path boundary colors
  static const Color toolPathBoundaryColor = Colors.yellow;

  /// Safety zone colors
  static const Color safetyZoneColor = Color(0xFFFF9800); // Orange
  static const double safetyZoneOpacity = 0.3;

  /// Origin indicator colors
  static const Color originIndicatorColor = Colors.green;

  // ==================== 3D OBJECT COLORS ====================

  /// Demo cube face colors
  static const Color cubeXYFaceColor = Colors.red;
  static const Color cubeXZFaceColor = Colors.green;
  static const Color cubeYZFaceColor = Colors.blue;
  static const double cubeOpacity = 0.3;
  static const double cubeEdgeWidth = 1.0;

  // ==================== RENDERING SETTINGS ====================

  /// Line thickness settings
  static const double rapidMoveThickness = 0.5; // Thinner for rapid moves
  static const double cuttingMoveThickness = 1.0; // Thicker for cutting moves

  /// Axis rendering settings
  static const double axisLength = 50.0;
  static const double axisLabelOffset = 5.0;
  static const double axisLabelSize = 8.0;

  /// Text styling for axis labels
  static const TextStyle axisLabelStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  // ==================== THEME VARIANTS ====================

  /// Get G-code colors for specified theme variant
  static Map<String, Color> getGCodeColors(VisualizerThemeVariant variant) {
    switch (variant) {
      case VisualizerThemeVariant.classic:
        return {
          'rapid': rapidMoveColor,
          'linear': linearMoveColor,
          'clockwise': clockwiseArcColor,
          'counterclockwise': counterClockwiseArcColor,
        };

      case VisualizerThemeVariant.highContrast:
        return {
          'rapid': rapidMoveColorHighContrast,
          'linear': linearMoveColorHighContrast,
          'clockwise': clockwiseArcColorHighContrast,
          'counterclockwise': counterClockwiseArcColorHighContrast,
        };

      case VisualizerThemeVariant.colorblindSafe:
        return {
          'rapid': rapidMoveColorColorblind,
          'linear': linearMoveColorColorblind,
          'clockwise': clockwiseArcColorColorblind,
          'counterclockwise': counterClockwiseArcColorColorblind,
        };
    }
  }

  /// Get axis colors for specified color mode
  static Map<String, Color> getAxisColors(AxisColorMode colorMode) {
    switch (colorMode) {
      case AxisColorMode.fullColor:
        return {'x': xAxisColor, 'y': yAxisColor, 'z': zAxisColor};

      case AxisColorMode.grayscale:
        return {
          'x': xAxisColorGrayscale,
          'y': yAxisColorGrayscale,
          'z': zAxisColorGrayscale,
        };
    }
  }

  /// Create a theme configuration for the specified variant
  static VisualizerThemeData createTheme(VisualizerThemeVariant variant) {
    final gcodeColors = getGCodeColors(variant);

    return VisualizerThemeData(
      rapidMoveColor: gcodeColors['rapid']!,
      linearMoveColor: gcodeColors['linear']!,
      clockwiseArcColor: gcodeColors['clockwise']!,
      counterClockwiseArcColor: gcodeColors['counterclockwise']!,
      xAxisColor: xAxisColor,
      yAxisColor: yAxisColor,
      zAxisColor: zAxisColor,
      rapidMoveThickness: rapidMoveThickness,
      cuttingMoveThickness: cuttingMoveThickness,
      workAreaFillColor: workAreaFillColor,
      workAreaOpacity: workAreaOpacity,
      variant: variant,
    );
  }
}

/// Available theme variants for the visualizer
enum VisualizerThemeVariant {
  /// Classic color scheme (current default)
  classic,

  /// High contrast colors for better visibility
  highContrast,

  /// Colorblind-safe color palette
  colorblindSafe,
}

/// Axis color modes (moved from axes_factory for consistency)
enum AxisColorMode {
  /// Full color: X=red, Y=green, Z=blue
  fullColor,

  /// Grayscale: Different shades of gray
  grayscale,
}

/// Complete theme data for visualization
class VisualizerThemeData {
  final Color rapidMoveColor;
  final Color linearMoveColor;
  final Color clockwiseArcColor;
  final Color counterClockwiseArcColor;
  final Color xAxisColor;
  final Color yAxisColor;
  final Color zAxisColor;
  final double rapidMoveThickness;
  final double cuttingMoveThickness;
  final Color workAreaFillColor;
  final double workAreaOpacity;
  final VisualizerThemeVariant variant;

  const VisualizerThemeData({
    required this.rapidMoveColor,
    required this.linearMoveColor,
    required this.clockwiseArcColor,
    required this.counterClockwiseArcColor,
    required this.xAxisColor,
    required this.yAxisColor,
    required this.zAxisColor,
    required this.rapidMoveThickness,
    required this.cuttingMoveThickness,
    required this.workAreaFillColor,
    required this.workAreaOpacity,
    required this.variant,
  });

  /// Create a copy with different values
  VisualizerThemeData copyWith({
    Color? rapidMoveColor,
    Color? linearMoveColor,
    Color? clockwiseArcColor,
    Color? counterClockwiseArcColor,
    Color? xAxisColor,
    Color? yAxisColor,
    Color? zAxisColor,
    double? rapidMoveThickness,
    double? cuttingMoveThickness,
    Color? workAreaFillColor,
    double? workAreaOpacity,
    VisualizerThemeVariant? variant,
  }) {
    return VisualizerThemeData(
      rapidMoveColor: rapidMoveColor ?? this.rapidMoveColor,
      linearMoveColor: linearMoveColor ?? this.linearMoveColor,
      clockwiseArcColor: clockwiseArcColor ?? this.clockwiseArcColor,
      counterClockwiseArcColor:
          counterClockwiseArcColor ?? this.counterClockwiseArcColor,
      xAxisColor: xAxisColor ?? this.xAxisColor,
      yAxisColor: yAxisColor ?? this.yAxisColor,
      zAxisColor: zAxisColor ?? this.zAxisColor,
      rapidMoveThickness: rapidMoveThickness ?? this.rapidMoveThickness,
      cuttingMoveThickness: cuttingMoveThickness ?? this.cuttingMoveThickness,
      workAreaFillColor: workAreaFillColor ?? this.workAreaFillColor,
      workAreaOpacity: workAreaOpacity ?? this.workAreaOpacity,
      variant: variant ?? this.variant,
    );
  }
}
