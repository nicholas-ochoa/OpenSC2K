shader_type canvas_item;
#include "res://src/view/environment/environment_color.gdshaderinc"
#include "res://src/view/clouds/cloud_field.gdshaderinc"
#include "res://src/view/water/water_color.gdshaderinc"
#include "res://src/view/water/water_appearance.gdshaderinc"

uniform sampler2D animated_palette : source_color, filter_nearest, repeat_disable;
uniform sampler2D water_surface : filter_nearest, repeat_disable;
uniform sampler2D water_seabed : filter_nearest, repeat_disable;
uniform bool water_has_seabed = false;
uniform float water_clock = 0.0;
uniform float water_rain = 0.0;
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

// Interpolate resolved colors, never palette indices. The light and vegetation
// masks use the same source coordinate as their reflected artwork.
vec4 mirror_sample(vec4 source, vec2 uv, float level, float shade) {
	vec4 receiver = texture(water_surface, uv);
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))
			|| abs(receiver.r - level) > 0.001 || receiver.a < 0.5) { return vec4(0.0); }
	if (source.a <= 0.0) { return vec4(0.0); }
	return vec4(environment_color(palette_color(source.r) * shade, uv) * source.a, source.a);
}

// Reflected trees and lights keep their own masks and authored emission colors.
void fragment() {
	vec2 dimensions = vec2(textureSize(TEXTURE, 0));
	vec2 pixel = floor(UV * dimensions);
	vec4 surface = texture(water_surface, UV);
	if (!water_enabled || surface.a < 0.5 || any(lessThan(pixel, vec2(water_padding)))
			|| any(greaterThanEqual(pixel, dimensions - vec2(water_padding)))) {
		discard;
	}
	vec2 world = water_origin + (pixel + vec2(0.5)) * water_divisor;
	vec4 bottom = water_has_seabed ? texture(water_seabed, UV) : vec4(0.0);
	float level = round(surface.r * 255.0) - 1.0;
	float depth = max(level - bottom.r * 31.0, 0.0);
	float coast = water_has_seabed ? bottom.b * 255.0 / 8.0 : 32.0;
	vec3 swell = water_waves_enabled && !water_geometry_preview
		? water_swell(world, water_clock, water_rain, coast, round(surface.b * 255.0)) : vec3(0.0);
	vec3 base = water_season_color(palette_color(surface.g));
	if (!water_geometry_preview && (water_reflections_enabled || water_topography || water_waves_enabled)) {
		base = water_body(base, bottom, depth, world, water_topography);
		if (water_waves_enabled) {
			base *= 1.0 + swell.x + water_light_lines(world, round(surface.b * 255.0), water_clock, water_rain);
			vec3 foam = environment_lut_linear_canvas ? lut_linear(vec3(0.66, 0.79, 0.83)) : vec3(0.66, 0.79, 0.83);
			float detail = 1.0 - smoothstep(2.0, 8.0, length(fwidth(world)));
			base = mix(base, foam, water_surf(world, coast, water_clock, water_rain) * detail);
		}
	}
	// Surface and reflection share the same shadow at this fragment.
	float cloud_shade = cloud_shadow(vec3(1.0), cloud_ground_grid).r;
	base = environment_ambient(base * cloud_shade);
	vec3 combined = base;
	if (water_reflections_enabled) {
		vec4 original_reflection = texture(TEXTURE, UV);
		// Distance attenuation is encoded in alpha by the geometry pass. Keep
		// contact pixels still, particularly where bridge piers meet the water.
		float contact = max(original_reflection.a, max(texture(TEXTURE, UV + vec2(1.0, 0.0) / dimensions).a,
			texture(TEXTURE, UV - vec2(1.0, 0.0) / dimensions).a));
		float detached = smoothstep(0.025, 0.20, 1.0 - contact);
		float offset = water_geometry_preview || !water_waves_enabled ? 0.0 : clamp(swell.y * detached, -1.5, 1.5) / water_divisor;
		vec2 first_uv = UV + vec2(floor(offset), 0.0) / dimensions;
		vec2 second_uv = first_uv + vec2(1.0, 0.0) / dimensions;
		vec4 reflected = mix(mirror_sample(texture(TEXTURE, first_uv), first_uv, surface.r, cloud_shade),
			mirror_sample(texture(TEXTURE, second_uv), second_uv, surface.r, cloud_shade), fract(offset));
		if (reflected.a > 0.0) {
			vec3 mirror_color = reflected.rgb / reflected.a;
			float strength = water_geometry_preview ? 1.0 : mix(0.15, 0.23, 1.0 - exp(-depth * 0.4) * bottom.a);
			if (!water_geometry_preview && water_waves_enabled) { strength *= 1.0 - swell.z * 0.25; }
			if (!water_geometry_preview) { mirror_color *= vec3(0.78, 0.87, 1.0); }
			combined = mix(base, mirror_color, reflected.a * strength);
		}
	}
	COLOR = vec4(combined, 1.0);
}
