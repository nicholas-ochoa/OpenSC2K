shader_type canvas_item;

#include "res://src/view/environment/environment_color.gdshaderinc"
#include "res://src/view/clouds/cloud_field.gdshaderinc"

varying vec2 cloud_ground_grid;

void vertex() {
	cloud_ground_grid = cloud_grid_at((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy);
}

void fragment() {
	vec4 artwork = texture(TEXTURE, UV);
	COLOR = vec4(environment_color(cloud_shadow(artwork.rgb, cloud_ground_grid), UV), artwork.a);
}
