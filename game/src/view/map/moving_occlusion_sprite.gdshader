
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D animated_palette : source_color, filter_nearest, repeat_disable;
uniform bool palette_cycle_enabled = false;
uniform bool palette_lookup_all = false;
uniform bool gpu_occlusion = false;
uniform sampler2D static_index : filter_nearest, repeat_disable;
uniform sampler2D static_depth : filter_nearest, repeat_disable;
uniform sampler2D train_depth : filter_nearest, repeat_disable;
uniform float buffer_divisor = 1.0;
uniform vec2 buffer_origin = vec2(0.0);
uniform vec2 buffer_size = vec2(1.0);

varying flat vec4 item;
varying vec2 source_position;

float decode_value(vec4 encoded) {
	vec3 bytes = floor(encoded.rgb * 255.0 + 0.5);
	return bytes.r * 65536.0 + bytes.g * 256.0 + bytes.b;
}

vec4 palette_color(int index) {
	return texture(animated_palette, vec2((float(index) + 0.5) / 256.0, 0.5));
}

void vertex() {
	item = COLOR;
	source_position = VERTEX;
}

void fragment() {
	vec4 base_color = texture(TEXTURE, UV);
	int mode = int(round(item.a * 255.0));

	if (mode == 255) {
		// the unchanged indexed-sprite path of the palette cycle shader
		int palette_index = int(round(base_color.r * 255.0));
		COLOR = palette_cycle_enabled && palette_lookup_all
			? vec4(palette_color(palette_index).rgb, base_color.a)
			: base_color;
	} else {
		if (base_color.a <= 0.0) {
			discard;
		}

		// decide once per native source pixel, as the cpu path does
		vec2 native_pixel = floor(source_position / buffer_divisor);
		vec2 buffer_uv = (native_pixel + 0.5 - buffer_origin) / buffer_size;
		int palette_index = int(round(base_color.r * 255.0));

		if (gpu_occlusion) {
			float order = decode_value(item);
			vec4 depth = mode == 3 ? texture(train_depth, buffer_uv) : texture(static_depth, buffer_uv);
			float stored = decode_value(depth);

			if (stored >= order + 2.0) {
				discard;
			}
		}

		if (mode == 2) {
			if (!gpu_occlusion) {
				discard;
			}

			int under = int(round(texture(static_index, buffer_uv).r * 255.0));
			int shadow = under == 95 ? 100 : ((under >= 116 && under <= 126) ? 126 : under);

			if (shadow == under) {
				discard;
			}

			palette_index = shadow;
		}

		COLOR = palette_cycle_enabled
			? vec4(palette_color(palette_index).rgb, 1.0)
			: vec4(vec3(float(palette_index) / 255.0), 1.0);
	}
}
