shader_type canvas_item;
// The water's surface, masked to water pixels: the reflection of the world, caustic light in the shallows, thin wave
// lines everywhere, sun sparkle (and at night, stars). Patterns shrink toward the far shore, as the camera looks across.
// mask: R = water, G = depth (0 shore .. 1 deep), A = coverage. noise: a seamless noise (tools/art/make_fx.py).
// reflection: the world mirrored in the water (render_reflection in tools/blender/vf_topdown.py).

uniform sampler2D mask : filter_linear;
uniform sampler2D noise : filter_linear, repeat_enable;
uniform sampler2D reflection : filter_linear;
uniform vec4 tint : source_color = vec4(1.0);
uniform float gain = 1.0;
uniform float mirror = 0.42;        // how strong the reflection is
uniform vec4 glint : source_color = vec4(1.0);    // the colour of the light on the water
uniform vec2 sun_at = vec2(0.7, 0.6);             // where on the water the sun (or moon) shines back
uniform float sun_glow = 0.0;       // a broad shine there: low sun, or the moon
uniform float stars = 0.0;          // 0 by day, 1 at night

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
	if (water < 0.004) {
		COLOR = vec4(0.0);
	} else {
		float depth = m.g;
		float t = TIME * 0.55;
		float w = 1.0 / (0.62 + UV.y * 0.72);           // the perspective: 1.6 at the far side, 0.75 up close
		vec2 p = vec2((UV.x - 0.5) * 1.78, UV.y) * w;
		float k = pow(1.0 - caustic(p * vec2(19.0, 22.0), t), 5.0);
		// thin wave lines: the ridges of a stretched, drifting noise
		float a1 = texture(noise, p * vec2(0.55, 2.6) + vec2(t * 0.014, t * 0.03)).r;
		float a2 = texture(noise, p * vec2(0.9, 3.7) + vec2(-t * 0.02, t * 0.04)).r;
		float lines = smoothstep(0.93, 1.0, 1.0 - abs(a1 + a2 - 1.0) * 1.6);
		// sparkle: where two sliding noises peak together; on the patch of water toward the sun, or everywhere at night
		float s1 = texture(noise, p * vec2(2.6, 5.4) + vec2(t * 0.012, t * 0.008)).g;
		float s2 = texture(noise, p * vec2(3.5, 7.2) + vec2(-t * 0.01, t * 0.011)).g;
		float sun = smoothstep(0.85, 0.1, length((UV - sun_at) * vec2(1.0, 1.5)));
		float sparkle = smoothstep(1.91, 1.97, s1 + s2 + sun * 0.05) * max(sun, stars * 0.65);
		// the reflection, broken up by the small waves
		vec2 ruv = UV;
		ruv.x += (sin(UV.y * 150.0 + TIME * 2.3) * 0.0016 + sin(UV.y * 71.0 - TIME * 1.4) * 0.0022) * (0.5 + a1);
		ruv.y += sin(UV.x * 90.0 + TIME * 1.7) * 0.001;
		vec4 r = texture(reflection, ruv);
		float ra = r.a * mirror * water;
		// the light on top of it
		float a = (k * 0.5 * (1.0 - depth * 0.8) + lines * 0.11) * gain;
		float g = sparkle * 0.5 * gain + sun * sun_glow;
		a = clamp(a * water, 0.0, 1.0);
		g = clamp(g * water, 0.0, 1.0);
		float light = 1.0 - (1.0 - a) * (1.0 - g);
		vec3 lit = (tint.rgb * a + glint.rgb * g * (1.0 - a)) / max(light, 0.001);
		float total = 1.0 - (1.0 - light) * (1.0 - ra);
		COLOR = vec4((lit * light + r.rgb * ra * (1.0 - light)) / max(total, 0.001), total);
	}
}
