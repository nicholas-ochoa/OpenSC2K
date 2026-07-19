class_name CityMapConstants
extends RefCounted
# shared view constants and unchanged palette shader source

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const HighwayTool = preload("res://src/tools/city/highway_command.gd")
const DemolishTool = preload("res://src/tools/city/demolish_command.gd")
const BuildingTool = preload("res://src/tools/city/building_command.gd")
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
		float high = max(COLOR.r, max(COLOR.g, COLOR.b));
		float low = min(COLOR.r, min(COLOR.g, COLOR.b));
		// Preserve sprite shading. Only white is the underground paper background.
		if (palette_lookup_all && palette_index >= 200 && palette_index <= 207) {
			// Original flowing-water cycle. Keep its moving highlights.
			COLOR.rgb = mix(vec3(0.22, 0.66, 0.82), vec3(0.66, 0.94, 1.0), COLOR.g);
		} else if (palette_lookup_all && palette_index >= 140 && palette_index <= 147) {
			// Original fixed blue pipe ramp means no water, not flowing water.
			COLOR.rgb = mix(vec3(0.36, 0.20, 0.12), vec3(0.72, 0.46, 0.28), high);
		} else if (low > 0.97) {
			COLOR.rgb = vec3(0.125, 0.157, 0.188);
		} else if (high - low < 0.08) {
			COLOR.rgb = mix(vec3(0.28, 0.33, 0.38), vec3(0.60, 0.66, 0.70), high);
		} else if (COLOR.b > COLOR.r * 1.3 && COLOR.b > COLOR.g * 1.15) {
			// Water pipes: readable blue with enough green for dark-background contrast.
			COLOR.rgb = mix(vec3(0.18, 0.43, 0.65), vec3(0.40, 0.78, 0.96), high);
		} else if (COLOR.g > COLOR.r * 1.2 && COLOR.g > COLOR.b * 1.2) {
			// Subway routes remain green and distinct from the water network.
			COLOR.rgb = mix(vec3(0.18, 0.43, 0.28), vec3(0.45, 0.82, 0.56), high);
		} else {
			// Keep terrain wireframes subordinate to the networks.
			COLOR.rgb *= 0.60;
		}
	}
}
"""
