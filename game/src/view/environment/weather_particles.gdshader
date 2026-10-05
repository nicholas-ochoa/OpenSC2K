shader_type canvas_item;
render_mode unshaded;

uniform vec2 extent = vec2(1024.0, 768.0);
uniform float clock = 0.0;
uniform float rain = 0.0;
uniform float snow = 0.0;
uniform float flash = 0.0;

float random(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 pixel = UV * extent;
	float rain_alpha = 0.0;
	float snow_alpha = 0.0;
	for (int layer = 0; layer < 3; layer++) {
		float depth = float(layer);
		vec2 r = vec2(pixel.x + pixel.y * 0.21 - clock * (34.0 + depth * 7.0), pixel.y - clock * (270.0 + depth * 75.0));
		vec2 cell = floor(r / vec2(23.0, 43.0));
		vec2 local = mod(r, vec2(23.0, 43.0));
		float seed = random(cell + depth * 71.0);
		float drop = step(abs(local.x - (2.0 + seed * 18.0)), 0.65) * step(local.y, 5.0 + rain * 6.0);
		rain_alpha += drop * step(seed, rain * 0.82) * (0.23 + depth * 0.07);
		vec2 s = vec2(pixel.x - clock * (9.0 + depth * 5.0), pixel.y - clock * (24.0 + depth * 15.0));
		vec2 scell = floor(s / vec2(28.0, 30.0));
		float flake_seed = random(scell + depth * 53.0);
		vec2 center = vec2(4.0 + flake_seed * 19.0 + sin(clock * 1.2 + flake_seed * 20.0) * 3.0, 3.0 + random(scell.yx) * 22.0);
		vec2 distance = abs(mod(s, vec2(28.0, 30.0)) - center);
		snow_alpha += step(max(distance.x, distance.y), 0.75 + depth * 0.45) * step(flake_seed, snow * 0.9) * (0.5 + depth * 0.12);
	}
	vec3 color = mix(vec3(0.64, 0.75, 0.85), vec3(0.94, 0.97, 1.0), step(rain_alpha, snow_alpha));
	float alpha = clamp(rain_alpha + snow_alpha, 0.0, 0.9);
	COLOR = vec4(mix(color, vec3(0.87, 0.93, 1.0), flash), max(alpha, flash * 0.72));
}
