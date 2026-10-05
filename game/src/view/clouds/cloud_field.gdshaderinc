// Shared by the city pixels and the aerial cloud layer. Coordinates are tiles
// in the unrotated map, independent of atlas UVs, camera movement and zoom.
uniform bool cloud_enabled = false;
uniform sampler2D cloud_field : filter_linear_mipmap, repeat_enable;
uniform mat3 cloud_canvas_to_grid = mat3(1.0);
uniform vec2 cloud_drift = vec2(0.0);
uniform float cloud_span = 192.0;
uniform float cloud_density = 0.4;
uniform float cloud_shadow_strength = 0.22;
uniform vec2 cloud_shadow_offset = vec2(4.0, 2.0);

vec2 cloud_grid_at(vec2 canvas_position) {
	return (cloud_canvas_to_grid * vec3(canvas_position, 1.0)).xy;
}

float cloud_threshold() {
	return mix(0.76, 0.48, cloud_density);
}

float cloud_cover(vec2 grid_position) {
	vec2 uv = (grid_position - cloud_drift) / cloud_span;
	float shape = texture(cloud_field, uv).r;
	float detail = texture(cloud_field, uv * 7.0).r;
	return smoothstep(cloud_threshold() - 0.025, cloud_threshold() + 0.055,
		shape + (detail - 0.5) * 0.075);
}

vec3 cloud_shadow(vec3 color, vec2 grid_position) {
	if (!cloud_enabled || cloud_density <= 0.0 || cloud_shadow_strength <= 0.0) {
		return color;
	}
	vec2 point = grid_position - cloud_shadow_offset;
	float coverage = cloud_cover(point) * 0.4;
	coverage += cloud_cover(point + vec2(1.5, 0.0)) * 0.15;
	coverage += cloud_cover(point - vec2(1.5, 0.0)) * 0.15;
	coverage += cloud_cover(point + vec2(0.0, 1.5)) * 0.15;
	coverage += cloud_cover(point - vec2(0.0, 1.5)) * 0.15;
	return color * (1.0 - coverage * cloud_shadow_strength);
}
