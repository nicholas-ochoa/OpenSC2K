shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 5.0) = 3.0;

void fragment() {
	// each panel style supplies the active theme tint and its opacity
	// opaque style borders remain sharp. child controls use their own materials
	vec4 tint = COLOR;
	vec3 background = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb;
	COLOR = vec4(mix(background, tint.rgb, tint.a), 1.0);
}
