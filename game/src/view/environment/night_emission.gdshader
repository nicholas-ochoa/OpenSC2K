shader_type canvas_item;
render_mode unshaded;
uniform sampler2D emission : source_color, filter_nearest, repeat_disable;
uniform bool has_emission = false;
varying flat float building_emission;
void vertex() {
	float tag = round(COLOR.r * 255.0);
	building_emission = float(tag < 128.0 || tag == 255.0);
}
void fragment() {
	vec4 surface = texture(TEXTURE, UV);
	vec4 light = has_emission ? texture(emission, UV) : vec4(0.0);
	// Opaque unlit foreground pixels erase lights behind them in painter order.
	COLOR = vec4(light.rgb * light.a * building_emission, surface.a);
}
