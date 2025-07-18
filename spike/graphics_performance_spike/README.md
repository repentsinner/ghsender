# Graphics Performance Spike - 3D flutter_scene

This spike tests 3D graphics rendering performance using flutter_scene library.

## Requirements

⚠️ **This spike requires Flutter master channel** - it will NOT work with Flutter stable.

### Setup Instructions

1. **Switch to Flutter master channel:**
   ```bash
   flutter channel master
   flutter upgrade
   ```

2. **Enable required features:**
   ```bash
   flutter config --enable-native-assets
   ```

3. **Install CMake** (required for flutter_scene native assets):
   - CMake is available in the toolchain directory: `toolchain/cmake/CMake.app/Contents/bin/cmake`
   - Or install via the setup script: `./tools/setup-toolchain.sh`

4. **Run the spike:**
   ```bash
   cd spike/graphics_performance_spike
   export PATH="../../toolchain/cmake/CMake.app/Contents/bin:$PATH"
   flutter run --enable-impeller --enable-flutter-gpu -d macos
   ```

## Features

- **10,000 3D cubes** rendered using flutter_scene
- **100 animated cubes** with smooth interpolation
- **Orbital camera animation** around the scene center
- **3D positioning** in a pile toward the center
- **Performance measurement** with FPS reporting

## Performance Results

- **~21 FPS** with 10,000 cubes (100 animated) using flutter_scene + Impeller
- **Mesh sharing optimization** applied from flutter-scene-example patterns

## Dependencies

- `flutter_scene: ^0.9.2-0` - 3D rendering library
- `vector_math: ^2.1.4` - Vector mathematics
- Requires Flutter master channel
- Requires CMake for native assets compilation
- Requires Impeller rendering backend
- Requires Flutter GPU feature flag

## Notes

- This spike demonstrates the difference between 2D Canvas rendering (~117 FPS) and 3D scene rendering (~21 FPS)
- The implementation uses proper flutter_scene APIs with Scene.render() instead of custom 3D projection
- Optimizations include shared mesh resources and UnlitMaterial for better performance