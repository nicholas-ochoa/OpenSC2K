shader_type canvas_item;

#include "res://src/view/environment/environment_color.gdshaderinc"
#include "res://src/view/clouds/cloud_field.gdshaderinc"

varying vec2 cloud_ground_grid;
uniform sampler2D vehicle_emission : source_color, filter_nearest, repeat_disable;
uniform bool vehicle_has_emission = false;

void vertex() {
	cloud_ground_grid = cloud_grid_at((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy);
}

void fragment() {
	vec4 artwork = texture(TEXTURE, UV);
	vec3 color = environment_color(cloud_shadow(artwork.rgb, cloud_ground_grid), UV);
	if (vehicle_has_emission && environment_enabled) {
		vec4 lamps = texture(vehicle_emission, UV);
		color = mix(color, lamps.rgb, lamps.a * environment_night);
	}
	COLOR = vec4(color, artwork.a);
}
