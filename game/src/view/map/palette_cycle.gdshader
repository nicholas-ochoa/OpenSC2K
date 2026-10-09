
shader_type canvas_item;
#include "res://src/view/environment/environment_color.gdshaderinc"
#include "res://src/view/clouds/cloud_field.gdshaderinc"
#include "res://src/view/water/water_color.gdshaderinc"

uniform sampler2D palette_indices : filter_nearest, repeat_disable;
uniform sampler2D animated_palette : source_color, filter_nearest, repeat_disable;
uniform bool palette_cycle_enabled = false;
uniform bool palette_lookup_all = false;
uniform bool dark_underground = false;
uniform sampler2D dark_underground_palette : source_color, filter_nearest, repeat_disable;
uniform sampler2D power_warning_palette : source_color, filter_nearest, repeat_disable;
uniform float power_warning_blend = 0.0;
// One tiny shared texture, no extra draw pass or per-tile frame updates.
uniform bool nature_terrain_enabled = false;
uniform bool nature_forests_enabled = false;
uniform float nature_terrain_strength : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D nature_ground : filter_linear, repeat_enable;
uniform mat3 nature_canvas_to_grid = mat3(1.0);
varying vec2 nature_grid;

varying flat float emission_draw;
varying flat float indexed_emission_draw;
varying flat float transparent_shadow_draw;
varying flat float fullbright_draw;
varying flat float toxic_draw;
varying flat float warm_cloud_draw;
varying vec2 cloud_ground_grid;
varying flat float hazard_draw;
varying flat float hazard_phase;
varying flat float hazard_opacity;
void vertex() {
	nature_grid = (nature_canvas_to_grid * vec3((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy, 1.0)).xy;
	hazard_draw = float(COLOR.b == 0.25 || COLOR.b == 0.5 || COLOR.b == 0.125 || COLOR.b == 0.75);
	hazard_phase = COLOR.r * 8.0;
	hazard_opacity = COLOR.g;
	emission_draw = float(COLOR.rgb == vec3(0.0, 1.0, 1.0));
	indexed_emission_draw = float(COLOR.rgb == vec3(0.0, 1.0, 0.0));
	transparent_shadow_draw = float(COLOR.rgb == vec3(1.0, 0.0, 1.0));
	fullbright_draw = float(COLOR.rgb == vec3(1.0, 1.0, 0.0) || COLOR.b == 0.5);
	toxic_draw = float(COLOR.rgb == vec3(1.0, 0.0, 0.0) || COLOR.b == 0.25);
	warm_cloud_draw = float(COLOR.rgb == vec3(1.0, 0.5, 0.0) || COLOR.b == 0.125);
	cloud_ground_grid = cloud_grid_at((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy);
}

void fragment() {
	vec4 base_color = texture(TEXTURE, UV);
	float encoded_index = (
		palette_lookup_all ? base_color.r : texture(palette_indices, UV).r
	);
	int palette_index = int(round(encoded_index * 255.0));
	// The auxiliary mask follows sprite silhouettes and painter occlusion.
	// Its blue channel is reserved for power warnings, not terrain colors.
	vec4 natural_mask = environment_has_seasons ? texture(environment_season_mask, UV) : vec4(0.0);
	bool power_warning = natural_mask.b > 0.5;
	bool animated_index =
		(palette_index >= 171 && palette_index <= 198) ||
		(palette_index >= 200 && palette_index <= 219) ||
		(palette_index >= 224 && palette_index <= 239);
	if (palette_cycle_enabled && (palette_lookup_all || animated_index)) {
		vec2 palette_uv = vec2((float(palette_index) + 0.5) / 256.0, 0.5);
		vec4 cycle_color = texture(animated_palette, palette_uv);
		COLOR = vec4(cycle_color.rgb, base_color.a);
	} else {
		COLOR = base_color;
	}
	if (power_warning && palette_cycle_enabled && power_warning_blend > 0.0) {
		vec3 next_color = texture(power_warning_palette, vec2((float(palette_index) + 0.5) / 256.0, 0.5)).rgb;
		COLOR.rgb = mix(COLOR.rgb, next_color, power_warning_blend);
	}
	if (nature_forests_enabled && natural_mask.r > 0.5 && natural_mask.g > 0.05 && natural_mask.g < 0.35 && !dark_underground) {
		// Restore the selected artwork's dark greens after indexed palette
		// lookup, which otherwise makes the imported greens unnaturally vivid.
		float leaf = clamp((COLOR.g - 0.15) / 0.85, 0.0, 1.0);
		COLOR.rgb = mix(vec3(0.01, 0.10, 0.04), vec3(0.28, 0.58, 0.06), leaf);
		// With environmental grading off, display the same softened summer
		// palette. Otherwise season_color retains the original winter shades.
		if (!environment_enabled) {
			COLOR.rgb = nature_foliage_color(COLOR.rgb, 0.40);
		}
	}
	if (nature_terrain_enabled && nature_terrain_strength > 0.0 && natural_mask.g > 0.5 && !dark_underground) {
		// Broad related meadow/dry-soil patches, with narrow pixel-dither
		// boundaries and sparse detail. World-fixed: no per-frame randomness.
		vec3 patch = texture(nature_ground, nature_grid / 160.0).rgb;
		vec3 grain = texture(nature_ground, (floor(nature_grid * 16.0) + 0.5) / 32.0).rgb;
		float field = patch.r + (grain.r - 0.5) * 0.035;
		float dry = smoothstep(0.56, 0.70, field);
		float earth = smoothstep(0.73, 0.85, field);
		vec3 meadow = mix(vec3(0.32, 0.42, 0.23), vec3(0.43, 0.50, 0.28), smoothstep(0.22, 0.68, patch.g));
		vec3 ground = mix(meadow, vec3(0.55, 0.49, 0.32), dry);
		ground = mix(ground, vec3(0.43, 0.36, 0.26), earth);
		float rock = 1.0 - smoothstep(0.6, 0.9, natural_mask.a);
		ground = mix(ground, vec3(0.43, 0.44, 0.39), rock);
		float original_shade = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
		float slope = 1.0 - step(0.97, natural_mask.a);
		float surface_shade = mix(0.72 + original_shade * 0.45, clamp(0.10 + original_shade * 1.55, 0.28, 1.22), slope);
		float shading = mix(surface_shade, clamp(0.25 + original_shade * 1.6, 0.28, 1.2), rock);
		float detail = (step(0.91, grain.g) - step(grain.g, 0.07)) * 0.012;
		COLOR.rgb = mix(COLOR.rgb, ground * shading + vec3(detail), nature_terrain_strength);

	}
	if (hazard_draw > 0.5) {
		float frame = floor(hazard_phase);
		vec4 first = texture(TEXTURE, vec2(UV.x, (UV.y + frame) / 8.0));
		vec4 next = texture(TEXTURE, vec2(UV.x, (UV.y + mod(frame + 1.0, 8.0)) / 8.0));
		vec3 a = texture(animated_palette, vec2((round(first.r * 255.0) + 0.5) / 256.0, 0.5)).rgb;
		vec3 b = texture(animated_palette, vec2((round(next.r * 255.0) + 0.5) / 256.0, 0.5)).rgb;
		float alpha = mix(first.a, next.a, fract(hazard_phase));
		// Blend resolved colors in premultiplied form, never palette addresses.
		COLOR = vec4(mix(a * first.a, b * next.a, fract(hazard_phase)) / max(alpha, 0.00001), alpha * hazard_opacity);
	}
	if (transparent_shadow_draw > 0.5) {
		COLOR = vec4(vec3(0.0), base_color.a);
	} else if (indexed_emission_draw > 0.5) {
		float index = round(base_color.r * 255.0);
		vec3 light = texture(animated_palette, vec2((index + 0.5) / 256.0, 0.5)).rgb;
		COLOR = vec4(light, base_color.a * environment_night * float(environment_enabled));
	} else if (emission_draw > 0.5) {
		COLOR = vec4(base_color.rgb, base_color.a * environment_night * float(environment_enabled));
	} else if (toxic_draw > 0.5 || warm_cloud_draw > 0.5) {
		// Preserve cloud shading and coverage; eruption ash is amber, toxic gas green.
		float shade = dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722));
		vec3 gas = warm_cloud_draw > 0.5
			? mix(vec3(0.32, 0.105, 0.015), vec3(1.0, 0.78, 0.18), shade)
			: mix(vec3(0.08, 0.28, 0.015), vec3(0.55, 1.0, 0.12), shade);
		vec3 ambient = environment_color(cloud_shadow(gas, cloud_ground_grid), UV);
		COLOR.rgb = mix(ambient, gas, float(environment_enabled) * clamp(environment_night, 0.0, 1.0));
	} else if (dark_underground) {
		COLOR.rgb = texture(dark_underground_palette, vec2((float(palette_index) + 0.5) / 256.0, 0.5)).rgb;
	} else if (fullbright_draw < 0.5 && !power_warning) {
		if (water_enabled && natural_mask.b > 0.2 && natural_mask.b < 0.3) {
			// Water sides keep their original shading/animation and painter
			// occlusion. Only share the surface tint; no flat waves or mirrors.
			COLOR.rgb = water_season_color(COLOR.rgb);
			if (water_reflections_enabled || water_topography || water_waves_enabled) {
				COLOR.rgb = water_body_tone(COLOR.rgb, 0.0, 0.0);
			}
		}
		COLOR.rgb = environment_color(cloud_shadow(COLOR.rgb, cloud_ground_grid), UV);
	}
}
