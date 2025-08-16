#version 320 es

/*
 * Three.js Line2-style Anti-aliased Line Fragment Shader
 * 
 * Implements distance-based anti-aliasing using UV coordinates from vertex shader
 * Compatible with flutter_scene UnlitMaterial architecture
 */

precision mediump float;

uniform FrameInfo {
  mat4 model_transform;
  mat4 camera_transform;
  vec3 camera_position;
}
frame_info;

uniform FragInfo {
  vec4 color;
  float vertex_color_weight;
}
frag_info;

uniform sampler2D base_color_texture;

in vec3 v_position;       // Line start in world space
in vec3 v_normal;         // Line end in world space
in vec3 v_viewvector;
in vec2 v_texture_coords;
in vec4 v_color;

out vec4 frag_color;

void main() {
  // Get sharpness from material uniform (repurposed vertex_color_weight)
  float sharpness = frag_info.vertex_color_weight;
  
  // Base color calculation (flutter_scene compatibility)
  // For lines, we want solid colors from material, not vertex colors
  vec4 base_color = texture(base_color_texture, v_texture_coords) * frag_info.color;

  // Three.js Line2-style anti-aliasing with expanded geometry
  // v_texture_coords.x contains side coordinate: 0 = left edge, 1 = right edge, 0.5 = center
  float distance_from_center = abs(v_texture_coords.x - 0.5) * 2.0; // Convert to 0-1 range from center
  
  // Account for anti-aliasing padding in geometry (1px padding on each side)
  // For a 3px line with 1px padding on each side = 5px total geometry
  // We want: center 0.5, visual line edges at ~0.21 and ~0.79, geometry edges at 0.0 and 1.0
  float aa_padding_pixels = 1.0; // Must match vertex shader value
  float line_width_pixels = v_color.z; // Default line width 
  float total_width_pixels = line_width_pixels + (aa_padding_pixels * 2.0);
  
  // Visual line boundary in UV space (where the visual line should end)
  float visual_line_radius = (line_width_pixels * 0.5) / (total_width_pixels * 0.5); // ~0.43 for 3px line in 7px geometry
  
  // Calculate anti-aliasing falloff based on sharpness
  // Sharpness controls transition sharpness in the padding area
  float fade_zone_start = mix(visual_line_radius * 0.7, visual_line_radius, sharpness);
  float fade_zone_end = 1.0; // Always fade to zero at geometry edge
  
  // Create smooth alpha falloff at line edges  
  float alpha = 1.0 - smoothstep(fade_zone_start, fade_zone_end, distance_from_center);
  
  // Handle line caps using U coordinate (v_texture_coords.y: 0 = start, 1 = end)
  // For now, use simple rectangular caps - can be enhanced later for rounded caps
  if (v_texture_coords.y < 0.0 || v_texture_coords.y > 1.0) {
    // Outside line segment bounds - fade to transparent
    alpha = 0.0;
  }
  
  // Apply anti-aliasing alpha to final color
  frag_color = base_color;
  frag_color.a = base_color.a * alpha; // Combine material alpha with distance-based alpha
  frag_color.rgb *= frag_color.a;
  
  // Discard fully transparent fragments for performance
  if (frag_color.a < 0.01) {
    discard;
  }
  
  // v_position contains the interpolated world position for this fragment
  // This is interpolated from the vertex positions which were calculated along the line
  vec3 fragment_world_pos = v_position;
  
  // Transform this world position to clip space for depth calculation
  vec4 line_clip_pos = frame_info.camera_transform * vec4(fragment_world_pos, 1.0);
  
  // Calculate proper per-pixel depth
  float clip_space_z = line_clip_pos.z / line_clip_pos.w;
  
  // Standard depth mapping: (-1 to +1) -> (0 to 1) where 0=near, 1=far
  float correct_depth = clip_space_z * 0.5 + 0.5;
  
  // Set fragment depth for proper z-ordering
  // TODO: fix this, the fragDepth is likely not being computed correctly
  // causing depth tests to fail.
  gl_FragDepth = clamp(correct_depth, 0.0, 1.0);

  // Color-code the depth for visual debugging (optional - comment out if too distracting)
  // Uncomment to visualize depth values:
  // frag_color.rgb = mix(frag_color.rgb, vec3(correct_depth, 0.0, 1.0 - correct_depth), 0.3);
}