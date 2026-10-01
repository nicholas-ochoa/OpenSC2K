shader_type canvas_item;
render_mode unshaded;
// Debug tile layer: each tile reads its value, and the color table gives the tint.
// UVs hold two units for each tile; the y tile is in U and the x tile in V.
uniform sampler2D tile_values : filter_nearest, repeat_disable;
uniform sampler2D value_colors : source_color, filter_nearest, repeat_disable;
uniform float map_edge = 128.0;
uniform float opacity = 0.6;
void fragment() {
	vec2 tile = floor(UV * 0.5);
	vec2 local_uv = UV - tile * 2.0;
	float value = texture(tile_values, (tile + vec2(0.5)) / map_edge).r;
	vec4 tint = texture(value_colors, vec2((round(value * 255.0) + 0.5) / 256.0, 0.5));
	vec2 edge = min(local_uv, vec2(1.0) - local_uv) / max(fwidth(local_uv), vec2(0.00001));
	float border = 1.0 - smoothstep(0.5, 1.5, min(edge.x, edge.y));
	COLOR = vec4(mix(tint.rgb, tint.rgb * 0.45, border), tint.a * opacity);
}
