shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
uniform float strength = 0.0;
void fragment() {
	vec4 light = texture(TEXTURE, UV);
	COLOR = vec4(light.rgb * light.a * strength, 0.0);
}
