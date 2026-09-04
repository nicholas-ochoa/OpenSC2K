class_name CityMapControl
extends Control
# scene node for the city map. its public methods are the node api that
# application and ui code call through map_view. components do the work

signal selection_completed(
	start: Vector2i, finish: Vector2i, path: Array[Vector2i], dragged: bool
)
signal selection_changed(
	start: Vector2i, finish: Vector2i, path: Array[Vector2i], dragged: bool
)
signal stretch_changed(levels: int, deferred: bool)
signal selection_started()
signal selection_finished()
signal selection_canceled()
signal query_requested(point: Vector2i)
signal center_requested(point: Vector2i)
signal zoom_changed(percent: int)
signal viewport_changed()

const Renderer = CityMapConstants.Renderer
const DynamicSpriteCanvas = CityMapConstants.DynamicSpriteCanvas
const ZOOM_LEVELS = CityMapConstants.ZOOM_LEVELS
const DEFAULT_ZOOM_INDEX = CityMapConstants.DEFAULT_ZOOM_INDEX
const WHEEL_ZOOM_DEBOUNCE_MSEC = CityMapConstants.WHEEL_ZOOM_DEBOUNCE_MSEC
const WHEEL_ZOOM_MAX_DEBOUNCE_MSEC = CityMapConstants.WHEEL_ZOOM_MAX_DEBOUNCE_MSEC
const NETWORK_PREVIEW_Z_INDEX = CityMapConstants.NETWORK_PREVIEW_Z_INDEX
const PRICE_LAYER_Z_INDEX = CityMapConstants.PRICE_LAYER_Z_INDEX
const SIGN_FONT_HEIGHTS = CityMapConstants.SIGN_FONT_HEIGHTS
const SIGN_PANEL_FILL = CityMapConstants.SIGN_PANEL_FILL
const SIGN_POST_FILL = CityMapConstants.SIGN_POST_FILL
const SIGN_EDGE_LIGHT = CityMapConstants.SIGN_EDGE_LIGHT
const SIGN_EDGE_MIDDLE = CityMapConstants.SIGN_EDGE_MIDDLE
const SIGN_EDGE_DARK = CityMapConstants.SIGN_EDGE_DARK
const SIGN_TEXT_COLOR = CityMapConstants.SIGN_TEXT_COLOR
const PALETTE_CYCLE_SHADER = CityMapConstants.PALETTE_CYCLE_SHADER

var _preserve_sign_layout := false
var city: CityState:
	set(value):
		city = value

		if not _preserve_sign_layout:
			signs._invalidate_sign_entries()
var city_source: CityMapSource
var palette_index_texture: Texture2D
var animated_palette_texture: Texture2D
var dark_underground := false:
	set(value):
		dark_underground = value
		layers._sync_base_material()
var base_palette_lookup_all := false
var signs_visible := true
var edit_enabled := false
var shift_rectangle_enabled := false
var selection_mode := "rectangle"
var point_footprint_area := 1
var shift_query_enabled := false
var desktop_cursor_app := "city"
var desktop_cursor_role := 0
var zoom_factor: float = ZOOM_LEVELS[DEFAULT_ZOOM_INDEX]
var source_center := Vector2.ZERO
# the unobstructed camera area. rendering still covers the full control
var camera_view_rect := Rect2():
	set(value):
		if camera_view_rect == value:
			return

		camera_view_rect = value
		camera._on_resized()
var pending_loaded_center := Vector2i(-1, -1)
var selection_start := Vector2i(-1, -1)
var selection_end := Vector2i(-1, -1)
var selection_path: Array[Vector2i] = []
var selection_moved := false
var selection_price := -1
var selection_price_affordable := true
# the price label draws above the network preview layer, not under it
var _price_layer: Node2D
var placement_error_provider := Callable()
var placement_error_popup: PanelContainer
var placement_error_label: Label
var placement_validator := Callable()
var show_selection_preview := true
var terrain_diamond_preview := false
var stretch_terrain := false
var stretch_height_delta := 0
var _stretch_press_y := 0.0
var network_preview_active := false
var highway_preview := false
var query_footprint_preview := false
var scurk_stamp_visuals: Array[Dictionary] = []
var service_query: ServiceQueryOverlay
var trip_reach: TripReachOverlay
var trip_query_underground := false
var query_city: CityState
var _shift_pressed := false
var shift_line_enabled := false
var continuous_placement := false
var landscape_brush := false
var demolish_brush := false
var bulldozer_visual_provider := Callable()
var bulldozer_direction := 0
var brush_box_selection := false
var brush_size := 1
var brush_round := false
var _last_brush_tile := Vector2i(-1, -1)
var _brush_elapsed := 0.0
var data_view_mode := CityViewMode.Mode.NONE
var data_view_mesh: ArrayMesh
var data_view_layer: MeshInstance2D
var data_view_signature: Array = []
var data_geometry_signature: Array = []
var data_value_texture: ImageTexture

var hover_tile := Vector2i(-1, -1)
var transient_effects: Array[Dictionary] = []
var dynamic_sprites: Array[Dictionary] = []
var sign_occlusion_visuals: Dictionary[int, CitySignVisual] = {}
var _panning := false
var _middle_click_pending := false
var _middle_press_position := Vector2.ZERO
var _effect_generation := 0
var _shake_generation := 0
var _shake_offset := Vector2.ZERO
var _next_wheel_zoom_msec := 0
var _last_wheel_zoom_msec := 0
var _tile_layers: Array[TextureRect] = []
var _mesh_layers: Array[MeshInstance2D] = []
var _mesh_view_scale := -1.0
var _tiled_source: CityMapSource
var _base_layer: TextureRect
var _base_material: ShaderMaterial
var _dynamic_canvas: CityDynamicSpriteCanvas
var _dynamic_material: ShaderMaterial
var _palette_shader: Shader
var _foreground_palette_material: ShaderMaterial
var _sign_font: SystemFont
var _sign_entries: Array[CityMapSigns.Entry] = []
var _sign_entries_city: CityState
var _sign_entries_zoom := -1.0
var _sign_layout_signature: Array = []
var _external_sign_layout_token: Array = []
var _sign_cache_build_count := 0

var layers: CityMapLayers = CityMapLayers.new(self)
var signs: CityMapSigns = CityMapSigns.new(self)
var camera: CityMapCamera = CityMapCamera.new(self)
var presentation: CityMapPresentation = CityMapPresentation.new(self)
var selection: CityMapSelection = CityMapSelection.new(self)
var interaction: CityMapInteraction = CityMapInteraction.new(self)
var moving_occlusion: CityMapMovingOcclusion = CityMapMovingOcclusion.new(self)


func _ready() -> void:
	theme_changed.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layers._ensure_base_layer()
	resized.connect(camera._on_resized)
	mouse_exited.connect(selection._clear_hover)


func set_data_view(value: CityState, mode: CityViewMode.Mode) -> void:
	layers.set_data_view(value, mode)


func clear_data_view() -> void:
	layers.clear_data_view()


func set_city_view(
	value: CityState,
	source: CityMapSource,
	index_texture: Texture2D = null,
	palette_lookup_all := false,
	preserve_sign_cache := false,
	sign_layout_token: Array = []
) -> void:
	presentation.set_city_view(value, source, index_texture, palette_lookup_all, preserve_sign_cache, sign_layout_token)


func set_animated_palette(texture: Texture2D) -> void:
	signs.set_animated_palette(texture)


func set_signs_visible(value: bool) -> void:
	signs.set_signs_visible(value)


func set_sign_occlusion_visuals(value: Dictionary[int, CitySignVisual]) -> void:
	signs.set_sign_occlusion_visuals(value)


func sign_source_entries() -> Array[CitySignRequest]:
	return signs.sign_source_entries()


func set_edit_enabled(
	value: bool,
	mode := "rectangle",
	footprint_area := 1,
	shift_queries := false
) -> void:
	selection.set_edit_enabled(value, mode, footprint_area, shift_queries)


func zoom_percent() -> int:
	return camera.zoom_percent()


func zoom_in(local_point := Vector2.INF) -> bool:
	return camera.zoom_in(local_point)


func zoom_out(local_point := Vector2.INF) -> bool:
	return camera.zoom_out(local_point)


func can_zoom_in() -> bool:
	return camera.can_zoom_in()


func can_zoom_out() -> bool:
	return camera.can_zoom_out()


func uses_paint_brush() -> bool:
	return selection.uses_paint_brush()


func is_left_drag_active() -> bool:
	return selection.is_left_drag_active()


func pan_screen(displacement: Vector2) -> void:
	camera.pan_screen(displacement)


func is_panning() -> bool:
	return camera.is_panning()


func set_selection_price(value: int, affordable := true) -> void:
	selection.set_selection_price(value, affordable)


func clear_selection_price() -> void:
	selection.clear_selection_price()


func cancel_active_selection() -> bool:
	return selection.cancel_active_selection()


func center_on_tile(point: Vector2i) -> bool:
	return camera.center_on_tile(point)


func center_on_tiles(first: Vector2i, last: Vector2i) -> bool:
	return camera.center_on_tiles(first, last)


func center_tile() -> Vector2i:
	return camera.center_tile()


func visible_source_rect() -> Rect2:
	return camera.visible_source_rect()


func visible_tile_outline() -> PackedVector2Array:
	return camera.visible_tile_outline()


func show_transient_effects(effects: Array[Dictionary], duration := 0.1) -> void:
	presentation.show_transient_effects(effects, duration)


func shake_view(frames := 24, frame_duration := 0.005, distance := 4.0) -> void:
	presentation.shake_view(frames, frame_duration, distance)


func set_dynamic_sprites(sprites: Array[Dictionary]) -> void:
	presentation.set_dynamic_sprites(sprites)


# use gpu occlusion and shadows for moving objects when the base allows it
func set_moving_occlusion_enabled(value: bool) -> void:
	moving_occlusion.set_enabled(value)


func moving_occlusion_active() -> bool:
	return moving_occlusion.active()


# render-target pixels per source pixel, including zoom and window scale
func screen_pixels_per_source_pixel() -> float:
	return zoom_factor * moving_occlusion._screen_transform().get_scale().x


# display-only offsets and draw orders for interpolated moving objects, by xthg record
func set_moving_blend(offsets: Dictionary, orders: Dictionary) -> void:
	if _dynamic_canvas != null:
		_dynamic_canvas.set_blend(offsets, orders)


func debug_metrics() -> Dictionary:
	return presentation.debug_metrics()


func _draw() -> void:
	presentation._draw()


func _gui_input(event: InputEvent) -> void:
	interaction._gui_input(event)


func _input(event: InputEvent) -> void:
	interaction._input(event)


func _get_tooltip(at_position: Vector2) -> String:
	return selection._get_tooltip(at_position)


func _process(delta: float) -> void:
	interaction._process(delta)


func show_trip_reach(source: CityState, point: Vector2i) -> Dictionary:
	return presentation.show_trip_reach(source, point)


func clear_trip_reach() -> void:
	presentation.clear_trip_reach()


func show_service_query(source: CityState, point: Vector2i, all_stations := false) -> Dictionary:
	return presentation.show_service_query(source, point, all_stations)


func clear_service_query() -> void:
	presentation.clear_service_query()


# bind timers to this node so they stop with it
func _expire_transient_effects(generation: int) -> void:
	presentation._expire_transient_effects(generation)


# bind timers to this node so they stop with it
func _show_transient_effect_frame(
	effects: Array[Dictionary],
	frame: int,
	last_frame: int,
	duration: float,
	generation: int
) -> void:
	presentation._show_transient_effect_frame(effects, frame, last_frame, duration, generation)


# bind timers to this node so they stop with it
func _show_shake_frame(
	frame: int, frames: int, duration: float, distance: float, generation: int
) -> void:
	presentation._show_shake_frame(frame, frames, duration, distance, generation)
