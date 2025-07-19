#version 450 core

// Vertex attributes
layout(location = 0) in vec3 position;
layout(location = 1) in vec3 color;

// Uniforms
layout(set = 0, binding = 0) uniform UniformData {
  mat4 mvp_matrix;
} uniforms;

// Output to fragment shader
layout(location = 0) out vec3 v_color;
layout(location = 1) out vec3 v_world_pos;
layout(location = 2) out vec3 v_barycentric;

void main() {
  // Transform vertex position by MVP matrix
  gl_Position = uniforms.mvp_matrix * vec4(position, 1.0);
  
  // Pass color to fragment shader
  v_color = color;
  
  // Pass world position for depth-based effects
  v_world_pos = position;
  
  // Generate barycentric coordinates for wireframe rendering
  // For indexed rendering, we use a simple hash to distribute coordinates
  // This ensures each vertex gets consistent barycentric coordinates
  int hash = gl_VertexIndex * 1327; // Simple hash for distribution
  int baryIndex = hash % 3;
  
  if (baryIndex == 0) {
    v_barycentric = vec3(1.0, 0.0, 0.0);
  } else if (baryIndex == 1) {
    v_barycentric = vec3(0.0, 1.0, 0.0);
  } else {
    v_barycentric = vec3(0.0, 0.0, 1.0);
  }
}