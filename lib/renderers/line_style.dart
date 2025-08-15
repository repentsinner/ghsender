import 'package:flutter/material.dart';

/// Application-agnostic line styling for high-quality GPU rendering
/// Provides fine-grained control over line appearance and anti-aliasing
class LineStyle {
  /// Base color of the line
  final Color color;

  /// Line width in world units
  final double width;

  /// Anti-aliasing sharpness (0.0 = very soft, 1.0 = very sharp)
  /// Controls how quickly the line fades at edges
  final double sharpness;

  /// Opacity multiplier for the entire line
  final double opacity;

  /// Distance-based width scaling factor
  /// Allows lines to appear thinner/thicker based on view distance
  final double distanceScale;

  /// Whether this line should use enhanced anti-aliasing
  final bool smoothed;

  const LineStyle({
    required this.color,
    this.width = 1.0,
    this.sharpness = 0.5,
    this.opacity = 1.0,
    this.distanceScale = 0.0,
    this.smoothed = true,
  });

  /// Create a sharp, precise line style
  const LineStyle.sharp({
    required Color color,
    double width = 1.0,
    double opacity = 1.0,
  }) : this(
         color: color,
         width: width,
         sharpness: 0.8,
         opacity: opacity,
         distanceScale: 0.0,
         smoothed: true,
       );

  /// Create a soft, subtle line style
  const LineStyle.soft({
    required Color color,
    double width = 1.0,
    double opacity = 0.7,
  }) : this(
         color: color,
         width: width,
         sharpness: 0.2,
         opacity: opacity,
         distanceScale: 0.0,
         smoothed: true,
       );

  /// Create a distance-adaptive line style
  const LineStyle.adaptive({
    required Color color,
    double width = 1.0,
    double sharpness = 0.5,
    double distanceScale = 0.001,
  }) : this(
         color: color,
         width: width,
         sharpness: sharpness,
         opacity: 1.0,
         distanceScale: distanceScale,
         smoothed: true,
       );

  /// Create a basic line style without anti-aliasing (for performance)
  const LineStyle.basic({
    required Color color,
    double width = 1.0,
    double opacity = 1.0,
  }) : this(
         color: color,
         width: width,
         sharpness: 1.0,
         opacity: opacity,
         distanceScale: 0.0,
         smoothed: false,
       );

  /// Convert color to normalized float components
  List<double> get colorComponents {
    return [
      color.r,
      color.g,
      color.b,
      color.a * opacity,
    ];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LineStyle &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          width == other.width &&
          sharpness == other.sharpness &&
          opacity == other.opacity &&
          distanceScale == other.distanceScale &&
          smoothed == other.smoothed;

  @override
  int get hashCode =>
      Object.hash(color, width, sharpness, opacity, distanceScale, smoothed);

  @override
  String toString() =>
      'LineStyle('
      'color: $color, '
      'width: $width, '
      'sharpness: $sharpness, '
      'opacity: $opacity, '
      'smoothed: $smoothed'
      ')';
}

/// Predefined line styles for common use cases
class LineStyles {
  /// Precise, sharp lines for technical drawings
  static const technical = LineStyle.sharp(color: Colors.white, width: 1.0);

  /// Soft, subtle lines for guides or secondary content
  static const guide = LineStyle.soft(color: Colors.grey, width: 0.5);

  /// High-contrast lines for primary content
  static const primary = LineStyle.sharp(color: Colors.blue, width: 1.5);

  /// Secondary lines with medium contrast
  static const secondary = LineStyle(
    color: Colors.green,
    width: 1.0,
    sharpness: 0.5,
    opacity: 0.8,
  );

  /// Warning or alert lines
  static const warning = LineStyle.sharp(color: Colors.orange, width: 1.2);

  /// Error or danger lines
  static const error = LineStyle.sharp(color: Colors.red, width: 1.5);

  /// Disabled or inactive lines
  static const disabled = LineStyle(
    color: Colors.grey,
    width: 0.8,
    sharpness: 0.3,
    opacity: 0.4,
  );
}
