// A shared, deterministic aerial plane. Tile coordinates are canonical; the
// projection turns billboard artwork with the camera without stretching it.
uniform bool cloud_enabled = false;
uniform sampler2D cloud_field : source_color, filter_linear_mipmap, repeat_disable;
uniform mat3 cloud_canvas_to_grid = mat3(1.0);
uniform vec4 cloud_projection = vec4(1.0, 0.5, -1.0, 0.5);
uniform vec2 cloud_drift = vec2(0.0);
uniform float cloud_span = 192.0;
uniform float cloud_density = 0.4;
uniform float cloud_shadow_strength = 0.4;
uniform vec2 cloud_shadow_offset = vec2(4.0, 2.0);

vec2 cloud_grid_at(vec2 canvas_position) {
	return (cloud_canvas_to_grid * vec3(canvas_position, 1.0)).xy;
}

float cloud_hash(vec2 cell) {
	vec2 p = fract(cell * vec2(0.1031, 0.0973));
	return fract(19.19 * (p.x + 0.37) * (p.y + 0.71));
}

vec4 cloud_sample(vec2 grid_position, float softness, float map_edge) {
	// Compute the footprint before cell selection diverges between neighboring
	// fragments. Implicit texture derivatives inside that search can select
	// unrelated atlas mip levels as a cloud crosses a cell boundary.
	vec2 dx = dFdx(grid_position);
	vec2 dy = dFdy(grid_position);
	vec2 sky_dx = dx.x * cloud_projection.xy + dx.y * cloud_projection.zw;
	vec2 sky_dy = dy.x * cloud_projection.xy + dy.y * cloud_projection.zw;
	float footprint = max(length(sky_dx), length(sky_dy));
	float atlas_side = float(textureSize(cloud_field, 0).x) * 0.5;
	float base_lod = log2(max(footprint * atlas_side / (cloud_span / 3.0), 0.001));
	if (!cloud_enabled || cloud_density <= 0.0) { return vec4(0.0); }
	vec2 wrapped_drift = mod(cloud_drift, vec2(cloud_span));
	vec2 point = grid_position - wrapped_drift;
	float spacing = cloud_span * 0.25;
	vec2 cell = floor(point / spacing);
	vec4 combined = vec4(0.0);
	// Padded clusters reach at most the neighboring canonical cells, including
	// after a compass turn. The periodic layout makes clock wrapping seamless.
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 site = cell + vec2(float(x), float(y));
			vec2 id = mod(site, vec2(4.0));
			float seed = cloud_hash(id + vec2(17.0, 31.0));
			// Density selects whole clouds. It must not turn their solid cores
			// into persistent translucent copies in the overview.
			if (seed >= cloud_density * 1.55) { continue; }
			float amount = 1.0;
			vec2 jitter = vec2(cloud_hash(id + vec2(5.0, 9.0)),
				cloud_hash(id + vec2(23.0, 3.0))) - vec2(0.5);
			vec2 center = (site + vec2(0.5) + jitter * 0.24) * spacing;
			if (map_edge > 0.0) {
				// Fade whole clouds at the city edge, keeping their billowing outline.
				vec2 distance = min(center + wrapped_drift, vec2(map_edge) - center - wrapped_drift);
				amount *= smoothstep(-4.0, 3.0, min(distance.x, distance.y));
			}
			vec2 delta = point - center;
			vec2 sky = delta.x * cloud_projection.xy + delta.y * cloud_projection.zw;
			float size_factor = mix(0.86, 1.06, cloud_hash(id + vec2(7.0, 11.0)));
			float size = cloud_span / 3.0 * size_factor;
			vec2 uv = sky / size + vec2(0.5);
			if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) { continue; }
			float variant = floor(cloud_hash(id + vec2(13.0, 19.0)) * 4.0);
			vec2 quadrant = vec2(mod(variant, 2.0), floor(variant * 0.5));
			vec2 atlas_uv = (quadrant + uv) * 0.5;
			float lod = softness < 0.0 ? max(base_lod - log2(size_factor), 0.0) : softness;
			vec4 cloud = textureLod(cloud_field, atlas_uv, lod);
			cloud.a *= amount;
			combined.rgb = cloud.rgb * cloud.a + combined.rgb * (1.0 - cloud.a);
			combined.a = cloud.a + combined.a * (1.0 - cloud.a);
		}
	}
	return vec4(combined.rgb / max(combined.a, 0.001), combined.a);
}

float cloud_cover(vec2 grid_position) {
	// A prefiltered alpha gives diffuse shadow edges with one shared lookup
	// per candidate instead of multiplying the full cloud search five times.
	return cloud_sample(grid_position, 5.0, -1.0).a;
}

// Air and water reflections use exactly the same authored volume and alpha.
vec4 cloud_body(vec2 grid_position, float map_edge, float opacity, vec3 light) {
	if (opacity <= 0.0) { return vec4(0.0); }
	vec4 cloud = cloud_sample(grid_position, -1.0, map_edge);
	return vec4(cloud.rgb * light, cloud.a * opacity);
}

vec3 cloud_shadow(vec3 color, vec2 grid_position) {
	if (!cloud_enabled || cloud_density <= 0.0 || cloud_shadow_strength <= 0.0) { return color; }
	return color * (1.0 - cloud_cover(grid_position - cloud_shadow_offset) * cloud_shadow_strength);
}
