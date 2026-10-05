shader_type canvas_item;
render_mode blend_add;

uniform float night = 0.0;
uniform vec2 vehicle_world = vec2(0.0);
uniform vec2 forward = vec2(0.0, 1.0);
uniform float front = 3.0;
uniform float opacity = 1.0;

void fragment() {
	vec4 road = texture(TEXTURE, UV);
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
