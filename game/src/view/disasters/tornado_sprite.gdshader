shader_type canvas_item;
render_mode unshaded;
#include "res://src/view/environment/environment_color.gdshaderinc"
#include "res://src/view/clouds/cloud_field.gdshaderinc"
uniform sampler2D animated_palette : source_color, filter_nearest, repeat_disable;
uniform sampler2D foreground : filter_nearest, repeat_disable;
uniform bool has_foreground = false;
uniform bool frame_blending = false;
uniform float frame_mix = 1.0;
uniform vec2 sprite_size;
uniform vec2 mask_size;
uniform vec2 mask_offset;
varying vec2 cloud_ground_grid;
void vertex() {
	cloud_ground_grid = cloud_grid_at((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy);
}
void fragment() {
	vec4 indexed = texture(TEXTURE, UV);
	vec3 color = texture(animated_palette, vec2((round(indexed.r * 255.0) + 0.5) / 256.0, 0.5)).rgb;
	float alpha = indexed.a;
	if (frame_blending) {
		vec4 a = texture(TEXTURE, vec2(UV.x, UV.y * 0.5));
		vec4 b = texture(TEXTURE, vec2(UV.x, (UV.y + 1.0) * 0.5));
		vec3 ca = texture(animated_palette, vec2((round(a.r * 255.0) + 0.5) / 256.0, 0.5)).rgb;
		vec3 cb = texture(animated_palette, vec2((round(b.r * 255.0) + 0.5) / 256.0, 0.5)).rgb;
		alpha = mix(a.a, b.a, frame_mix);
		color = mix(ca * a.a, cb * b.a, frame_mix) / max(alpha, 0.00001);
	}
	if (has_foreground) {
		vec2 at = (mask_offset + UV * sprite_size) / mask_size;
		alpha *= 1.0 - texture(foreground, at).a;
	}
	COLOR = vec4(environment_color(cloud_shadow(color, cloud_ground_grid), UV), alpha);
}
