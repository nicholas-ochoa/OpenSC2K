shader_type canvas_item;
render_mode unshaded;
uniform sampler2D city_screen : hint_screen_texture, filter_linear, repeat_disable;
uniform float amount = 0.0;
uniform vec2 shake_direction = vec2(1.0, 0.3);
void fragment() {
	vec2 p = SCREEN_PIXEL_SIZE * normalize(shake_direction) * amount * 14.0;
	vec3 center = texture(city_screen, SCREEN_UV).rgb;
	vec3 blur = center * 0.20;
	for (int i = 1; i <= 4; i++) {
		float weight = (5.0 - float(i)) * 0.04;
		vec2 offset = p * float(i) * 0.25;
		blur += (texture(city_screen, SCREEN_UV + offset).rgb + texture(city_screen, SCREEN_UV - offset).rgb) * weight;
	}
	COLOR = vec4(mix(center, blur, amount), 1.0);
}
