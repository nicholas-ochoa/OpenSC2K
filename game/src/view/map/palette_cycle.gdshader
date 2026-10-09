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
// Seconds of HD sprite animation. They stop while the game is paused.
uniform float artwork_animation_seconds = 0.0;

// The red byte of the vertex color of a GPU region quad tells how to draw it.
// Other values are indexed sprites. Refer to native/core/render/src/region.rs.
const float ARTWORK_TAG = 2.0;
const float POWER_WARNING_TAG = 50.0;
const float ANIMATION_TAG = 64.0;
const float SLOW_ANIMATION_TAG = 65.0;
const float TRAFFIC_TAG = 80.0;
const float LAST_TRAFFIC_TAG = 111.0;
// Optional HD effects. Refer to `effects` in native/core/render/src/lib.rs.
// Grid lines: UV.y is the distance across the line, in view pixels.
const float GRID_TAG = 48.0;
// Waterfall art: green is the view, blue and alpha the sprite position.
const float WATERFALL_TAG = 49.0;
// The indexed sprite under underground HD art, for the water in its pipes.
const float PIPE_FLOW_TAG = 52.0;
const vec3 GRID_COLOR = vec3(0.22, 0.19, 0.10);
const float GRID_OPACITY = 0.36;
const float GRID_WIDTH = 0.45;
const float PIPE_FLOW_OPACITY = 0.32;
// The palette entry that makes the power warning blink.
const float POWER_WARNING_INDEX = 195.0;
// The dark underground view: art at least this light is the white background.
const float DARK_WHITE = 0.97;
const vec3 DARK_BACKGROUND = vec3(0.125, 0.157, 0.188);
const float DARK_ARTWORK = 0.85;
// Filtered art reads at most this many texels on each side of a sample.
const float MAX_FOOTPRINT = 4.0;

// 0: indexed sprite. 1: full-color art. 2: full-color traffic with a road mask.
// 3: grid line. 4: palette animation over art. 5: water in underground pipes.
varying flat float artwork_kind;
varying flat float building_emission;
varying flat float grid_width;
// The view of waterfall art, or -1, and the position in its sprite in large
// view pixels.
varying flat float waterfall_view;
varying vec2 waterfall_local;
// The position in the city, in large view pixels.
varying vec2 world_position;
varying flat float power_warning;
// The frame count, the frames each second, and the frame stride in texels.
varying flat vec3 artwork_frames;
// The texel of the record of a masked traffic quad.
varying flat vec2 traffic_record;

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

	vec4 bytes = round(COLOR * 255.0);
	float tag = bytes.r;
	// Native building quads reserve red bit 7; plain indexed white (255) is unchanged.
	building_emission = float(tag < 128.0 || tag == 255.0);
	if (building_emission < 0.5) { tag -= 128.0; }
	artwork_kind = 0.0;
	power_warning = 0.0;
	artwork_frames = vec3(1.0, 8.0, 0.0);
	traffic_record = vec2(0.0);
	grid_width = 0.0;
	waterfall_view = -1.0;
	waterfall_local = vec2(0.0);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy / max(length(MODEL_MATRIX[0].xy), 0.00001);

	if (tag == ARTWORK_TAG || tag == POWER_WARNING_TAG) {
		artwork_kind = 1.0;
		power_warning = tag == POWER_WARNING_TAG ? 1.0 : 0.0;
	} else if (tag == ANIMATION_TAG || tag == SLOW_ANIMATION_TAG) {
		artwork_kind = 1.0;
		artwork_frames = vec3(bytes.g, tag == SLOW_ANIMATION_TAG ? 5.0 : 8.0, bytes.b * 256.0 + bytes.a);
	} else if (tag >= TRAFFIC_TAG && tag <= LAST_TRAFFIC_TAG) {
		artwork_kind = 2.0;
		traffic_record = vec2((tag - TRAFFIC_TAG) * 256.0 + bytes.g, bytes.b * 256.0 + bytes.a);
	} else if (tag == GRID_TAG) {
		artwork_kind = 3.0;
		grid_width = GRID_WIDTH / exp2(2.0 - bytes.g);
	} else if (tag == WATERFALL_TAG) {
		artwork_kind = 1.0;
		waterfall_view = bytes.g;
		// a small view pixel is 4 large view pixels
		float divisor = exp2(2.0 - bytes.g);
		world_position *= divisor;
		waterfall_local = COLOR.ba * vec2(32.0, 28.0 + divisor);
	} else if (tag == PIPE_FLOW_TAG) {
		artwork_kind = 5.0;
	}
	// Effect phases use the red channel continuously, so their rounded value
	// must never select an HD-art record. The blue effect tag takes priority.
	if (hazard_draw > 0.5) {
		artwork_kind = 0.0;
		power_warning = 0.0;
	}
}

// Two 16-bit words from one texel of a record, high byte first.
vec2 record_words(vec4 texel) {
	vec4 bytes = round(texel * 255.0);
	return vec2(bytes.r * 256.0 + bytes.g, bytes.b * 256.0 + bytes.a);
}

vec4 premultiplied(vec4 color) {
	return vec4(color.rgb * color.a, color.a);
}

vec4 indexed_color(vec2 uv, vec4 base_color) {
	vec4 result;
	float encoded_index = (
		palette_lookup_all ? base_color.r : texture(palette_indices, uv).r
	);
	int palette_index = int(round(encoded_index * 255.0));
	bool animated_index =
		(palette_index >= 171 && palette_index <= 198) ||
		(palette_index >= 200 && palette_index <= 219) ||
		(palette_index >= 224 && palette_index <= 239);
	if (palette_cycle_enabled && (palette_lookup_all || animated_index)) {
		vec2 palette_uv = vec2((float(palette_index) + 0.5) / 256.0, 0.5);
		vec4 cycle_color = texture(animated_palette, palette_uv);
		result = vec4(cycle_color.rgb, base_color.a);
	} else {
		result = base_color;
	}
	if (dark_underground) {
		result.rgb = texture(dark_underground_palette, vec2((float(palette_index) + 0.5) / 256.0, 0.5)).rgb;
	}
	return result;
}

vec4 palette_color(int index) {
	return texture(animated_palette, vec2((float(index) + 0.5) / 256.0, 0.5));
}

bool animated_color(int index) {
	return (index >= 171 && index <= 198) || (index >= 200 && index <= 219) || (index >= 224 && index <= 239);
}

int palette_index(vec4 encoded) {
	return int(round(encoded.r * 255.0));
}

// Bilinear filtering of four premultiplied texels, with straight alpha out.
vec4 filtered(vec4 a, vec4 b, vec4 c, vec4 d, vec2 weight) {
	vec4 result = mix(mix(a, b, weight.x), mix(c, d, weight.x), weight.y);
	return result.a > 0.0 ? vec4(result.rgb / result.a, result.a) : vec4(0.0);
}

// The water of a watered underground pipe (the water colors 200 to 207), premultiplied.
vec4 pipe_water(vec4 encoded) {
	int index = palette_index(encoded);

	if (encoded.a <= 0.0 || index < 200 || index > 207) {
		return vec4(0.0);
	}

	vec3 cycle = palette_color(index).rgb;
	vec3 flow = mix(vec3(0.05, 0.45, 0.65), vec3(0.75, 1.0, 1.0), clamp(cycle.g * 1.6, 0.0, 1.0));
	float alpha = encoded.a * PIPE_FLOW_OPACITY;

	return vec4((dark_underground ? flow * DARK_ARTWORK : flow) * alpha, alpha);
}

float flow_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float flow_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 phase = fract(point);
	phase = phase * phase * (3.0 - 2.0 * phase);
	return mix(mix(flow_hash(cell), flow_hash(cell + vec2(1.0, 0.0)), phase.x),
		mix(flow_hash(cell + vec2(0.0, 1.0)), flow_hash(cell + vec2(1.0)), phase.x), phase.y);
}

// Falling water on the two vertical faces of a waterfall, under a quiet top.
// The top face spans the upper half-tile diamond of the sprite.
vec3 waterfall_flow(vec3 material) {
	float edge_y = 16.0 - abs(waterfall_local.x - 16.0) * 0.5;
	float face = smoothstep(-0.18, 0.18, waterfall_local.y - edge_y);
	float seconds = artwork_animation_seconds;
	float ripple = flow_noise(world_position * vec2(0.21, 0.27) - vec2(0.0, seconds * 0.55));
	vec3 surface = material * (0.98 + ripple * 0.04);
	float running = world_position.y - seconds * 12.0;
	float ribbons = flow_noise(vec2(world_position.x * 0.62, running * 0.14));
	float fine = flow_noise(vec2(world_position.x * 1.2 + 17.0, running * 0.29));
	float foam = smoothstep(0.55, 0.86, ribbons) * 0.52 + smoothstep(0.72, 0.95, fine) * 0.16;
	vec3 falling = mix(material * (0.94 + ribbons * 0.10), vec3(0.79, 0.94, 0.98), foam);

	return mix(surface, falling, face);
}

// The atlas texel at texel coordinates `texel`. Only fragment() can read TEXTURE.
// Reads stay inside the texture: a CPU region texture ends at its edge texels.
#define ATLAS(texel) texture(TEXTURE, (clamp(texel, vec2(0.0), 1.0 / TEXTURE_PIXEL_SIZE - 1.0) + 0.5) * TEXTURE_PIXEL_SIZE)

void fragment() {
	vec2 texel = UV / TEXTURE_PIXEL_SIZE;
	vec2 footprint = fwidth(texel);

	if (artwork_kind < 0.5) {

		vec4 base_color = texture(TEXTURE, UV);
		float encoded_index = (
			palette_lookup_all ? base_color.r : texture(palette_indices, UV).r
		);
		int palette_index = int(round(encoded_index * 255.0));
		// The auxiliary mask follows sprite silhouettes and painter occlusion.
		// Its blue channel is reserved for power warnings, not terrain colors.
		vec4 natural_mask = environment_has_seasons ? texture(environment_season_mask, UV) : vec4(0.0);
		bool indexed_power_warning = natural_mask.b > 0.5;
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
		} else if (fullbright_draw < 0.5 && !indexed_power_warning) {
			if (water_enabled && natural_mask.b > 0.2 && natural_mask.b < 0.3) {
				// Water sides keep their original shading/animation and painter
				// occlusion. Only share the surface tint; no flat waves or mirrors.
				COLOR.rgb = water_season_color(COLOR.rgb);
				if (water_reflections_enabled || water_topography || water_waves_enabled) {
					COLOR.rgb = water_body_tone(COLOR.rgb, 0.0, 0.0);
				}
			}
			COLOR.rgb = environment_color_emission(cloud_shadow(COLOR.rgb, cloud_ground_grid), UV, building_emission);
		}
	} else if (artwork_kind > 2.5 && artwork_kind < 3.5) {
		// an antialiased line along the edge of a tile
		float feather = max(fwidth(UV.y), 0.00001);
		float coverage = clamp((grid_width * 0.5 + feather * 0.5 - abs(UV.y - grid_width * 0.5)) / feather, 0.0, 1.0);
		COLOR = vec4(GRID_COLOR, coverage * GRID_OPACITY);
	} else if (artwork_kind > 4.5) {
		vec2 cell = texel - 0.5;
		vec2 corner = floor(cell);
		COLOR = filtered(pipe_water(ATLAS(corner)), pipe_water(ATLAS(corner + vec2(1.0, 0.0))),
			pipe_water(ATLAS(corner + vec2(0.0, 1.0))), pipe_water(ATLAS(corner + vec2(1.0))), cell - corner);
	} else {
		vec3 frames = artwork_frames;
		vec4 origin = vec4(0.0);
		vec4 mask = vec4(0.0);
		float mirrored = 0.0;

		// The record of masked traffic: the art slot and its frame size, the
		// frame timing, the road mask slot and its size, and the mirror flag.
		if (artwork_kind > 1.5) {
			origin = vec4(record_words(ATLAS(traffic_record)), record_words(ATLAS(traffic_record + vec2(1.0, 0.0))));
			vec2 timing = record_words(ATLAS(traffic_record + vec2(2.0, 0.0)));
			frames = vec3(floor(timing.x / 256.0), mod(timing.x, 256.0), timing.y);
			mask = vec4(record_words(ATLAS(traffic_record + vec2(3.0, 0.0))), record_words(ATLAS(traffic_record + vec2(4.0, 0.0))));
			mirrored = record_words(ATLAS(traffic_record + vec2(5.0, 0.0))).x;
		}

		float frame = mod(floor(artwork_animation_seconds * frames.y), max(frames.x, 1.0));
		vec2 center = texel + vec2(0.0, frame * frames.z);

		// Bilinear filtering of premultiplied colors, so transparent texels
		// add no dark edge. Where the art is smaller on screen than its
		// texels, four bilinear samples spread over the pixel average it.
		vec2 spread = (clamp(footprint, vec2(1.0), vec2(MAX_FOOTPRINT)) - 1.0) * 0.25;
		vec4 sum = vec4(0.0);

		for (int tap = 0; tap < 4; tap++) {
			vec2 offset = vec2(tap % 2 == 0 ? -spread.x : spread.x, tap < 2 ? -spread.y : spread.y);
			vec2 cell = center + offset - 0.5;
			vec2 corner = floor(cell);
			vec2 weight = cell - corner;
			vec4 a = premultiplied(ATLAS(corner));
			vec4 b = premultiplied(ATLAS(corner + vec2(1.0, 0.0)));
			vec4 c = premultiplied(ATLAS(corner + vec2(0.0, 1.0)));
			vec4 d = premultiplied(ATLAS(corner + vec2(1.0)));
			sum += mix(mix(a, b, weight.x), mix(c, d, weight.x), weight.y);
		}

		sum *= 0.25;
		COLOR = sum.a > 0.0 ? vec4(sum.rgb / sum.a, sum.a) : vec4(0.0);

		if (artwork_kind > 1.5) {
			// The road mask has one texel for each logical pixel of the sprite.
			vec2 local = clamp((texel - origin.xy) / origin.zw, vec2(0.0), vec2(0.999999));
			if (mirrored > 0.5) {
				local.x = 1.0 - local.x;
			}
			COLOR.a *= ATLAS(mask.xy + floor(local * mask.zw)).a;
		}

		if (waterfall_view >= 0.0) {
			COLOR.rgb = waterfall_flow(COLOR.rgb);
		}

		// the dark underground view makes the white background slate, and dims
		// the art a little, as its palette does for indexed sprites
		if (dark_underground) {
			COLOR.rgb = min(COLOR.r, min(COLOR.g, COLOR.b)) > DARK_WHITE ? DARK_BACKGROUND : COLOR.rgb * DARK_ARTWORK;
		}

		if (!dark_underground && power_warning < 0.5) {
			COLOR.rgb = environment_color_emission(cloud_shadow(COLOR.rgb, cloud_ground_grid), center * TEXTURE_PIXEL_SIZE, building_emission);
		}

		if (power_warning > 0.5 && palette_cycle_enabled) {
			vec3 phase = texture(animated_palette, vec2((POWER_WARNING_INDEX + 0.5) / 256.0, 0.5)).rgb;
			COLOR.rgb = mix(COLOR.rgb, phase, 0.3);
		}
	}
}
