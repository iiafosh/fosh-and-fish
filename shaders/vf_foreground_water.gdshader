shader_type canvas_item;
// Stylised foreground water drawn in front of the boat hull.
// Colours come from the biome (manifest.json water_near / water_far / accent).

uniform vec4 near_col : source_color = vec4(0.12, 0.5, 0.62, 1.0);
uniform vec4 far_col : source_color = vec4(0.5, 0.78, 0.86, 1.0);
uniform vec4 foam_col : source_color = vec4(0.9, 0.98, 1.0, 1.0);
uniform float edge = 0.10;
uniform float bob = 0.0;

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float wave = 0.035 * sin(uv.x * 14.0 + t * 1.4) + 0.022 * sin(uv.x * 31.0 - t * 2.1) + bob;
	float top = edge + wave;
	if (uv.y < top) {
		discard;
	}
	float d = uv.y - top;
	vec3 c = mix(far_col.rgb, near_col.rgb, clamp(d * 1.6, 0.0, 1.0));
	float foam = 1.0 - smoothstep(0.0, 0.028, d);
	float s = sin(uv.x * 46.0 + sin(uv.y * 9.0 + t * 0.7) * 3.0 + t * 0.9) * sin(uv.y * 70.0 - t * 1.2);
	float streak = step(0.94, s) * (1.0 - clamp(d * 1.2, 0.0, 1.0));
	c = mix(c, foam_col.rgb, max(foam, streak * 0.7));
	COLOR = vec4(c, 0.96);
}
