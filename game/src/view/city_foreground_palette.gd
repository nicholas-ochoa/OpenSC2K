class_name CityForegroundPalette
extends RefCounted
# the reserved draw color marks indexed foreground commands, not image pixels
# other city overlay commands retain their normal texture and vertex colors
const INDEXED_DRAW_COLOR := Color.MAGENTA
const SHADER := """
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
"""


static func create_material(palette: Texture2D) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = SHADER
	var result := ShaderMaterial.new()
	result.shader = shader
	result.set_shader_parameter("foreground_palette", palette)

	return result
