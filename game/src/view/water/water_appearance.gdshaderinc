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
	vec3 color = original * (0.92 + 0.09 * shallows + water_field(world) * 0.075);
	color = mix(color, vec3(original.r * 0.9, original.g * 1.45, original.b * 0.94), shallows * 0.22);
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
