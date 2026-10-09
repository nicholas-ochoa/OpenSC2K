// Shared by horizontal water and the original vertical water-side sprites.
// Include after environment_color so both paths share LUT and ambient rules.
uniform bool water_enabled = false;
uniform bool water_reflections_enabled = true;
uniform bool water_topography = true;
uniform bool water_waves_enabled = false;
uniform float water_season_strength = 0.0;

vec3 water_season_color(vec3 base) {
	if (!environment_enabled || water_season_strength <= 0.0) { return base; }
	vec3 input_color = environment_lut_linear_canvas ? lut_srgb(base) : base;
	float blue = max(input_color.b - min(input_color.r, input_color.g), 0.0);
	vec3 spring = input_color + blue * vec3(0.015, 0.28, -0.10);
	vec3 summer = input_color + blue * vec3(0.0, 0.14, -0.025);
	vec3 autumn = input_color + blue * vec3(0.13, 0.20, -0.20);
	vec3 winter = input_color + blue * vec3(0.11, 0.22, -0.07);
	vec3 seasonal = spring * environment_seasons.x + summer * environment_seasons.y
		+ autumn * environment_seasons.z + winter * environment_seasons.w;
	vec3 colored = mix(input_color, clamp(seasonal, vec3(0.0), vec3(1.0)), water_season_strength);
	if (environment_lut_linear_canvas) { colored = lut_linear(colored); }
	return lut_four(environment_season_luts, colored, environment_season_lut_weights,
		environment_season_lut_strength * water_season_strength);
}

vec3 water_body_tone(vec3 original, float shallows, float variation) {
	vec3 color = original * (0.92 + 0.09 * shallows + variation * 0.075);
	return mix(color, vec3(original.r * 0.9, original.g * 1.45, original.b * 0.94), shallows * 0.22);
}
