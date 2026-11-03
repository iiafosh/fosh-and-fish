shader_type canvas_item;
// The backdrop, with wind in its trees. sway: how far each pixel moves (0 at the foot of a tree, 1 high up in it).

uniform sampler2D sway : filter_linear;
uniform float wind = 1.0;

void fragment() {
	float m = texture(sway, UV).r * wind;
	vec2 uv = UV;
	if (m > 0.004) {
		float t = TIME;
		float gust = 0.55 + 0.45 * sin(t * 0.43 + UV.x * 5.0 + sin(t * 0.17) * 2.0);
		uv.x += m * gust * (sin(t * 1.5 + UV.x * 31.0 + UV.y * 17.0) * 0.0023 + sin(t * 3.1 + UV.y * 61.0 + UV.x * 23.0) * 0.0007);
		uv.y += m * gust * sin(t * 1.9 + UV.x * 43.0) * 0.001;
	}
	COLOR = texture(TEXTURE, uv);
}
