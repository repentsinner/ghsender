# Filled Square Rendering Plan for ghSender 3D Viewer

## Overview
Add plane-aligned filled square rendering capability to the existing 3D viewer. Squares will have a filled interior using a new primitive geometry, with outlined edges rendered using the existing high-performance line renderer. This creates a hybrid approach combining solid fill rendering with anti-aliased edge rendering.

## Design Approach

### 1. Hybrid Rendering Architecture
Filled squares require two rendering components:
- **Fill Primitive**: New geometry for solid interior using standard Flutter Scene materials
- **Edge Lines**: Existing line renderer for anti-aliased perimeter outline

### 2. Extend Scene Object System
Add a new `SceneObjectType.filledSquare` with dual rendering support.

```dart
enum SceneObjectType {
  line,          // Existing - for G-code paths and coordinate axes
  cube,          // Existing - for 3D cube objects  
  filledSquare,  // NEW - for filled squares with outlined edges
}

class SceneObject {
  final SceneObjectType type;
  final Color color;
  final String id;
  
  // Existing line properties
  final vm.Vector3? startPoint;
  final vm.Vector3? endPoint;
  
  // NEW: Filled square properties
  final vm.Vector3? center;        // Square center point
  final double? size;              // Square side length
  final SquarePlane? plane;        // Which plane (XY, XZ, YZ)
  final double? rotation;          // Rotation around plane normal (radians)
  final Color? fillColor;          // Interior fill color
  final Color? edgeColor;          // Edge outline color
  final double? edgeWidth;         // Edge line width
  final double? opacity;           // Overall opacity (0.0-1.0)
}

enum SquarePlane {
  xy,  // Square in XY plane (normal = Z axis)
  xz,  // Square in XZ plane (normal = Y axis) 
  yz,  // Square in YZ plane (normal = X axis)
}
```

### 3. New Filled Square Geometry
Create a new geometry class for rendering filled squares with proper depth testing and transparency.

```dart
class FilledSquareGeometry extends UnskinnedGeometry {
  final vm.Vector3 center;
  final double size;
  final SquarePlane plane;
  final double rotation;

  FilledSquareGeometry({
    required this.center,
    required this.size,
    required this.plane,
    this.rotation = 0.0,
  }) {
    _generateSquareGeometry();
  }

  void _generateSquareGeometry() {
    // Calculate the 4 corner points
    final corners = _calculateSquareCorners();
    
    // Create vertices for 2 triangles forming the square
    // Triangle 1: corners[0], corners[1], corners[2]
    // Triangle 2: corners[0], corners[2], corners[3]
    final vertices = <double>[];
    final indices = <int>[];
    
    // Add vertices (position + normal + uv + color = 12 floats per vertex)
    for (int i = 0; i < 4; i++) {
      final corner = corners[i];
      final normal = _getPlaneNormal();
      final uv = _getUVCoordinate(i);
      
      vertices.addAll([
        corner.x, corner.y, corner.z,     // position (3)
        normal.x, normal.y, normal.z,     // normal (3)
        uv.x, uv.y,                       // texture coords (2)
        1.0, 1.0, 1.0, 1.0,              // color (4) - white, material handles actual color
      ]);
    }
    
    // Triangle indices (counter-clockwise winding)
    indices.addAll([
      0, 1, 2,  // First triangle
      0, 2, 3,  // Second triangle
    ]);
    
    // Create GPU buffers and set geometry data
    _createBuffers(vertices, indices);
  }
  
  List<vm.Vector3> _calculateSquareCorners() {
    final halfSize = size * 0.5;
    
    // Base corner offsets in 2D
    final baseOffsets = [
      vm.Vector2(-halfSize, -halfSize), // Bottom-left
      vm.Vector2( halfSize, -halfSize), // Bottom-right  
      vm.Vector2( halfSize,  halfSize), // Top-right
      vm.Vector2(-halfSize,  halfSize), // Top-left
    ];
    
    // Apply rotation if specified
    final rotatedOffsets = baseOffsets.map((offset) {
      if (rotation != 0.0) {
        final cos = math.cos(rotation);
        final sin = math.sin(rotation);
        return vm.Vector2(
          offset.x * cos - offset.y * sin,
          offset.x * sin + offset.y * cos,
        );
      }
      return offset;
    }).toList();
    
    // Convert to 3D points based on plane
    return rotatedOffsets.map((offset) {
      switch (plane) {
        case SquarePlane.xy:
          return center + vm.Vector3(offset.x, offset.y, 0.0);
        case SquarePlane.xz:
          return center + vm.Vector3(offset.x, 0.0, offset.y);
        case SquarePlane.yz:
          return center + vm.Vector3(0.0, offset.x, offset.y);
      }
    }).toList();
  }
  
  vm.Vector3 _getPlaneNormal() {
    switch (plane) {
      case SquarePlane.xy: return vm.Vector3(0, 0, 1);  // Z-up
      case SquarePlane.xz: return vm.Vector3(0, 1, 0);  // Y-up  
      case SquarePlane.yz: return vm.Vector3(1, 0, 0);  // X-up
    }
  }
  
  vm.Vector2 _getUVCoordinate(int cornerIndex) {
    // Standard UV mapping for square
    switch (cornerIndex) {
      case 0: return vm.Vector2(0, 0); // Bottom-left
      case 1: return vm.Vector2(1, 0); // Bottom-right
      case 2: return vm.Vector2(1, 1); // Top-right
      case 3: return vm.Vector2(0, 1); // Top-left
      default: return vm.Vector2(0, 0);
    }
  }
}
```

### 4. Filled Square Material
Create a material for rendering the filled interior with proper transparency support.

```dart
class FilledSquareMaterial extends UnlitMaterial {
  FilledSquareMaterial({
    required Color fillColor,
    double opacity = 1.0,
  }) {
    // Set base color with opacity
    baseColorFactor = vm.Vector4(
      fillColor.red / 255.0,
      fillColor.green / 255.0, 
      fillColor.blue / 255.0,
      opacity,
    );
  }
  
  @override
  bool isOpaque() {
    // Return false if we have any transparency
    return baseColorFactor.w >= 1.0;
  }
}
```

### 5. Hybrid Square Renderer
Combine filled geometry with line edges for complete square rendering.

```dart
class FilledSquareRenderer {
  /// Create both fill and edge meshes for a filled square
  static FilledSquareResult createFilledSquare({
    required vm.Vector3 center,
    required double size,
    required SquarePlane plane,
    double rotation = 0.0,
    required Color fillColor,
    required Color edgeColor,
    double edgeWidth = 1.0,
    double opacity = 1.0,
    String? id,
  }) {
    final squareId = id ?? 'filled_square_${DateTime.now().millisecondsSinceEpoch}';
    
    // Create filled interior mesh
    final fillGeometry = FilledSquareGeometry(
      center: center,
      size: size,
      plane: plane,
      rotation: rotation,
    );
    
    final fillMaterial = FilledSquareMaterial(
      fillColor: fillColor,
      opacity: opacity,
    );
    
    final fillMesh = Mesh.primitives(
      primitives: [MeshPrimitive(fillGeometry, fillMaterial)],
    );
    
    // Create edge outline using existing line renderer
    final corners = _calculateSquareCorners(center, size, plane, rotation);
    final edgeLines = LineMeshFactory.createPolyline(
      [...corners, corners[0]], // Close the loop
      lineWidth: edgeWidth,
      color: edgeColor,
      opacity: 1.0, // Edges always opaque for clarity
    );
    
    return FilledSquareResult(
      fillMesh: fillMesh,
      edgeMesh: edgeLines,
      id: squareId,
    );
  }
}

class FilledSquareResult {
  final Mesh fillMesh;
  final Mesh edgeMesh;
  final String id;
  
  const FilledSquareResult({
    required this.fillMesh,
    required this.edgeMesh,
    required this.id,
  });
  
  /// Get both meshes as scene nodes
  List<Node> toNodes() {
    final fillNode = Node()..mesh = fillMesh;
    final edgeNode = Node()..mesh = edgeMesh;
    return [fillNode, edgeNode];
  }
}
```

### 6. Integration with Scene Manager
Extend SceneManager to handle filled square objects and create both fill and edge meshes.

```dart
// In SceneManager._buildSceneFromParsedData()
void _buildSceneFromParsedData(GCodePath gcodePath) {
  try {
    // Existing G-code objects
    final gcodeObjects = GCodeSceneGenerator.generateSceneObjects(gcodePath);
    
    // World axes
    final worldAxes = _createWorldOriginAxes();
    
    // NEW: Add example filled squares for testing
    final filledSquares = _createExampleFilledSquares();
    
    // Convert filled squares to mesh nodes (both fill and edges)
    final squareNodes = filledSquares
        .expand((square) => _createFilledSquareNodes(square))
        .toList();
    
    // Convert existing objects to nodes
    final gcodeNodes = _convertObjectsToNodes(gcodeObjects);
    final axesNodes = _convertObjectsToNodes(worldAxes);
    
    final allNodes = [...gcodeNodes, ...axesNodes, ...squareNodes];
    
    // Update scene with nodes instead of objects
    _sceneData = SceneData(
      nodes: allNodes,  // Changed from objects to nodes
      camera: cameraConfig,
      lighting: lightConfig,
    );
    
    // Rest of scene building...
  }
}

List<SceneObject> _createExampleFilledSquares() {
  return [
    // Semi-transparent work area in XY plane
    SceneObject(
      type: SceneObjectType.filledSquare,
      center: vm.Vector3(0, 0, 0),
      size: 100.0,
      plane: SquarePlane.xy,
      fillColor: Colors.blue.withOpacity(0.2),
      edgeColor: Colors.blue,
      edgeWidth: 2.0,
      opacity: 0.3,
      id: 'work_area_xy',
    ),
    
    // Safety zone in XZ plane
    SceneObject(
      type: SceneObjectType.filledSquare, 
      center: vm.Vector3(50, 0, 25),
      size: 20.0,
      plane: SquarePlane.xz,
      rotation: math.pi / 6, // 30 degree rotation
      fillColor: Colors.red.withOpacity(0.3),
      edgeColor: Colors.red,
      edgeWidth: 1.5,
      id: 'safety_zone_xz',
    ),
  ];
}

List<Node> _createFilledSquareNodes(SceneObject square) {
  assert(square.type == SceneObjectType.filledSquare);
  
  final result = FilledSquareRenderer.createFilledSquare(
    center: square.center!,
    size: square.size!,
    plane: square.plane!,
    rotation: square.rotation ?? 0.0,
    fillColor: square.fillColor ?? square.color,
    edgeColor: square.edgeColor ?? square.color,
    edgeWidth: square.edgeWidth ?? 1.0,
    opacity: square.opacity ?? 1.0,
    id: square.id,
  );
  
  return result.toNodes();
}
```

### 7. Filled Square Factory for Easy Creation
Provide a convenient API for creating filled squares programmatically.

```dart
class FilledSquareFactory {
  /// Create a filled square in the XY plane
  static SceneObject createXYFilledSquare({
    required vm.Vector3 center,
    required double size,
    required Color fillColor,
    Color? edgeColor,
    double edgeWidth = 1.0,
    double opacity = 1.0,
    double rotation = 0.0,
    String? id,
  }) {
    return SceneObject(
      type: SceneObjectType.filledSquare,
      center: center,
      size: size,
      plane: SquarePlane.xy,
      rotation: rotation,
      fillColor: fillColor,
      edgeColor: edgeColor ?? fillColor.withOpacity(1.0),
      edgeWidth: edgeWidth,
      opacity: opacity,
      id: id ?? 'filled_square_xy_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
  
  /// Create a filled square in the XZ plane  
  static SceneObject createXZFilledSquare({
    required vm.Vector3 center,
    required double size,
    required Color fillColor,
    Color? edgeColor,
    double edgeWidth = 1.0,
    double opacity = 1.0,
    double rotation = 0.0,
    String? id,
  }) {
    return SceneObject(
      type: SceneObjectType.filledSquare,
      center: center,
      size: size,
      plane: SquarePlane.xz,
      rotation: rotation,
      fillColor: fillColor,
      edgeColor: edgeColor ?? fillColor.withOpacity(1.0),
      edgeWidth: edgeWidth,
      opacity: opacity,
      id: id ?? 'filled_square_xz_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
  
  /// Create a filled square in the YZ plane
  static SceneObject createYZFilledSquare({
    required vm.Vector3 center,
    required double size,
    required Color fillColor,
    Color? edgeColor,
    double edgeWidth = 1.0,
    double opacity = 1.0,
    double rotation = 0.0,
    String? id,
  }) {
    return SceneObject(
      type: SceneObjectType.filledSquare,
      center: center,
      size: size,
      plane: SquarePlane.yz,
      rotation: rotation,
      fillColor: fillColor,
      edgeColor: edgeColor ?? fillColor.withOpacity(1.0),
      edgeWidth: edgeWidth,
      opacity: opacity,
      id: id ?? 'filled_square_yz_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
  
  /// Create a semi-transparent work area boundary (common CNC use case)
  static SceneObject createWorkAreaBoundary({
    required double width,
    required double height,
    vm.Vector3? center,
    Color fillColor = Colors.blue,
    Color? edgeColor,
    double opacity = 0.2,
    double edgeWidth = 2.0,
  }) {
    return SceneObject(
      type: SceneObjectType.filledSquare,
      center: center ?? vm.Vector3(width/2, height/2, 0),
      size: math.max(width, height),
      plane: SquarePlane.xy,
      fillColor: fillColor.withOpacity(opacity),
      edgeColor: edgeColor ?? fillColor,
      edgeWidth: edgeWidth,
      opacity: opacity,
      id: 'work_area_boundary',
    );
  }
  
  /// Create a safety zone marker (semi-transparent red)
  static SceneObject createSafetyZone({
    required vm.Vector3 center,
    required double size,
    SquarePlane plane = SquarePlane.xy,
    double rotation = 0.0,
  }) {
    return SceneObject(
      type: SceneObjectType.filledSquare,
      center: center,
      size: size,
      plane: plane,
      rotation: rotation,
      fillColor: Colors.red.withOpacity(0.3),
      edgeColor: Colors.red,
      edgeWidth: 1.5,
      opacity: 0.4,
      id: 'safety_zone_${center.hashCode}',
    );
  }
  
  /// Create a coordinate system indicator
  static SceneObject createCoordinateIndicator({
    required vm.Vector3 origin,
    double size = 5.0,
    SquarePlane plane = SquarePlane.xy,
    Color color = Colors.green,
  }) {
    return SceneObject(
      type: SceneObjectType.filledSquare,
      center: origin,
      size: size,
      plane: plane,
      fillColor: color.withOpacity(0.5),
      edgeColor: color,
      edgeWidth: 1.0,
      opacity: 0.7,
      id: 'coordinate_indicator_${origin.hashCode}',
    );
  }
}
```

## Implementation Strategy

### Phase 1: Core Filled Square Support
1. **Extend SceneObject model** - Add filled square properties and SquarePlane enum
2. **Implement FilledSquareGeometry** - New primitive for solid fill rendering
3. **Create FilledSquareMaterial** - Material with transparency support
4. **Build FilledSquareRenderer** - Hybrid renderer combining fill + edges
5. **Test with static squares** - Add example filled squares to verify rendering

### Phase 2: Scene Integration & API
1. **Update SceneManager** - Handle filled square objects in scene building
2. **Create FilledSquareFactory** - Convenient creation methods for common use cases
3. **Integration testing** - Verify filled squares work with existing camera/interaction
4. **Transparency ordering** - Ensure proper depth sorting for semi-transparent fills

### Phase 3: Advanced Features & Optimization
1. **Dynamic square updates** - Modify squares without rebuilding entire scene
2. **Square selection/interaction** - Click handling for both fill and edge areas
3. **Performance optimization** - Batch filled squares for efficient rendering
4. **Specialized square types** - Work area boundaries, safety zones, coordinate indicators

## Performance Considerations

### Rendering Efficiency
- **Hybrid approach** - Fill uses standard geometry pipeline, edges use optimized line renderer
- **Minimal geometry** - Only 2 triangles (6 vertices) per filled square
- **Edge optimization** - Reuse existing high-performance line renderer for outlines
- **Transparency handling** - Proper depth sorting for semi-transparent fills

### Memory Usage
- **Efficient geometry** - Minimal vertex data for square fills
- **Shared line renderer** - Edge rendering shares existing line batching system
- **On-demand creation** - Squares created only when needed during scene building
- **GPU-friendly** - Standard vertex buffer layout compatible with Flutter Scene

### Transparency Performance
- **Depth sorting** - Semi-transparent fills rendered in back-to-front order
- **Alpha blending** - Proper blend modes for realistic transparency
- **Edge clarity** - Opaque edges maintain visibility even with transparent fills
- **Batch separation** - Opaque and transparent squares batched separately

### Update Performance
- **Incremental updates** - Only rebuild changed squares
- **Scene invalidation** - Proper cache invalidation when squares change
- **Culling support** - Squares outside view frustum can be culled
- **LOD potential** - Future support for level-of-detail based on distance

## Use Cases

### 1. Work Area Visualization
```dart
// Semi-transparent machine work envelope with clear boundaries
final workArea = FilledSquareFactory.createWorkAreaBoundary(
  width: machineWidth,
  height: machineHeight,
  center: vm.Vector3(machineWidth/2, machineHeight/2, 0),
  fillColor: Colors.blue,
  edgeColor: Colors.blue,
  opacity: 0.2,
  edgeWidth: 2.0,
);
```

### 2. Tool Path Boundaries
```dart
// Highlight G-code bounding area with subtle fill
final pathBounds = FilledSquareFactory.createXYFilledSquare(
  center: gcodePath.center,
  size: gcodePath.maxDimension,
  fillColor: Colors.yellow.withOpacity(0.1),
  edgeColor: Colors.yellow,
  edgeWidth: 1.5,
  id: 'gcode_bounds',
);
```

### 3. Safety Zones
```dart
// Prominent safety zone with red fill and strong outline
final safetyZone = FilledSquareFactory.createSafetyZone(
  center: vm.Vector3(dangerX, dangerY, 0),
  size: safetyRadius * 2,
  plane: SquarePlane.xy,
);
```

### 4. Coordinate System Indicators
```dart
// Active coordinate system with filled indicator
final g54Origin = FilledSquareFactory.createCoordinateIndicator(
  origin: g54Offset,
  size: 8.0,
  plane: SquarePlane.xy,
  color: Colors.green,
);
```

### 5. Multi-Plane Visualization
```dart
// Show cutting planes in different orientations
final xyPlane = FilledSquareFactory.createXYFilledSquare(
  center: vm.Vector3(0, 0, cutHeight),
  size: 50.0,
  fillColor: Colors.cyan.withOpacity(0.3),
  edgeColor: Colors.cyan,
);

final xzPlane = FilledSquareFactory.createXZFilledSquare(
  center: vm.Vector3(0, cutDepth, 25),
  size: 50.0,
  fillColor: Colors.magenta.withOpacity(0.3),
  edgeColor: Colors.magenta,
);
```

## File Structure

```
lib/
├── scene/
│   ├── scene_manager.dart              # Updated with filled square support
│   └── filled_square_factory.dart      # NEW - FilledSquareFactory
├── models/
│   └── scene_object.dart              # Updated with filled square properties
├── renderers/
│   ├── filled_square_geometry.dart     # NEW - FilledSquareGeometry
│   ├── filled_square_material.dart     # NEW - FilledSquareMaterial  
│   ├── filled_square_renderer.dart     # NEW - FilledSquareRenderer
│   └── line_mesh_factory.dart         # Existing - used for edges
└── geometry/
    └── plane_utils.dart               # NEW - Shared plane calculation utilities
```

## Testing Strategy

### Unit Tests
- **SquareToLinesConverter** - Verify correct corner calculation for all planes
- **Rotation math** - Test rotation calculations for accuracy
- **Edge cases** - Zero size, invalid planes, extreme rotations

### Integration Tests  
- **Scene building** - Squares properly converted and added to scene
- **Rendering** - Squares visible in 3D viewer
- **Performance** - No regression in line rendering performance

### Visual Tests
- **Plane alignment** - Squares properly aligned to XY, XZ, YZ planes
- **Rotation** - Rotated squares render correctly
- **Color/styling** - Square outlines use correct colors and line styles

## Benefits of This Approach

### 1. **Hybrid Rendering Excellence**
- **Best of both worlds**: Solid fills for area visualization + anti-aliased edges for clarity
- **Leverages existing infrastructure**: Reuses proven high-performance line renderer for edges
- **Maintains visual consistency**: Edge styling matches existing G-code line rendering

### 2. **Clean Architecture**
- **First-class scene objects**: Filled squares are proper scene primitives
- **Clear separation**: Fill geometry separate from edge rendering
- **Extensible foundation**: Easy to add filled rectangles, circles, polygons later

### 3. **Performance Optimized**
- **Minimal geometry**: Only 2 triangles per filled square (6 vertices)
- **Efficient batching**: Fill geometry batches separately from edge lines
- **Transparency support**: Proper depth sorting for realistic semi-transparent areas
- **GPU-friendly**: Standard vertex layout compatible with Flutter Scene pipeline

### 4. **Flexible and Extensible**
- **Multi-plane support**: XY, XZ, YZ planes with arbitrary rotations
- **Independent styling**: Separate control over fill color, edge color, opacity, line width
- **Transparency control**: Per-square opacity for layered visualization effects
- **Easy extension**: Foundation for filled rectangles, circles, and complex polygons

### 5. **CNC-Specific Features**
- **Work area visualization**: Semi-transparent machine boundaries with clear edges
- **Safety zone marking**: Prominent filled areas with strong outlines
- **Multi-layer visualization**: Different cutting planes in different orientations
- **Coordinate system indicators**: Clear visual markers for work coordinate systems
- **Tool path boundaries**: Subtle area highlighting with precise edge definition

### 6. **Visual Quality**
- **Professional appearance**: Filled areas provide clear spatial understanding
- **Edge clarity**: Anti-aliased outlines remain visible even with transparent fills
- **Depth perception**: Proper transparency and depth sorting for 3D understanding
- **Customizable styling**: Full control over appearance for different use cases

This hybrid approach provides a robust foundation for filled square rendering that combines the visual clarity of solid fills with the precision of anti-aliased edge rendering, perfectly suited for CNC visualization needs.