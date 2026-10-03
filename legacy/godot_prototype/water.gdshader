shader_type canvas_item;

// Ocean & River Water Shader for Virtual Fisher Overworld
uniform vec4 deep_color : source_color = vec4(0.04, 0.12, 0.22, 0.95);
uniform vec4 shallow_color : source_color = vec4(0.08, 0.32, 0.42, 0.85);
uniform vec4 foam_color : source_color = vec4(0.65, 0.88, 0.95, 0.60);
uniform vec4 highlight_color : source_color = vec4(0.35, 0.75, 0.88, 0.35);

uniform float wave_speed : hint_range(0.1, 5.0) = 1.2;
uniform float wave_frequency : hint_range(1.0, 50.0) = 16.0;
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.015;
uniform float caustic_intensity : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec2 uv = UV;
	float t = TIME * wave_speed;

	// Dual wave sine ripples
	float wave1 = sin(uv.x * wave_frequency + t * 1.5) * cos(uv.y * wave_frequency * 0.7 + t);
	float wave2 = cos(uv.x * wave_frequency * 0.5 - t * 0.8) * sin(uv.y * wave_frequency + t * 1.2);
	float combined_wave = (wave1 + wave2) * 0.5;

	// Distort coordinates slightly
	vec2 distorted_uv = uv + vec2(wave1, wave2) * wave_amplitude;

	// Caustic glints
	float caustic = sin(distorted_uv.x * 28.0 + t * 2.0) * sin(distorted_uv.y * 28.0 - t * 1.8);
	caustic = pow(max(0.0, caustic), 3.0) * caustic_intensity;

	// Gradient depth
	vec4 water_col = mix(deep_color, shallow_color, smoothstep(0.2, 0.8, uv.y + combined_wave * 0.1));
	water_col = mix(water_col, highlight_color, caustic);

	// Edge foam
	float foam = smoothstep(0.42, 0.50, combined_wave);
	water_col = mix(water_col, foam_color, foam * 0.35);

	COLOR = water_col;
}
