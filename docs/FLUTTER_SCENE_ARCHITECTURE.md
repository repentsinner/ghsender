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
4. **Runtime Loading**: Load via `gpu.ShaderLibrary.fromAsset()`.
   - **Important Note**: This operation is **synchronous**. The build hook embeds the compiled shader bundle directly into the application binary, allowing for immediate memory mapping at runtime without asynchronous file I/O. This is a key optimization in the `flutter_gpu` pipeline.

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

## Screen-Space and Clip-Space Rendering Conventions

### Overview

When implementing custom renderers that need pixel-accurate sizing or screen-space effects (like consistent line widths or billboard sizing), we've established standardized conventions for attribute packing and coordinate transformations.

### Critical Architectural Constraints

#### 1. Flutter Scene Uniform Binding Limitations Force Attribute Abuse

**Flutter Scene's separated uniform binding makes it impossible to pass custom data to vertex shaders via uniforms:**

- **Material.bind()** can only bind uniforms to fragment shaders
- **Geometry.bind()** can only bind uniforms to vertex shaders, but has no access to material data
- **No mechanism exists** for materials to pass data to vertex shaders

**Therefore, we MUST repurpose vertex attributes to carry non-vertex data:**

```glsl
// What we WANT to do (but can't):
uniform ScreenSpaceInfo {
  vec2 viewport_size;
  float line_width;
} screen_info;

// What we MUST do instead:
in vec4 color;  // Repurpose color attribute to carry [viewport_width, viewport_height, line_width, opacity]
```

This is not a design choice - it's the **only way** to get screen-space parameters into vertex shaders within Flutter Scene's architecture.

#### 2. Viewport Size in Vertex Shaders is Mandatory for Aspect Ratio Correctness

**Without viewport dimensions in the vertex shader, aspect ratio calculations will be wrong:**

```glsl
// WRONG - assumes square viewport
vec2 ndc_offset = pixel_offset * (2.0 / 800.0);  // Hardcoded, breaks on resize

// CORRECT - maintains aspect ratio at any viewport size  
vec2 viewport_size = color.xy;
vec2 ndc_offset = (pixel_offset / viewport_size) * 2.0;
```

**Why viewport_size is essential:**
- Screen-space effects must account for viewport aspect ratio
- NDC space is always square (-1 to +1), but viewports are rarely square
- Without viewport dimensions, circles become ellipses, squares become rectangles
- Pixel-accurate sizing requires knowing the actual viewport dimensions

**This is why `color.xy` always contains viewport dimensions in our convention.**

### Viewport Size Convention

**All custom renderers use `color.xy` for viewport dimensions:**

```glsl
// Standard convention across all renderers
in vec4 color;           // [viewport_width, viewport_height, param1, param2]
vec2 viewport_size = color.xy;  // Always viewport dimensions
```

**Examples:**
- **Line Renderer**: `[viewport_width, viewport_height, lineWidth, opacity]`
- **Billboard Renderer**: `[viewport_width, viewport_height, width_pixels, height_pixels]`

This ensures consistency and makes it clear that the first two color components always represent the rendering viewport.

### Screen-Space Sizing Formula

For pixel-accurate rendering, we use the standard NDC (Normalized Device Coordinates) conversion:

```glsl
// Convert pixel dimensions to NDC space
vec2 pixel_size = vec2(width_pixels, height_pixels);
vec2 ndc_size = (pixel_size / viewport_size) * 2.0;
```

**Why this works:**
- NDC range is -1 to +1 (total range of 2.0) maps to viewport dimensions
- `pixel_size / viewport_size` gives us the fraction of viewport
- Multiply by 2.0 to convert to NDC range

### Clip-Space Billboard Approach

For billboards that maintain pixel-accurate sizing regardless of distance:

```glsl
// Transform billboard center to clip space
vec4 billboard_clip_pos = camera_transform * model_transform * vec4(world_pos, 1.0);

// Apply corner offset with perspective correction
vec2 corner_offset = quad_corner * ndc_size * billboard_clip_pos.w;
billboard_clip_pos.xy += corner_offset;
```

**Key insight:** Multiply offset by `billboard_clip_pos.w` for proper perspective correction - closer objects get larger offsets, farther objects get smaller offsets, maintaining consistent pixel sizing.

### Coordinate System Considerations

When working with screen-space effects in the CNC → Impeller coordinate transform pipeline:

1. **Apply screen-space calculations BEFORE coordinate transformation** when possible
2. **Use viewport aspect ratio correction** for directional calculations:
   ```glsl
   float aspect = viewport_size.x / viewport_size.y;
   screen_direction.x *= aspect;  // Apply correction
   // ... do calculations ...
   screen_offset.x /= aspect;     // Undo correction
   ```

### Attribute Packing Standards

**Consistent layout for all screen-space renderers:**

```dart
// Dart side - vertex generation
vertices.addAll([
  worldPos.x, worldPos.y, worldPos.z,           // position (3) - world coordinates
  customData1, customData2, customData3,        // normal (3) - renderer-specific
  uv.x, uv.y,                                   // texture_coords (2) - UV or params  
  viewportWidth, viewportHeight, param1, param2 // color (4) - viewport + renderer-specific
]);
```

**Benefits:**
- **Predictable**: `color.xy` always contains viewport dimensions
- **Efficient**: No wasted attribute space
- **Consistent**: Same pattern across all custom renderers
- **Future-proof**: Easy to add new renderers following the same convention

### Performance Considerations

**Viewport updates trigger scene regeneration:**
- Screen-space renderers bake viewport dimensions into vertex data
- When viewport size changes, geometry must be regenerated
- This is handled automatically by the `_updateViewportResolution()` system

**Why vertex attributes over uniforms:**
- **Flutter Scene's architecture makes uniforms impossible** - no way to pass material data to vertex shaders
- **Only vertex attributes can carry custom data** to vertex shaders in Flutter Scene
- **Attribute repurposing is the only viable solution** - not a performance optimization, but an architectural necessity
- Modern GPUs handle redundant vertex data efficiently, making this approach practical

### Real-World Examples

**Line Renderer (Three.js Line2-style):**
- Uses screen-space expansion for consistent pixel line widths
- Applies aspect ratio correction for directional calculations
- Implements anti-aliasing padding in screen space

**Billboard Renderer (Clip-space sizing):**
- Achieves pixel-perfect billboard sizing at any distance
- Maintains aspect ratio through viewport-aware NDC conversion
- Uses perspective correction for proper depth behavior

### Key Takeaways for Custom Renderer Implementation

**When implementing any screen-space renderer in Flutter Scene, remember:**

1. **You CANNOT use uniforms for custom vertex shader data** - Flutter Scene's architecture prevents this
2. **You MUST repurpose vertex attributes** - specifically the `color` attribute for screen-space parameters  
3. **You MUST include viewport dimensions** (`color.xy`) for aspect ratio correctness
4. **You MUST regenerate geometry on viewport changes** - screen-space data is baked into vertices

**These are not recommendations - they are architectural requirements imposed by Flutter Scene's limitations.**

## References

- Flutter GPU Documentation: https://github.com/flutter/flutter/blob/main/engine/src/flutter/docs/impeller/Flutter-GPU.md
- Flutter Scene Package: https://pub.dev/packages/flutter_scene
- Three.js BufferGeometry (for comparison): https://threejs.org/docs/#api/en/core/BufferGeometry