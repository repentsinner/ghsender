#version 320 es

/*
 * Billboard Vertex Shader - Three.js Sprite System Equivalent
 * 
 * Creates camera-facing quads that maintain orientation towards the camera
 * regardless of camera position. Handles both world-space and screen-space
 * sizing modes with proper coordinate system conversion.
 * 
 * Key features:
 * - GPU-based billboard orientation (no CPU matrix calculations)
 * - Right-handed CNC to left-handed Impeller coordinate system conversion
 * - Screen-space size invariance
 * - Correct winding order to avoid back-face culling
 */

uniform FrameInfo {
  mat4 model_transform;
  mat4 camera_transform;
  vec3 camera_position;
}
frame_info;

// Billboard-specific uniforms
uniform BillboardInfo {
  vec3 billboard_position;    // Billboard center position in world space (CNC coordinates)
  vec2 billboard_size;        // Width, height in world units or pixels (depending on size_mode)
  float size_mode;           // 0.0 = world space, 1.0 = screen space
  vec2 screen_resolution;    // Viewport width, height for screen-space calculations
  float field_of_view;       // Camera FOV in radians for screen-space calculations
}
billboard_info;

// Input vertex attributes (simple quad)
in vec3 position;      // Quad corner position: (-0.5,-0.5,0), (0.5,-0.5,0), (0.5,0.5,0), (-0.5,0.5,0)
//in vec3 normal;        // Not used for billboards (could be repurposed for orientation later)
in vec2 texture_coords; // UV coordinates: (0,1), (1,1), (1,0), (0,0)
in vec4 color;         // Vertex color (passed through)

// Outputs to fragment shader
out vec3 v_position;      // World position for depth calculations
out vec3 v_normal;        // Billboard facing direction
out vec3 v_viewvector;    // Direction from billboard to camera
out vec2 v_texture_coords;
out vec4 v_color;

void main() {
  // Step 1: Convert billboard position from CNC coordinates to display coordinates
  // Apply Y-negation transformation: CNC(x,y,z) -> Display(x,-y,z)
  vec3 display_billboard_pos = vec3(
    billboard_info.billboard_position.x,
    -billboard_info.billboard_position.y,  // Y-negation for coordinate system conversion
    billboard_info.billboard_position.z
  );
  
  // Step 2: Calculate camera direction vectors from camera transform matrix
  // Extract camera basis vectors from view matrix (inverse of camera transform)
  mat4 view_matrix = inverse(frame_info.camera_transform);
  
  // Camera right vector (world X-axis in camera space) - Row 0 of view matrix
  vec3 camera_right = normalize(vec3(view_matrix[0][0], view_matrix[1][0], view_matrix[2][0]));
  
  // Camera up vector (world Y-axis in camera space) - Row 1 of view matrix  
  vec3 camera_up = normalize(vec3(view_matrix[0][1], view_matrix[1][1], view_matrix[2][1]));
  
  // Step 3: Calculate billboard size based on size mode
  vec2 final_billboard_size = billboard_info.billboard_size;
  
  if (billboard_info.size_mode > 0.5) { // Screen space mode
    // Calculate distance from camera to billboard (both in display coordinates)
    float camera_distance = length(frame_info.camera_position - display_billboard_pos);
    
    // Convert pixel size to world size using perspective projection
    // Formula: worldSize = pixelSize * (2 * distance * tan(fov/2)) / screenHeight
    float world_height_at_distance = 2.0 * camera_distance * tan(billboard_info.field_of_view / 2.0);
    
    // Scale factor from pixels to world units
    float pixels_to_world = world_height_at_distance / billboard_info.screen_resolution.y;
    
    // Convert pixel sizes to world sizes
    final_billboard_size = billboard_info.billboard_size * pixels_to_world;
  }
  
  // Step 4: Create billboard quad in camera-aligned space
  // position.xy contains the local quad coordinates (-0.5 to 0.5)
  vec3 local_offset = 
    camera_right * position.x * final_billboard_size.x +
    camera_up * position.y * final_billboard_size.y;
  
  // Step 5: Final world position of this vertex
  vec3 world_position = display_billboard_pos + local_offset;
  
  // Step 6: Transform to clip space using the full transform pipeline
  // Apply model transform first (this includes the CNC->Impeller transform at root level)
  vec4 model_position = frame_info.model_transform * vec4(world_position, 1.0);
  
  // Then apply camera transform
  gl_Position = frame_info.camera_transform * model_position;
  
  // Step 7: Calculate outputs for fragment shader
  v_position = world_position;  // World position for depth calculations
  
  // Billboard normal points towards camera (for lighting calculations if needed)
  vec3 to_camera = normalize(frame_info.camera_position - display_billboard_pos);
  v_normal = to_camera;
  
  // View vector for potential lighting calculations
  v_viewvector = frame_info.camera_position - world_position;
  
  // Pass through texture coordinates and color
  v_texture_coords = texture_coords;
  v_color = color;
}