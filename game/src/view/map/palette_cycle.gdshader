
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
