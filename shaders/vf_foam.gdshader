shader_type canvas_item;
// Foam and a soft shadow on the water around a hull. The texture is the hull's footprint, blurred:
// 1 under the hull, about 0.5 at its edge, 0 a little way out (render_foam in tools/blender/vf_topdown.py).

uniform vec4 foam_color : source_color = vec4(1.0);
uniform vec4 shade_color : source_color = vec4(0.0, 0.12, 0.2, 1.0);
uniform float foam_amount = 1.0;    // 0 for a craft that floats above the water: only its shadow
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float d = texture(TEXTURE, UV).r;
	float t = TIME + seed;
	float n = vnoise(UV * 24.0 + vec2(t * 0.35, -t * 0.22));
	float n2 = vnoise(UV * 52.0 + vec2(-t * 0.5, t * 0.3));
	// the foam hugging the hull swells and shrinks a little
	float hug = d + (n - 0.5) * 0.2 + sin(t * 1.4) * 0.016;
	float f1 = smoothstep(0.385, 0.41, hug);
	// a broken ring further out, drifting away from the hull
	float ph = fract(t * 0.16);
	float r = mix(0.24, 0.05, ph);
	float ring = smoothstep(0.016, 0.004, abs(d + (n - 0.5) * 0.05 - r)) * smoothstep(0.42, 0.56, n2) * sin(ph * 3.14159);
	float foam = clamp(max(f1, ring * 0.85), 0.0, 1.0) * foam_amount;
	float shade = smoothstep(0.0, 0.3, d) * 0.32;
	COLOR = vec4(mix(shade_color.rgb, foam_color.rgb, foam), max(shade, foam * 0.9));
}
