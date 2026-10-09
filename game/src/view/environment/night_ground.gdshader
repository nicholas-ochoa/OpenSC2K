shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
uniform float strength = 0.0;
uniform float fade_clock = -1.0;
uniform float fade_duration = 0.65;
varying float light_birth;
void vertex() {
	light_birth = COLOR.r;
}
void fragment() {
	vec4 light = texture(TEXTURE, UV);
	float fade = fade_clock < 0.0 ? 1.0 : smoothstep(0.0, fade_duration, fade_clock - light_birth);
	COLOR = vec4(light.rgb * light.a * strength * fade, 0.0);
}
