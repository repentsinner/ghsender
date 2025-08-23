import 'dart:math' as math;
import 'package:vector_math/vector_math.dart' as vm;
import 'utils/logger.dart';
import 'utils/coordinate_converter.dart';

/// CameraDirector manages smooth transitions between manual and automatic camera control
/// Provides cinematic camera animation with seamless handoff to/from user input
class CameraDirector {
  static const double _userTimeoutSeconds = 8.0;
  static const double _transitionDurationSeconds = 3.0;

  // Animation parameters
  static const double _baseElevationMin = 15.0;
  static const double _baseElevationMax = 40.0;
  static const double _baseAzimuthMin = 35.0;
  static const double _baseAzimuthMax = 180.0;
  static const double _baseDistanceMin = 200.0;
  static const double _baseDistanceMax = 400.0;

  // Current state
  late DateTime _animationStartTime;
  DateTime? _lastUserInteraction;

  // Animation configuration
  late double _elevationCycleDuration;
  late double _azimuthCycleDuration;
  late double _distanceCycleDuration;

  late double _elevationRangeMin;
  late double _elevationRangeMax;
  late double _azimuthRangeMin;
  late double _azimuthRangeMax;
  late double _distanceRangeMin;
  late double _distanceRangeMax;

  // Phase offsets to start animation cycles from user's position
  double _elevationPhaseOffset = 0.0;
  double _azimuthPhaseOffset = 0.0;
  double _distancePhaseOffset = 0.0;

  // Control states
  bool _isAutoMode = true; // Start in auto mode by default
  bool _isTransitioning = false;

  // Manual control state
  double _manualRotationX = 30.0 * math.pi / 180.0; // 30° elevation in radians
  double _manualRotationY = 0.0; // 0° azimuth
  double _manualDistance = 384.2; // Default from initial camera setup

  // Camera orbit parameters (from scene data)
  vm.Vector3 _orbitTarget = vm.Vector3.zero(); // Point the camera orbits around

  // Transition state
  DateTime? _transitionStartTime;
  double _transitionFromRotationX = 0.0;
  double _transitionFromRotationY = 0.0;
  double _transitionFromDistance = 0.0;

  CameraDirector() {
    _animationStartTime = DateTime.now();
    _randomizeAnimationRanges();
    AppLogger.info('CameraDirector initialized');
  }

  /// Initialize the camera orbit target from scene data
  void initializeFromSceneData(vm.Vector3 cameraTarget) {
    _orbitTarget = cameraTarget;
    AppLogger.info('CameraDirector: Orbit target set to $_orbitTarget');
  }

  /// Update camera target dynamically based on job envelope (G-code bounds) and machine position
  /// When both are available, sets the target to the midpoint between them
  /// 
  /// Note: This method accepts CNC coordinates and automatically converts them to
  /// display coordinates for the camera system.
  void updateDynamicTarget({
    vm.Vector3? jobEnvelopeCentroid,
    vm.Vector3? machinePosition,
  }) {
    vm.Vector3? newCncTarget;
    
    if (jobEnvelopeCentroid != null && machinePosition != null) {
      // Calculate midpoint between job envelope centroid and machine position (in CNC space)
      newCncTarget = (jobEnvelopeCentroid + machinePosition) * 0.5;
    } else if (jobEnvelopeCentroid != null) {
      // Only job envelope available - use its centroid
      newCncTarget = jobEnvelopeCentroid;
    } else if (machinePosition != null) {
      // Only machine position available - use it as target
      newCncTarget = machinePosition;
    }
    // If neither available, keep current target unchanged
    
    if (newCncTarget != null) {
      // Convert CNC coordinates to display coordinates for camera system
      final displayTarget = CoordinateConverter.cncCameraTargetToDisplay(newCncTarget);
      _orbitTarget = displayTarget;
    }
  }

  /// Start automatic camera animation
  void startAutoMode() {
    if (_isAutoMode) return;

    _isAutoMode = true;
    _isTransitioning = true;
    _transitionStartTime = DateTime.now();

    // Store current manual position as transition start point
    _transitionFromRotationX = _manualRotationX;
    _transitionFromRotationY = _manualRotationY;
    _transitionFromDistance = _manualDistance;

    // Create new animation cycle centered around user's last position
    _createAnimationCycleFromPosition(
      _manualRotationX,
      _manualRotationY,
      _manualDistance,
    );

    AppLogger.info(
      'CameraDirector: Starting auto mode with smooth transition from user position',
    );
  }

  /// Stop automatic camera animation
  void stopAutoMode() {
    if (!_isAutoMode) return;

    // Capture current auto position as the starting point for manual control
    final currentTime = DateTime.now();
    final currentAutoPos = _calculateAutomaticPosition(currentTime);

    // Apply elevation limits when capturing auto position for manual mode
    _manualRotationX = math.max(
      -math.pi * 0.4, // About -72 degrees (don't go below horizon too much)
      math.min(
        math.pi * 0.4,
        currentAutoPos.rotationX,
      ), // About +72 degrees (don't go too high)
    );
    // Normalize azimuth when transitioning from auto to manual
    _manualRotationY = _normalizeAzimuth(currentAutoPos.rotationY);
    _manualDistance = currentAutoPos.distance;

    _isAutoMode = false;
    _isTransitioning = false;
    _lastUserInteraction = currentTime;

    AppLogger.info('CameraDirector: Switched to manual mode');
  }

  /// Update manual camera position (from user input)
  void updateManualPosition(double rotationX, double rotationY) {
    // Apply elevation limits immediately to prevent camera from going underground or flipping
    _manualRotationX = math.max(
      -math.pi * 0.4, // About -72 degrees (don't go below horizon too much)
      math.min(
        math.pi * 0.4,
        rotationX,
      ), // About +72 degrees (don't go too high)
    );

    // Normalize azimuth angle to 0-360 degrees (0 to 2π radians) with seamless wrapping
    _manualRotationY = _normalizeAzimuth(rotationY);
    _lastUserInteraction = DateTime.now();

    // If we were in auto mode, switch to manual
    if (_isAutoMode) {
      stopAutoMode();
    }
  }

  /// Get current camera position, handling transitions and timeouts
  CameraPosition getCameraPosition(DateTime currentTime) {
    // Check if we should resume auto mode after user timeout
    if (!_isAutoMode && _lastUserInteraction != null) {
      final timeSinceLastInput =
          currentTime.difference(_lastUserInteraction!).inMilliseconds / 1000.0;
      if (timeSinceLastInput >= _userTimeoutSeconds) {
        startAutoMode();
      }
    }

    if (!_isAutoMode) {
      // Manual mode - return current manual position
      return CameraPosition(
        rotationX: _manualRotationX,
        rotationY: _manualRotationY,
        distance: _manualDistance,
      );
    }

    // Auto mode - calculate animated position
    final autoPosition = _calculateAutomaticPosition(currentTime);

    if (!_isTransitioning) {
      // Pure auto mode
      return autoPosition;
    }

    // Transitioning from manual to auto
    final transitionProgress = _calculateTransitionProgress(currentTime);

    if (transitionProgress >= 1.0) {
      // Transition complete
      _isTransitioning = false;
      return autoPosition;
    }

    // Interpolate between manual and auto positions
    final t = _easeInOutCubic(transitionProgress);
    return CameraPosition(
      rotationX: _lerp(_transitionFromRotationX, autoPosition.rotationX, t),
      rotationY: _lerp(_transitionFromRotationY, autoPosition.rotationY, t),
      distance: _lerp(_transitionFromDistance, autoPosition.distance, t),
    );
  }

  /// Calculate automatic camera position using cinematic animation
  CameraPosition _calculateAutomaticPosition(DateTime currentTime) {
    final elapsed =
        currentTime.difference(_animationStartTime).inMilliseconds / 1000.0;

    // Calculate elevation animation (true pendulum motion with phase offset)
    final elevationPhase =
        2 * math.pi * elapsed / _elevationCycleDuration + _elevationPhaseOffset;
    final elevationOscillation = math.sin(elevationPhase); // -1 to +1
    final elevationMid = (_elevationRangeMin + _elevationRangeMax) / 2.0;
    final elevationAmplitude = (_elevationRangeMax - _elevationRangeMin) / 2.0;
    final targetElevation =
        elevationMid + elevationAmplitude * elevationOscillation;

    // Calculate azimuth animation (true pendulum motion with phase offset)
    final azimuthPhase =
        2 * math.pi * elapsed / _azimuthCycleDuration + _azimuthPhaseOffset;
    final azimuthOscillation = math.sin(azimuthPhase); // -1 to +1
    final azimuthMid = (_azimuthRangeMin + _azimuthRangeMax) / 2.0;
    final azimuthAmplitude = (_azimuthRangeMax - _azimuthRangeMin) / 2.0;
    final targetAzimuth = azimuthMid + azimuthAmplitude * azimuthOscillation;

    // Calculate distance animation (true pendulum motion with phase offset)
    final distancePhase =
        2 * math.pi * elapsed / _distanceCycleDuration + _distancePhaseOffset;
    final distanceOscillation = math.sin(distancePhase); // -1 to +1
    final distanceMid = (_distanceRangeMin + _distanceRangeMax) / 2.0;
    final distanceAmplitude = (_distanceRangeMax - _distanceRangeMin) / 2.0;
    final targetDistance =
        distanceMid + distanceAmplitude * distanceOscillation;

    return CameraPosition(
      rotationX: targetElevation * math.pi / 180.0, // Convert to radians
      rotationY: targetAzimuth * math.pi / 180.0, // Convert to radians
      distance: targetDistance,
    );
  }

  /// Calculate transition progress (0.0 to 1.0)
  double _calculateTransitionProgress(DateTime currentTime) {
    if (_transitionStartTime == null) return 1.0;

    final elapsed =
        currentTime.difference(_transitionStartTime!).inMilliseconds / 1000.0;
    return math.min(elapsed / _transitionDurationSeconds, 1.0);
  }

  /// Smooth easing function for transitions
  double _easeInOutCubic(double t) {
    return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
  }

  /// Linear interpolation
  double _lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  /// Normalize azimuth angle to 0-360 degrees (0 to 2π radians) with seamless wrapping
  double _normalizeAzimuth(double azimuthRadians) {
    // Convert to 0-2π range using modulo operation
    double normalized = azimuthRadians % (2 * math.pi);

    // Handle negative angles by adding 2π to get equivalent positive angle
    if (normalized < 0) {
      normalized += 2 * math.pi;
    }

    return normalized;
  }

  /// Create animation cycle centered around a specific position
  void _createAnimationCycleFromPosition(
    double centerElevation,
    double centerAzimuth,
    double centerDistance,
  ) {
    final random = math.Random();

    // Convert center position from radians to degrees for easier calculations
    final centerElevationDeg = centerElevation * 180 / math.pi;
    final centerAzimuthDeg = centerAzimuth * 180 / math.pi;

    // Randomize cycle durations (same as before)
    _elevationCycleDuration = 25.0 + random.nextDouble() * 30.0;
    _azimuthCycleDuration = 45.0 + random.nextDouble() * 30.0;
    _distanceCycleDuration = 25.0 + random.nextDouble() * 30.0;

    // Create animation ranges centered around user's position
    // but gently constrained to valid limits

    // Elevation: Create range around center, but ensure it's within global limits
    double elevationRange =
        15.0 + random.nextDouble() * 10.0; // 15-25 degree range
    double targetElevationMin = centerElevationDeg - elevationRange / 2;
    double targetElevationMax = centerElevationDeg + elevationRange / 2;

    // Gently constrain elevation to valid limits (-72° to +72°)
    final elevationGlobalMin = -72.0;
    final elevationGlobalMax = 72.0;

    if (targetElevationMin < elevationGlobalMin) {
      final shift = elevationGlobalMin - targetElevationMin;
      targetElevationMin = elevationGlobalMin;
      targetElevationMax = math.min(
        targetElevationMax + shift,
        elevationGlobalMax,
      );
    }
    if (targetElevationMax > elevationGlobalMax) {
      final shift = targetElevationMax - elevationGlobalMax;
      targetElevationMax = elevationGlobalMax;
      targetElevationMin = math.max(
        targetElevationMin - shift,
        elevationGlobalMin,
      );
    }

    _elevationRangeMin = targetElevationMin;
    _elevationRangeMax = targetElevationMax;

    // Azimuth: Create range around center (azimuth has no global limits, wraps around)
    double azimuthRange =
        60.0 + random.nextDouble() * 120.0; // 60-180 degree range
    _azimuthRangeMin = centerAzimuthDeg - azimuthRange / 2;
    _azimuthRangeMax = centerAzimuthDeg + azimuthRange / 2;

    // Distance: Create range around center, constrained to reasonable limits
    double distanceRange = 100.0 + random.nextDouble() * 100.0; // 100-200 range
    double targetDistanceMin = centerDistance - distanceRange / 2;
    double targetDistanceMax = centerDistance + distanceRange / 2;

    // Constrain distance to global limits
    final distanceGlobalMin = _baseDistanceMin;
    final distanceGlobalMax = _baseDistanceMax;

    if (targetDistanceMin < distanceGlobalMin) {
      final shift = distanceGlobalMin - targetDistanceMin;
      targetDistanceMin = distanceGlobalMin;
      targetDistanceMax = math.min(
        targetDistanceMax + shift,
        distanceGlobalMax,
      );
    }
    if (targetDistanceMax > distanceGlobalMax) {
      final shift = targetDistanceMax - distanceGlobalMax;
      targetDistanceMax = distanceGlobalMax;
      targetDistanceMin = math.max(
        targetDistanceMin - shift,
        distanceGlobalMin,
      );
    }

    _distanceRangeMin = targetDistanceMin;
    _distanceRangeMax = targetDistanceMax;

    // Calculate phase offsets to start animation from user's current position
    // This ensures smooth transition instead of jarring jumps

    // For elevation: find the phase that would produce the current elevation
    final elevationMid = (_elevationRangeMin + _elevationRangeMax) / 2.0;
    final elevationAmplitude = (_elevationRangeMax - _elevationRangeMin) / 2.0;
    if (elevationAmplitude > 0) {
      final normalizedElevation =
          (centerElevationDeg - elevationMid) / elevationAmplitude;
      _elevationPhaseOffset = math.asin(
        math.max(-1.0, math.min(1.0, normalizedElevation)),
      );
    } else {
      _elevationPhaseOffset = 0.0;
    }

    // For azimuth: find the phase that would produce the current azimuth
    final azimuthMid = (_azimuthRangeMin + _azimuthRangeMax) / 2.0;
    final azimuthAmplitude = (_azimuthRangeMax - _azimuthRangeMin) / 2.0;
    if (azimuthAmplitude > 0) {
      final normalizedAzimuth =
          (centerAzimuthDeg - azimuthMid) / azimuthAmplitude;
      _azimuthPhaseOffset = math.asin(
        math.max(-1.0, math.min(1.0, normalizedAzimuth)),
      );
    } else {
      _azimuthPhaseOffset = 0.0;
    }

    // For distance: find the phase that would produce the current distance
    final distanceMid = (_distanceRangeMin + _distanceRangeMax) / 2.0;
    final distanceAmplitude = (_distanceRangeMax - _distanceRangeMin) / 2.0;
    if (distanceAmplitude > 0) {
      final normalizedDistance =
          (centerDistance - distanceMid) / distanceAmplitude;
      _distancePhaseOffset = math.asin(
        math.max(-1.0, math.min(1.0, normalizedDistance)),
      );
    } else {
      _distancePhaseOffset = 0.0;
    }

    // Reset animation start time to current time for smooth continuation
    _animationStartTime = DateTime.now();

    AppLogger.info(
      'CameraDirector: Created animation cycle centered on user position',
    );
    AppLogger.info(
      '  Elevation: ${_elevationRangeMin.toStringAsFixed(1)}° - ${_elevationRangeMax.toStringAsFixed(1)}° (${_elevationCycleDuration.toStringAsFixed(1)}s)',
    );
    AppLogger.info(
      '  Azimuth: ${_azimuthRangeMin.toStringAsFixed(1)}° - ${_azimuthRangeMax.toStringAsFixed(1)}° (${_azimuthCycleDuration.toStringAsFixed(1)}s)',
    );
    AppLogger.info(
      '  Distance: ${_distanceRangeMin.toStringAsFixed(1)} - ${_distanceRangeMax.toStringAsFixed(1)} (${_distanceCycleDuration.toStringAsFixed(1)}s)',
    );
  }

  /// Randomize animation ranges for variety
  void _randomizeAnimationRanges() {
    final random = math.Random();

    // Randomize cycle durations (25-55s elevation, 45-75s azimuth, 25-55s distance)
    _elevationCycleDuration = 25.0 + random.nextDouble() * 30.0;
    _azimuthCycleDuration = 45.0 + random.nextDouble() * 30.0;
    _distanceCycleDuration = 25.0 + random.nextDouble() * 30.0;

    // Randomize ranges within base limits
    final elevationRange = _baseElevationMax - _baseElevationMin;
    final azimuthRange = _baseAzimuthMax - _baseAzimuthMin;
    final distanceRange = _baseDistanceMax - _baseDistanceMin;

    // Create random sub-ranges (use 60-100% of full range)
    final elevationSubRange =
        elevationRange * (0.6 + random.nextDouble() * 0.4);
    final azimuthSubRange = azimuthRange * (0.6 + random.nextDouble() * 0.4);
    final distanceSubRange = distanceRange * (0.6 + random.nextDouble() * 0.4);

    // Position the sub-range randomly within the full range
    _elevationRangeMin =
        _baseElevationMin +
        random.nextDouble() * (elevationRange - elevationSubRange);
    _elevationRangeMax = _elevationRangeMin + elevationSubRange;

    _azimuthRangeMin =
        _baseAzimuthMin +
        random.nextDouble() * (azimuthRange - azimuthSubRange);
    _azimuthRangeMax = _azimuthRangeMin + azimuthSubRange;

    _distanceRangeMin =
        _baseDistanceMin +
        random.nextDouble() * (distanceRange - distanceSubRange);
    _distanceRangeMax = _distanceRangeMin + distanceSubRange;

    // Reset phase offsets for initial random animation
    _elevationPhaseOffset = 0.0;
    _azimuthPhaseOffset = 0.0;
    _distancePhaseOffset = 0.0;

    AppLogger.info('CameraDirector: Animation ranges randomized');
    AppLogger.info(
      '  Elevation: ${_elevationRangeMin.toStringAsFixed(1)}° - ${_elevationRangeMax.toStringAsFixed(1)}° (${_elevationCycleDuration.toStringAsFixed(1)}s)',
    );
    AppLogger.info(
      '  Azimuth: ${_azimuthRangeMin.toStringAsFixed(1)}° - ${_azimuthRangeMax.toStringAsFixed(1)}° (${_azimuthCycleDuration.toStringAsFixed(1)}s)',
    );
    AppLogger.info(
      '  Distance: ${_distanceRangeMin.toStringAsFixed(1)} - ${_distanceRangeMax.toStringAsFixed(1)} (${_distanceCycleDuration.toStringAsFixed(1)}s)',
    );
  }

  /// Update camera distance (for zoom controls)
  void updateManualDistance(double distance) {
    _manualDistance = distance;
    _lastUserInteraction = DateTime.now();

    if (_isAutoMode) {
      stopAutoMode();
    }
  }

  /// Process pan gesture input and update camera position
  /// Takes screen-space delta and converts to camera rotation
  void processPanGesture(double deltaX, double deltaY) {
    // Get current camera position for relative updates
    final currentTime = DateTime.now();
    final currentCameraPos = getCameraPosition(currentTime);

    // Convert screen-space delta to rotation delta
    // Sensitivity factor: 0.01 radians per pixel seems to work well
    const double rotationSensitivity = 0.01;

    // Apply delta to current position
    final newRotationX =
        currentCameraPos.rotationX + (deltaY * rotationSensitivity);
    final newRotationY =
        currentCameraPos.rotationY + (deltaX * rotationSensitivity);

    // Update camera position through existing method (handles limits and normalization)
    updateManualPosition(newRotationX, newRotationY);

    // Maintain current distance (no zoom from pan gestures)
    updateManualDistance(currentCameraPos.distance);
  }

  /// Process pinch-to-zoom gesture input and update camera distance
  /// Takes scale factor from gesture (1.0 = no change, >1.0 = zoom out, <1.0 = zoom in)
  void processPinchZoom(double scaleFactor) {
    // Get current camera position
    final currentTime = DateTime.now();
    final currentCameraPos = getCameraPosition(currentTime);

    // Convert scale factor to distance multiplier
    // Invert the scale so pinch-in zooms in (decreases distance)
    const double zoomSensitivity = 2.0; // Adjust sensitivity
    final double zoomMultiplier = 1.0 / math.pow(scaleFactor, zoomSensitivity);

    // Apply zoom to current distance
    final double newDistance = currentCameraPos.distance * zoomMultiplier;

    // Constrain distance to reasonable limits
    final double constrainedDistance = _constrainDistance(newDistance);

    // Update camera position maintaining rotation
    updateManualPosition(
      currentCameraPos.rotationX,
      currentCameraPos.rotationY,
    );
    updateManualDistance(constrainedDistance);
  }

  /// Process mouse scroll wheel input and update camera distance
  /// Takes scroll delta (positive = scroll up/zoom in, negative = scroll down/zoom out)
  void processScrollZoom(double scrollDelta) {
    // Get current camera position
    final currentTime = DateTime.now();
    final currentCameraPos = getCameraPosition(currentTime);

    // Convert scroll delta to distance change
    // Positive scrollDelta = scroll up = zoom in (decrease distance)
    // Negative scrollDelta = scroll down = zoom out (increase distance)
    const double scrollSensitivity = 0.1; // Adjust for comfortable scrolling
    final double distanceChange = -scrollDelta * scrollSensitivity;
    final double newDistance = currentCameraPos.distance + distanceChange;

    // Constrain distance to reasonable limits
    final double constrainedDistance = _constrainDistance(newDistance);

    // Update camera position maintaining rotation
    updateManualPosition(
      currentCameraPos.rotationX,
      currentCameraPos.rotationY,
    );
    updateManualDistance(constrainedDistance);
  }

  /// Constrain camera distance to reasonable limits
  double _constrainDistance(double distance) {
    // Define reasonable zoom limits
    const double minDistance = 50.0; // Close zoom limit
    const double maxDistance = 1000.0; // Far zoom limit

    return math.max(minDistance, math.min(maxDistance, distance));
  }

  /// Get current mode for debugging
  String get currentMode {
    if (_isTransitioning) return 'Transitioning to Auto';
    return _isAutoMode ? 'Auto' : 'Manual';
  }

  /// Check if currently in auto mode
  bool get isAutoMode => _isAutoMode;

  /// Toggle between auto and manual mode
  void toggleMode() {
    if (_isAutoMode) {
      stopAutoMode();
    } else {
      startAutoMode();
    }
  }

  /// Get complete camera state with 3D position and target vectors
  CameraState getCameraState(DateTime currentTime) {
    // Get camera parameters from existing logic
    final cameraPosition = getCameraPosition(currentTime);

    // Convert spherical coordinates to 3D position
    final position = _calculateCameraPosition3D(
      cameraPosition.rotationX,
      cameraPosition.rotationY,
      cameraPosition.distance,
    );

    return CameraState(
      position: position,
      target: _orbitTarget,
      azimuthDegrees: cameraPosition.rotationY * 180 / math.pi,
      elevationDegrees: cameraPosition.rotationX * 180 / math.pi,
      distance: cameraPosition.distance,
    );
  }

  /// Calculate 3D camera position from spherical coordinates
  vm.Vector3 _calculateCameraPosition3D(
    double rotationX,
    double rotationY,
    double distance,
  ) {
    // Convert rotation inputs to spherical coordinates for Z-up system
    final azimuth = rotationY; // Horizontal rotation around Z axis
    final elevation =
        rotationX; // Elevation limits are now applied in updateManualPosition()

    // Convert to spherical coordinates in Z-up system:
    // - azimuth: rotation around Z axis (0 = +X direction)
    // - elevation: angle from XY plane (positive = above horizon)
    final x = distance * math.cos(elevation) * math.cos(azimuth);
    final y = distance * math.cos(elevation) * math.sin(azimuth);
    final z = distance * math.sin(elevation);

    // Return camera position relative to orbit target
    return _orbitTarget + vm.Vector3(x, y, z);
  }
}

/// Camera position data structure
class CameraPosition {
  final double rotationX;
  final double rotationY;
  final double distance;

  CameraPosition({
    required this.rotationX,
    required this.rotationY,
    required this.distance,
  });
}

/// Complete camera state with position and target vectors
class CameraState {
  final vm.Vector3 position;
  final vm.Vector3 target;
  final double azimuthDegrees; // For UI display
  final double elevationDegrees; // For UI display
  final double distance; // For UI display

  CameraState({
    required this.position,
    required this.target,
    required this.azimuthDegrees,
    required this.elevationDegrees,
    required this.distance,
  });
}
