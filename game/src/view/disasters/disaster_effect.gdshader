shader_type canvas_item;
render_mode unshaded;
#include "res://src/view/environment/environment_color.gdshaderinc"

uniform int effect_kind = 0;
uniform float effect_time = 0.0;
uniform float effect_seed = 0.0;
uniform float effect_strength = 0.7;
uniform float light_strength = 0.4;
uniform float progress = -1.0;
uniform float impact_phase = 0.0;
uniform vec2 world_origin = vec2(0.0);
uniform vec4 flood_edges = vec4(1.0);
uniform sampler2D foreground : filter_nearest, repeat_disable;
uniform bool has_foreground = false;
uniform sampler2D people : source_color, filter_nearest, repeat_disable;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
float puff(vec2 p, vec2 center, vec2 radius) { return 1.0 - smoothstep(0.5, 1.0, length((p - center) / radius)); }
vec4 over(vec4 base, vec3 color, float alpha) {
	float a = clamp(alpha, 0.0, 1.0);
	float total = a + base.a * (1.0 - a);
	return vec4((color * a + base.rgb * base.a * (1.0 - a)) / max(total, 0.001), total);
}

void fragment() {
	// Native pixels keep contours stable at every map zoom. q=0 is the tile centre.
	vec2 q = floor(UV * vec2(96.0, 144.0)) + vec2(0.5) - vec2(48.0, 128.0);
	float t = effect_time + effect_seed;
	float diamond = abs(q.x) / 16.0 + abs(q.y) / 8.0;
	float emission = 0.0;
	vec4 ink = vec4(0.0);
	float strength = mix(0.55, 1.0, effect_strength);
	if (effect_kind == 0 || effect_kind == 7 || effect_kind == 12) {
		// Separate expanding billows leave gaps through the plume.
		float plume_height = effect_kind == 7 ? 108.0 : (effect_kind == 12 ? 36.0 : 64.0);
		for (int i = 0; i < 8; i++) {
			float f = fract(t * 0.17 + float(i) * 0.125);
			vec2 at = vec2(f * 15.0 + sin(t * 0.7 + float(i) * 2.4) * 3.0, -8.0 - f * plume_height);
			vec2 r = vec2(5.0 + f * 9.0, 6.0 + f * 7.0);
			float shade = floor((noise(q * 0.35 + vec2(0.0, t * 0.9)) * 0.12 + (q.x - at.x) / r.x * 0.06 + 0.40) * 12.0) / 12.0;
			ink = over(ink, vec3(shade, shade * 0.98, shade * 0.94), puff(q, at, r) * sin(f * 3.14159) * 0.82 * strength);
		}
		if (effect_kind == 0) {
			ink = over(ink, vec3(1.0, 0.39, 0.055), puff(q, vec2(0.0, -1.0), vec2(21.0, 9.0)) * light_strength * 0.65);
			// Staggered flame tongues replace the original repeated fire bitmap.
			for (int i = 0; i < 6; i++) {
				float id = float(i), base = -12.0 + id * 4.8;
				float height = 15.0 + sin(t * 4.1 + id * 2.7) * 4.0 + hash(vec2(id, effect_seed)) * 10.0;
				float y = (2.0 - abs(base) * 0.19 - q.y) / height;
				float axis = base + sin(y * 5.0 - t * 4.5 + id) * y * 3.5;
				float width = (1.0 - y) * 4.3;
				float body = step(abs(q.x - axis), width) * step(0.0, y) * step(y, 1.0);
				float inner = step(abs(q.x - axis + 0.7), width * 0.55) * step(y, 0.67);
				vec3 flame = y > 0.6 ? vec3(0.96, 0.25, 0.025) : vec3(1.0, 0.49, 0.045);
				flame = mix(flame, y < 0.28 ? vec3(1.0, 0.92, 0.48) : vec3(1.0, 0.73, 0.14), inner);
				ink = over(ink, flame, body * 0.97);
				emission = max(emission, body * 0.85);
			}
		}
		if (effect_kind != 12) {
			for (int i = 0; i < 7; i++) {
				float f = fract(t * 0.31 + float(i) * 0.143);
				vec2 at = vec2(sin(float(i) * 3.0 + t) * 11.0 + f * 12.0, -12.0 - f * plume_height);
				float spark = step(length(q - at), 0.85) * (1.0 - f);
				ink = over(ink, vec3(1.0, 0.72, 0.23), spark);
				emission = max(emission, spark);
			}
		}
	} else if (effect_kind == 1) {
		if (diamond < 1.0) {
			// World-aligned, broken horizontal ripples join across flooded tiles.
			vec2 w = q + world_origin;
			float n = noise(w * vec2(0.15, 0.32) + vec2(effect_time * 0.4, 0.0));
			float ripple = noise(w * vec2(0.24, 0.9) - vec2(effect_time, effect_time * 0.5));
			vec3 water = mix(vec3(0.16, 0.40, 0.54), vec3(0.30, 0.59, 0.68), floor(n * 4.0) / 3.0);
			water = mix(water, vec3(0.58, 0.77, 0.80), step(0.77, ripple) * 0.65);
			float edge = q.x > 0.0 ? (q.y > 0.0 ? flood_edges.x : flood_edges.y) : (q.y > 0.0 ? flood_edges.z : flood_edges.w);
			float foam = step(0.80 + n * 0.09, diamond) * edge;
			ink = vec4(mix(water, vec3(0.78, 0.87, 0.83), foam), mix(0.78, 0.92, foam));
		}
	} else if (effect_kind == 2 || effect_kind == 9) {
		vec3 gas = effect_kind == 9 ? vec3(0.64, 0.55, 0.25) : vec3(0.55, 0.62, 0.23);
		if (diamond < 1.0) {
			float n = noise((q + world_origin) * 0.21 + vec2(t * 0.3, 0.0));
			ink = vec4(mix(gas * 0.60, gas, n), 0.55);
			if (diamond > 0.88) { ink = over(ink, gas * 1.3, 0.48); }
		}
		for (int i = 0; i < 5; i++) {
			float f = fract(t * 0.16 + float(i) * 0.2);
			vec2 at = vec2(sin(float(i) * 2.6 + t * 0.5) * 9.0, -3.0 - f * 15.0);
			ink = over(ink, gas * (0.95 + f * 0.30), puff(q, at, vec2(8.0, 5.0)) * sin(f * 3.14159) * 0.44 * strength);
		}
	} else if (effect_kind == 3) {
		ink = texture(people, vec2((UV.x + mod(floor(t * 6.0), 8.0)) / 8.0, UV.y));
	} else if (effect_kind == 4) {
		float h = clamp(-q.y / 102.0, 0.0, 1.0);
		float axis = sin(h * 4.8 + t * 1.5) * h * 7.0;
		float radius = 2.5 + pow(h, 0.8) * 23.0;
		float radial = (q.x - axis) / radius;
		float band = sin(q.y * 0.65 + radial * 2.5 - t * 7.0);
		float contour = 1.0 - smoothstep(0.80, 1.04, abs(radial) + band * 0.035);
		float ends = step(-103.0, q.y) * step(q.y, 1.0);
		float shade = floor((0.57 - radial * 0.15 + band * 0.08 + noise(q * 0.3 + t) * 0.08) * 12.0) / 12.0;
		ink = vec4(vec3(shade * 0.96, shade, shade * 1.02), contour * ends * 0.96);
		for (int i = 0; i < 9; i++) {
			float a = t * (2.0 + float(i) * 0.13) + float(i) * 2.4;
			float r = 12.0 + mod(float(i) * 7.0, 19.0);
			vec2 at = vec2(cos(a) * r, -4.0 - mod(float(i) * 11.0, 40.0) + sin(a) * 5.0);
			ink = over(ink, vec3(0.36, 0.30, 0.22), step(length((q - at) / vec2(1.7, 1.0)), 1.0) * 0.85);
		}
		ink = over(ink, vec3(0.62, 0.56, 0.43), puff(q, vec2(sin(t * 3.0) * 8.0, -1.0), vec2(17.0, 5.0)) * 0.36);
	} else if (effect_kind == 5 || effect_kind == 8) {
		float f = effect_kind == 5 ? clamp(progress, 0.0, 1.0) : fract(t * 0.65);
		float fade = effect_kind == 5 ? (1.0 - smoothstep(0.25, 1.0, f)) : sin(f * 3.14159) * 0.7;
		for (int i = 0; i < 7; i++) {
			float a = float(i) * 2.4 + effect_seed;
			vec2 at = vec2(cos(a) * (4.0 + f * 13.0), -3.0 - f * 14.0 + sin(a) * (2.0 + f * 4.0));
			vec2 r = vec2(5.0 + f * 7.0, 4.0 + f * 6.0);
			float shade = floor((0.72 + (at.y - q.y) / r.y * 0.10 + noise(q * 0.4) * 0.1) * 12.0) / 12.0;
			ink = over(ink, vec3(shade, shade * 0.94, shade * 0.81), puff(q, at, r) * fade * 0.66 * strength);
			vec2 chip = vec2(cos(a) * f * 23.0, -sin(f * 3.14159) * (7.0 + float(i)) + sin(a) * f * 6.0);
			ink = over(ink, vec3(0.41, 0.37, 0.28), step(length(q - chip), 1.0) * fade * 0.65);
		}
	} else if (effect_kind == 6) {
		float beam = 1.0 - smoothstep(0.5, 2.5, abs(q.x));
		ink = vec4(vec3(0.75, 0.87, 1.0), q.y < 0.0 ? beam * 0.8 : 0.0);
		ink = over(ink, vec3(0.87, 0.95, 1.0), puff(q, vec2(0.0, -1.0), vec2(9.0, 4.0)) * 0.9);
		emission = 0.85;
	} else if (effect_kind == 10) {
		float lane = fract(UV.x * 149.0 + UV.y * 48.0);
		float drop = fract(UV.y * 42.0 - effect_time * 3.0 + floor(UV.x * 149.0 + UV.y * 48.0) * 0.37);
		bool rain = lane > 0.94 && drop > 0.66;
		ink = rain ? vec4(0.68, 0.77, 0.84, 0.40) : vec4(0.13, 0.20, 0.29, 0.14);
		ink.a *= strength;
	} else if (effect_kind == 11) {
		float n = noise(q * 0.3 + vec2(0.0, -t * 4.0));
		float r = length((q - vec2(0.0, -8.0 - impact_phase * 6.0)) / (vec2(12.0, 15.0) + impact_phase * 6.0)) + n * 0.3;
		float body = 1.0 - smoothstep(0.8, 1.15, r);
		vec3 color = r < 0.47 ? vec3(1.0, 0.94, 0.64) : (r < 0.72 ? vec3(1.0, 0.67, 0.11) : vec3(0.91, 0.29, 0.04));
		ink = vec4(color, body * 0.96);
		if (impact_phase > 0.5) {
			ink = over(ink, vec3(0.40, 0.38, 0.34), puff(q, vec2(4.0, -26.0), vec2(15.0, 11.0)) * 0.7);
		}
		emission = 0.85 * body;
	}
	ink.rgb = mix(environment_color(ink.rgb, UV), ink.rgb, clamp(emission, 0.0, 1.0));
	if (progress >= 0.0 && effect_kind != 5) { ink.a *= 1.0 - smoothstep(0.65, 1.0, progress); }
	if (has_foreground) { ink.a *= 1.0 - texture(foreground, UV).a; }
	// Replacement artwork remains identifiable; strength controls surrounding atmosphere.
	COLOR = vec4(ink.rgb, clamp(ink.a, 0.0, 1.0));
}
