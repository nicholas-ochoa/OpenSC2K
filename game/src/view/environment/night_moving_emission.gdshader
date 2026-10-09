shader_type canvas_item;
render_mode unshaded;
varying flat float emitting;
void vertex() {
	emitting = float(COLOR.rgb == vec3(0.0, 1.0, 1.0));
}
void fragment() {
	vec4 surface = texture(TEXTURE, UV);
	COLOR = vec4(surface.rgb * emitting, surface.a);
}
