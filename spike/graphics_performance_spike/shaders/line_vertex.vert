/*
 * Screen-Space Line Expansion Vertex Shader
 * Based on Three.js Line2/LineSegments2 approach
 * 
 * Interprets vertex attributes as line segment data and performs 
 * screen-space expansion for consistent line thickness.
 */

uniform FrameInfo {
  mat4 model_transform;
  mat4 camera_transform;
  vec3 camera_position;
}
frame_info;

// Input vertex attributes (repurposed to carry line segment data)
in vec3 position;      // Line start point (3 floats)
in vec3 normal;        // Line end point (3 floats) 
in vec2 texture_coords; // [side, u] where side = -1/+1, u = 0/1 (2 floats)
in vec4 color;         // Color data (4 floats)

// Standard outputs for fragment shader compatibility
out vec3 v_position;
out vec3 v_normal;
out vec3 v_viewvector;
out vec2 v_texture_coords;
out vec4 v_color;

void main() {
  // Extract line segment data from repurposed attributes
  vec3 line_start = position;      // Line start point (stored in position)
  vec3 line_end = normal;          // Line end point (stored in normal)
  float side = texture_coords.x;   // Side direction (-1 or +1)
  float u = texture_coords.y;      // U coordinate (0 = start, 1 = end)
  
  // Transform line endpoints to clip space
  vec4 clip_start = frame_info.camera_transform * frame_info.model_transform * vec4(line_start, 1.0);
  vec4 clip_end = frame_info.camera_transform * frame_info.model_transform * vec4(line_end, 1.0);
  
  // Convert to normalized device coordinates
  vec2 ndc_start = clip_start.xy / clip_start.w;
  vec2 ndc_end = clip_end.xy / clip_end.w;
  
  // Calculate screen-space direction and perpendicular
  vec2 screen_dir = normalize(ndc_end - ndc_start);
  vec2 screen_perp = vec2(-screen_dir.y, screen_dir.x);
  
  // Fixed line width in screen space (can be made configurable via uniforms later)
  float line_width = 0.002; // Adjust this value to control line thickness
  
  // Expand line by half width in screen space
  vec2 screen_offset = screen_perp * side * line_width * 0.5;
  
  // Choose base screen position (start or end based on u coordinate)
  vec2 base_screen_pos = mix(ndc_start, ndc_end, u);
  vec2 expanded_screen_pos = base_screen_pos + screen_offset;
  
  // Use appropriate clip space Z and W from interpolated position
  vec4 base_clip = mix(clip_start, clip_end, u);
  gl_Position = vec4(expanded_screen_pos * base_clip.w, base_clip.z, base_clip.w);
  
  // Standard outputs for fragment shader compatibility
  vec4 model_position = frame_info.model_transform * vec4(mix(line_start, line_end, u), 1.0);
  v_position = model_position.xyz;
  v_viewvector = frame_info.camera_position - v_position;
  v_normal = vec3(0.0, 0.0, 1.0);  // Use consistent normal for lines
  v_texture_coords = vec2(side > 0.0 ? 1.0 : 0.0, u); // Convert side to 0/1 for fragment shader
  v_color = color;
}