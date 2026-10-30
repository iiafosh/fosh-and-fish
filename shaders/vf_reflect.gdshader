shader_type canvas_item;
// A boat's reflection on the water (render_boat_reflection in tools/blender/vf_topdown.py), broken up by the small waves.

uniform float strength = 0.42;
uniform vec4 water : source_color = vec4(0.1, 0.5, 0.6, 1.0);
uniform float seed = 0.0;

void fragment() {
	vec2 uv = UV;
	float t = TIME + seed;
	uv.x += sin(UV.y * 120.0 + t * 2.3) * 0.0035 + sin(UV.y * 53.0 - t * 1.4) * 0.0035;
	vec4 c = texture(TEXTURE, uv);
	COLOR = vec4(mix(c.rgb, water.rgb, 0.3), c.a * strength);
}
