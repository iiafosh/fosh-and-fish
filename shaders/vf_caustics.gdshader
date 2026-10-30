shader_type canvas_item;
// The water's surface, masked to water pixels: caustic light in the shallows, thin wave lines everywhere and
// sun sparkle. Patterns shrink toward the far shore, as the camera looks across the water.
// mask: R = water, G = depth (0 shore .. 1 deep), A = coverage. noise: a seamless cloud-like noise.

uniform sampler2D mask : filter_linear;
uniform sampler2D noise : filter_linear, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float gain = 1.0;

float caustic(vec2 p, float t) {
	vec2 q = p;
	float v = 0.0;
	for (int i = 0; i < 3; i++) {
		q += vec2(sin(q.y * 1.7 + t), cos(q.x * 1.3 - t * 1.1)) * 0.55;
		v += abs(sin(q.x + q.y));
	}
	return v / 3.0;
}

void fragment() {
	vec4 m = texture(mask, UV);
	float water = m.r * m.a;
	float depth = m.g;
	float t = TIME * 0.55;
	float w = 1.0 / (0.62 + UV.y * 0.72);               // the perspective: 1.6 at the far side, 0.75 up close
	vec2 p = vec2((UV.x - 0.5) * 1.78, UV.y) * w;
	float k = pow(1.0 - caustic(p * vec2(19.0, 22.0), t), 5.0);
	// thin wave lines: the ridges of a stretched, drifting noise
	float a1 = texture(noise, p * vec2(0.55, 2.6) + vec2(t * 0.014, t * 0.03)).r;
	float a2 = texture(noise, p * vec2(0.9, 3.7) + vec2(-t * 0.02, t * 0.04)).r;
	float lines = smoothstep(0.93, 1.0, 1.0 - abs(a1 + a2 - 1.0) * 1.6);
	// sun sparkle: where two sliding noises peak together; only on the patch of water toward the sun
	float s1 = texture(noise, p * vec2(2.6, 5.4) + vec2(t * 0.012, t * 0.008)).g;
	float s2 = texture(noise, p * vec2(3.5, 7.2) + vec2(-t * 0.01, t * 0.011)).g;
	float sun = smoothstep(0.85, 0.1, length((UV - vec2(0.7, 0.6)) * vec2(1.0, 1.5)));
	float sparkle = smoothstep(1.87, 1.92, s1 + s2 + sun * 0.06) * sun;
	float a = (k * 0.5 * (1.0 - depth * 0.8) + lines * 0.13 + sparkle * 0.75) * gain * water;
	COLOR = vec4(tint.rgb, clamp(a, 0.0, 1.0));
}
