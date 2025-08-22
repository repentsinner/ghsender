#version 320 es

/*
 * Simplified Billboard Vertex Shader
 * 
 * Creates camera-facing quads using view-space expansion instead of 
 * trying to extract camera vectors from matrices.
 * 
 * Approach:
 * 1. Transform billboard center to view space  
 * 2. Expand in view space where X=right, Y=up relative to camera
 * 3. Transform back to clip space
 */

uniform FrameInfo {
  mat4 model_transform;
  mat4 camera_transform;
  vec3 camera_position;
}
frame_info;

// Input vertex attributes (UnskinnedGeometry format, repurposed for billboards)
in vec3 position;      // Local quad corner position: (-0.5,-0.5,0), etc.
in vec3 normal;        // Billboard world position (repurposed)
in vec2 texture_coords; // UV coordinates: (0,1), (1,1), (1,0), (0,0)
in vec4 color;         // Billboard info: [width, height, size_mode, pixel_size] (repurposed)

// Outputs to fragment shader
out vec3 v_position;      // World position for depth calculations
out vec3 v_normal;        // Billboard facing direction
out vec3 v_viewvector;    // Direction from billboard to camera
out vec2 v_texture_coords;
out vec4 v_color;

void main() {
  // Extract billboard data from repurposed UnskinnedGeometry attributes
  vec3 billboard_world_pos = normal;          // Billboard center position (repurposed normal)
  vec2 current_billboard_size = color.xy;     // Width, height (repurposed color.xy)
  float current_size_mode = color.z;          // 0.0 = world space, 1.0 = screen space (repurposed color.z)
  float current_pixel_size = color.w;         // Pixel size for screen-space mode (repurposed color.w)
  
  // DEBUG: For testing coordinate system, temporarily override positions
  // This will help us verify if the transformation pipeline works correctly
  // Comment out after testing
  // if (abs(billboard_world_pos.x) > 0.1) billboard_world_pos = vec3(50.0, 0.0, 0.0); // X-axis test
  // if (abs(billboard_world_pos.y) > 0.1) billboard_world_pos = vec3(0.0, 50.0, 0.0); // Y-axis test  
  // if (abs(billboard_world_pos.z) > 0.1) billboard_world_pos = vec3(0.0, 0.0, 50.0); // Z-axis test
  
  // Step 1: Transform billboard center to view space
  // For debugging: try direct transformation without coordinate system conversion
  vec4 billboard_model_pos = frame_info.model_transform * vec4(billboard_world_pos, 1.0);
  vec4 billboard_view_pos = frame_info.camera_transform * billboard_model_pos;
  
  // Step 2: Calculate final billboard size
  vec2 final_billboard_size = current_billboard_size;
  
  if (current_size_mode > 0.5) { // Screen space mode
    // For screen-space mode, scale size by distance to maintain constant pixel size
    // Distance is simply the Z coordinate in view space (negative)
    float view_distance = -billboard_view_pos.z;
    
    // Convert pixel size to world size at this view distance
    // Assume 60-degree FOV and 800px viewport height
    float tan_half_fov = tan(1.0472 * 0.5); // ~60 degrees / 2
    float world_height_at_distance = 2.0 * view_distance * tan_half_fov;
    float pixels_to_world = world_height_at_distance / 800.0;
    
    // Scale pixel size to world size
    final_billboard_size = vec2(current_pixel_size) * pixels_to_world;
  }
  
  // Step 3: Create billboard quad corners in view space
  // In view space: X=right, Y=up, Z=forward (toward camera)
  // position.xy are normalized coordinates (-0.5 to +0.5)
  vec2 corner_offset = position.xy * final_billboard_size;
  
  // Create the corner position by adding offset to the center
  // The center stays at billboard_view_pos, corners are offset from center
  vec4 corner_view_pos = billboard_view_pos;
  corner_view_pos.x += corner_offset.x;  // Offset this corner right/left from center
  corner_view_pos.y += corner_offset.y;  // Offset this corner up/down from center
  
  // Step 4: Set final position (already in clip space since we applied camera_transform)
  gl_Position = corner_view_pos;
  
  // Step 5: Calculate world position for fragment shader outputs
  // For simplicity, just use the billboard center position
  vec3 world_position = billboard_model_pos.xyz;
  v_position = world_position;
  
  // Billboard faces toward camera
  v_normal = normalize(frame_info.camera_position - world_position);
  v_viewvector = frame_info.camera_position - world_position;
  
  // Pass through texture coordinates  
  v_texture_coords = texture_coords;
  v_color = vec4(1.0);
}