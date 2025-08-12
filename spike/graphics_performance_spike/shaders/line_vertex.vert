/*
 * Flutter Scene UnskinnedGeometry Vertex Shader (Exact Copy)
 * 
 * This is the exact vertex shader used by flutter_scene's UnskinnedGeometry.
 * Source: https://github.com/bdero/flutter_scene/blob/master/shaders/flutter_scene_unskinned.vert
 */

uniform FrameInfo {
  mat4 model_transform;
  mat4 camera_transform;
  vec3 camera_position;
}
frame_info;

in vec3 position;
in vec3 normal;
in vec2 texture_coords;
in vec4 color;

out vec3 v_position;
out vec3 v_normal;
out vec3 v_viewvector;
out vec2 v_texture_coords;
out vec4 v_color;

void main() {
  vec4 model_position = frame_info.model_transform * vec4(position, 1.0);
  v_position = model_position.xyz;
  gl_Position = frame_info.camera_transform * model_position;
  v_viewvector = frame_info.camera_position - v_position;
  v_normal = (mat3(frame_info.model_transform) * normal).xyz;
  v_texture_coords = texture_coords;
  v_color = color;
}