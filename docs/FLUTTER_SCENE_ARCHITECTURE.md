# Flutter Scene Architecture: Vertex Attributes and Rendering Pipeline

## Overview

This document explains the architectural constraints and design decisions in Flutter Scene, particularly around vertex attributes, uniform binding, and shader integration. Understanding these constraints is essential when implementing custom geometry and materials within the Flutter Scene ecosystem.

## Key Distinction: Flutter GPU vs Flutter Scene

### Flutter GPU
- **Low-level graphics API** for building custom renderers from scratch
- Complete control over vertex buffer layouts
- No restrictions on vertex attribute formats
- Direct access to GPU pipeline configuration
- Requires manual implementation of scene graphs, sorting, blending

### Flutter Scene
- **High-level 3D rendering library** built on top of Flutter GPU
- Provides scene graph, materials, lighting, transparency handling
- **Enforces fixed vertex attribute layouts** for compatibility
- Designed for standard 3D asset pipelines (GLTF import, etc.)

## The Fixed Vertex Format Constraint

### UnskinnedGeometry Format
Flutter Scene's `UnskinnedGeometry` expects exactly **12 floats (48 bytes) per vertex**:

```glsl
// From flutter_scene_unskinned.vert
in vec3 position;       // 3 floats - vertex position
in vec3 normal;         // 3 floats - vertex normal
in vec2 texture_coords; // 2 floats - UV coordinates  
in vec4 color;          // 4 floats - vertex color
```

This layout is defined in:
- `/flutter_scene_importer/constants.dart`: `const int kUnskinnedPerVertexSize = 48`
- The FlatBuffer schema `scene.fbs` that defines the import format
- The base vertex shaders provided by Flutter Scene

### SkinnedGeometry Format
Adds 8 more floats for skeletal animation (20 floats total):
```glsl
// Additional attributes for skinned geometry
in vec4 joints;  // 4 floats - joint indices
in vec4 weights; // 4 floats - joint weights
```

## Why This Constraint Exists

1. **Compatibility with 3D Asset Pipelines**: Standard formats like GLTF expect these attributes
2. **Shader Reusability**: Base shaders can be shared across different materials
3. **Simplicity**: Developers don't need to configure vertex layouts
4. **Performance**: Fixed layout allows for optimizations in the importer

## Working Within the Constraints

### Approach 1: Repurpose Existing Attributes
When your custom geometry needs data beyond the standard attributes, you can repurpose the existing fields:

```dart
// Standard usage:
vertices.addAll([
  x, y, z,           // position (3) - vertex position
  nx, ny, nz,        // normal (3) - surface normal
  u, v,              // texture_coords (2) - UV coordinates
  r, g, b, a,        // color (4) - vertex color
]);

// Repurposed for custom data:
vertices.addAll([
  localX, localY, localZ,        // position → local/relative coordinates
  worldX, worldY, worldZ,        // normal → world position or other vec3 data
  u, v,                          // texture_coords → UV or 2D parameters
  param1, param2, param3, param4 // color → custom parameters
]);
```

**Pros:**
- Works within Flutter Scene's ecosystem
- Maintains compatibility with render pipeline
- Can leverage scene graph, sorting, transparency

**Cons:**
- Semantically incorrect (attributes don't match their names)
- Limited to 12 floats per vertex
- Requires careful documentation

**Real-world Examples:**
- **Billboard Renderer**: Uses `normal` for world position, `color` for size/mode parameters
- **Line Renderer**: Uses `normal` for line end position, `color` for line width/sharpness

### Approach 2: Use Uniforms for Per-Object Data

#### The Uniform Binding Architecture in Flutter Scene

Flutter Scene enforces a separation of uniform binding responsibilities:

1. **Geometry.bind()** → Binds uniforms for the **vertex shader**
   - Binds `FrameInfo` uniform block (model/camera transforms, camera position)
   - Accesses `vertexShader.getUniformSlot('FrameInfo')`
   - Called first in the render pipeline

2. **Material.bind()** → Binds uniforms for the **fragment shader**
   - Binds `FragInfo` uniform block (color, material properties)
   - Accesses `fragmentShader.getUniformSlot('FragInfo')`
   - Called second in the render pipeline

#### Challenge: Cross-Stage Uniform Sharing

While GLSL allows uniforms to be shared between vertex and fragment shaders, Flutter Scene's architecture makes this difficult:

```glsl
// Even if declared in both shaders:
uniform BillboardInfo {
  vec3 billboard_center;
  vec2 billboard_size;
  float size_mode;
} billboard_info;
```

The uniform must be bound from the appropriate place:
- **Problem**: Material has the data but can only bind to fragment shader
- **Geometry** doesn't have access to material data but can bind to vertex shader
- Each class only has access to its own shader reference

```dart
// In Material.bind() - can only access fragmentShader
pass.bindUniform(
  fragmentShader.getUniformSlot('BillboardInfo'), // ✓ Works for fragment
  data
);

// Cannot do this from Material:
pass.bindUniform(
  vertexShader.getUniformSlot('BillboardInfo'), // ✗ No access to vertexShader!
  data
);
```

**Pros:**
- Semantically correct for per-object data
- No attribute repurposing
- Reduces vertex buffer redundancy

**Cons:**
- Only works for per-object data, not per-vertex
- Difficult to share between vertex and fragment shaders in Flutter Scene
- Would require architectural changes to pass data between Geometry and Material

### Approach 3: Texture Samplers for Additional Data
```glsl
// In vertex shader
uniform sampler2D vertexDataTexture;
void main() {
  vec4 extraData = texelFetch(vertexDataTexture, ivec2(gl_VertexID, 0), 0);
  // Use extraData for additional per-vertex information
}
```

**Pros:**
- Unlimited additional vertex data
- Used by Flutter Scene for skeletal animation

**Cons:**
- More complex setup
- Texture fetch overhead

### Approach 4: Use Flutter GPU Directly
```dart
// Direct Flutter GPU usage with custom vertex layout
final vertices = Float32List.fromList([
  // Define any vertex format you want
  x, y, z, nx, ny, nz, u, v, customData1, customData2, ...
]);

// Write matching vertex shader
// in vec3 position;
// in vec3 normal;
// in vec2 uv;
// in float customData1;
// in float customData2;
```

**Pros:**
- Complete control over vertex format
- Semantically correct attributes
- Optimal memory usage

**Cons:**
- Must implement scene graph yourself
- Must handle render passes, sorting, transparency
- No integration with Flutter Scene's features

## Practical Implications for Custom Renderers

### When to Use Flutter Scene
- Standard 3D rendering with imported assets
- Need scene graph, materials, lighting
- Can work within 12-float vertex constraint
- Want automatic transparency sorting

### When to Use Flutter GPU Directly
- Building specialized 2D renderers
- Non-standard vertex formats (e.g., particle systems)
- Rendering non-Euclidean spaces
- Need maximum performance with minimal overhead

## Implementation Strategy for Custom Renderers

### Choosing the Right Approach

When implementing custom geometry/materials in Flutter Scene, consider:

1. **Data Requirements**
   - How many floats per vertex do you need?
   - Is the data per-vertex or per-object?
   - Does the vertex shader need access to material properties?

2. **Architecture Constraints**
   - Can you fit within 12 floats per vertex?
   - Can you work with separated uniform binding?
   - Do you need the scene graph features?

3. **Performance Trade-offs**
   - Redundant vertex data vs complex uniform setup
   - Texture fetches vs direct attribute access
   - Custom pipeline vs Flutter Scene integration

### Why Vertex Attribute Repurposing is Often the Best Choice

While it seems inefficient to duplicate per-object data across vertices, this approach works around Flutter Scene's uniform binding limitations:

1. **Data Availability**: All data is available in the vertex shader without complex uniform sharing
2. **Single Source**: Geometry owns all the data, no Material coordination needed
3. **Pipeline Compatibility**: Works with existing pipeline without modifications
4. **Performance**: Modern GPUs handle redundant vertex data efficiently

### Example: Custom Renderer Vertex Layouts

Different custom renderers might repurpose attributes differently:

```dart
// Particle System:
position → particle center
normal → velocity vector
texture_coords → age, lifetime
color → size, rotation, type, opacity

// Instanced Geometry:
position → local vertex position
normal → instance position
texture_coords → instance UV offset
color → instance color tint

// Procedural Geometry:
position → base position
normal → displacement direction
texture_coords → procedural parameters
color → blend weights
```

## Custom Shader Integration in Flutter Scene

### Shader Compilation and Loading

Flutter Scene uses the `flutter_gpu_shaders` package for shader compilation:

1. **Shader Files**: Write GLSL shaders in `shaders/` directory
2. **Bundle Configuration**: Define shaders in `shaders/[name].shaderbundle.json`
3. **Build Hook**: Compile shaders via `hook/build.dart`
4. **Runtime Loading**: Load via `gpu.ShaderLibrary.fromAsset()`

### Creating Custom Geometry and Materials

To implement custom rendering in Flutter Scene:

```dart
class CustomGeometry extends UnskinnedGeometry {
  @override
  gpu.Shader get vertexShader => _shaderLibrary!['CustomVertex'];
  
  // Generate vertex data using the 12-float format
  // Repurpose attributes as needed for your use case
}

class CustomMaterial extends UnlitMaterial {
  @override
  gpu.Shader get fragmentShader => _shaderLibrary!['CustomFragment'];
  
  @override
  void bind(...) {
    super.bind(...);
    // Bind additional uniforms if needed
  }
}
```

## Future Considerations

### Potential Flutter Scene Improvements

1. **Custom Vertex Formats**: Support for arbitrary vertex attribute layouts
2. **Unified Uniform Binding**: Allow Materials to bind uniforms for vertex shaders
3. **Attribute Semantics**: Named attributes instead of fixed position/normal/uv/color
4. **Direct GPU Access**: Hybrid approach mixing Flutter Scene and Flutter GPU

### Migration Path

If Flutter Scene evolves to support these features:
1. Define semantic vertex attribute names in shaders
2. Create geometry with matching layouts
3. Remove repurposing workarounds
4. Update uniform binding to use new APIs

Until then, the attribute repurposing approach provides a pragmatic balance between functionality and integration with Flutter Scene's ecosystem.

## References

- Flutter GPU Documentation: https://github.com/flutter/flutter/blob/main/engine/src/flutter/docs/impeller/Flutter-GPU.md
- Flutter Scene Package: https://pub.dev/packages/flutter_scene
- Three.js BufferGeometry (for comparison): https://threejs.org/docs/#api/en/core/BufferGeometry