shader_type canvas_item;
render_mode unshaded;
#include "res://src/view/environment/environment_color.gdshaderinc"

uniform int effect_kind = 0;
uniform int cloud_style = 0;
uniform float effect_time = 0.0;
uniform float effect_seed = 0.0;
uniform float effect_strength = 0.7;
uniform float light_strength = 0.4;
uniform float progress = -1.0;
uniform bool frame_blending = false;
uniform float lifecycle_opacity = 1.0;
uniform float impact_phase = 0.0;
uniform float smoke_density = 1.0;
uniform bool sparse_crowd = false;
uniform vec2 world_origin = vec2(0.0);
uniform vec4 flood_edges = vec4(1.0);
uniform sampler2D foreground : filter_nearest, repeat_disable;
uniform bool has_foreground = false;
uniform vec2 foreground_scale = vec2(1.0);
uniform vec2 foreground_offset = vec2(0.0);
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

vec4 effect_frame(vec2 uv, float sample_time) {
	// Native pixels keep contours stable at every map zoom. q=0 is the tile centre.
	vec2 q = floor(uv * vec2(96.0, 144.0)) + vec2(0.5) - vec2(48.0, 128.0);
	float t = sample_time + effect_seed;
	float diamond = abs(q.x) / 16.0 + abs(q.y) / 8.0;
	float emission = 0.0;
	vec4 ink = vec4(0.0);
	float strength = mix(0.55, 1.0, effect_strength);
	if (effect_kind == 0 || effect_kind == 7 || effect_kind == 12 || effect_kind == 11) {
		// Separate expanding billows leave gaps through the plume.
		float plume_height = effect_kind == 7 ? 108.0 : (effect_kind == 12 ? 36.0 : 64.0);
		for (int i = 0; i < 8; i++) {
			float f = fract(t * 0.17 + float(i) * 0.125);
			vec2 at = vec2(f * 15.0 + sin(t * 0.7 + float(i) * 2.4) * 3.0, -8.0 - f * plume_height);
			vec2 r = vec2(5.0 + f * 9.0, 6.0 + f * 7.0);
			float shade = floor((noise(q * 0.35 + vec2(0.0, t * 0.9)) * 0.12 + (q.x - at.x) / r.x * 0.06 + 0.40) * 12.0) / 12.0;
			ink = over(ink, vec3(shade, shade * 0.98, shade * 0.94), puff(q, at, r) * sin(f * 3.14159) * 0.34 * strength * smoke_density);
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
			float n = noise(w * vec2(0.15, 0.32) + vec2(sample_time * 0.4, 0.0));
			float ripple = noise(w * vec2(0.24, 0.9) - vec2(sample_time, sample_time * 0.5));
			vec3 water = mix(vec3(0.16, 0.40, 0.54), vec3(0.30, 0.59, 0.68), floor(n * 4.0) / 3.0);
			water = mix(water, vec3(0.58, 0.77, 0.80), step(0.77, ripple) * 0.65);
			float edge = q.x > 0.0 ? (q.y > 0.0 ? flood_edges.x : flood_edges.y) : (q.y > 0.0 ? flood_edges.z : flood_edges.w);
			float foam = step(0.80 + n * 0.09, diamond) * edge;
			ink = vec4(mix(water, vec3(0.78, 0.87, 0.83), foam), mix(0.78, 0.92, foam));
		}
	} else if (effect_kind == 2 || effect_kind == 9) {
		vec3 gas = effect_kind == 9 ? vec3(0.64, 0.55, 0.25)
			: (cloud_style == 2 ? vec3(0.92, 0.50, 0.09) : (cloud_style == 1 ? vec3(0.55, 0.62, 0.23) : vec3(0.53, 0.51, 0.47)));
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
		vec2 uv = vec2((uv.x + mod(floor(t * 6.0), 8.0)) / 8.0, (uv.y + (sparse_crowd ? 1.0 : 0.0)) * 0.5);
		ink = texture(people, uv);
	} else if (effect_kind == 4) {
		for (int i = 0; i < 9; i++) {
			float a = t * (2.0 + float(i) * 0.13) + float(i) * 2.4;
			float r = 12.0 + mod(float(i) * 7.0, 19.0);
			vec2 at = vec2(cos(a) * r, -4.0 - mod(float(i) * 11.0, 40.0) + sin(a) * 5.0);
			ink = over(ink, vec3(0.36, 0.30, 0.22), step(length((q - at) / vec2(1.7, 1.0)), 1.0) * 0.85);
		}
		ink = over(ink, vec3(0.62, 0.56, 0.43), puff(q, vec2(sin(t * 3.0) * 8.0, -1.0), vec2(17.0, 5.0)) * 0.36);
	} else if (effect_kind == 5) {
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
		// Stepped pixel core and a narrow blue halo fit the original raster artwork.
		float core = step(abs(q.x), 1.5);
		float halo = 1.0 - smoothstep(1.5, 5.0, abs(q.x));
		ink = vec4(mix(vec3(0.025, 0.28, 1.0), vec3(0.22, 0.66, 1.0), core), q.y < 0.0 ? (core * 0.95 + halo * 0.28) : 0.0);
		ink = over(ink, vec3(0.12, 0.56, 1.0), puff(q, vec2(0.0, -1.0), vec2(9.0, 4.0)) * 0.85);
		emission = 1.0;
	} else if (effect_kind == 10) {
		float lane = fract(uv.x * 149.0 + uv.y * 48.0);
		float drop = fract(uv.y * 42.0 - sample_time * 3.0 + floor(uv.x * 149.0 + uv.y * 48.0) * 0.37);
		bool rain = lane > 0.94 && drop > 0.66;
		ink = rain ? vec4(0.68, 0.77, 0.84, 0.40) : vec4(0.13, 0.20, 0.29, 0.14);
		ink.a *= strength;
	} else if (effect_kind == 13) {
		// Roof fragments and masonry only follow confirmed structure destruction.
		float f = clamp(progress, 0.0, 1.0);
		for (int i = 0; i < 12; i++) {
			float id = float(i), a = id * 2.4 + effect_seed;
			vec2 at = vec2(cos(a) * f * (22.0 + mod(id * 7.0, 18.0)), -sin(f * 3.14159) * (18.0 + mod(id * 11.0, 28.0)) + f * sin(a) * 6.0);
			vec2 d = q - at;
			float turn = a + f * 9.0;
			d = mat2(vec2(cos(turn), -sin(turn)), vec2(sin(turn), cos(turn))) * d;
			float chip = step(abs(d.x), 2.5) * step(abs(d.y), 1.4);
			vec3 color = mod(id, 3.0) < 1.0 ? vec3(0.59, 0.27, 0.15) : (mod(id, 3.0) < 2.0 ? vec3(0.62, 0.59, 0.50) : vec3(0.35, 0.25, 0.15));
			ink = over(ink, color, chip * (1.0 - smoothstep(0.60, 1.0, f)));
		}
	}
	ink.rgb = mix(environment_color(ink.rgb, uv), ink.rgb, clamp(emission, 0.0, 1.0));
	if (progress >= 0.0 && effect_kind != 5) { ink.a *= 1.0 - smoothstep(0.65, 1.0, progress); }
	// Only real treatment tiles receive an edge; foreground covers it like the crowd.
	if (effect_kind == 3 && !sparse_crowd && diamond > 0.82 && diamond < 1.0) {
		ink = over(ink, vec3(0.92, 0.64, 0.24), 0.58);
	}
	if (has_foreground) { ink.a *= 1.0 - texture(foreground, uv * foreground_scale + foreground_offset).a; }
	// Replacement artwork remains identifiable; strength controls surrounding atmosphere.
	return vec4(ink.rgb, clamp(ink.a, 0.0, 1.0));
}

void fragment() {
	vec4 ink;
	if (frame_blending && (effect_kind <= 2 || effect_kind == 4 || effect_kind == 5 || effect_kind == 7 || effect_kind >= 11)) {
		float phase = effect_time * 15.0;
		float first_time = floor(phase) / 15.0;
		vec4 a = effect_frame(UV, first_time);
		vec4 b = effect_frame(UV, first_time + 1.0 / 15.0);
		float alpha = mix(a.a, b.a, fract(phase));
		ink = vec4(mix(a.rgb * a.a, b.rgb * b.a, fract(phase)) / max(alpha, 0.00001), alpha);
	} else {
		ink = effect_frame(UV, effect_time);
	}
	COLOR = vec4(ink.rgb, ink.a * lifecycle_opacity);
}
