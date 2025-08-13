import 'dart:math' as math;
import 'package:vector_math/vector_math.dart' as vm;
import 'utils/logger.dart';

/// CameraDirector manages smooth transitions between manual and automatic camera control
/// Provides cinematic camera animation with seamless handoff to/from user input
class CameraDirector {
  static const double _userTimeoutSeconds = 8.0;
  static const double _transitionDurationSeconds = 3.0;
  
  // Animation parameters
  static const double _baseElevationMin = 15.0;
  static const double _baseElevationMax = 40.0;
  static const double _baseAzimuthMin = -135.0;
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
  
  // Control states
  bool _isAutoMode = true;  // Start in auto mode by default
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
    
    AppLogger.info('CameraDirector: Starting auto mode with smooth transition');
  }
  
  /// Stop automatic camera animation  
  void stopAutoMode() {
    if (!_isAutoMode) return;
    
    // Capture current auto position as the starting point for manual control
    final currentTime = DateTime.now();
    final currentAutoPos = _calculateAutomaticPosition(currentTime);
    _manualRotationX = currentAutoPos.rotationX;
    _manualRotationY = currentAutoPos.rotationY;
    _manualDistance = currentAutoPos.distance;
    
    _isAutoMode = false;
    _isTransitioning = false;
    _lastUserInteraction = currentTime;
    
    AppLogger.info('CameraDirector: Switched to manual mode');
  }
  
  /// Update manual camera position (from user input)
  void updateManualPosition(double rotationX, double rotationY) {
    _manualRotationX = rotationX;
    _manualRotationY = rotationY;
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
      final timeSinceLastInput = currentTime.difference(_lastUserInteraction!).inMilliseconds / 1000.0;
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
    final elapsed = currentTime.difference(_animationStartTime).inMilliseconds / 1000.0;
    
    // Calculate elevation animation (true pendulum motion)
    final elevationPhase = 2 * math.pi * elapsed / _elevationCycleDuration;
    final elevationOscillation = math.sin(elevationPhase); // -1 to +1
    final elevationMid = (_elevationRangeMin + _elevationRangeMax) / 2.0;
    final elevationAmplitude = (_elevationRangeMax - _elevationRangeMin) / 2.0;
    final targetElevation = elevationMid + elevationAmplitude * elevationOscillation;
    
    // Calculate azimuth animation (true pendulum motion)  
    final azimuthPhase = 2 * math.pi * elapsed / _azimuthCycleDuration;
    final azimuthOscillation = math.sin(azimuthPhase); // -1 to +1
    final azimuthMid = (_azimuthRangeMin + _azimuthRangeMax) / 2.0;
    final azimuthAmplitude = (_azimuthRangeMax - _azimuthRangeMin) / 2.0;
    final targetAzimuth = azimuthMid + azimuthAmplitude * azimuthOscillation;
    
    // Calculate distance animation (true pendulum motion)
    final distancePhase = 2 * math.pi * elapsed / _distanceCycleDuration;
    final distanceOscillation = math.sin(distancePhase); // -1 to +1
    final distanceMid = (_distanceRangeMin + _distanceRangeMax) / 2.0;
    final distanceAmplitude = (_distanceRangeMax - _distanceRangeMin) / 2.0;
    final targetDistance = distanceMid + distanceAmplitude * distanceOscillation;
    
    return CameraPosition(
      rotationX: targetElevation * math.pi / 180.0, // Convert to radians
      rotationY: targetAzimuth * math.pi / 180.0,   // Convert to radians
      distance: targetDistance,
    );
  }
  
  /// Calculate transition progress (0.0 to 1.0)
  double _calculateTransitionProgress(DateTime currentTime) {
    if (_transitionStartTime == null) return 1.0;
    
    final elapsed = currentTime.difference(_transitionStartTime!).inMilliseconds / 1000.0;
    return math.min(elapsed / _transitionDurationSeconds, 1.0);
  }
  
  /// Smooth easing function for transitions
  double _easeInOutCubic(double t) {
    return t < 0.5 
        ? 4 * t * t * t 
        : 1 - math.pow(-2 * t + 2, 3) / 2;
  }
  
  /// Linear interpolation
  double _lerp(double a, double b, double t) {
    return a + (b - a) * t;
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
    final elevationSubRange = elevationRange * (0.6 + random.nextDouble() * 0.4);
    final azimuthSubRange = azimuthRange * (0.6 + random.nextDouble() * 0.4);
    final distanceSubRange = distanceRange * (0.6 + random.nextDouble() * 0.4);
    
    // Position the sub-range randomly within the full range
    _elevationRangeMin = _baseElevationMin + random.nextDouble() * (elevationRange - elevationSubRange);
    _elevationRangeMax = _elevationRangeMin + elevationSubRange;
    
    _azimuthRangeMin = _baseAzimuthMin + random.nextDouble() * (azimuthRange - azimuthSubRange);
    _azimuthRangeMax = _azimuthRangeMin + azimuthSubRange;
    
    _distanceRangeMin = _baseDistanceMin + random.nextDouble() * (distanceRange - distanceSubRange);
    _distanceRangeMax = _distanceRangeMin + distanceSubRange;
    
    AppLogger.info('CameraDirector: Animation ranges randomized');
    AppLogger.info('  Elevation: ${_elevationRangeMin.toStringAsFixed(1)}° - ${_elevationRangeMax.toStringAsFixed(1)}° (${_elevationCycleDuration.toStringAsFixed(1)}s)');
    AppLogger.info('  Azimuth: ${_azimuthRangeMin.toStringAsFixed(1)}° - ${_azimuthRangeMax.toStringAsFixed(1)}° (${_azimuthCycleDuration.toStringAsFixed(1)}s)');
    AppLogger.info('  Distance: ${_distanceRangeMin.toStringAsFixed(1)} - ${_distanceRangeMax.toStringAsFixed(1)} (${_distanceCycleDuration.toStringAsFixed(1)}s)');
  }
  
  /// Update camera distance (for zoom controls)
  void updateManualDistance(double distance) {
    _manualDistance = distance;
    _lastUserInteraction = DateTime.now();
    
    if (_isAutoMode) {
      stopAutoMode();
    }
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
  vm.Vector3 _calculateCameraPosition3D(double rotationX, double rotationY, double distance) {
    // Convert rotation inputs to spherical coordinates for Z-up system
    final azimuth = rotationY; // Horizontal rotation around Z axis
    
    // Constrain elevation to prevent camera from going underground or flipping
    final elevation = math.max(
      -math.pi * 0.4,
      math.min(math.pi * 0.4, rotationX),
    );
    
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
  final double azimuthDegrees;  // For UI display
  final double elevationDegrees; // For UI display
  final double distance;        // For UI display
  
  CameraState({
    required this.position,
    required this.target,
    required this.azimuthDegrees,
    required this.elevationDegrees,
    required this.distance,
  });
}