
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D foreground_palette : filter_nearest, repeat_disable;
varying flat float indexed_foreground;
void vertex() {
	indexed_foreground = all(equal(COLOR, vec4(1.0, 0.0, 1.0, 1.0))) ? 1.0 : 0.0;
}
void fragment() {
	if (indexed_foreground > 0.5) {
		vec4 encoded = texture(TEXTURE, UV);
		float index = floor(encoded.r * 255.0 + 0.5);
		vec4 color = texture(foreground_palette, vec2((index + 0.5) / 256.0, 0.5));
		COLOR = vec4(color.rgb, encoded.a);
	}
}
