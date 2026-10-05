shader_type canvas_item;
#include "res://src/view/environment/environment_color.gdshaderinc"
#include "res://src/view/clouds/cloud_field.gdshaderinc"

uniform sampler2D animated_palette : source_color, filter_nearest, repeat_disable;
uniform sampler2D water_surface : filter_nearest, repeat_disable;
uniform sampler2D water_seabed : filter_nearest, repeat_disable;
uniform bool water_enabled = false;
uniform bool water_reflections_enabled = true;
uniform bool water_topography = true;
uniform bool water_has_seabed = false;
uniform float water_clock = 0.0;
uniform float water_rain = 0.0;
uniform float water_season_strength = 0.0;
uniform vec2 water_origin = vec2(0.0);
uniform float water_divisor = 1.0;
uniform float water_padding = 3.0;
// Tests inspect the geometric reflection without waves or artistic attenuation.
uniform bool water_geometry_preview = false;

varying vec2 cloud_ground_grid;
void vertex() {
	cloud_ground_grid = cloud_grid_at((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy);
}

vec3 palette_color(float encoded) {
	return texture(animated_palette, vec2((round(encoded * 255.0) + 0.5) / 256.0, 0.5)).rgb;
}

// Seasonal water color is independent of the reflected art's vegetation mask.
// Work in numeric sRGB before ambient light, weather and the optional LUT.
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

// Reflected trees and lights keep their own masks and authored emission colors.
vec3 water_ambient(vec3 base) {
	return environment_ambient(water_season_color(base));
}

void fragment() {
	vec2 dimensions = vec2(textureSize(TEXTURE, 0));
	vec2 pixel = floor(UV * dimensions);
	vec4 surface = texture(water_surface, UV);
	if (!water_enabled || surface.a < 0.5 || any(lessThan(pixel, vec2(water_padding)))
			|| any(greaterThanEqual(pixel, dimensions - vec2(water_padding)))) {
		discard;
	}
	vec2 world = water_origin + (pixel + vec2(0.5)) * water_divisor;
	float wave = sin(world.y * 0.17 + water_clock * 0.9)
		+ 0.38 * sin((world.x + world.y) * 0.073 - water_clock * 0.61);
	float offset = water_geometry_preview ? 0.0 : round(wave * (0.65 + 0.8 * water_rain));
	vec3 base = water_ambient(cloud_shadow(palette_color(surface.g), cloud_ground_grid));
	if (water_topography && water_has_seabed) {
		vec4 bottom = texture(water_seabed, UV);
		float level = round(surface.r * 255.0) - 1.0;
		float ground = bottom.r * 31.0;
		float depth = max(level - ground, 0.0);
		float transmission = 0.24 * exp(-depth * 0.7) * bottom.a;
		vec3 floor_color = environment_ambient(cloud_shadow(vec3(0.47, 0.40, 0.25) * (0.65 + 0.45 * bottom.g), cloud_ground_grid));
		base = mix(base, floor_color, transmission);
	}
	vec3 combined = base;
	if (water_reflections_enabled) {
		vec2 reflected_uv = UV + vec2(offset, 0.0) / dimensions;
		vec4 sampled_surface = texture(water_surface, reflected_uv);
		vec4 reflected = texture(TEXTURE, reflected_uv);
		if (abs(sampled_surface.r - surface.r) > 0.001 || sampled_surface.a < 0.5) {
			reflected.a = 0.0;
		}
		if (reflected.a > 0.0) {
			vec3 mirror_color = environment_color(cloud_shadow(palette_color(reflected.r), cloud_ground_grid), reflected_uv);
			if (!water_geometry_preview) { mirror_color *= vec3(0.78, 0.87, 1.0); }
			combined = mix(base, mirror_color, reflected.a * (water_geometry_preview ? 1.0 : 0.20));
		}
	}
	float shimmer = water_geometry_preview ? 0.0 : max(wave - 0.72, 0.0) * 0.014;
	COLOR = vec4(combined + base * shimmer, 1.0);
}
