
shader_type canvas_item;
#include "res://src/view/environment/environment_color.gdshaderinc"
#include "res://src/view/clouds/cloud_field.gdshaderinc"

uniform sampler2D palette_indices : filter_nearest, repeat_disable;
uniform sampler2D animated_palette : source_color, filter_nearest, repeat_disable;
uniform bool palette_cycle_enabled = false;
uniform bool palette_lookup_all = false;
uniform bool dark_underground = false;
uniform sampler2D dark_underground_palette : source_color, filter_nearest, repeat_disable;

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
	} else if (fullbright_draw < 0.5) {
		COLOR.rgb = environment_color(cloud_shadow(COLOR.rgb, cloud_ground_grid), UV);
	}
}
