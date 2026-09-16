
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D tile_values : filter_nearest, repeat_disable;
uniform sampler2D value_colors : source_color, filter_nearest, repeat_disable;
uniform float map_edge = 128.0;
void fragment() {
	vec2 tile = floor(UV * 0.5);
	vec2 local_uv = UV - tile * 2.0;
	float value = texture(tile_values, (tile + vec2(0.5)) / map_edge).r;
	vec3 tint = texture(value_colors, vec2((round(value * 255.0) + 0.5) / 256.0, 0.5)).rgb;
	COLOR = COLOR.a < 0.9 ? vec4(0.35, 0.75, 1.0, 0.28) : vec4(tint * COLOR.b, 1.0);
	vec2 edge = min(local_uv, vec2(1.0) - local_uv) / max(fwidth(local_uv), vec2(0.00001));
	float fill = smoothstep(0.45, 0.95, min(edge.x, edge.y));
	COLOR.rgb *= mix(0.28, 1.0, fill);
}
