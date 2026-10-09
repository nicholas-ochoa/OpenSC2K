shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
uniform float strength = 0.0;
uniform vec2 sample_scale = vec2(1.0);
uniform vec2 sample_offset = vec2(0.0);
void fragment() {
	vec3 glow = texture(TEXTURE, UV * sample_scale + sample_offset).rgb;
	// Add energy without changing the destination alpha (also in HDR canvases).
	COLOR = vec4(glow * strength, 0.0);
}
