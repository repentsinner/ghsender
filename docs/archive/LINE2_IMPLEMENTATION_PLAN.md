# Line2/LineSegments2 Implementation Plan for Flutter Scene

## Overview
Implement Three.js-compatible Line2/LineSegments2 for Flutter Scene using instanced quad tessellation, following the proven Three.js LineMaterial architecture for anti-aliased thick lines.

## Architecture Decision: Three.js Compatibility
- Follow Three.js LineSegment2 implementation as closely as possible (known good, well-tested)
- Use instanced geometry for quad tessellation (efficient GPU rendering)
- Vertex shader performs line-to-quad expansion (GPU tessellation)
- Fragment shader handles anti-aliasing via distance calculations

## Shader Strategy: Extract and Adapt Three.js LineMaterial
- **Extract GLSL shaders** from Three.js LineMaterial source (proven, battle-tested algorithm)
- **Store in separate .glsl files** (not embedded strings) for proper tooling support
- **Adapt uniform/attribute names** for flutter_gpu compatibility
- **Credit original source** with date and URL in shader comments
- **Maintain Three.js algorithm fidelity** while using Flutter Scene conventions

**Source Reference:**
- Original: `three.js/examples/jsm/lines/LineMaterial.js`
- License: MIT (compatible with our usage)
- Approach: Algorithm adaptation, not direct copying

## File Structure
```
lib/renderers/
├── line_geometry.dart      # LineGeometry class with polyline/segments modes
├── line_material.dart      # LineMaterial for anti-aliased line rendering  
└── line_mesh_factory.dart  # Factory for creating Line2/LineSegments2 meshes

shaders/
├── line.vert               # Instanced quad tessellation vertex shader
├── line.frag               # Anti-aliased line fragment shader
└── line.shaderbundle.json  # Line shader bundle configuration

shaders/ghsender.shaderbundle.json                  # Updated with line shaders
```

## API Design (Option B - Single class with modes)
```dart
// Continuous polyline (Line2 equivalent)
final line2 = LineGeometry.polyline([point1, point2, point3, point4]);

// Discrete segments (LineSegments2 equivalent)  
final segments = LineGeometry.segments([start1, end1, start2, end2]);

// Material with Three.js Line2 capabilities
final material = LineMaterial(
  lineWidth: 5.0,
  color: Colors.red,
  // Future: dashArray, opacity, etc.
);

final mesh = Mesh(line2, material);
```

## Technical Implementation Details

### 1. LineGeometry Class (extends UnskinnedGeometry)

**Core Functionality:**
- **polyline mode**: Convert consecutive points [P1, P2, P3, P4] → [(P1→P2), (P2→P3), (P3→P4)]
- **segments mode**: Use point pairs directly [P1, P2, P3, P4] → [(P1→P2), (P3→P4)]

**Geometry Structure (Following Three.js):**
```dart
// Base quad template (6 vertices, 2 triangles)
final quadVertices = Float32List.fromList([
  // Triangle 1
  -1, -1, 0,  // Bottom-left
   1, -1, 0,  // Bottom-right
   1,  1, 0,  // Top-right
  // Triangle 2  
  -1, -1, 0,  // Bottom-left (shared)
   1,  1, 0,  // Top-right (shared)
  -1,  1, 0   // Top-left
]);

// Instanced attributes (per line segment)
final instanceStart = Float32List.fromList([...]);      // Line start points
final instanceEnd = Float32List.fromList([...]);        // Line end points
final instanceColorStart = Float32List.fromList([...]); // Start colors
final instanceColorEnd = Float32List.fromList([...]);   // End colors
```

**Custom Vertex Shader:**
- References line tessellation vertex shader
- Handles instanced attributes for line segment data

### 2. LineMaterial Class (extends Material)

**Properties (Three.js Line2 Compatible):**
- `lineWidth`: Line width in pixels
- `color`: Base line color  
- `opacity`: Line transparency
- Future: `dashArray`, `dashOffset`, gradient support

**Custom Fragment Shader:**
- Distance-based anti-aliasing
- Round line caps
- Smooth edge falloff

### 3. Shader Implementation (Adapted from Three.js LineMaterial)

**Important:** The actual shader implementation will be extracted and adapted from Three.js LineMaterial source code, stored in separate `.glsl` files with proper source attribution.

**Vertex Shader (line.vert):** 
- Will be adapted from Three.js LineMaterial vertex shader
- Instanced quad tessellation algorithm
- Screen-space line expansion calculations
- Perspective-correct rendering
- Source attribution in header comments

**Fragment Shader (line.frag):**
- Will be adapted from Three.js LineMaterial fragment shader  
- Distance-based anti-aliasing algorithm
- Round line caps implementation
- Alpha blending for smooth edges
- Source attribution in header comments

**Adaptation Strategy:**
```glsl
/*
 * Adapted from Three.js LineMaterial
 * Original source: https://github.com/mrdoob/three.js/blob/master/examples/jsm/lines/LineMaterial.js
 * Date extracted: [DATE]
 * License: MIT
 * Modifications: Adapted for flutter_gpu uniform/attribute naming conventions
 */
```

**Flutter Scene Compatibility Adaptations:**
- Three.js `uniform float linewidth;` → flutter_gpu `uniform float lineWidth;`
- Three.js WebGL attribute bindings → flutter_gpu attribute bindings
- Three.js projection matrices → Flutter Scene camera transforms
- Maintain core algorithm unchanged for proven reliability

### 4. Integration Points

**Flutter Scene Renderer Integration:**
- Add to `flutter_scene_batch_renderer.dart`
- Support line geometries alongside existing cube geometry
- Use existing material batching system where possible

**Shader Bundle (line.shaderbundle.json):**
```json
{
  "LineVertex": {
    "type": "vertex",
    "file": "shaders/line.vert"
  },
  "LineFragment": {
    "type": "fragment", 
    "file": "shaders/line.frag"
  }
}
```

## Vector Math Library
Use `package:vector_math` (`vm.Vector3`) for consistency with flutter_scene internals and existing codebase.

## Line Properties (Three.js Line2 Features)
- ✅ **Arbitrary line width** in pixels (not limited to 1px)
- ✅ **Per-segment colors** (start/end color interpolation)
- ✅ **Anti-aliased edges** with smooth falloff
- ✅ **Round line caps** built into fragment shader
- ✅ **Screen-space rendering** (consistent width regardless of camera distance)
- 🔄 **Future features**: Dash patterns, opacity gradients, custom caps

## Performance Characteristics
**Expected Performance (vs alternatives):**
- **vs Individual Lines**: 10-100x fewer draw calls via instancing
- **vs CPU Tessellation**: GPU parallel tessellation vs serial CPU  
- **vs Flutter Canvas**: True GPU rendering vs software rasterization
- **Memory Efficiency**: 6 base vertices + 2N instance data vs 6N vertices

## Testing Integration
Add line rendering to existing flutter_scene performance comparison:

```dart
// Add to performance test options
enum RendererType {
  flutterScene,
  gpuBatch,
  flutterSceneLines,  // NEW: Line2/LineSegments2 test
}

// Test both modes
final polylines = LineGeometry.polyline(gcodePath);     // Continuous toolpath
final segments = LineGeometry.segments(gridLines);     // Discrete grid
```

## Implementation Notes

### Flutter Scene Compatibility
- LineGeometry must extend UnskinnedGeometry (for vertex shader override)
- LineMaterial must extend Material (for fragment shader override)
- Use existing Mesh/MeshPrimitive/Node structure
- Integrate with existing SceneEncoder pipeline

### Three.js Fidelity Checklist
- ✅ Instanced rendering architecture
- ✅ Screen-space line width calculation  
- ✅ Vertex shader quad tessellation
- ✅ Fragment shader anti-aliasing
- ✅ Round caps by default
- ✅ Perspective-correct rendering
- 🔄 Dash pattern support (future)
- 🔄 Custom line joins (future)

### Error Handling
- Validate minimum 2 points for polylines
- Validate even number of points for segments
- Handle degenerate lines (zero length)
- Graceful fallback for unsupported features

## Questions Resolved
1. **Data Input Format**: Option B (single class with modes) ✅
2. **Vector Math**: Use vector_math (vm.Vector3) for flutter_scene compatibility ✅
3. **Line Properties**: Duplicate Three.js Line2 capabilities ✅  
4. **Shader Bundle**: Create separate line.shaderbundle.json for reusability ✅
5. **Integration**: Flutter Scene renderer only, add to existing performance test ✅

## Implementation Priority
1. **Phase 1**: Basic LineGeometry + LineMaterial with solid colors
2. **Phase 2**: Per-segment color interpolation
3. **Phase 3**: Advanced features (dash patterns, custom caps)
4. **Phase 4**: Performance optimization and benchmarking

---
*This document serves as the definitive implementation reference. Update as implementation progresses.*