
shader_type canvas_item;
render_mode unshaded, blend_disabled;

varying flat vec4 depth_color;

void vertex() {
	depth_color = COLOR;
}

void fragment() {
	if (texture(TEXTURE, UV).a <= 0.0) {
		discard;
	}

	COLOR = vec4(depth_color.rgb, 1.0);
}
