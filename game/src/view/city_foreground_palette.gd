class_name CityForegroundPalette
extends RefCounted
# the reserved draw color marks indexed foreground commands, not image pixels
# other city overlay commands retain their normal texture and vertex colors
const INDEXED_DRAW_COLOR := Color.MAGENTA
const SHADER := preload("res://src/view/city_foreground_palette.gdshader")


static func create_material(palette: Texture2D) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = SHADER
	result.set_shader_parameter("foreground_palette", palette)

	return result
