class_name CityVisualClouds
extends RefCounted
## Presentation-only cloud field. Never writes city data or simulation RNG.

const BODIES := preload("res://src/view/clouds/cloud_bodies.gdshader")
const CUMULUS := preload("res://assets/clouds/cumulus_atlas.png")
const FIELD_SPAN := 192.0
const HEIGHT_PIXELS := 192.0
const WIND := Vector2(0.32, 0.20)
const WEATHER_COVERAGE := [0.65, 1.05, 1.35, 1.55, 1.3, 1.0, 1.4]
const FAIR_WEATHER_COVERAGE := [0.85, 0.6, 0.45, 0.7, 0.85, 1.25, 1.0, 1.0, 0.8]

var app: CityApplication
var drift := Vector2.ZERO
var opacity := 0.0
var density := 0.0
var fog := 0.0
var weather_clock := 0.0
var layer: ColorRect
var material: ShaderMaterial
var field: Texture2D
var parameters: Dictionary = {"cloud_enabled": false}
var _initialized := false
var _fog_enabled := false
var _zoom := -1.0


func _init(application: CityApplication) -> void:
	app = application


func reset() -> void:
	drift = Vector2.ZERO
	opacity = 0.0
	density = 0.0
	fog = 0.0
	weather_clock = 0.0
	_initialized = false
	_zoom = -1.0


func process(delta: float, phase_elapsed: float, active: bool, light: Color, darkness: float, weather_kind: int) -> void:
	var options := app.preferences.visual_enhancements
	var clouds_enabled: bool = options.get("cloud_enabled", true)
	var fog_enabled: bool = options.weather_enabled and options.get("weather_fog_enabled", true)
	var enabled: bool = active and (clouds_enabled or fog_enabled) and app.map_view.city_source != null
	parameters = {"cloud_enabled": enabled and clouds_enabled}
	if not enabled:
		parameters["cloud_fog_density"] = 0.0
		if layer != null:
			layer.hide()
		opacity = 0.0
		_initialized = false
		return
	if field == null:
		field = make_field()
	var speed := float(options.get("cloud_speed", 1.0))
	drift += WIND * maxf(phase_elapsed, 0.0) * speed
	drift = Vector2(fposmod(drift.x, FIELD_SPAN), fposmod(drift.y, FIELD_SPAN))
	var target := body_opacity(app.map_view.zoom_factor) if clouds_enabled else 0.0
	# A paused weather clock freezes drift, not the camera's cloud visibility.
	opacity = move_toward(opacity, target, maxf(delta, 0.0) * 3.0) if _initialized and _zoom == app.map_view.zoom_factor else target
	_zoom = app.map_view.zoom_factor
	var city := app.document_state.city
	var edge := city.map_size
	var rotation := city.compass_rotation()
	var scale := app.map_view.camera._view_scale()
	var offset := app.map_view.camera._draw_offset(scale)
	var source_to_canvas := app.map_view.get_global_transform() * Transform2D(Vector2(scale, 0), Vector2(0, scale), offset)
	var canvas_to_grid := source_to_grid(edge, rotation) * source_to_canvas.affine_inverse()
	var projection := source_to_grid(edge, rotation)
	var grid_to_source := projection.affine_inverse()
	var base_density := float(options.get("cloud_density", 0.4))
	var target_density := base_density
	var target_fog := 0.0
	if options.weather_enabled:
		weather_clock = fposmod(weather_clock + maxf(phase_elapsed, 0.0), 900.0)
		var game_weather := city.weather_type() if options.weather_mode == 0 else -1
		target_density = weather_density(base_density, weather_kind, game_weather, weather_clock)
		if fog_enabled:
			target_fog = weather_fog(weather_kind, game_weather, weather_clock) * float(options.weather_strength)
	# Weather fronts form over many seconds, even at high simulation speed.
	# Paused weather cycles retain their exact coverage. Manual disable/zero
	# density still takes effect immediately.
	if not _initialized or not options.weather_enabled or base_density <= 0.0:
		density = target_density
	elif phase_elapsed > 0.0:
		density = move_toward(density, target_density, minf(maxf(delta, 0.0), phase_elapsed) * 0.006)
	if not _initialized or not fog_enabled or fog_enabled != _fog_enabled:
		fog = target_fog
	elif phase_elapsed > 0.0:
		fog = move_toward(fog, target_fog, minf(maxf(delta, 0.0), phase_elapsed) * 0.004)
	_initialized = true
	_fog_enabled = fog_enabled
	parameters.merge({
		"cloud_field": field,
		"cloud_span": FIELD_SPAN,
		"cloud_drift": drift,
		"cloud_density": density,
		"cloud_formation": 0.18 if options.weather_enabled else 0.0,
		"cloud_fog_density": minf(fog, 0.3),
		"cloud_fog_drift": Vector2.ONE * (weather_clock / 900.0 * FIELD_SPAN),
		"cloud_shadow_strength": float(options.get("cloud_shadow_strength", 0.4)) * (1.0 - darkness * 0.85),
		"cloud_canvas_to_grid": shader_basis(canvas_to_grid),
		"cloud_projection": Vector4(grid_to_source.x.x, grid_to_source.x.y, grid_to_source.y.x, grid_to_source.y.y) / 16.0,
		"cloud_height_grid": projection.y * HEIGHT_PIXELS,
		"cloud_level_grid": projection.y * IsometricConstants.ALTITUDE_STEP,
		"cloud_map_edge": float(edge),
		"cloud_opacity": opacity,
		"cloud_light": Vector3(light.r, light.g, light.b),
	})
	_sync_layer(source_to_canvas, edge, rotation)


func _sync_layer(source_to_canvas: Transform2D, edge: int, rotation: int) -> void:
	if opacity <= 0.001:
		if layer != null:
			layer.hide()
		return
	if layer == null:
		layer = ColorRect.new()
		layer.name = "VisualClouds"
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		material = ShaderMaterial.new()
		material.shader = BODIES
		layer.material = material
		app.map_view.add_child(layer)
		# Above both textured layers and direct city drawing, below weather and
		# tool previews. Cloud bodies never intercept map input.
		var foreground: Control = app.visual_environment.weather.layer
		if foreground == null:
			foreground = app.map_view.layers.overlay_layer
		if foreground != null:
			app.map_view.move_child(layer, foreground.get_index())
	var bounds := app.map_view.camera._camera_rect()
	layer.position = bounds.position
	layer.size = bounds.size
	layer.show()
	var lift := Transform2D(0.0, Vector2(0, HEIGHT_PIXELS))
	material.set_shader_parameter("cloud_canvas_to_body_grid", shader_basis(source_to_grid(edge, rotation) * lift * source_to_canvas.affine_inverse()))


static func body_opacity(zoom: float) -> float:
	return 1.0 - smoothstep(0.25, 1.0, zoom)


static func weather_density(base: float, kind: int, game_weather: int, clock: float) -> float:
	var coverage: float = WEATHER_COVERAGE[clampi(kind, 0, WEATHER_COVERAGE.size() - 1)]
	if kind == CityVisualWeather.Kind.SUNNY and game_weather >= 0 and game_weather < FAIR_WEATHER_COVERAGE.size():
		coverage = FAIR_WEATHER_COVERAGE[game_weather]
	# Both waves meet exactly at the 900-second wrap; no simulation random
	# numbers are consumed and fixed weather still has gentle passing fronts.
	var variation := 1.0 + 0.12 * sin(clock * TAU / 180.0) + 0.07 * sin(clock * TAU / 300.0 + 0.7)
	return clampf(base * coverage * variation, 0.0, 1.0)


static func weather_fog(kind: int, game_weather: int, clock: float) -> float:
	var amount := 0.0
	if game_weather == 3:
		amount = 0.24
	elif kind in [CityVisualWeather.Kind.LIGHT_RAIN, CityVisualWeather.Kind.LIGHT_SNOW]:
		amount = 0.055
	elif kind in [CityVisualWeather.Kind.HEAVY_RAIN, CityVisualWeather.Kind.RAIN_STORM, CityVisualWeather.Kind.HEAVY_SNOW]:
		amount = 0.09
	return amount * (0.8 + 0.2 * sin(clock * TAU / 300.0))


static func shader_basis(transform: Transform2D) -> Basis:
	# Shader mat3 uniforms require Basis, including the translation column.
	return Basis(Vector3(transform.x.x, transform.x.y, 0), Vector3(transform.y.x, transform.y.y, 0),
		Vector3(transform.origin.x, transform.origin.y, 1))


static func source_to_grid(edge: int, rotation: int) -> Transform2D:
	var origin := Vector2(IsometricConstants.SIDE_MARGIN + (edge + 1) * IsometricConstants.HALF_WIDTH,
		IsometricConstants.TOP_MARGIN + IsometricConstants.HALF_HEIGHT)
	var projection := Transform2D(Vector2(1.0 / 32.0, -1.0 / 32.0), Vector2(1.0 / 16.0, 1.0 / 16.0), Vector2.ZERO)
	projection.origin = -(projection * origin)
	# A counterclockwise city turn increments compass and maps (x,y) to
	# (y,edge-1-x). Invert that turn to keep the cloud field above the city.
	var turn := Transform2D(Vector2(0, -1), Vector2(1, 0), Vector2(0, edge - 1))
	for _index in posmod(rotation, 4):
		projection = turn.affine_inverse() * projection
	return projection


static func make_field() -> Texture2D:
	# Authored cloud colors and alpha are shared by tops, shadows and water.
	# Placement is deterministic; no city RNG or per-frame image work is used.
	return CUMULUS
