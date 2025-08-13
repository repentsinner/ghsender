/*
 * Impeller-Compatible Screen-Space Line Expansion Vertex Shader
 * Based on Three.js Line2/LineSegments2 approach, w/o instanced geometry
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
in vec4 color;         // Line info: [resolution.x, resolution.y, lineWidth, opacity] (4 floats)

// Standard outputs for fragment shader compatibility
out vec3 v_position;      // Line start in world space
out vec3 v_normal;        // Line end in world space  
out vec3 v_viewvector;
out vec2 v_texture_coords;
out vec4 v_color;

void main() {
  // Extract line segment data from repurposed attributes
  vec3 line_start = position;      // Line start point (stored in position)
  vec3 line_end = normal;          // Line end point (stored in normal)
  float side = texture_coords.x;   // Side direction (-1 or +1)
  float u = texture_coords.y;      // U coordinate (0 = start, 1 = end)
  
  // Extract line info from repurposed color attribute
  vec2 resolution = color.xy;      // Screen resolution (width, height)
  float line_width_pixels = color.z; // Line width in pixels
  // color.w is unused - sharpness now comes from material uniform
  
  // Transform line endpoints to clip space
  vec4 clip_start = frame_info.camera_transform * frame_info.model_transform * vec4(line_start, 1.0);
  vec4 clip_end = frame_info.camera_transform * frame_info.model_transform * vec4(line_end, 1.0);
  
  // Convert to Normalized Device Coordinates (NDC)
  vec2 ndc_start = clip_start.xy / clip_start.w;
  vec2 ndc_end = clip_end.xy / clip_end.w;
  
  // Calculate screen-space direction
  vec2 screen_dir = ndc_end - ndc_start;
  
  // Aspect ratio correction
  float aspect = resolution.x / resolution.y;
  
  // Account for clip-space aspect ratio in direction calculation
  screen_dir.x *= aspect;
  screen_dir = normalize(screen_dir);
  
  // Calculate perpendicular vector
  vec2 screen_perp = vec2(-screen_dir.y, screen_dir.x);
  
  // Convert pixel line width to NDC space, adding extra pixels for anti-aliasing
  // Three.js Line2 approach: expand geometry wider than visual line width
  float aa_padding = 1.0; // Extra pixels on each side for anti-aliasing fade
  float expanded_line_width = line_width_pixels + (aa_padding * 2.0);
  float ndc_line_width = expanded_line_width * (2.0 / resolution.y);
  
  // Create offset and apply aspect ratio correction
  vec2 screen_offset = screen_perp * side * ndc_line_width * 0.5;
  
  // Undo aspect ratio adjustment for the offset
  screen_offset.x /= aspect;
  
  // Choose base screen position (start or end based on u coordinate)
  vec2 base_screen_pos = mix(ndc_start, ndc_end, u);
  vec2 expanded_screen_pos = base_screen_pos + screen_offset;
  
  // Use appropriate clip space Z and W from interpolated position
  vec4 base_clip = mix(clip_start, clip_end, u);
  gl_Position = vec4(expanded_screen_pos * base_clip.w, base_clip.z, base_clip.w);
  
  // Calculate world space positions for depth calculation
  vec4 world_start = frame_info.model_transform * vec4(line_start, 1.0);
  vec4 world_end = frame_info.model_transform * vec4(line_end, 1.0);
  
  // Calculate the world position for THIS vertex (interpolated along the line)
  vec3 vertex_world_pos = mix(world_start.xyz, world_end.xyz, u);
  
  // Pass through for fragment shader
  // Since all 4 vertices of a quad have the same start/end but different u values,
  // the interpolation will give us a smooth transition
  v_position = vertex_world_pos;  // This vertex's position on the line
  v_normal = vec3(u, 0.0, 0.0);   // Store u coordinate for debugging
  v_viewvector = frame_info.camera_position - vertex_world_pos;
  
  v_texture_coords = vec2((side + 1.0) * 0.5, u); // Convert side from [-1,1] to [0,1] for smooth anti-aliasing
  v_color = vec4(1.0); // Pass white color to fragment shader (actual color comes from frag_info.color)
}