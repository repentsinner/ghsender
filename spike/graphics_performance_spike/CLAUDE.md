# Graphics Performance Spike - Project Memory

## Project Overview
Flutter graphics performance comparison spike comparing GPU batching vs individual object rendering using flutter_gpu and flutter_scene.

## Key Technical Learnings

### Critical Requirements (MUST REMEMBER)
1. **NO Canvas Drawing in GPU Renderer**: flutter_gpu must use actual GPU APIs, not Canvas shortcuts
2. **flutter_gpu API is Complete**: flutter_scene is built on flutter_gpu, proving the API works
3. **Shaders are Required**: Conceptual GPU rendering without shaders provides no performance benefit
4. **True Batching**: Must render all 120,000 triangles in 1 draw call, not 10,000 shortcuts

### Flutter GPU vs Flutter Scene Performance
- **GPU Renderer (Batched)**: 120,000 triangles in 1 draw call
- **Flutter Scene Renderer**: 120,000 triangles in 10,000 draw calls  
- **10,000× difference in draw call efficiency**

## Current Implementation Status

### Completed Components
1. **Scene Configuration** (`lib/scene.dart`): Shared 3D cube positioning and coloring
2. **GPU Batch Renderer** (`lib/renderers/gpu_batch_renderer.dart`): 
   - Creates GPU buffers with vertex data (position + color)
   - Vertex format: 6 floats per vertex (x,y,z,r,g,b)
   - True geometry batching: 10k cubes → 80k vertices → 360k indices
3. **Flutter Scene Renderer** (`lib/renderers/flutter_scene_batch_renderer.dart`): Individual node rendering
4. **Interactive Controls**: Click-drag rotation, renderer switching, wireframe toggle
5. **Shader Files Created**:
   - `shaders/cube.vert`: MVP transformation vertex shader
   - `shaders/cube.frag`: Distance-based fog fragment shader  
   - `shaders/wireframe.frag`: Wireframe-specific fragment shader
   - `.shaderbundle.json`: Shader compilation config

### Current Status: GPU Shaders Implementation
✅ **flutter_gpu_shaders setup complete**: Dependencies resolved, build hook created
✅ **Shader files created**: vertex, fragment, and wireframe shaders written
✅ **API fixes applied**: Corrected flutter_gpu method signatures

### Flutter GPU API Corrections Made
- ✅ Shader access: `gpu.ShaderLibrary.fromAsset()` instead of `gpu.shaderLibrary`
- ✅ Buffer management: `HostBuffer.emplace()` instead of `DeviceBuffer`
- ✅ Drawing: `bindIndexBuffer()` + `drawIndexed(count)` instead of `drawIndexed(buffer, count)`
- ✅ Uniforms: `getUniformSlot()` for shader binding
- ✅ Pipeline creation: Simple `createRenderPipeline(vertex, fragment)` call

### Shader Development Workflow
- **IMPORTANT**: Shader changes require `flutter clean` before `flutter run` to force recompilation
- Flutter does not automatically detect shader source file changes
- Always run `flutter clean && flutter run` after editing .vert/.frag files

## File Structure
```
lib/
├── main.dart                    # App entry, UI controls, renderer switching
├── scene.dart                   # Shared 3D scene configuration
└── renderers/
    ├── gpu_batch_renderer.dart      # Flutter GPU batched rendering
    └── flutter_scene_batch_renderer.dart  # Flutter Scene individual rendering

shaders/
├── cube.vert                   # Vertex shader with MVP transformation
├── cube.frag                   # Fragment shader with fog effects
└── wireframe.frag              # Wireframe fragment shader

.shaderbundle.json              # Shader compilation configuration
```

## Performance Testing Instructions
1. Run app with `flutter run`
2. Use floating action button to switch between renderers
3. Observe FPS difference between 1 vs 10,000 draw calls
4. Use wireframe toggle (GPU mode only) to see 3D structure
5. Click-drag to rotate scene interactively

## Next Critical Steps
1. **Fix flutter_gpu_shaders dependency** - Research proper setup method
2. **Correct flutter_gpu API usage** - Find actual method signatures
3. **Compile shaders successfully** - Get shader pipeline working
4. **Validate performance claims** - Ensure real GPU rendering vs conceptual

## Important Reminders
- flutter_gpu API is NOT incomplete - it's fully functional
- flutter_scene proves flutter_gpu works (it's built on top of it)
- Sample code exists in flutter_gpu showing proper usage patterns
- Must use actual GPU shaders for meaningful performance comparison