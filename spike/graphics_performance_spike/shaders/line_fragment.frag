/*
 * Adapted from Three.js LineMaterial Fragment Shader
 * Original source: https://github.com/mrdoob/three.js/blob/master/examples/jsm/lines/LineMaterial.js
 * Date extracted: 2025-01-11
 * License: MIT
 * 
 * Modifications for Flutter Scene compatibility:
 * - Adapted uniform naming conventions for flutter_gpu
 * - Simplified for screen-space rendering (no world units initially)
 * - Removed conditional compilation for initial implementation
 * - Core anti-aliasing algorithm unchanged
 */

// Standard flutter_scene UnlitMaterial uniforms (must match UnlitMaterial.dart)
uniform FragInfo {
  vec4 base_color_factor;
  float vertex_color_weight;
} frag_info;

// Inputs from vertex shader
in vec2 vUv;
in vec4 vColor;

// Output
out vec4 fragColor;

void main() {
	// Use UnlitMaterial's baseColorFactor (RGBA)
	vec4 diffuseColor = frag_info.base_color_factor;

	// Screen-space anti-aliasing (adapted from Three.js non-world-units path)
	// This is the core anti-aliasing algorithm from Three.js
	if ( abs( vUv.y ) > 1.0 ) {
		float a = vUv.x;
		float b = ( vUv.y > 0.0 ) ? vUv.y - 1.0 : vUv.y + 1.0;
		float len2 = a * a + b * b;

		if ( len2 > 1.0 ) discard;
	}

	// Apply vertex color modulation
	diffuseColor.rgb *= vColor.rgb;
	diffuseColor.a *= vColor.a;

	fragColor = diffuseColor;
}