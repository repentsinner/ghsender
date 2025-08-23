import 'package:flutter_gpu/gpu.dart' as gpu;
import '../utils/logger.dart';

/// Service for centralized shader management and loading
///
/// Provides type-safe access to pre-compiled shader bundles that are built
/// at compile time via the native assets build hook (hook/build.dart).
///
/// Note: Unlike typical Flutter asset loading (which is async), shader bundles
/// are synchronously available through gpu.ShaderLibrary.fromAsset() because
/// they are pre-compiled and bundled with the app during the build process.
/// This is a counter-pattern to normal Flutter asset loading but enables
/// immediate shader access without async complexity in renderers.
class ShaderService {
  static ShaderService? _instance;
  static ShaderService get instance => _instance ??= ShaderService._();

  /// Required shader names that must be present in the shader bundle
  ///
  /// Note: This list is maintained manually due to flutter_gpu API limitations -
  /// gpu.ShaderLibrary doesn't expose shader names directly for introspection.
  static const List<String> _requiredShaderNames = [
    'LineVertex',
    'LineFragment',
    'BillboardVertex',
    'BillboardFragment',
  ];

  ShaderService._();

  gpu.ShaderLibrary? _shaderLibrary;
  bool _initialized = false;
  bool _initializationFailed = false;
  String? _initializationError;

  /// Initialize the shader service - must be called at app startup
  ///
  /// Loads pre-compiled shader bundle and verifies all required shaders are present.
  /// Must complete successfully before any renderers are created.
  ///
  /// Note: This method is synchronous because gpu.ShaderLibrary.fromAsset()
  /// loads pre-compiled shader bundles that are available immediately.
  void initialize() {
    if (_initialized) {
      AppLogger.info('ShaderService: Already initialized');
      return;
    }

    if (_initializationFailed) {
      throw Exception(
        'ShaderService: Previous initialization failed: $_initializationError',
      );
    }

    try {
      AppLogger.info('ShaderService: Loading shader bundle...');

      _shaderLibrary = gpu.ShaderLibrary.fromAsset(
        'build/shaderbundles/ghsender.shaderbundle',
      );

      _initialized = true;
      AppLogger.info('ShaderService: Shader bundle loaded successfully');

      // Verify expected shaders are present
      _verifyRequiredShaders();
    } catch (e) {
      _initializationFailed = true;
      _initializationError = e.toString();
      AppLogger.error('ShaderService: Failed to load shader bundle', e);
      throw Exception(
        'ShaderService initialization failed. This typically indicates:\n'
        '1. Shader compilation failed (check shaders/ directory)\n'
        '2. Build hook not working (check hook/build.dart)\n'
        '3. Shader bundle not generated (check build/shaderbundles/)\n'
        'Original error: $e',
      );
    }
  }

  /// Verify that all required shaders are present in the bundle
  void _verifyRequiredShaders() {
    final missingShaders = <String>[];

    for (final shaderName in _requiredShaderNames) {
      if (_shaderLibrary![shaderName] == null) {
        missingShaders.add(shaderName);
      }
    }

    if (missingShaders.isNotEmpty) {
      throw Exception(
        'ShaderService: Missing required shaders in bundle: ${missingShaders.join(', ')}',
      );
    }

    AppLogger.info('ShaderService: All required shaders verified');
  }

  /// Get a shader by name
  ///
  /// Throws exception if shader service is not initialized or shader is not found.
  /// This should only be called after successful initialization.
  gpu.Shader getShader(String shaderName) {
    if (!_initialized) {
      throw Exception(
        'ShaderService: Cannot get shader "$shaderName" - service not initialized. '
        'Call initialize() first during app startup.',
      );
    }

    if (_shaderLibrary == null) {
      throw Exception(
        'ShaderService: Shader library is null despite initialization success. '
        'This indicates a programming error.',
      );
    }

    final shader = _shaderLibrary![shaderName];
    if (shader == null) {
      throw Exception(
        'ShaderService: Shader "$shaderName" not found in bundle. '
        'Available shaders: ${_getAvailableShaderNames().join(', ')}',
      );
    }

    return shader;
  }

  /// Check if a shader exists in the bundle
  bool hasShader(String shaderName) {
    if (!_initialized || _shaderLibrary == null) {
      return false;
    }
    return _shaderLibrary![shaderName] != null;
  }

  /// Get list of available shader names for debugging
  List<String> _getAvailableShaderNames() {
    if (_shaderLibrary == null) return [];

    // Note: gpu.ShaderLibrary doesn't expose shader names directly
    // This is a limitation of the flutter_gpu API
    // Return the expected shader names for now
    return _requiredShaderNames;
  }

  /// Reset the service state (for testing purposes)
  void reset() {
    _shaderLibrary = null;
    _initialized = false;
    _initializationFailed = false;
    _initializationError = null;
    _instance = null;
  }

  /// Get initialization status
  bool get isInitialized => _initialized;
  bool get initializationFailed => _initializationFailed;
  String? get initializationError => _initializationError;
}
