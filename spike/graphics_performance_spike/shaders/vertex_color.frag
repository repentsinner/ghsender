#version 450 core

// Input from vertex shader
layout(location = 0) in vec3 v_color;
layout(location = 1) in vec3 v_world_pos;

// Output color
layout(location = 0) out vec4 frag_color;

void main() {
  // Calculate distance-based fog effect
  float distance = length(v_world_pos);
  float fog_factor = clamp(1.0 - (distance / 400.0), 0.1, 1.0);
  
  // Apply fog to color
  vec3 final_color = v_color * fog_factor;
  
  // Output final color with full alpha
  frag_color = vec4(final_color, 1.0);
}