uniform bool environment_enabled = false;
uniform vec3 environment_tint = vec3(1.0);
uniform float environment_saturation = 1.0;
uniform float environment_night = 0.0;
uniform float environment_ambient_lift = 0.0;
uniform sampler2D environment_emission : source_color, filter_nearest, repeat_disable;
uniform bool environment_has_emission = false;
// LUT pixels are numeric sRGB data. Never let the sampler gamma-decode them.
uniform sampler2D environment_lut : filter_linear, repeat_disable;
uniform float environment_lut_size = 0.0;
uniform bool environment_lut_linear_canvas = false;
uniform sampler2D environment_day_luts : filter_linear, repeat_disable;
uniform sampler2D environment_season_luts : filter_linear, repeat_disable;
uniform sampler2D environment_weather_luts : filter_linear, repeat_disable;
uniform vec4 environment_day_lut_weights = vec4(0.0);
uniform vec4 environment_season_lut_weights = vec4(0.0);
uniform vec4 environment_weather_lut_weights_a = vec4(0.0);
uniform vec3 environment_weather_lut_weights_b = vec3(0.0);
uniform float environment_day_lut_strength = 0.0;
uniform float environment_season_lut_strength = 0.0;
uniform float environment_weather_lut_strength = 0.0;
uniform sampler2D environment_season_mask : filter_nearest, repeat_disable;
uniform bool environment_has_seasons = false;
uniform vec4 environment_seasons = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec3 environment_weather = vec3(1.0);
uniform float environment_frost = 0.0;

vec3 lut_srgb(vec3 color) {
	return mix(12.92 * color, 1.055 * pow(max(color, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), color));
}

vec3 lut_linear(vec3 color) {
	return mix(color / 12.92, pow((max(color, vec3(0.0)) + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), color));
}

vec3 lut_sample(sampler2D table, vec3 color, float size, float row, float rows) {
	vec3 p = clamp(color, vec3(0.0), vec3(1.0)) * (size - 1.0);
	float z = floor(p.b);
	vec2 xy = vec2(p.r + 0.5, p.g + 0.5);
	vec2 a = vec2((xy.x + z * size) / (size * size), (xy.y + row * size) / (size * rows));
	vec2 b = vec2((xy.x + min(z + 1.0, size - 1.0) * size) / (size * size), a.y);
	return mix(texture(table, a).rgb, texture(table, b).rgb, fract(p.b));
}

vec3 lut_four(sampler2D table, vec3 base, vec4 weights, float strength) {
	if (strength <= 0.0 || dot(weights, vec4(1.0)) <= 0.0) { return base; }
	vec3 input_color = environment_lut_linear_canvas ? lut_srgb(base) : base;
	vec3 output_color = input_color;
	for (int i = 0; i < 4; i++) {
		if (weights[i] > 0.0) {
			output_color += (lut_sample(table, input_color, 32.0, float(i), 4.0) - input_color) * weights[i];
		}
	}
	output_color = mix(input_color, output_color, strength);
	return environment_lut_linear_canvas ? lut_linear(output_color) : output_color;
}

vec3 lut_weather(vec3 base) {
	if (environment_weather_lut_strength <= 0.0 || dot(environment_weather_lut_weights_a, vec4(1.0)) + dot(environment_weather_lut_weights_b, vec3(1.0)) <= 0.0) { return base; }
	vec3 input_color = environment_lut_linear_canvas ? lut_srgb(base) : base;
	vec3 output_color = input_color;
	for (int i = 0; i < 7; i++) {
		float weight = i < 4 ? environment_weather_lut_weights_a[i] : environment_weather_lut_weights_b[i - 4];
		if (weight > 0.0) {
			output_color += (lut_sample(environment_weather_luts, input_color, 32.0, float(i), 7.0) - input_color) * weight;
		}
	}
	output_color = mix(input_color, output_color, environment_weather_lut_strength);
	return environment_lut_linear_canvas ? lut_linear(output_color) : output_color;
}

// Lift near-black foliage shadows toward muted meadow greens. Keep the
// original shade for snow and autumn broadleaves below.
vec3 nature_foliage_color(vec3 base, float strength) {
	return mix(base, vec3(0.40, 0.50, 0.26), strength);
}

vec3 season_color(vec3 base, vec2 uv) {
	if (!environment_has_seasons) { return base; }
	vec4 mask = texture(environment_season_mask, uv);
	float amount = clamp((mask.r + mask.g) * mask.a, 0.0, 1.0);
	if (amount <= 0.0) { return base; }
	float shade = dot(base, vec3(0.2126, 0.7152, 0.0722));
	vec3 spring = mix(vec3(0.49, 0.59, 0.29), vec3(0.34, 0.72, 0.16), mask.r) * (0.35 + shade);
	vec3 autumn = mix(vec3(0.65, 0.43, 0.23), mix(vec3(0.86, 0.42, 0.12), vec3(0.71, 0.57, 0.18), base.g), mask.r) * (0.35 + shade);
	vec3 winter = vec3(0.86, 0.92, 0.97) * (0.56 + shade * 0.55);
	vec3 summer = base;
	// Authored nature foliage stores species in green below the ground range.
	// Original masks (red only) retain their existing seasonal treatment.
	if (mask.r > 0.5 && mask.g > 0.05 && mask.g < 0.35) {
		if (mask.g < 0.15) {
			spring = base * vec3(1.03, 1.12, 1.02);
			autumn = base * vec3(0.96, 0.94, 0.93);
			winter = mix(base * vec3(0.82, 0.90, 0.95), winter, 0.60);
		} else if (mask.g > 0.25) {
			autumn = vec3(0.77, 0.65, 0.22) * (0.35 + shade);
		}
		summer = nature_foliage_color(base, 0.40);
		spring = nature_foliage_color(spring, 0.25);
		if (mask.g < 0.15) {
			autumn = nature_foliage_color(autumn, 0.36);
		}
	}
	vec3 colored = spring * environment_seasons.x + summer * environment_seasons.y + autumn * environment_seasons.z + winter * environment_seasons.w;
	colored = mix(colored, winter, environment_frost);
	colored = lut_four(environment_season_luts, colored, environment_season_lut_weights, environment_season_lut_strength);
	return mix(base, colored, amount);
}

vec3 environment_custom_color(vec3 color) {
	if (environment_lut_size >= 2.0) {
		vec3 input_color = environment_lut_linear_canvas ? lut_srgb(color) : color;
		color = lut_sample(environment_lut, input_color, environment_lut_size, 0.0, 1.0);
		if (environment_lut_linear_canvas) { color = lut_linear(color); }
	}
	return color;
}

// Cloud art already receives the ambient light and weather tint via cloud_light.
vec3 environment_cloud_color(vec3 base) {
	if (!environment_enabled) { return base; }
	return environment_custom_color(lut_weather(lut_four(environment_day_luts, base, environment_day_lut_weights, environment_day_lut_strength)));
}

// Shared by city art, moving art and the water surface. Emission is applied later.
vec3 environment_ambient(vec3 base) {
	if (!environment_enabled) { return base; }
	float luminance = dot(base, vec3(0.2126, 0.7152, 0.0722));
	vec3 color = mix(vec3(luminance), base, environment_saturation) * environment_tint;
	color = lut_four(environment_day_luts, color, environment_day_lut_weights, environment_day_lut_strength);
	color = environment_custom_color(lut_weather(color * environment_weather));
	// Recover the surface's own color, not a constant grey veil. Black stays
	// black and existing bright pixels are never darkened by the fill light.
	float shade = dot(color, vec3(0.2126, 0.7152, 0.0722));
	vec3 fill = base * vec3(0.48, 0.56, 0.72);
	return mix(color, max(color, fill), environment_ambient_lift * (1.0 - smoothstep(0.12, 0.65, shade)));
}

vec3 environment_color_emission(vec3 base, vec2 uv, float emission_amount) {
	if (!environment_enabled) { return base; }
	vec3 color = environment_ambient(season_color(base, uv));
	if (environment_has_emission) {
		vec4 emission = texture(environment_emission, uv);
		color = mix(color, emission.rgb, emission.a * environment_night * emission_amount);
	}
	return color;
}

vec3 environment_color(vec3 base, vec2 uv) {
	return environment_color_emission(base, uv, 1.0);
}
