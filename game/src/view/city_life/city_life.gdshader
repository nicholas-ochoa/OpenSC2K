shader_type canvas_item;

#include "res://src/view/environment/environment_color.gdshaderinc"

void fragment() {
	vec4 artwork = texture(TEXTURE, UV);
	COLOR = vec4(environment_color(artwork.rgb, UV), artwork.a);
}
