/*
 * Adapted from Three.js LineMaterial Vertex Shader
 * Original source: https://github.com/mrdoob/three.js/blob/master/examples/jsm/lines/LineMaterial.js
 * Date extracted: 2025-01-11
 * License: MIT
 * 
 * Modifications for Flutter Scene compatibility:
 * - Adapted uniform/in naming conventions for flutter_gpu
 * - Simplified shader includes for flutter_scene environment
 * - Removed conditional compilation for initial implementation
 * - Core line tessellation algorithm unchanged
 */

// Standard flutter_scene uniforms  
uniform FrameInfo {
  mat4 model_transform;
  mat4 camera_transform;
  vec3 camera_position;
} frame_info;

// Line-specific uniforms (will be bound by LineMaterial)
uniform LineInfo {
  float line_width;
  vec2 resolution;
} line_info;

// Instanced attributes (per line segment) 
in vec3 instanceStart;
in vec3 instanceEnd;
in vec3 instanceColorStart;
in vec3 instanceColorEnd;

// Vertex attributes (per quad corner)
in vec3 position;
in vec2 uv;

// Outputs to fragment shader
out vec2 vUv;
out vec4 vColor;

void trimSegment( const in vec4 start, inout vec4 end ) {
	// trim end segment so it terminates between the camera plane and the near plane
	// conservative estimate of the near plane
	float a = frame_info.camera_transform[ 2 ][ 2 ]; // 3nd entry in 3th column
	float b = frame_info.camera_transform[ 3 ][ 2 ]; // 3nd entry in 4th column
	float nearEstimate = - 0.5 * b / a;

	float alpha = ( nearEstimate - start.z ) / ( end.z - start.z );
	end.xyz = mix( start.xyz, end.xyz, alpha );
}

void main() {
	// Interpolate color based on position along line
	vColor.xyz = ( position.y < 0.5 ) ? instanceColorStart : instanceColorEnd;
	
	float aspect = line_info.resolution.x / line_info.resolution.y;

	// Transform to camera space (adapted from Three.js modelViewMatrix)
	vec4 start = frame_info.model_transform * vec4( instanceStart, 1.0 );
	vec4 end = frame_info.model_transform * vec4( instanceEnd, 1.0 );

	vUv = uv;

	// Special case for perspective projection, and segments that terminate either in, or behind, the camera plane
	// clearly the gpu firmware has a way of addressing this issue when projecting into ndc space
	// but we need to perform ndc-space calculations in the shader, so we must address this issue directly
	// perhaps there is a more elegant solution -- WestLangley

	bool perspective = ( frame_info.camera_transform[ 2 ][ 3 ] == - 1.0 ); // 4th entry in the 3rd column

	if ( perspective ) {
		if ( start.z < 0.0 && end.z >= 0.0 ) {
			trimSegment( start, end );
		} else if ( end.z < 0.0 && start.z >= 0.0 ) {
			trimSegment( end, start );
		}
	}

	// clip space
	vec4 clipStart = frame_info.camera_transform * start;
	vec4 clipEnd = frame_info.camera_transform * end;

	// ndc space
	vec3 ndcStart = clipStart.xyz / clipStart.w;
	vec3 ndcEnd = clipEnd.xyz / clipEnd.w;

	// direction
	vec2 dir = ndcEnd.xy - ndcStart.xy;

	// account for clip-space aspect ratio
	dir.x *= aspect;
	dir = normalize( dir );

	// Screen-space line rendering (non-world units for simplicity)
	vec2 offset = vec2( dir.y, - dir.x );
	// undo aspect ratio adjustment
	dir.x /= aspect;
	offset.x /= aspect;

	// sign flip
	if ( position.x < 0.0 ) offset *= - 1.0;

	// endcaps
	if ( position.y < 0.0 ) {
		offset += - dir;
	} else if ( position.y > 1.0 ) {
		offset += dir;
	}

	// adjust for linewidth
	offset *= line_info.line_width;

	// adjust for clip-space to screen-space conversion
	offset /= line_info.resolution.y;

	// select end
	vec4 clip = ( position.y < 0.5 ) ? clipStart : clipEnd;

	// back to clip space
	offset *= clip.w;
	clip.xy += offset;

	gl_Position = clip;
}