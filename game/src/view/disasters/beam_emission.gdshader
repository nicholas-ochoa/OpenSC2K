shader_type canvas_item;
render_mode unshaded;
uniform bool indexed = false;
uniform sampler2D animated_palette : source_color, filter_nearest, repeat_disable;
void fragment() {
	vec4 light = texture(TEXTURE, UV);
	if (indexed) {
		float index = round(light.r * 255.0);
		light.rgb = texture(animated_palette, vec2((index + 0.5) / 256.0, 0.5)).rgb;
	}
	// Resolve palette addresses before the shared building-glow blur samples RGB.
	COLOR = light;
}
