
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_image : hint_screen_texture, repeat_disable, filter_nearest;
void fragment() {
	vec4 mask = texture(TEXTURE, UV);
	ivec3 background = ivec3(round(textureLod(screen_image, SCREEN_UV, 0.0).rgb * 255.0));
	ivec3 foreground = ivec3(round(mask.rgb * 255.0));
	ivec3 result = (mask.a > 0.5 ? background : ivec3(0)) ^ foreground;
	COLOR = vec4(vec3(result) / 255.0, 1.0);
}
