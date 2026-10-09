shader_type canvas_item;
render_mode unshaded;

uniform float fade_clock = -1.0;
uniform float fade_duration = 0.65;
varying float light_birth;

void vertex() {
	// Red carries a per-draw timestamp, not a tint. Alpha retains night strength.
	light_birth = COLOR.r;
	COLOR.rgb = vec3(1.0);
}

void fragment() {
	float fade = fade_clock < 0.0 ? 1.0 : smoothstep(0.0, fade_duration, fade_clock - light_birth);
	COLOR.a *= fade;
}
