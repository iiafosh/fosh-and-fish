shader_type canvas_item;
render_mode blend_mul;
// The light over the whole stage, multiplied onto everything: the time of day (land and water apart, so lava can glow
// at night), slow cloud shadows drifting across, and a gentle vignette.

uniform sampler2D noise : filter_linear, repeat_enable;
uniform sampler2D mask : filter_linear;
uniform vec3 land = vec3(1.0);
uniform vec3 water = vec3(1.0);
uniform float clouds = 0.16;        // how dark a cloud's shadow gets (0 where there are no clouds)
uniform float vignette = 0.2;

void fragment() {
	vec2 p = vec2(UV.x * 1.78, UV.y * 1.3);        // (flattened: they lie on the ground, seen at an angle)
	float c = texture(noise, p * 0.62 + TIME * vec2(0.006, 0.0022)).r;
	c = c * 0.75 + texture(noise, p * 1.7 + TIME * vec2(0.009, 0.004)).r * 0.25;
	float sh = smoothstep(0.5, 0.82, c) * clouds;
	float v = smoothstep(0.42, 0.95, length((UV - 0.5) * vec2(1.05, 0.95))) * vignette;
	vec4 m = texture(mask, UV);
	vec3 light = mix(land, water, m.r * m.a);
	vec3 shade = vec3(0.1, 0.2, 0.36);             // what's left in the blue of a shadow
	light *= mix(vec3(1.0), shade, sh);
	light *= mix(vec3(1.0), shade, v);
	COLOR = vec4(light, 1.0);
}
