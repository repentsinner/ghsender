#version 320 es

/*
 * Billboard Textured Fragment Shader
 * 
 * Handles texture-mapped billboards for sprites and text rendering.
 * Supports alpha transparency, proper blending, and maintains compatibility
 * with the existing texture creation pipeline.
 */

precision mediump float;

uniform FrameInfo {
  mat4 model_transform;
  mat4 camera_transform;
  vec3 camera_position;
}
frame_info;

uniform FragInfo {
  vec4 color;                    // Billboard tint color
  float vertex_color_weight;     // Blend weight between material and vertex colors
}
frag_info;

// Texture sampler for billboard content (sprites, text, etc.)
uniform sampler2D base_color_texture;

// Inputs from vertex shader
in vec3 v_position;       // World position of fragment
in vec3 v_normal;         // Billboard facing direction
in vec3 v_viewvector;     // Direction from billboard to camera
in vec2 v_texture_coords; // UV coordinates (0,0) to (1,1)
in vec4 v_color;          // Vertex color

out vec4 frag_color;

void main() {
  // Sample texture at UV coordinates
  vec4 texture_color = texture(base_color_texture, v_texture_coords);
  
  // Base color from material uniform (used as tint)
  vec4 base_color = frag_info.color;
  
  // Blend with vertex color if specified
  if (frag_info.vertex_color_weight > 0.0) {
    base_color = mix(base_color, v_color, frag_info.vertex_color_weight);
  }
  
  // Combine texture color with material tint
  // This allows the same texture to be tinted different colors
  frag_color = texture_color * base_color;
  
  // For text rendering: preserve alpha channel from texture
  // For sprite rendering: combine alpha channels
  frag_color.a = texture_color.a * base_color.a;
  
  // Discard fully transparent fragments for performance
  if (frag_color.a < 0.01) {
    discard;
  }
  
  // Note: Flutter's rawRgba format already contains premultiplied alpha
  // No additional premultiplication needed here
  
  // Calculate proper depth for z-ordering
  // Transform world position to clip space for depth calculation
  vec4 clip_pos = frame_info.camera_transform * frame_info.model_transform * vec4(v_position, 1.0);
  float clip_space_z = clip_pos.z / clip_pos.w;
  
  // Convert from clip space (-1 to +1) to depth buffer space (0 to 1)
  float depth = clip_space_z * 0.5 + 0.5;
  gl_FragDepth = clamp(depth, 0.0, 1.0);
  
  // Optional: Debug visualizations (comment out for production)
  
  // Show UV coordinates as red/green channels
  // frag_color.rg = mix(frag_color.rg, v_texture_coords, 0.2);
  
  // Show texture alpha channel as blue intensity
  // frag_color.b = mix(frag_color.b, texture_color.a, 0.3);
  
  // Show depth as intensity variation
  // frag_color.rgb = mix(frag_color.rgb, vec3(depth), 0.1);
}