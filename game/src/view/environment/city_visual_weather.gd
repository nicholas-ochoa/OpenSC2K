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
var tint := Color.WHITE
var frost := 0.0
var rain := 0.0
var snow := 0.0
var clock := 0.0
var flash := 0.0
var interval := 0.0
var lightning_wait := 4.0
var thunder_wait := -1.0
var last_game_weather := -1
var last_mode := -1
var layer: ColorRect
var material: ShaderMaterial
var thunder: AudioStreamWAV


func _init(application: CityApplication) -> void:
	app = application
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
	thunder_wait = -1.0
	flash = 0.0


func process(delta: float, phase_elapsed: float, active: bool, season: float) -> void:
	var options := app.preferences.visual_enhancements
	var enabled: bool = active and options.weather_enabled
	if enabled:
		if options.weather_mode != last_mode:
			last_mode = options.weather_mode
			last_game_weather = -1
			interval = float(options.weather_seconds)
		if options.weather_mode == 0:
			var game_weather := app.document_state.city.weather_type()
			if game_weather != last_game_weather:
				last_game_weather = game_weather
				kind = from_game(game_weather, random.randf() < 0.5)
		elif options.weather_mode == 1:
			interval += phase_elapsed
			if interval >= float(options.weather_seconds):
				interval = fposmod(interval, float(options.weather_seconds))
				var choices := [Kind.SUNNY, Kind.SUNNY, Kind.LIGHT_RAIN, Kind.HEAVY_RAIN, Kind.RAIN_STORM, Kind.DRY_STORM]
				if int(season) == 3:
					choices = [Kind.SUNNY, Kind.SUNNY, Kind.LIGHT_SNOW, Kind.LIGHT_SNOW, Kind.HEAVY_SNOW]
				kind = choices[random.randi_range(0, choices.size() - 1)]
		else:
			kind = int(options.weather_fixed) as Kind
	else:
		kind = Kind.SUNNY
		thunder_wait = -1.0
		flash = 0.0
	var weight := minf(1.0, maxf(delta, 0.0) / float(options.weather_transition)) if enabled else 1.0
	var strength := float(options.weather_strength)
	var target_tint := Color.WHITE.lerp(TINTS[kind], strength)
	tint = Color(move_toward(tint.r, target_tint.r, weight), move_toward(tint.g, target_tint.g, weight), move_toward(tint.b, target_tint.b, weight))
	frost = move_toward(frost, (0.18 if kind == Kind.LIGHT_SNOW else (0.85 if kind == Kind.HEAVY_SNOW else 0.0)) * strength, weight)
	rain = move_toward(rain, (0.28 if kind == Kind.LIGHT_RAIN else (1.0 if kind in [Kind.HEAVY_RAIN, Kind.RAIN_STORM] else 0.0)) * strength, weight)
	snow = move_toward(snow, (0.24 if kind == Kind.LIGHT_SNOW else (1.0 if kind == Kind.HEAVY_SNOW else 0.0)) * strength, weight)
	clock = fposmod(clock + maxf(delta, 0.0), 3600.0)
	flash = maxf(0.0, flash - delta * 3.0)
	if kind in [Kind.RAIN_STORM, Kind.DRY_STORM] and enabled:
		lightning_wait -= delta
		if lightning_wait <= 0.0:
			flash = strength
			lightning_wait = random.randf_range(7.0, 18.0)
			thunder_wait = random.randf_range(0.2, 1.2)
	else:
		thunder_wait = -1.0
	if thunder_wait >= 0.0:
		thunder_wait -= delta
		if thunder_wait < 0.0:
			play_thunder()
	_sync_layer(enabled)


func _sync_layer(enabled: bool) -> void:
	if not enabled and layer == null:
		return
	if layer == null:
		layer = ColorRect.new()
		layer.name = "VisualWeather"
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.show_behind_parent = true
		material = ShaderMaterial.new()
		material.shader = PARTICLES
		layer.material = material
		app.map_view.add_child(layer)
	var bounds := app.map_view.camera._camera_rect()
	layer.position = bounds.position
	layer.size = bounds.size
	layer.visible = enabled and (rain > 0.001 or snow > 0.001 or flash > 0.001)
	material.set_shader_parameter("extent", bounds.size)
	material.set_shader_parameter("clock", clock)
	material.set_shader_parameter("rain", rain)
	material.set_shader_parameter("snow", snow)
	material.set_shader_parameter("flash", flash)


func play_thunder() -> void:
	var audio := app.audio_controller
	if audio == null or not audio.audio_allowed() or audio.effects_volume <= 0.0 or not app.document_state.city.sound_enabled():
		return
	if AudioServer.get_driver_name() == "Dummy":
		return
	if thunder == null:
		thunder = make_thunder()
	var player := AudioStreamPlayer.new()
	player.stream = thunder
	player.volume_linear = audio.effects_volume
	player.finished.connect(player.queue_free)
	audio.add_child(player)
	player.add_to_group(CityAudioController.SOUND_EFFECT_GROUP)
	player.play()


static func make_thunder() -> AudioStreamWAV:
	var generator := RandomNumberGenerator.new()
	generator.seed = 983574
	var rate := 22050
	var data := PackedByteArray()
	data.resize(rate * 3 * 2)
	var low := 0.0
	for i in rate * 3:
		var time := float(i) / rate
		low = lerpf(low, generator.randf_range(-1.0, 1.0), 0.07)
		var envelope := minf(time * 28.0, 1.0) * exp(-time * 1.6)
		var value := clampi(int((low * 2.0 + sin(time * 43.0) * 0.08) * envelope * 26000.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream
