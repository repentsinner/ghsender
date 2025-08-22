#version 320 es

/*
 * Billboard Solid Color Fragment Shader
 * 
 * Simple solid color rendering for testing billboard orientation and 
 * coordinate system conversion. This shader focuses on:
 * - Proper depth testing
 * - Basic alpha blending
 * - Diagnostic capabilities for testing
 */

precision mediump float;

uniform FrameInfo {
  mat4 model_transform;
  mat4 camera_transform;
  vec3 camera_position;
}
frame_info;

uniform FragInfo {
  vec4 color;                    // Billboard base color
  float vertex_color_weight;     // Blend weight between material and vertex colors
}
frag_info;

// Inputs from vertex shader
in vec3 v_position;       // World position of fragment
in vec3 v_normal;         // Billboard facing direction  
in vec3 v_viewvector;     // Direction from billboard to camera
in vec2 v_texture_coords; // UV coordinates (0,0) to (1,1)
in vec4 v_color;          // Vertex color

out vec4 frag_color;

void main() {
  // Base color from material uniform
  vec4 base_color = frag_info.color;
  
  // Blend with vertex color if specified
  if (frag_info.vertex_color_weight > 0.0) {
    base_color = mix(base_color, v_color, frag_info.vertex_color_weight);
  }
  
  // For testing: create a simple gradient based on UV coordinates
  // This helps verify orientation and UV mapping
  vec2 centered_uv = v_texture_coords - 0.5; // Center UV coordinates
  float distance_from_center = length(centered_uv);
  
  // Create a circular gradient for visual testing
  float gradient_factor = 1.0 - smoothstep(0.0, 0.5, distance_from_center);
  
  // Apply gradient to alpha for circular billboards (optional)
  float alpha_multiplier = mix(0.8, 1.0, gradient_factor);
  
  // Final color calculation
  frag_color = base_color;
  frag_color.a *= alpha_multiplier;
  
  // Premultiply alpha for proper blending
  frag_color.rgb *= frag_color.a;
  
  // Discard fully transparent fragments for performance
  if (frag_color.a < 0.01) {
    discard;
  }
  
  // Calculate proper depth for z-ordering
  // Transform world position to clip space for depth calculation
  vec4 clip_pos = frame_info.camera_transform * frame_info.model_transform * vec4(v_position, 1.0);
  float clip_space_z = clip_pos.z / clip_pos.w;
  
  // Convert from clip space (-1 to +1) to depth buffer space (0 to 1)
  float depth = clip_space_z * 0.5 + 0.5;
  gl_FragDepth = clamp(depth, 0.0, 1.0);
  
  // Optional: Color-code UV coordinates for debugging
  // Uncomment to visualize UV mapping:
  // frag_color.rg = mix(frag_color.rg, v_texture_coords, 0.3);
  
  // Optional: Color-code depth for debugging
  // Uncomment to visualize depth values:
  // frag_color.rgb = mix(frag_color.rgb, vec3(depth, 0.0, 1.0 - depth), 0.2);
}