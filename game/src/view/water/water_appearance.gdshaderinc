// All patterns use map pixels, never screen or region coordinates.
float water_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float water_field(vec2 world) {
	vec2 cell = floor(world / 96.0);
	vec2 blend = smoothstep(vec2(0.0), vec2(1.0), fract(world / 96.0));
	float a = mix(water_hash(cell), water_hash(cell + vec2(1.0, 0.0)), blend.x);
	float b = mix(water_hash(cell + vec2(0.0, 1.0)), water_hash(cell + vec2(1.0)), blend.x);
	// Five quiet color bands preserve the original pixel-art vocabulary.
	return floor(mix(a, b, blend.y) * 5.0) / 4.0 - 0.5;
}

// Long, crossing swells in map space. Their normal, highlights and reflection
// displacement share one phase so the surface reads as a moving body of water.
vec3 water_swell(vec2 world, float clock, float rain, float coast, float axis) {
	vec2 plane = vec2(world.x, world.y * 2.0);
	float phase = dot(plane, vec2(0.042, 0.075)) - clock * 0.78;
	float crossing = dot(plane, vec2(-0.085, 0.038)) - clock * 1.03;
	float envelope = 0.7 + 0.3 * sin(dot(plane, vec2(0.012, -0.017)) + clock * 0.16);
	float exposure = mix(0.25, 1.0, smoothstep(3.0, 28.0, coast)) * (axis > 0.0 ? 0.35 : 1.0);
	float normal = cos(phase) * 0.72 + cos(crossing) * 0.28;
	float crest = smoothstep(0.78, 0.98, sin(phase + 0.28 * sin(crossing)));
	float segments = smoothstep(-0.15, 0.65, sin(dot(plane, vec2(0.09, -0.04)) + clock * 0.19));
	float light = normal * 0.065 + crest * segments * 0.10;
	return vec3(light, normal * 1.25, crest * segments) * envelope * exposure * (1.0 + rain * 0.45);
}

float water_surf(vec2 world, float coast, float clock, float rain) {
	// Advancing crests travel toward the shore, then fade on the same contour.
	// Distance is from terrain only; object silhouettes cannot produce surf.
	float phase = coast * 0.53 + clock * 1.35 + 0.18 * sin(world.x * 0.027 + world.y * 0.039);
	float crest = smoothstep(0.68, 0.98, sin(phase));
	float broken = smoothstep(-0.65, 0.6, sin(world.x * 0.19 + world.y * 0.23 + sin(clock * 0.37)));
	float wash = (1.0 - smoothstep(1.5, 5.0, coast)) * (0.5 + 0.5 * sin(phase - 0.6));
	float band = smoothstep(0.3, 2.0, coast) * (1.0 - smoothstep(12.0, 24.0, coast));
	return (crest * broken * band * 0.24 + wash * 0.055) * (1.0 + rain * 0.25);
}

float water_light_lines(vec2 world, float axis, float clock, float rain) {
	vec2 direction = axis == 2.0 ? vec2(-0.8944, 0.4472) : vec2(0.8944, 0.4472);
	if (axis == 0.0) { direction = vec2(1.0, 0.0); }
	float along = dot(world, direction);
	float across = dot(world, vec2(-direction.y, direction.x));
	float speed = axis > 0.0 ? 1.2 : 0.25;
	float phase = fract((across + sin(along * 0.035 - clock * speed) * 1.4) / 17.0);
	float line = step(0.91, phase);
	float segments = step(0.60, sin(along * 0.13 + sin(across * 0.07)));
	float envelope = 0.55 + 0.45 * sin(clock * 0.45 + along * 0.025);
	return line * segments * envelope * (axis > 0.0 ? 0.045 : 0.022) * (1.0 + rain * 0.4);
}

vec3 water_body(vec3 original, vec4 bottom, float depth, vec2 world, bool show_bottom) {
	float known = bottom.a;
	float shallows = exp(-depth * 0.55) * known;
	vec3 color = water_body_tone(original, shallows, water_field(world));
	if (show_bottom) {
		float transmission = 0.42 * exp(-depth * 0.48) * known;
		// Actual triangle slopes provide the relief. Small fixed grain only
		// varies the substrate color; it cannot invent underwater heights.
		float grain = water_field(world * 3.0) * 0.04;
		float face = 0.48 + 0.64 * bottom.g;
		vec3 substrate = mix(vec3(0.40, 0.36, 0.25), vec3(0.28, 0.37, 0.39), clamp(depth / 6.0, 0.0, 1.0));
		color = mix(color, substrate * (face + grain), transmission);
	}
	return color;
}
