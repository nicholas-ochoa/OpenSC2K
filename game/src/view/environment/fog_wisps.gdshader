shader_type canvas_item;
render_mode unshaded;

uniform sampler2D fog_field : repeat_enable, filter_linear_mipmap;
uniform mat3 fog_canvas_to_grid = mat3(1.0);
uniform float fog_map_edge = 128.0;
uniform vec2 fog_drift = vec2(0.0);
uniform float fog_density = 0.0;
uniform vec3 fog_light = vec3(1.0);
uniform bool fog_has_height_mask = false;
uniform sampler2D fog_height_mask : filter_linear, repeat_disable;
varying vec2 fog_grid;

void vertex() {
	vec2 canvas_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	fog_grid = (fog_canvas_to_grid * vec3(canvas_position, 1.0)).xy;
}

float wisp(vec2 point) {
	vec2 curl = vec2(texture(fog_field, point * 2.0).r,
		texture(fog_field, point * 2.0 + vec2(0.37, 0.61)).r) - 0.5;
	float body = texture(fog_field, point + curl * 0.38).r;
	float detail = texture(fog_field, point * 4.0 + curl * 0.2).r;
	return smoothstep(0.36, 0.72, body * 0.92 + detail * 0.08);
}

void fragment() {
	// Three irregular, elongated sheets with different drift and scale.
	// Power-of-two periods keep the explicit drift wrap seamless.
	vec2 p = vec2(fog_grid.x - fog_grid.y, (fog_grid.x + fog_grid.y) * 2.0);
	vec2 drift = mod(fog_drift, vec2(4096.0));
	float far_sheet = wisp((p - drift) / 256.0);
	float middle_sheet = wisp((p - drift * 2.0) / 128.0 + vec2(0.31, 0.57));
	float near_sheet = wisp((p - drift * 4.0) / 64.0 + vec2(0.73, 0.19));
	float mist = far_sheet * 0.56 + middle_sheet * 0.36 + near_sheet * 0.08;
	vec2 edge_distance = min(fog_grid, vec2(fog_map_edge) - fog_grid);
	float map_mask = smoothstep(0.0, 2.0, min(edge_distance.x, edge_distance.y));
	if (fog_has_height_mask) { map_mask = texture(fog_height_mask, UV).r; }
	vec3 color = vec3(0.82, 0.86, 0.89) * clamp(fog_light, vec3(0.12), vec3(1.05));
	COLOR = vec4(color, mist * fog_density * map_mask);
}
