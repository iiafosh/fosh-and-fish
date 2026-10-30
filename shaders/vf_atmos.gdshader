shader_type canvas_item;
// The air over the whole stage: slow cloud shadows drifting across land and water, and a gentle vignette.

uniform sampler2D noise : filter_linear, repeat_enable;
uniform vec4 shadow : source_color = vec4(0.05, 0.1, 0.22, 1.0);
uniform float clouds = 0.2;         // how dark a cloud's shadow gets (0 where there are no clouds)
uniform float vignette = 0.2;

void fragment() {
	vec2 p = vec2(UV.x * 1.78, UV.y * 1.3);        // (flattened: they lie on the ground, seen at an angle)
	float c = texture(noise, p * 0.62 + TIME * vec2(0.006, 0.0022)).r;
	c = c * 0.75 + texture(noise, p * 1.7 + TIME * vec2(0.009, 0.004)).r * 0.25;
	float sh = smoothstep(0.5, 0.82, c) * clouds;
	float v = smoothstep(0.42, 0.95, length((UV - 0.5) * vec2(1.05, 0.95))) * vignette;
	COLOR = vec4(shadow.rgb, 1.0 - (1.0 - sh) * (1.0 - v));
}
