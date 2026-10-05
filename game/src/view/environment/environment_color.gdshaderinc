uniform bool environment_enabled = false;
uniform vec3 environment_tint = vec3(1.0);
uniform float environment_saturation = 1.0;
uniform float environment_night = 0.0;
uniform sampler2D environment_emission : source_color, filter_nearest, repeat_disable;
uniform bool environment_has_emission = false;
uniform sampler2D environment_lut : source_color, filter_linear, repeat_disable;
uniform float environment_lut_size = 0.0;
uniform sampler2D environment_season_mask : filter_nearest, repeat_disable;
uniform bool environment_has_seasons = false;
uniform vec4 environment_seasons = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec3 environment_weather = vec3(1.0);
uniform float environment_frost = 0.0;

vec3 season_color(vec3 base, vec2 uv) {
	if (!environment_has_seasons) { return base; }
	vec4 mask = texture(environment_season_mask, uv);
	float shade = dot(base, vec3(0.2126, 0.7152, 0.0722));
	vec3 spring = mix(vec3(0.49, 0.59, 0.29), vec3(0.34, 0.72, 0.16), mask.r) * (0.35 + shade);
	vec3 autumn = mix(vec3(0.65, 0.43, 0.23), mix(vec3(0.86, 0.42, 0.12), vec3(0.71, 0.57, 0.18), base.g), mask.r) * (0.35 + shade);
	vec3 winter = vec3(0.86, 0.92, 0.97) * (0.56 + shade * 0.55);
	vec3 colored = spring * environment_seasons.x + base * environment_seasons.y + autumn * environment_seasons.z + winter * environment_seasons.w;
	colored = mix(colored, winter, environment_frost);
	return mix(base, colored, clamp((mask.r + mask.g) * mask.a, 0.0, 1.0));
}

vec3 environment_color(vec3 base, vec2 uv) {
	if (!environment_enabled) { return base; }
	base = season_color(base, uv);
	float luminance = dot(base, vec3(0.2126, 0.7152, 0.0722));
	vec3 color = mix(vec3(luminance), base, environment_saturation) * environment_tint * environment_weather;
	if (environment_lut_size >= 2.0) {
		float size = environment_lut_size;
		vec3 p = clamp(color, vec3(0.0), vec3(1.0)) * (size - 1.0);
		float z = floor(p.b);
		vec2 xy = vec2(p.r + 0.5, p.g + 0.5);
		vec2 a = vec2((xy.x + z * size) / (size * size), xy.y / size);
		vec2 b = vec2((xy.x + min(z + 1.0, size - 1.0) * size) / (size * size), xy.y / size);
		color = mix(texture(environment_lut, a).rgb, texture(environment_lut, b).rgb, fract(p.b));
	}
	if (environment_has_emission) {
		vec4 emission = texture(environment_emission, uv);
		color = mix(color, emission.rgb, emission.a * environment_night);
	}
	return color;
}
