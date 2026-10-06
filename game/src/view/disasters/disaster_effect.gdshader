shader_type canvas_item;
render_mode unshaded;

#include "res://src/view/environment/environment_color.gdshaderinc"

uniform int effect_kind = 0;
uniform float effect_time = 0.0;
uniform float effect_seed = 0.0;
uniform float effect_strength = 0.7;
uniform float light_strength = 0.4;
uniform float progress = -1.0;
uniform vec4 flood_edges = vec4(1.0);
uniform sampler2D foreground : filter_nearest, repeat_disable;
uniform bool has_foreground = false;
uniform sampler2D people : source_color, filter_nearest, repeat_disable;

float puff(vec2 p, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(0.25, 1.0, length((p - center) / radius));
}

void fragment() {
	// Work in original large-view pixels, even at fractional display zoom.
	vec2 p = floor(UV * vec2(64.0, 96.0)) + vec2(0.5);
	float t = effect_time + effect_seed;
	vec3 color = vec3(0.48, 0.47, 0.43);
	float alpha = 0.0;
	float emission = 0.0;
	float diamond = abs(p.x - 32.0) / 16.0 + abs(p.y - 80.0) / 8.0;
	if (effect_kind == 0 || effect_kind == 4 || effect_kind == 7 || effect_kind == 8 || effect_kind == 12) {
		// Broken smoke, windblown ash, or dust around a moving disaster.
		for (int i = 0; i < 5; i++) {
			float f = fract(t * 0.19 + float(i) * 0.2);
			float rise = f * (effect_kind == 7 ? 65.0 : 40.0);
			float sway = sin(t * 1.3 + float(i) * 2.4) * (effect_kind == 4 ? 9.0 : 3.0);
			vec2 at = vec2(32.0 + sway + f * 8.0, 75.0 - rise);
			alpha += puff(p, at, vec2(4.0 + f * 7.0, 5.0 + f * 5.0)) * sin(f * 3.14159) * 0.10;
		}
		if (effect_kind == 4 || effect_kind == 8) {
			color = vec3(0.62, 0.57, 0.45);
			float a = atan((p.y - 80.0) * 2.0, p.x - 32.0);
			alpha *= 0.75;
			alpha += puff(p, vec2(32.0 + sin(t * 2.0) * 10.0, 80.0 + cos(t * 2.0) * 3.0), vec2(5.0, 3.0)) * 0.20;
			alpha += (1.0 - smoothstep(0.05, 0.22, abs(diamond - 0.7))) * max(0.0, sin(a * 3.0 - t * 5.0)) * 0.09;
		} else if (effect_kind != 12) {
			float glow = puff(p, vec2(32.0, 79.0), vec2(22.0, 10.0)) * light_strength;
			color = mix(color, vec3(1.0, 0.39, 0.07), glow);
			alpha += glow * 0.22;
			emission = glow;
			for (int i = 0; i < 3; i++) {
				float f = fract(t * 0.4 + float(i) * 0.31);
				vec2 at = vec2(32.0 + sin(float(i) * 3.0 + t) * 7.0, 74.0 - f * 30.0);
				float spark = puff(p, at, vec2(1.2)) * (1.0 - f);
				color = mix(color, vec3(1.0, 0.67, 0.12), spark);
				alpha += spark * 0.65;
				emission = max(emission, spark);
			}
		}
	} else if (effect_kind == 1) {
		// Flood stays inside its actual tile; foam only on exposed boundaries.
		if (diamond < 1.0) {
			float wave = sin(p.x * 0.65 + p.y * 0.9 - t * 3.0);
			color = mix(vec3(0.13, 0.36, 0.55), vec3(0.39, 0.65, 0.77), wave * 0.5 + 0.5);
			alpha = 0.53;
			vec2 q = vec2((p.x - 32.0) / 16.0, (p.y - 80.0) / 8.0);
			float edge = q.x > 0.0 ? (q.y > 0.0 ? flood_edges.x : flood_edges.y) : (q.y > 0.0 ? flood_edges.z : flood_edges.w);
			if (diamond > 0.82 && edge > 0.5 && wave > -0.1) {
				color = vec3(0.72, 0.86, 0.87);
				alpha = 0.68;
			}
		}
	} else if (effect_kind == 2 || effect_kind == 9) {
		color = effect_kind == 9 ? vec3(0.69, 0.61, 0.27) : vec3(0.49, 0.60, 0.20);
		alpha = diamond < 1.0 ? 0.20 : 0.0;
		if (effect_kind == 2 && diamond > 0.82 && diamond < 1.0) {
			color = vec3(0.69, 0.68, 0.26);
			alpha = 0.50;
		}
		for (int i = 0; i < 4; i++) {
			float f = fract(t * 0.15 + float(i) * 0.25);
			vec2 at = vec2(32.0 + sin(t + float(i) * 2.0) * 7.0, 79.0 - f * 11.0);
			alpha += puff(p, at, vec2(7.0, 4.0)) * sin(f * 3.14159) * 0.10;
		}
	} else if (effect_kind == 3) {
		vec2 uv = vec2((UV.x + mod(floor(t * 5.0), 2.0)) * 0.5, UV.y);
		vec4 person = texture(people, uv);
		color = person.rgb;
		alpha = person.a;
	} else if (effect_kind == 5) {
		// Demolition is pale settling dust, without flames or an impact flash.
		float f = clamp(progress, 0.0, 1.0);
		color = vec3(0.73, 0.68, 0.56);
		for (int i = 0; i < 6; i++) {
			float angle = float(i) * 1.0472 + effect_seed;
			vec2 at = vec2(32.0, 78.0 - f * 12.0) + vec2(cos(angle) * (4.0 + f * 11.0), sin(angle) * (2.0 + f * 4.0));
			alpha += puff(p, at, vec2(5.0 + f * 5.0, 4.0 + f * 4.0)) * 0.17 * (1.0 - f);
		}
	} else if (effect_kind == 6) {
		float beam = 1.0 - smoothstep(0.5, 2.0, abs(p.x - 32.0));
		alpha = p.y < 80.0 ? beam * 0.50 : 0.0;
		alpha += puff(p, vec2(32.0, 79.0), vec2(7.0, 4.0)) * 0.65;
		color = vec3(0.71, 0.85, 1.0);
		emission = light_strength;
	} else if (effect_kind == 10) {
		// Sparse directional rain. The canvas remains clear for dispatch tools.
		float lane = fract(UV.x * 73.0 + UV.y * 28.0);
		float drop = fract(UV.y * 35.0 - effect_time * 4.0 + floor(UV.x * 73.0) * 0.37);
		alpha = lane > 0.96 && drop > 0.65 ? 0.16 : 0.025;
		color = lane > 0.96 && drop > 0.65 ? vec3(0.67, 0.75, 0.81) : vec3(0.17, 0.22, 0.28);
	} else if (effect_kind == 11) {
		float f = fract(t * 0.7);
		alpha = puff(p, vec2(32.0, 75.0), vec2(9.0, 7.0)) * (0.35 + 0.20 * f);
		color = vec3(1.0, 0.48 + f * 0.24, 0.09);
		emission = light_strength;
	}
	vec3 shaded = environment_color(color, UV);
	color = mix(shaded, color, clamp(emission, 0.0, 1.0));
	if (progress >= 0.0 && effect_kind != 5) {
		alpha *= 1.0 - smoothstep(0.65, 1.0, progress);
	}
	if (has_foreground) {
		alpha *= 1.0 - texture(foreground, UV).a;
	}
	// Keep confirmed hazard tiles readable even at a low cosmetic strength.
	float opacity = effect_kind == 3 ? 1.0 : effect_strength;
	if (effect_kind == 1 || effect_kind == 2) {
		opacity = mix(0.7, 1.0, effect_strength);
	}
	COLOR = vec4(color, clamp(alpha, 0.0, effect_kind == 3 ? 1.0 : 0.72) * opacity);
}
