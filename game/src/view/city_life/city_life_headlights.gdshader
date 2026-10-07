shader_type canvas_item;
render_mode blend_add;

uniform float night = 0.0;
uniform sampler2DArray surfaces : filter_nearest, repeat_disable;
uniform sampler2D headlight_data : filter_nearest, repeat_disable;
varying flat float layer;
varying flat vec2 vehicle_world;
varying flat vec2 forward;
varying flat float front;
varying flat float opacity;

void vertex() {
	layer = float(INSTANCE_ID);
	vec4 data = texelFetch(headlight_data, ivec2(INSTANCE_ID, 0), 0);
	vehicle_world = data.xy;
	int packed = int(data.z);
	int direction = packed % 8;
	forward = vec2(direction == 1 ? 1.0 : (direction == 3 ? -1.0 : 0.0),
		direction == 2 ? 1.0 : (direction == 0 ? -1.0 : 0.0));
	if (direction >= 4) {
		forward = vec2(direction < 6 ? 1.0 : -1.0,
			(direction == 5 || direction == 6) ? 1.0 : -1.0) * 0.7071067811865476;
	}
	front = float(3 + packed / 8);
	opacity = data.w;
}

void fragment() {
	// QuadMesh has the opposite vertical UV orientation to Sprite2D.
	vec4 road = texture(surfaces, vec3(UV.x, 1.0 - UV.y, layer));
	vec2 relative = (road.rg - vehicle_world) * 16.0;
	float distance = dot(relative, forward) - front;
	float across = abs(dot(relative, vec2(-forward.y, forward.x)));
	float width = 1.1 + max(distance, 0.0) * 0.15;
	float strength = 0.0;
	if (road.a > 0.0 && distance >= 0.0 && distance < 22.0 && across < width) {
		strength = 0.38 * pow(1.0 - distance / 22.0, 1.2) * pow(1.0 - across / width, 0.7);
	}
	COLOR = vec4(vec3(1.0, 0.8902, 0.6275), strength * opacity * night);
}
