shader_type canvas_item;
render_mode unshaded;
uniform sampler2D emission : source_color, filter_nearest, repeat_disable;
uniform bool has_emission = false;
void fragment() {
	vec4 surface = texture(TEXTURE, UV);
	vec4 light = has_emission ? texture(emission, UV) : vec4(0.0);
	// Opaque unlit foreground pixels erase lights behind them in painter order.
	COLOR = vec4(light.rgb * light.a, surface.a);
}
