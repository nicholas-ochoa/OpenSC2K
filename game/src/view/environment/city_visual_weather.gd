class_name CityVisualWeather
extends RefCounted
## Presentation-only weather and random state. No city writes or simulation RNG.

enum Kind { SUNNY, LIGHT_RAIN, HEAVY_RAIN, RAIN_STORM, DRY_STORM, LIGHT_SNOW, HEAVY_SNOW }
const PARTICLES := preload("res://src/view/environment/weather_particles.gdshader")
const TINTS := [Color.WHITE, Color(0.86, 0.9, 0.96), Color(0.7, 0.77, 0.86),
	Color(0.59, 0.67, 0.79), Color(0.63, 0.7, 0.82), Color(0.93, 0.96, 1.0), Color(0.81, 0.87, 0.95)]

var app: CityApplication
var random := RandomNumberGenerator.new()
var kind := Kind.SUNNY
var selected_kind := Kind.SUNNY
var tint := Color.WHITE
var frost := 0.0
var rain := 0.0
var snow := 0.0
var clock := 0.0
var flash := 0.0
var interval := 0.0
var lightning := CityLightning.new()
var audio: CityWeatherAudio
var last_game_weather := -1
var last_mode := -1
var layer: ColorRect
var material: ShaderMaterial
var camera_pan := Vector2.ZERO
var last_camera_center := Vector2.ZERO
var last_camera_zoom := 0.0
var _preview_signature: Array = []


func _init(application: CityApplication) -> void:
	app = application
	audio = CityWeatherAudio.new(app)
	random.randomize()


static func from_game(value: int, heavy_rain: bool) -> Kind:
	match value:
		6: return Kind.LIGHT_SNOW
		7: return Kind.HEAVY_RAIN if heavy_rain else Kind.LIGHT_RAIN
		9: return Kind.HEAVY_SNOW
		10: return Kind.RAIN_STORM
		11: return Kind.DRY_STORM
	return Kind.SUNNY


func reset() -> void:
	interval = 0.0
	last_game_weather = -1
	last_mode = -1
	kind = Kind.SUNNY
	selected_kind = Kind.SUNNY
	tint = Color.WHITE
	frost = 0.0
	rain = 0.0
	snow = 0.0
	clock = 0.0
	lightning.reset()
	audio.reset()
	flash = 0.0
	camera_pan = Vector2.ZERO
	last_camera_zoom = 0.0
	_preview_signature.clear()


func process(delta: float, phase_elapsed: float, active: bool, season: float, paused := false) -> void:
	var options := app.preferences.visual_enhancements
	var enabled: bool = active and options.weather_enabled
	var snow_allowed: bool = options.weather_mode == 2 or int(fposmod(season, 4.0)) == 3
	if enabled:
		if options.weather_mode != last_mode:
			last_mode = options.weather_mode
			last_game_weather = -1
			interval = float(options.weather_seconds)
		if options.weather_mode == 0:
			var game_weather := app.document_state.city.weather_type()
			if game_weather != last_game_weather:
				last_game_weather = game_weather
				selected_kind = from_game(game_weather, random.randf() < 0.5)
		elif options.weather_mode == 1:
			interval += phase_elapsed if not paused else 0.0
			if not paused and interval >= float(options.weather_seconds):
				interval = fposmod(interval, float(options.weather_seconds))
				var choices := [Kind.SUNNY, Kind.SUNNY, Kind.LIGHT_RAIN, Kind.HEAVY_RAIN, Kind.RAIN_STORM, Kind.DRY_STORM]
				if int(season) == 3:
					choices = [Kind.SUNNY, Kind.SUNNY, Kind.LIGHT_SNOW, Kind.LIGHT_SNOW, Kind.HEAVY_SNOW]
				selected_kind = choices[random.randi_range(0, choices.size() - 1)]
		else:
			selected_kind = int(options.weather_fixed) as Kind
		kind = selected_kind
		if not snow_allowed:
			if kind == Kind.LIGHT_SNOW:
				kind = Kind.LIGHT_RAIN
			elif kind == Kind.HEAVY_SNOW:
				kind = Kind.HEAVY_RAIN
	else:
		kind = Kind.SUNNY
		flash = 0.0
	var strength := float(options.weather_strength)
	var elapsed := 0.0 if paused else maxf(delta, 0.0)
	var preview := [enabled, kind, strength, options.weather_mode, snow_allowed]
	# Explicit menu changes remain visible while paused; existing fronts stay frozen.
	var weight := minf(1.0, elapsed / float(options.weather_transition)) if enabled else 1.0
	if paused and preview != _preview_signature:
		weight = 1.0
	_preview_signature = preview
	var target_tint := Color.WHITE.lerp(TINTS[kind], strength)
	tint = Color(move_toward(tint.r, target_tint.r, weight), move_toward(tint.g, target_tint.g, weight), move_toward(tint.b, target_tint.b, weight))
	frost = move_toward(frost, (0.18 if kind == Kind.LIGHT_SNOW else (0.85 if kind == Kind.HEAVY_SNOW else 0.0)) * strength, weight)
	rain = move_toward(rain, (0.28 if kind == Kind.LIGHT_RAIN else (1.0 if kind in [Kind.HEAVY_RAIN, Kind.RAIN_STORM] else 0.0)) * strength, weight)
	snow = move_toward(snow, (0.24 if kind == Kind.LIGHT_SNOW else (1.0 if kind == Kind.HEAVY_SNOW else 0.0)) * strength, weight)
	if not snow_allowed:
		# Automatic weather clears out-of-season flakes even while paused.
		snow = 0.0
		frost = 0.0
	clock = fposmod(clock + elapsed, 3600.0)
	var storm := enabled and kind in [Kind.RAIN_STORM, Kind.DRY_STORM]
	audio.update(elapsed, enabled and strength > 0.0, rain, storm, paused)
	var thunder_due := false
	if not paused or not storm or strength <= 0.0:
		thunder_due = lightning.advance(elapsed, storm, strength)
	flash = lightning.flash
	if not audio.allowed():
		# Muting or losing focus discards pending thunder, without a catch-up burst.
		lightning.thunder_wait = -1.0
	elif thunder_due:
		audio.play_thunder(lightning, strength)
	_sync_layer(enabled)


func _sync_layer(enabled: bool) -> void:
	var visible := enabled and (rain > 0.001 or snow > 0.001 or flash > 0.001)
	if not visible:
		if layer != null:
			layer.hide()
		return
	if layer == null:
		layer = ColorRect.new()
		layer.name = "VisualWeather"
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Precipitation must draw after both the city's texture layers and its
		# direct canvas commands, but before the selection/tool overlay.
		material = ShaderMaterial.new()
		material.shader = PARTICLES
		layer.material = material
		app.map_view.add_child(layer)
	var overlay := app.map_view.layers.overlay_layer
	if overlay != null and layer.get_index() > overlay.get_index():
		app.map_view.move_child(layer, overlay.get_index())
	var bounds := app.map_view.camera._camera_rect()
	var zoom := app.map_view.zoom_factor
	var center := app.map_view.source_center * app.map_view.map_pixel_ratio
	# Accumulate screen-space panning. Rebase on zoom changes so anchored
	# zooming and atlas resolution changes do not kick the atmosphere sideways.
	if is_equal_approx(zoom, last_camera_zoom):
		camera_pan += (center - last_camera_center) * zoom
	last_camera_center = center
	last_camera_zoom = zoom
	layer.position = bounds.position
	layer.size = bounds.size
	layer.show()
	material.set_shader_parameter("extent", bounds.size)
	material.set_shader_parameter("camera_pan", camera_pan)
	# Partial zoom scaling keeps precipitation legible in the city overview.
	material.set_shader_parameter("particle_scale", maxf(0.45, sqrt(app.map_view.zoom_factor)))
	material.set_shader_parameter("clock", clock)
	material.set_shader_parameter("rain", rain)
	material.set_shader_parameter("snow", snow)
	material.set_shader_parameter("flash", flash)

	material.set_shader_parameter("flash_origin", lightning.origin)
	material.set_shader_parameter("flash_spread", lightning.spread)
	material.set_shader_parameter("flash_color", Vector3(lightning.color.r, lightning.color.g, lightning.color.b))
