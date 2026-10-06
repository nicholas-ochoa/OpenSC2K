shader_type canvas_item;
render_mode unshaded;

uniform sampler2D city_screen : hint_screen_texture, filter_linear, repeat_disable;
uniform vec3 light_color = vec3(1.0, 0.24, 0.035);
uniform float light_amount = 0.7;
uniform float heat_amount = 1.0;
uniform float effect_time = 0.0;
uniform float effect_seed = 0.0;
uniform float pixel_scale = 1.0;

void fragment() {
	vec2 p = UV * vec2(192.0, 144.0) - vec2(96.0, 88.0);
	float distance = length((p + vec2(0.0, 12.0)) / vec2(80.0, 44.0));
	float weight = 1.0 - smoothstep(0.12, 1.0, distance);
	float t = effect_time + effect_seed;
	float flicker = 0.92 + 0.05 * sin(t * 9.1) + 0.03 * sin(t * 17.3);
	float heat = weight * heat_amount;
	vec2 pixel = SCREEN_PIXEL_SIZE * max(pixel_scale, 1.0);
	vec2 warp = vec2(sin(p.y * 0.35 - t * 8.0), cos(p.x * 0.27 + t * 5.0)) * pixel * heat * 0.7;
	vec2 uv = SCREEN_UV + warp;
	vec3 scene = texture(city_screen, uv).rgb;
	vec3 blur = (texture(city_screen, uv + vec2(pixel.x, 0.0)).rgb + texture(city_screen, uv - vec2(pixel.x, 0.0)).rgb
		+ texture(city_screen, uv + vec2(0.0, pixel.y)).rgb + texture(city_screen, uv - vec2(0.0, pixel.y)).rgb) * 0.25;
	scene = mix(scene, blur, heat * 0.22);
	vec3 contrast = (scene - vec3(0.42)) * (1.0 + 0.18 * weight) + vec3(0.42);
	vec3 lit = contrast * (vec3(0.90) + light_color * 0.32) + light_color * 0.24;
	COLOR = vec4(clamp(lit, vec3(0.0), vec3(1.0)), weight * light_amount * flicker);
}
