shader_type canvas_item;
// Animated caustic light on the water, masked to water pixels.
// mask: R = water, G = depth (0 shore .. 1 deep), A = coverage.

uniform sampler2D mask : filter_linear;
uniform vec4 tint : source_color = vec4(1.0);

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
	float k = pow(1.0 - caustic(UV * vec2(34.0, 19.0), t), 5.0);
	float sparkle = step(0.985, fract(sin(dot(floor(UV * vec2(260.0, 146.0)), vec2(12.9898, 78.233)) + floor(TIME * 2.0)) * 43758.5453));
	float a = (k * 0.55 * (1.0 - depth * 0.8) + sparkle * 0.5 * (1.0 - depth)) * water;
	COLOR = vec4(tint.rgb, a);
}
