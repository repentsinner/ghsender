#version 450 core

// Input from vertex shader
layout(location = 0) in vec3 v_color;
layout(location = 1) in vec3 v_world_pos;
layout(location = 2) in vec3 v_barycentric;

// Output color
layout(location = 0) out vec4 frag_color;

void main() {
  // Calculate distance-based fog effect (same as vertex_color.frag)
  float distance = length(v_world_pos);
  float fog_factor = clamp(1.0 - (distance / 400.0), 0.1, 1.0);
  
  // Apply fog to base color
  vec3 base_color = v_color * fog_factor;
  
  // Barycentric coordinate wireframe rendering
  // Find the minimum distance to any edge
  float edge_factor = min(min(v_barycentric.x, v_barycentric.y), v_barycentric.z);
  
  // Create wireframe lines with smooth edges
  float wireframe_width = 0.02;  // Adjust this to change line thickness
  float edge_smoothness = 0.01;  // Smoothness of the edge transition
  
  // Use smoothstep for clean antialiased edges
  float wireframe = 1.0 - smoothstep(wireframe_width - edge_smoothness, 
                                    wireframe_width + edge_smoothness, 
                                    edge_factor);
  
  // Mix base color with white wireframe lines
  vec3 final_color = mix(base_color, vec3(1.0, 1.0, 1.0), wireframe * 0.8);
  
  // Output final color
  frag_color = vec4(final_color, 1.0);
}