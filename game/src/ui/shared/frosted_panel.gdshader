shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 5.0) = 4.0;
// The outer style color's opacity separates edge coverage from glass tint.
uniform float edge_opacity : hint_range(0.0, 1.0) = 0.0;
// the chosen UI scale compared with the fitted size. the blur follows the
// interface size, not the screen pixel size
global uniform float ui_scale_factor;

void fragment() {
	// each panel style supplies the active theme tint and its opacity
	// opaque style borders remain sharp. child controls use their own materials
	vec4 tint = COLOR;
	float lod = max(0.0, blur_lod + log2(max(ui_scale_factor, 0.01)));
	vec3 background = textureLod(screen_texture, SCREEN_UV, lod).rgb;
	float coverage = edge_opacity > 0.0 ? min(tint.a / edge_opacity, 1.0) : 1.0;
	float opacity = max(tint.a, edge_opacity);
	COLOR = vec4(mix(background, tint.rgb, opacity), coverage);
}
