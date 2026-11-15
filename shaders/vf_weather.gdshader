shader_type canvas_item;
// The weather over the whole stage, laid on top of the scene (vf_world.gd): a storm's gloom, fog, rain, falling ash and
// embers, a glow bloom's drifting lights, an aurora's curtains, and lightning's flash. Each is 0 (off) .. 1.

uniform sampler2D noise : filter_linear, repeat_enable;
uniform float rain = 0.0;
uniform float fog = 0.0;
uniform float ash = 0.0;
uniform float gloom = 0.0;
uniform float flash = 0.0;
uniform float aurora = 0.0;
uniform float bloom = 0.0;
uniform vec3 fog_col : source_color = vec3(0.9, 0.94, 0.96);
uniform vec3 aurora_a : source_color = vec3(0.3, 1.0, 0.62);
uniform vec3 aurora_b : source_color = vec3(0.78, 0.42, 1.0);
uniform vec3 bloom_col : source_color = vec3(0.45, 1.0, 0.88);

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

// thin streaks falling down slanted columns
float streaks(vec2 uv, float cols, float speed, float len, float thin) {
	uv.x += uv.y * 0.16;
	float c = floor(uv.x * cols);
	float fx = abs(fract(uv.x * cols) - 0.5);
	float y = fract(uv.y * (0.9 + hash(c) * 0.5) - TIME * speed * (0.8 + hash(c + 3.0) * 0.5) + hash(c + 7.0));
	return smoothstep(len, 0.0, y) * smoothstep(0.0, 0.012, y) * smoothstep(thin, 0.0, fx) * step(0.3, hash(c + 11.0));
}

// soft dots drifting (down for ash, up for a bloom)
float flakes(vec2 uv, float cells, float speed, float sway, float keep) {
	vec2 g = uv * vec2(cells * 1.78, cells);
	g.y -= TIME * speed;
	g.x += sin(TIME * 0.5 + floor(g.y) * 1.7) * sway;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id.x * 17.0 + id.y * 131.0);
	vec2 o = vec2(hash(h * 91.0) - 0.5, hash(h * 53.0) - 0.5) * 0.6;
	float r = 0.05 + 0.09 * hash(h * 7.0);
	return smoothstep(r, r * 0.3, length(f - o)) * step(keep, h);
}

void over(inout vec4 acc, vec3 c, float a) {
	a = clamp(a, 0.0, 1.0);
	acc.rgb = acc.rgb * (1.0 - a) + c * a;
	acc.a = acc.a * (1.0 - a) + a;
}

void fragment() {
	vec4 acc = vec4(0.0);
	over(acc, vec3(0.06, 0.09, 0.17), gloom * 0.36);
	if (aurora > 0.001) {
		for (int i = 0; i < 2; i++) {
			float k = float(i);
			float y0 = 0.2 + 0.2 * k + 0.07 * sin(UV.x * (4.0 + k * 2.0) + TIME * 0.25 + k * 2.0) + 0.035 * sin(UV.x * 11.0 - TIME * 0.18);
			float d = UV.y - y0;
			float glow = (d < 0.0) ? exp(d * 9.0) : smoothstep(0.035, 0.0, d);
			float rays = 0.55 + 0.45 * texture(noise, vec2(UV.x * 3.0 + k * 0.4 + TIME * 0.01, 0.3 + k * 0.2)).r;
			over(acc, mix(aurora_a, aurora_b, clamp(-d * 5.0 + k * 0.3, 0.0, 1.0)), aurora * 0.5 * glow * rays);
		}
	}
	if (fog > 0.001) {
		float n = texture(noise, UV * vec2(1.2, 0.8) + TIME * vec2(0.012, 0.004)).r;
		n = n * 0.65 + texture(noise, UV * vec2(2.6, 1.9) - TIME * vec2(0.008, 0.006)).r * 0.35;
		over(acc, fog_col, fog * (0.08 + 0.3 * smoothstep(0.3, 0.85, n)));
	}
	if (bloom > 0.001) {
		float b = flakes(UV, 9.0, -0.22, 0.25, 0.5) + flakes(UV + 0.31, 15.0, -0.35, 0.2, 0.62) * 0.7;
		float pulse = 0.7 + 0.3 * sin(TIME * 1.3 + UV.x * 9.0 + UV.y * 5.0);
		over(acc, bloom_col, bloom * 0.8 * b * pulse);
	}
	if (ash > 0.001) {
		over(acc, vec3(0.3, 0.28, 0.28), ash * 0.75 * flakes(UV, 13.0, 1.1, 0.35, 0.45));
		over(acc, vec3(0.42, 0.4, 0.4), ash * 0.6 * flakes(UV + 0.47, 21.0, 1.6, 0.3, 0.5));
		over(acc, vec3(1.0, 0.56, 0.16), ash * 0.9 * flakes(UV + 0.13, 8.0, 0.7, 0.5, 0.78));
	}
	if (rain > 0.001) {
		float r = streaks(UV, 130.0, 1.7, 0.085, 0.09) + streaks(UV + vec2(0.37, 0.21), 210.0, 2.3, 0.06, 0.1) * 0.6;
		over(acc, vec3(0.86, 0.93, 1.0), rain * 0.5 * r);
	}
	over(acc, vec3(1.0, 1.0, 0.96), flash * 0.42);
	COLOR = vec4(acc.rgb / max(acc.a, 0.0001), acc.a);
}
