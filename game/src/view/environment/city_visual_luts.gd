class_name CityVisualLuts
extends RefCounted
## Numeric sRGB LUTs. Textures have no source_color hint or mipmaps.

const SIZE := 32
const GROUPS := {
	"day": ["day_morning", "day_day", "day_evening", "day_night"],
	"season": ["season_spring", "season_summer", "season_autumn", "season_winter"],
	"weather": ["weather_sunny", "weather_light_rain", "weather_heavy_rain", "weather_rain_thunder", "weather_dry_thunder", "weather_light_snow", "weather_heavy_snow"],
}
const BUILTINS := {
	"neutral": preload("res://assets/visual_luts/neutral.png"),
	"day_morning": preload("res://assets/visual_luts/day_morning.png"),
	"day_day": preload("res://assets/visual_luts/day_day.png"),
	"day_evening": preload("res://assets/visual_luts/day_evening.png"),
	"day_night": preload("res://assets/visual_luts/day_night.png"),
	"season_spring": preload("res://assets/visual_luts/season_spring.png"),
	"season_summer": preload("res://assets/visual_luts/season_summer.png"),
	"season_autumn": preload("res://assets/visual_luts/season_autumn.png"),
	"season_winter": preload("res://assets/visual_luts/season_winter.png"),
	"weather_sunny": preload("res://assets/visual_luts/weather_sunny.png"),
	"weather_light_rain": preload("res://assets/visual_luts/weather_light_rain.png"),
	"weather_heavy_rain": preload("res://assets/visual_luts/weather_heavy_rain.png"),
	"weather_rain_thunder": preload("res://assets/visual_luts/weather_rain_thunder.png"),
	"weather_dry_thunder": preload("res://assets/visual_luts/weather_dry_thunder.png"),
	"weather_light_snow": preload("res://assets/visual_luts/weather_light_snow.png"),
	"weather_heavy_snow": preload("res://assets/visual_luts/weather_heavy_snow.png"),
}

var atlases: Dictionary[String, ImageTexture] = {}
var identities: Dictionary[String, PackedByteArray] = {}
var issues := PackedStringArray()
var weather_weights := PackedFloat32Array([1, 0, 0, 0, 0, 0, 0])
var _weather_ready := false
var _weather_target := 0
var _weather_start := PackedFloat32Array([1, 0, 0, 0, 0, 0, 0])
var _weather_elapsed := 0.0


func reload(folder: String) -> void:
	issues.clear()
	var neutral := (BUILTINS.neutral as Texture2D).get_image()
	neutral.convert(Image.FORMAT_RGB8)
	for group: String in GROUPS:
		var names: Array = GROUPS[group]
		var atlas := Image.create(SIZE * SIZE, SIZE * names.size(), false, Image.FORMAT_RGB8)
		var flags := PackedByteArray()
		for i in range(names.size()):
			var name: String = names[i]
			var image: Image
			if folder.is_empty():
				image = (BUILTINS[name] as Texture2D).get_image()
			else:
				var path := folder.path_join(name + ".png")
				image = load_strip(path, SIZE)
				if not valid_profile(image):
					issues.append(name + ".png: missing or invalid; neutral fallback")
					image = neutral.duplicate()
			image.convert(Image.FORMAT_RGB8)
			flags.append(1 if image.get_data() == neutral.get_data() else 0)
			atlas.blit_rect(image, Rect2i(0, 0, SIZE * SIZE, SIZE), Vector2i(0, i * SIZE))
		atlases[group] = ImageTexture.create_from_image(atlas)
		identities[group] = flags


static func valid_profile(image: Image) -> bool:
	if image == null or image.get_size() != Vector2i(SIZE * SIZE, SIZE) or image.is_compressed():
		return false
	# Alpha is not an intensity channel. Reject partially transparent tables.
	return image.detect_alpha() == Image.ALPHA_NONE


static func load_strip(path: String, required_size := 0) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 33 or file.get_length() > 8 * 1024 * 1024:
		return null
	var header := file.get_buffer(24)
	if header.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]) or header.slice(12, 16).get_string_from_ascii() != "IHDR":
		return null
	var width := (int(header[16]) << 24) | (int(header[17]) << 16) | (int(header[18]) << 8) | int(header[19])
	var size := (int(header[20]) << 24) | (int(header[21]) << 16) | (int(header[22]) << 8) | int(header[23])
	if size < 2 or size > 64 or width != size * size or (required_size > 0 and size != required_size):
		return null
	var image := Image.load_from_file(path)
	if image == null or image.detect_alpha() != Image.ALPHA_NONE:
		return null
	return image


func reset() -> void:
	_weather_ready = false
	weather_weights = PackedFloat32Array([1, 0, 0, 0, 0, 0, 0])


func advance_weather(kind: int, delta: float, transition: float, enabled: bool) -> void:
	if not enabled:
		reset()
		return
	kind = clampi(kind, 0, 6)
	if not _weather_ready or kind != _weather_target:
		_weather_start = weather_weights.duplicate()
		_weather_elapsed = 0.0
		_weather_target = kind
	_weather_elapsed += maxf(delta, 0.0)
	var amount := clampf(_weather_elapsed / maxf(transition, 0.1), 0.0, 1.0)
	for i in range(7):
		weather_weights[i] = lerpf(_weather_start[i], 1.0 if i == kind else 0.0, amount)
	_weather_ready = true


func parameters(options: Dictionary, hour: float, season: Vector4, linear_canvas := false) -> Dictionary:
	var day := day_weights(hour) * float(options.night_strength)
	var days := _weighted("day", [day.x, day.y, day.z, day.w])
	var seasons := _weighted("season", [season.x, season.y, season.z, season.w])
	var weather := _weighted("weather", weather_weights)
	return {
		"environment_day_luts": atlases.get("day"),
		"environment_season_luts": atlases.get("season"),
		"environment_weather_luts": atlases.get("weather"),
		"environment_day_lut_weights": Vector4(days[0], days[1], days[2], days[3]),
		"environment_season_lut_weights": Vector4(seasons[0], seasons[1], seasons[2], seasons[3]),
		"environment_weather_lut_weights_a": Vector4(weather[0], weather[1], weather[2], weather[3]),
		"environment_weather_lut_weights_b": Vector3(weather[4], weather[5], weather[6]),
		"environment_day_lut_strength": options.day_lut_strength if options.day_enabled else 0.0,
		"environment_season_lut_strength": options.season_lut_strength if options.season_enabled else 0.0,
		"environment_weather_lut_strength": options.weather_lut_strength * options.weather_strength if options.weather_enabled else 0.0,
		"environment_lut_linear_canvas": linear_canvas,
	}


func _weighted(group: String, weights: Variant) -> PackedFloat32Array:
	var result := PackedFloat32Array(weights)
	var flags: PackedByteArray = identities.get(group, PackedByteArray())
	for i in range(result.size()):
		if i >= flags.size() or flags[i] == 1:
			result[i] = 0.0
	return result


static func day_weights(hour: float) -> Vector4:
	# Same keyframes as the existing ambient light; no separate presentation clock.
	var keys := [0.0, 5.0, 7.0, 10.0, 16.0, 19.0, 22.0, 24.0]
	var profiles := [3, 3, 0, 1, 1, 2, 3, 3]
	var h := fposmod(hour, 24.0)
	var result := Vector4.ZERO
	for i in range(keys.size() - 1):
		if h <= keys[i + 1]:
			var weight := smoothstep(keys[i], keys[i + 1], h)
			result[profiles[i]] += 1.0 - weight
			result[profiles[i + 1]] += weight
			return result
	return result


static func export_profiles(folder: String) -> String:
	if folder.is_empty() or folder.begins_with("res://"):
		return "Choose a writable LUT profile folder."
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return "Cannot create LUT profile folder: " + folder
	for name: String in BUILTINS:
		var path := folder.path_join(name + ".png")
		if not FileAccess.file_exists(path) and (BUILTINS[name] as Texture2D).get_image().save_png(path) != OK:
			return "Cannot export LUT: " + path
	var instructions := folder.path_join("README.txt")
	if not FileAccess.file_exists(instructions):
		var file := FileAccess.open(instructions, FileAccess.WRITE)
		if file == null:
			return "Cannot write LUT instructions."
		file.store_string(FileAccess.get_file_as_string("res://assets/visual_luts/README.txt"))
	return ""
