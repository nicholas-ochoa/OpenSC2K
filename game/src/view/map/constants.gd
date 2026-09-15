class_name CityMapConstants
extends RefCounted
# shared view constants and unchanged palette shader source

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const DynamicSpriteCanvas = preload("res://src/view/city_dynamic_sprite_canvas.gd")
const ZOOM_LEVELS := [0.1, 0.25, 0.5, 1.0, 2.0, 3.0, 4.0]
const DEFAULT_ZOOM_INDEX := 3
const WHEEL_ZOOM_DEBOUNCE_MSEC := 250
# a continuing wheel gesture can delay the next wheel zoom by at most this much
const WHEEL_ZOOM_MAX_DEBOUNCE_MSEC := 500
# child layer order: network preview artwork, then the price label above it
const NETWORK_PREVIEW_Z_INDEX := 80
const PRICE_LAYER_Z_INDEX := 90
const SIGN_FONT_HEIGHTS := [12, 14, 16]
const SIGN_PANEL_FILL := Color("9f9f9f")
const SIGN_POST_FILL := Color("bbbbbb")
const SIGN_EDGE_LIGHT := Color("e3e3e3")
const SIGN_EDGE_MIDDLE := Color("838383")
const SIGN_EDGE_DARK := Color("575757")
const SIGN_TEXT_COLOR := Color("000030")
const PALETTE_CYCLE_SHADER := """
shader_type canvas_item;

uniform sampler2D palette_indices : filter_nearest, repeat_disable;
uniform sampler2D animated_palette : source_color, filter_nearest, repeat_disable;
uniform bool palette_cycle_enabled = false;
uniform bool palette_lookup_all = false;
uniform bool dark_underground = false;
uniform sampler2D dark_underground_palette : source_color, filter_nearest, repeat_disable;

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
	if (dark_underground) {
		COLOR.rgb = texture(dark_underground_palette, vec2((float(palette_index) + 0.5) / 256.0, 0.5)).rgb;
	}
}
"""
