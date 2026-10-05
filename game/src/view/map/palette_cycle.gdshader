shader_type canvas_item;

uniform sampler2D palette_indices : filter_nearest, repeat_disable;
uniform sampler2D animated_palette : source_color, filter_nearest, repeat_disable;
uniform bool palette_cycle_enabled = false;
uniform bool palette_lookup_all = false;
uniform bool dark_underground = false;
uniform sampler2D dark_underground_palette : source_color, filter_nearest, repeat_disable;
// Seconds of HD sprite animation. They stop while the game is paused.
uniform float artwork_animation_seconds = 0.0;

// The red byte of the vertex color of a GPU region quad tells how to draw it.
// Other values are indexed sprites. Refer to native/rendering/src/region.rs.
const float ARTWORK_TAG = 2.0;
const float POWER_WARNING_TAG = 50.0;
const float ANIMATION_TAG = 64.0;
const float SLOW_ANIMATION_TAG = 65.0;
const float TRAFFIC_TAG = 80.0;
const float LAST_TRAFFIC_TAG = 111.0;
// The palette entry that makes the power warning blink.
const float POWER_WARNING_INDEX = 195.0;
// Filtered art reads at most this many texels on each side of a sample.
const float MAX_FOOTPRINT = 4.0;

// 0: indexed sprite. 1: full-color art. 2: full-color traffic with a road mask.
varying flat float artwork_kind;
varying flat float power_warning;
// The frame count, the frames each second, and the frame stride in texels.
varying flat vec3 artwork_frames;
// The texel of the record of a masked traffic quad.
varying flat vec2 traffic_record;

void vertex() {
	vec4 bytes = round(COLOR * 255.0);
	float tag = bytes.r;
	artwork_kind = 0.0;
	power_warning = 0.0;
	artwork_frames = vec3(1.0, 8.0, 0.0);
	traffic_record = vec2(0.0);

	if (tag == ARTWORK_TAG || tag == POWER_WARNING_TAG) {
		artwork_kind = 1.0;
		power_warning = tag == POWER_WARNING_TAG ? 1.0 : 0.0;
	} else if (tag == ANIMATION_TAG || tag == SLOW_ANIMATION_TAG) {
		artwork_kind = 1.0;
		artwork_frames = vec3(bytes.g, tag == SLOW_ANIMATION_TAG ? 5.0 : 8.0, bytes.b * 256.0 + bytes.a);
	} else if (tag >= TRAFFIC_TAG && tag <= LAST_TRAFFIC_TAG) {
		artwork_kind = 2.0;
		traffic_record = vec2((tag - TRAFFIC_TAG) * 256.0 + bytes.g, bytes.b * 256.0 + bytes.a);
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

// The atlas texel at texel coordinates `texel`. Only fragment() can read TEXTURE.
#define ATLAS(texel) texture(TEXTURE, ((texel) + 0.5) * TEXTURE_PIXEL_SIZE)

void fragment() {
	vec2 texel = UV / TEXTURE_PIXEL_SIZE;
	vec2 footprint = fwidth(texel);

	if (artwork_kind < 0.5) {
		COLOR = indexed_color(UV, texture(TEXTURE, UV));
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

		if (power_warning > 0.5 && palette_cycle_enabled) {
			vec3 phase = texture(animated_palette, vec2((POWER_WARNING_INDEX + 0.5) / 256.0, 0.5)).rgb;
			COLOR.rgb = mix(COLOR.rgb, phase, 0.3);
		}
	}
}
