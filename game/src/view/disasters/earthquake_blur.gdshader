shader_type canvas_item;
render_mode unshaded;
uniform sampler2D city_screen : hint_screen_texture, filter_linear, repeat_disable;
uniform float amount = 0.0;
void fragment() {
	vec2 p = SCREEN_PIXEL_SIZE * (1.0 + amount * 3.0);
	vec3 center = texture(city_screen, SCREEN_UV).rgb;
	vec3 blur = (texture(city_screen, SCREEN_UV + vec2(p.x, 0.0)).rgb + texture(city_screen, SCREEN_UV - vec2(p.x, 0.0)).rgb
		+ texture(city_screen, SCREEN_UV + vec2(0.0, p.y)).rgb + texture(city_screen, SCREEN_UV - vec2(0.0, p.y)).rgb) * 0.25;
	COLOR = vec4(mix(center, blur, amount * 0.8), 1.0);
}
