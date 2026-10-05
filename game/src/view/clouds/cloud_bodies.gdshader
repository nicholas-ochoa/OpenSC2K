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
	if (!cloud_enabled || cloud_density <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		vec2 uv = (body_grid - cloud_drift) / cloud_span;
		float height = texture(cloud_field, uv).r;
		float detail = texture(cloud_field, uv * 7.0).r;
		float upper_left = texture(cloud_field, uv - vec2(0.006, 0.009)).r;
		float lower_right = texture(cloud_field, uv + vec2(0.006, 0.009)).r;
		float relief = clamp(0.83 + (upper_left - lower_right) * 3.5
			+ (detail - 0.5) * 0.25 + (height - cloud_threshold()) * 0.9, 0.60, 1.0);
		vec3 color = mix(vec3(0.60, 0.67, 0.76), vec3(1.0), relief) * cloud_light;
		// Let clouds enter and leave gently at the map boundary. This clips the
		// aerial plane, not the city silhouette or the UI.
		vec2 edge_distance = min(body_grid, vec2(cloud_map_edge) - body_grid);
		float boundary = smoothstep(-4.0, 3.0, min(edge_distance.x, edge_distance.y));
		COLOR = vec4(color, cloud_cover(body_grid) * boundary * cloud_opacity * 0.94);
	}
}
