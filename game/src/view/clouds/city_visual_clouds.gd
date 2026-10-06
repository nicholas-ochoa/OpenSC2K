class_name CityVisualClouds
extends RefCounted
## Presentation-only cloud field. Never writes city data or simulation RNG.

const BODIES := preload("res://src/view/clouds/cloud_bodies.gdshader")
const CUMULUS := preload("res://assets/clouds/cumulus_atlas.png")
const FIELD_SPAN := 192.0
const HEIGHT_PIXELS := 192.0
const WIND := Vector2(0.32, 0.20)

var app: CityApplication
var drift := Vector2.ZERO
var opacity := 0.0
var layer: ColorRect
var material: ShaderMaterial
var field: Texture2D
var parameters: Dictionary = {"cloud_enabled": false}
var _initialized := false


func _init(application: CityApplication) -> void:
	app = application


func reset() -> void:
	drift = Vector2.ZERO
	opacity = 0.0
	_initialized = false


func process(delta: float, phase_elapsed: float, active: bool, light: Color, darkness: float, weather_kind: int) -> void:
	var options := app.preferences.visual_enhancements
	var enabled: bool = active and options.get("cloud_enabled", true) and app.map_view.city_source != null
	parameters = {"cloud_enabled": enabled}
	if not enabled:
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
	var target := body_opacity(app.map_view.zoom_factor)
	opacity = move_toward(opacity, target, maxf(delta, 0.0) * 3.0) if _initialized else target
	_initialized = true
	var city := app.document_state.city
	var edge := city.map_size
	var rotation := city.compass_rotation()
	var scale := app.map_view.camera._view_scale()
	var offset := app.map_view.camera._draw_offset(scale)
	var source_to_canvas := app.map_view.get_global_transform() * Transform2D(Vector2(scale, 0), Vector2(0, scale), offset)
	var canvas_to_grid := source_to_grid(edge, rotation) * source_to_canvas.affine_inverse()
	var projection := source_to_grid(edge, rotation)
	var grid_to_source := projection.affine_inverse()
	var density := float(options.get("cloud_density", 0.4))
	if options.weather_enabled and weather_kind != CityVisualWeather.Kind.SUNNY:
		density = minf(1.0, density * 1.25)
	parameters.merge({
		"cloud_field": field,
		"cloud_span": FIELD_SPAN,
		"cloud_drift": drift,
		"cloud_density": density,
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
