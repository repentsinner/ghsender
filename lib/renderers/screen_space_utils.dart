import 'dart:math' as math;
import 'package:vector_math/vector_math.dart' as vm;
import '../utils/coordinate_converter.dart';

/// Utility class for screen-space calculations shared between renderers
/// 
/// Provides methods for converting between pixel sizes and world sizes
/// based on camera parameters, similar to how Three.js handles screen-space calculations
class ScreenSpaceUtils {
  
  /// Convert a target pixel size to world size based on camera distance and field of view
  /// 
  /// This is the key formula for maintaining constant screen-space size:
  /// worldSize = pixelSize * (2 * cameraDistance * tan(fov/2)) / viewportHeight
  /// 
  /// Parameters:
  /// - [targetPixelSize]: Desired size in pixels (e.g., 24px)
  /// - [cameraDistance]: Distance from camera to object
  /// - [fieldOfViewRadians]: Camera field of view in radians
  /// - [screenResolution]: Viewport size (width, height)
  /// 
  /// Returns the world size needed to achieve the target pixel size
  static double pixelSizeToWorldSize(
    double targetPixelSize,
    double cameraDistance,
    double fieldOfViewRadians,
    vm.Vector2 screenResolution,
  ) {
    // Calculate the world height that the camera can see at the given distance
    final worldHeightAtDistance = 2.0 * cameraDistance * math.tan(fieldOfViewRadians / 2.0);
    
    // Convert pixel size to world size based on viewport height
    final worldSize = targetPixelSize * worldHeightAtDistance / screenResolution.y;
    
    return worldSize;
  }
  
  /// Convert pixel coordinates to Normalized Device Coordinates (NDC)
  /// 
  /// NDC range is [-1, 1] for both X and Y axes
  /// Parameters:
  /// - [pixelSize]: Size in pixels
  /// - [screenResolution]: Viewport size (width, height)
  /// 
  /// Returns NDC size (same scale for both width and height)
  static double pixelToNDC(double pixelSize, vm.Vector2 screenResolution) {
    // Use viewport height as reference for consistent scaling
    return 2.0 * pixelSize / screenResolution.y;
  }
  
  /// Calculate camera distance to a 3D point
  /// 
  /// Parameters:
  /// - [cameraPosition]: Camera position in world space
  /// - [targetPosition]: Target position in world space
  /// 
  /// Returns the distance between camera and target
  static double calculateCameraDistance(
    vm.Vector3 cameraPosition,
    vm.Vector3 targetPosition,
  ) {
    return (cameraPosition - targetPosition).length;
  }
  
  /// Calculate camera distance with optional coordinate conversion
  /// 
  /// This method handles the coordinate system transformation if needed.
  /// When [convertCoordinates] is true, it assumes the target position is in
  /// CNC coordinates and converts them to display coordinates before calculation.
  /// 
  /// Parameters:
  /// - [cameraPosition]: Camera position in display coordinates
  /// - [targetPosition]: Target position (CNC or display coordinates)
  /// - [convertCoordinates]: Whether to convert target from CNC to display coordinates
  /// 
  /// Returns the distance between camera and target in display coordinate system
  static double calculateCameraDistanceWithConversion(
    vm.Vector3 cameraPosition,
    vm.Vector3 targetPosition, {
    bool convertCoordinates = false,
  }) {
    vm.Vector3 displayTargetPosition = targetPosition;
    
    if (convertCoordinates) {
      // Convert from CNC coordinates to display coordinates
      displayTargetPosition = CoordinateConverter.cncToDisplay(targetPosition);
    }
    
    return calculateCameraDistance(cameraPosition, displayTargetPosition);
  }
  
  /// Create a billboard orientation matrix that faces the camera
  /// 
  /// This creates a rotation matrix that aligns the billboard with the camera's
  /// view plane, ensuring it always faces the camera regardless of camera orientation.
  /// 
  /// Parameters:
  /// - [billboardPosition]: Position of the billboard in world space
  /// - [cameraPosition]: Position of the camera in world space
  /// - [cameraUpVector]: Camera's up vector (usually Z-up for CNC: [0,0,1])
  /// 
  /// Returns a rotation matrix for billboard orientation
  static vm.Matrix4 calculateBillboardOrientation(
    vm.Vector3 billboardPosition,
    vm.Vector3 cameraPosition,
    vm.Vector3 cameraUpVector,
  ) {
    // Calculate direction from billboard to camera
    final toCamera = (cameraPosition - billboardPosition).normalized();
    
    // Avoid gimbal lock when camera is directly above/below billboard
    const double gimbalThreshold = 0.99;
    if (toCamera.dot(cameraUpVector).abs() > gimbalThreshold) {
      // Use alternative up vector when near gimbal lock
      final alternativeUp = vm.Vector3(1, 0, 0); // X-axis as backup
      final right = alternativeUp.cross(toCamera).normalized();
      final up = toCamera.cross(right).normalized();
      
      return _createRotationMatrix(right, up, -toCamera);
    }
    
    // Standard billboard calculation
    final right = cameraUpVector.cross(toCamera).normalized();
    final up = toCamera.cross(right).normalized();
    
    return _createRotationMatrix(right, up, -toCamera);
  }
  
  /// Create a rotation matrix from orthogonal basis vectors
  /// 
  /// Parameters:
  /// - [right]: Right vector (X-axis)
  /// - [up]: Up vector (Y-axis) 
  /// - [forward]: Forward vector (Z-axis)
  /// 
  /// Returns a rotation matrix with the specified orientation
  static vm.Matrix4 _createRotationMatrix(
    vm.Vector3 right,
    vm.Vector3 up,
    vm.Vector3 forward,
  ) {
    final rotationMatrix = vm.Matrix4.identity();
    
    // Set rotation matrix columns (column-major order)
    rotationMatrix.setColumn(0, vm.Vector4(right.x, right.y, right.z, 0.0));
    rotationMatrix.setColumn(1, vm.Vector4(up.x, up.y, up.z, 0.0));
    rotationMatrix.setColumn(2, vm.Vector4(forward.x, forward.y, forward.z, 0.0));
    rotationMatrix.setColumn(3, vm.Vector4(0.0, 0.0, 0.0, 1.0));
    
    return rotationMatrix;
  }
  
  /// Extension method to make Vector3 distance calculations more convenient
}

/// Extension methods for Vector3 to add screen-space utility methods
extension Vector3ScreenSpace on vm.Vector3 {
  /// Calculate distance to another point with optional coordinate conversion
  /// 
  /// When [convertOther] is true, assumes [other] is in CNC coordinates
  /// and converts it to display coordinates before calculating distance.
  /// This vector is assumed to already be in display coordinates.
  double distanceToWithConversion(vm.Vector3 other, {bool convertOther = false}) {
    return ScreenSpaceUtils.calculateCameraDistanceWithConversion(
      this,
      other,
      convertCoordinates: convertOther,
    );
  }
  
  /// Calculate screen-space world size needed for a target pixel size
  /// 
  /// This is a convenience method that combines distance calculation and
  /// pixel-to-world-size conversion in one call.
  /// 
  /// Parameters:
  /// - [targetPosition]: Position to calculate distance to
  /// - [targetPixelSize]: Desired size in pixels
  /// - [fieldOfViewRadians]: Camera field of view in radians
  /// - [screenResolution]: Viewport size
  /// - [convertTargetCoordinates]: Whether target position is in CNC coordinates
  /// 
  /// Returns the world size needed to achieve target pixel size
  double calculateScreenSpaceWorldSize(
    vm.Vector3 targetPosition,
    double targetPixelSize,
    double fieldOfViewRadians,
    vm.Vector2 screenResolution, {
    bool convertTargetCoordinates = false,
  }) {
    final distance = distanceToWithConversion(
      targetPosition,
      convertOther: convertTargetCoordinates,
    );
    
    return ScreenSpaceUtils.pixelSizeToWorldSize(
      targetPixelSize,
      distance,
      fieldOfViewRadians,
      screenResolution,
    );
  }
}