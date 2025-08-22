#version 320 es

/*
 * Billboard Vertex Shader - Clip Space Sizing
 * 
 * Creates camera-facing quads using pixel-accurate clip-space sizing.
 * 
 * Approach:
 * 1. Transform billboard center to clip space using combined camera transform
 * 2. Generate quad corners in shader using gl_VertexID
 * 3. Apply pixel-accurate sizing directly in clip space
 * 4. Automatic aspect ratio preservation through viewport-aware NDC conversion
 */

uniform FrameInfo {
  mat4 model_transform;
  mat4 camera_transform;  // Combined view-projection matrix
  vec3 camera_position;
}
frame_info;

// Input vertex attributes (UnskinnedGeometry format, semantically correct)
in vec3 position;       // Billboard center world position
in vec3 normal;         // Corner offset: xy=corner position (-0.5 to +0.5), z=unused
in vec2 texture_coords; // UV coordinates for texture mapping
in vec4 color;          // Billboard info: [width_pixels, height_pixels, viewport_width, viewport_height]

// Outputs to fragment shader
out vec3 v_position;      // World position for depth calculations
out vec3 v_normal;        // Billboard facing direction
out vec3 v_viewvector;    // Direction from billboard to camera
out vec2 v_texture_coords;
out vec4 v_color;

void main() {
  // Extract billboard data from vertex attributes
  vec3 billboard_world_pos = position;        // Billboard center world position
  vec2 billboard_pixel_size = color.xy;       // Width, height in pixels
  vec2 viewport_size = color.zw;              // Viewport width, height in pixels
  
  // Step 1: Transform billboard center to clip space
  vec4 billboard_model_pos = frame_info.model_transform * vec4(billboard_world_pos, 1.0);
  vec4 billboard_clip_pos = frame_info.camera_transform * billboard_model_pos;
  
  // Step 2: Get quad corner from normal attribute
  // Corner offset is passed via normal.xy attribute
  vec2 quad_corner = normal.xy;
  
  // Step 3: Convert pixel size to NDC (Normalized Device Coordinates)
  // NDC range is -1 to +1 (total range of 2.0) maps to viewport dimensions
  vec2 ndc_size = (billboard_pixel_size / viewport_size) * 2.0;
  
  // Step 4: Apply corner offset in clip space with perspective correction
  // Multiply by w component to maintain proper perspective scaling
  vec2 corner_offset = quad_corner * ndc_size * billboard_clip_pos.w;
  billboard_clip_pos.xy += corner_offset;
  
  // Step 5: Set final position
  gl_Position = billboard_clip_pos;
  
  // Step 6: Calculate outputs for fragment shader
  vec3 world_position = billboard_model_pos.xyz;
  v_position = world_position;
  
  // Billboard faces toward camera
  v_normal = normalize(frame_info.camera_position - world_position);
  v_viewvector = frame_info.camera_position - world_position;
  
  // Pass through texture coordinates for texturing
  v_texture_coords = texture_coords;
  v_color = vec4(1.0);
}