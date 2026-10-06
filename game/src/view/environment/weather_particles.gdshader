shader_type canvas_item;
render_mode unshaded;

uniform vec2 extent = vec2(1024.0, 768.0);
uniform float clock = 0.0;
uniform float rain = 0.0;
uniform float snow = 0.0;
uniform float flash = 0.0;
uniform float particle_scale = 1.0;
uniform vec2 camera_pan = vec2(0.0);
uniform vec2 flash_origin = vec2(0.5, -0.15);
uniform float flash_spread = 0.8;
uniform vec3 flash_color = vec3(0.87, 0.93, 1.0);

float random(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float snow_layer(vec2 pixel, float depth) {
	vec2 spacing = vec2(29.0 + depth * 8.0, 31.0 + depth * 5.0);
	float wind = clock * (6.0 + depth * 4.0);
	float x = pixel.x - wind;
	float column = floor(x / spacing.x);
	float flakes = 0.0;
	// Neighbour cells let flakes wander across cell edges without clipping.
	// Full-cell jitter and independent density/size seeds break up the grid.
	for (int dx = -1; dx <= 1; dx++) {
		float cx = column + float(dx);
		float speed = (22.0 + depth * 13.0) * mix(0.7, 1.3, random(vec2(cx, depth + 91.0)));
		float y = pixel.y - clock * speed;
		float row = floor(y / spacing.y);
		for (int dy = -1; dy <= 1; dy++) {
			vec2 cell = vec2(cx, row + float(dy));
			vec2 id = cell + vec2(depth * 113.0, depth * 79.0);
			float density = random(id + vec2(57.3, 19.8));
			if (density > snow * 0.85) { continue; }
			vec2 seed = vec2(random(id), random(id + vec2(31.7, 43.1)));
			float shape = random(id + vec2(89.2, 7.6));
			float phase = seed.y * 6.283185;
			vec2 drift = vec2(sin(clock * mix(0.35, 0.95, shape) + phase) * mix(2.0, 7.0, seed.x),
				cos(clock * mix(0.25, 0.6, seed.x) + phase) * 3.0);
			vec2 center = (cell + seed) * spacing + drift;
			float radius = mix(0.65, 1.25, shape) + depth * 0.35;
			float aa = 0.55 / particle_scale;
			float flake = 1.0 - smoothstep(max(0.0, radius - aa), radius + aa, length(vec2(x, y) - center));
			flakes += flake * mix(0.35, 0.75, shape);
		}
	}
	return flakes;
}

void fragment() {
	float rain_alpha = 0.0;
	float snow_alpha = 0.0;
	for (int layer = 0; layer < 3; layer++) {
		float depth = float(layer);
		// Nearby precipitation follows camera movement slightly more strongly.
		vec2 pixel = (UV * extent + camera_pan * (0.035 + depth * 0.035)) / particle_scale;
		vec2 r = vec2(pixel.x + pixel.y * 0.21 - clock * (34.0 + depth * 7.0), pixel.y - clock * (270.0 + depth * 75.0));
		vec2 cell = floor(r / vec2(23.0, 43.0));
		vec2 local = mod(r, vec2(23.0, 43.0));
		float seed = random(cell + depth * 71.0);
		float drop = step(abs(local.x - (2.0 + seed * 18.0)), 0.65) * step(local.y, 5.0 + rain * 6.0);
		rain_alpha += drop * step(seed, rain * 0.82) * (0.23 + depth * 0.07);
		if (snow > 0.001) {
			snow_alpha += snow_layer(pixel, depth);
		}
	}
	vec3 color = mix(vec3(0.64, 0.75, 0.85), vec3(0.94, 0.97, 1.0), step(rain_alpha, snow_alpha));
	float alpha = clamp(rain_alpha + snow_alpha, 0.0, 0.9);
	// Off-screen/cloud discharges illuminate a broad, varying part of the city.
	// There is no cosmetic ground strike suggesting damage or a disaster.
	vec2 offset = (UV - flash_origin) * vec2(extent.x / max(extent.y, 1.0), 1.0);
	float illumination = 0.16 + 0.84 * exp(-dot(offset, offset) / (flash_spread * flash_spread));
	float light = flash * illumination;
	COLOR = vec4(mix(color, flash_color, light), max(alpha, light * 0.55));
}
