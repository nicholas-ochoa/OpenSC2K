shader_type canvas_item;
render_mode unshaded;

// Native ALTM bytes are big-endian; XTER shares the same x-major tile order.
uniform sampler2D fog_altitudes : filter_nearest, repeat_disable;
uniform sampler2D fog_terrain : filter_nearest, repeat_disable;
uniform mat3 fog_mask_to_tiles = mat3(1.0);
uniform int fog_edge = 128;
uniform float fog_ceiling = 4.5;
uniform float fog_visible_levels = 32.0;
varying vec2 flat_tile;

void vertex() {
	flat_tile = (fog_mask_to_tiles * vec3(VERTEX, 1.0)).xy;
}

float surface_height(vec2 point, ivec2 cell) {
	if (any(lessThan(cell, ivec2(0))) || any(greaterThanEqual(cell, ivec2(fog_edge)))) { return -100.0; }
	ivec2 texel = cell.yx;
	vec2 bytes = round(texelFetch(fog_altitudes, texel, 0).rg * 255.0);
	int word = int(bytes.x) * 256 + int(bytes.y);
	float land = float(word & 31);
	if (land >= fog_visible_levels) { return -100.0; }
	int terrain = int(round(texelFetch(fog_terrain, texel, 0).r * 255.0));
	// Match IsometricGeometry. Water is its visible surface, not the seabed.
	if (terrain >= 16) { return float((word >> 5) & 31); }
	int shape = terrain & 15;
	uint packed = shape < 8 ? 0xe7bc6390u : 0x00f8421du;
	int mask = int(packed >> uint((shape % 8) * 4)) & 15;
	vec4 corners = vec4(float(mask & 1), float((mask >> 1) & 1),
		float((mask >> 2) & 1), float((mask >> 3) & 1));
	vec2 local = point - vec2(cell) + 0.5;
	// Top/right/bottom and top/bottom/left terrain triangles.
	float slope = local.x >= local.y
		? corners.x + (corners.y - corners.x) * local.x + (corners.z - corners.y) * local.y
		: corners.x + (corners.z - corners.w) * local.x + (corners.w - corners.x) * local.y;
	return land + slope;
}

void fragment() {
	float height = -100.0;
	// Trace the actual isometric ray, including the 12-pixel altitude lift.
	// A flat inverse lookup would place a mountain's mask behind its artwork.
	// Visit every crossed cell rather than taking fixed-height samples, which
	// can skip narrow slopes. Within a cell the diagonal ray stays on one
	// triangle, so its terrain intersection is an exact linear solve.
	// At most 49 cells are crossed over the full 32-level altitude range.
	float entry = 32.0;
	for (int step = 0; step < 65; step++) {
		vec2 point = flat_tile + vec2(entry * 0.75);
		ivec2 cell = ivec2(floor(point + 0.4999));
		vec2 exits = (vec2(cell) - 0.5 - flat_tile) / 0.75;
		float end = max(0.0, max(exits.x, exits.y));
		float near_surface = surface_height(point, cell);
		float far_surface = surface_height(flat_tile + vec2(end * 0.75), cell);
		float near_distance = entry - near_surface;
		float far_distance = end - far_surface;
		if (near_distance <= 0.0) {
			height = entry;
			break;
		}
		if (far_distance <= 0.0) {
			height = mix(entry, end, near_distance / (near_distance - far_distance));
			break;
		}
		if (end <= 0.0) { break; }
		entry = end;
	}
	float mist = height < -1.0 ? 0.0 : 1.0 - smoothstep(fog_ceiling - 1.5, fog_ceiling + 1.5, height);
	COLOR = vec4(vec3(mist), 1.0);
}
