shader_type canvas_item;
render_mode unshaded;
uniform vec2 direction = vec2(1.0, 0.0);
uniform float radius = 1.0;
void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * direction * radius;
	vec3 color = texture(TEXTURE, UV).rgb * 0.227027;
	color += (texture(TEXTURE, UV + step_uv * 1.384615).rgb + texture(TEXTURE, UV - step_uv * 1.384615).rgb) * 0.316216;
	color += (texture(TEXTURE, UV + step_uv * 3.230769).rgb + texture(TEXTURE, UV - step_uv * 3.230769).rgb) * 0.070270;
	COLOR = vec4(color, 1.0);
}
