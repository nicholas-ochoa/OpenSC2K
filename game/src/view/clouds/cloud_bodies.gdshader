shader_type canvas_item;
render_mode unshaded;
#include "res://src/view/clouds/cloud_field.gdshaderinc"

uniform mat3 cloud_canvas_to_body_grid = mat3(1.0);
uniform float cloud_map_edge = 128.0;
uniform float cloud_opacity = 1.0;
uniform vec3 cloud_light = vec3(1.0);
varying vec2 body_grid;

void vertex() {
	vec2 canvas_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	body_grid = (cloud_canvas_to_body_grid * vec3(canvas_position, 1.0)).xy;
}

void fragment() {
	COLOR = cloud_body(body_grid, cloud_map_edge, cloud_opacity, cloud_light);
}
