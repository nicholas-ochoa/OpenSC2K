# gdstyle:ignore-file=quality/max-class-variables
# gdstyle:ignore-file=quality/max-public-methods
class_name CityMapControl
extends Control

# scene node for the city map. its public methods are the node api that
# application and ui code call through map_view. components do the work

@warning_ignore("unused_signal")

signal selection_completed(
	start: Vector2i, finish: Vector2i, path: Array[Vector2i], dragged: bool
)
@warning_ignore("unused_signal")
signal selection_changed(
	start: Vector2i, finish: Vector2i, path: Array[Vector2i], dragged: bool
)
@warning_ignore("unused_signal")
signal stretch_changed(levels: int, deferred: bool)
@warning_ignore("unused_signal")
signal selection_started()
@warning_ignore("unused_signal")
signal selection_finished()
@warning_ignore("unused_signal")
signal selection_canceled()
@warning_ignore("unused_signal")
signal query_requested(point: Vector2i)
@warning_ignore("unused_signal")
signal center_requested(point: Vector2i)
@warning_ignore("unused_signal")
signal bulldoze_requested(point: Vector2i)
@warning_ignore("unused_signal")
signal zoom_changed(percent: int)
@warning_ignore("unused_signal")
signal viewport_changed()
# a mouse button bound to a player action that the application runs
@warning_ignore("unused_signal")
signal control_action_requested(action: String)
@warning_ignore("unused_signal")
signal control_hold_changed(action: String, button: MouseButton, pressed: bool)

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
const SIGN_EDGE_DARK = CityMapConstants.SIGN_EDGE_DARK
const SIGN_TEXT_COLOR = CityMapConstants.SIGN_TEXT_COLOR
const PALETTE_CYCLE_SHADER = CityMapConstants.PALETTE_CYCLE_SHADER
const ContextMenu = preload("res://src/view/map/context_menu.gd")

var _preserve_sign_layout := false
var city: CityState:
	set(value):
		city = value

		if not _preserve_sign_layout:
			signs._invalidate_sign_entries()
var city_source: CityMapSource
var palette_index_texture: Texture2D
var animated_palette_texture: Texture2D
var dark_underground_palette_texture: Texture2D
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
# the mouse buttons for map actions. the left button always uses the tool
var control_bindings := ControlBindings.defaults()
var context_menu: ContextMenu
var desktop_cursor_app := "city"
var desktop_cursor_role := 0
var zoom_factor: float = ZOOM_LEVELS[DEFAULT_ZOOM_INDEX]
# interface pixels for each source pixel at 100% zoom, so that the map keeps
# whole screen pixels at every interface scale
var map_pixel_ratio := 1.0
# screen pixels for each interface pixel. zero leaves the map offset in whole
# interface pixels
var screen_pixel_scale := 0.0
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
var placement_error_provider := Callable()
var placement_error_popup: PanelContainer
var placement_error_label: Label
var placement_validator := Callable()
var show_selection_preview := true
var terrain_diamond_preview := false
var stretch_terrain := false
var stretch_height_delta := 0
var network_preview_active := false
var highway_preview := false
var query_footprint_preview := false
var scurk_stamp_visuals: Array[CityDynamicVisual] = []
var trip_reach: TripReachOverlay
var _legend: CityMapLegend
var _data_tooltip: CityMapDataTooltip
var trip_query_underground := false
var query_city: CityState
var shift_line_enabled := false
var continuous_placement := false
var repeat_placement := false
var landscape_brush := false
var demolish_brush := false
var bulldozer_visual_provider := Callable()
# a translucent preview of the object that a click at a tile places
var placement_ghost_provider := Callable()
var bulldozer_direction := 0
var brush_box_selection := false
var brush_size := 1
var brush_round := false
var data_view_mode := CityViewMode.Mode.NONE
var data_view_mesh: ArrayMesh
var data_view_layer: MeshInstance2D
var data_view_signature: Array = []
var data_geometry_signature: Array = []
var data_value_texture: ImageTexture
var hover_tile := Vector2i(-1, -1)
var dynamic_sprites: Array[CityDynamicVisual] = []
var layers: CityMapLayers = CityMapLayers.new(self)
var signs: CityMapSigns = CityMapSigns.new(self)
var camera: CityMapCamera = CityMapCamera.new(self)
var presentation: CityMapPresentation = CityMapPresentation.new(self)
var selection: CityMapSelection = CityMapSelection.new(self)
var interaction: CityMapInteraction = CityMapInteraction.new(self)
var debug_view: CityMapDebugView = CityMapDebugView.new(self)


func _ready() -> void:
	theme_changed.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layers._ensure_base_layer()
	_legend = CityMapLegend.new()
	_legend.map = self
	add_child(_legend)
	_data_tooltip = CityMapDataTooltip.new()
	_data_tooltip.map = self
	add_child(_data_tooltip)
	context_menu = ContextMenu.new()
	context_menu.map = self
	add_child(context_menu)
	resized.connect(camera._on_resized)
	mouse_exited.connect(selection._clear_hover)


func _draw() -> void:
	presentation._draw()
	if _legend != null:
		_legend.refresh()
	if _data_tooltip != null:
		_data_tooltip.refresh()
	debug_view.sync()


func _gui_input(event: InputEvent) -> void:
	interaction._gui_input(event)


func _input(event: InputEvent) -> void:
	interaction._input(event)


func _process(delta: float) -> void:
	interaction._process(delta)


func set_data_view(value: CityState, mode: CityViewMode.Mode) -> void:
	layers.set_data_view(value, mode)


func clear_data_view() -> void:
	layers.clear_data_view()


# Use the source city here. Normal rendering can publish a display snapshot.
func discard_data_geometry_for_other_city(source_city: CityState) -> void:
	layers.discard_geometry_for_other_city(source_city)


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


func set_dark_underground_palette(texture: Texture2D) -> void:
	signs.set_dark_underground_palette(texture)


func set_signs_visible(value: bool) -> void:
	signs.set_signs_visible(value)


func sign_source_entries() -> Array[CityMapSigns.Entry]:
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


func set_pixel_scales(screen_pixels: float, map_pixels: int) -> void:
	camera.set_pixel_scales(screen_pixels, map_pixels)


func zoom_in(local_point := Vector2.INF) -> bool:
	return camera.zoom_in(local_point)


func reset_zoom() -> bool:
	return camera.reset_zoom()


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


func show_transient_effects(effects: Array[CityTransientEffectVisual], duration := 0.1) -> void:
	presentation.show_transient_effects(effects, duration)


func shake_view(frames := 24, frame_duration := 0.005, distance := 4.0) -> void:
	presentation.shake_view(frames, frame_duration, distance)


func set_dynamic_sprites(sprites: Array[CityDynamicVisual]) -> void:
	presentation.set_dynamic_sprites(sprites)


func debug_metrics() -> Dictionary:
	return presentation.debug_metrics()


func _get_tooltip(at_position: Vector2) -> String:
	return selection._get_tooltip(at_position)


func show_trip_reach(source: CityState, point: Vector2i) -> TransportTripReachResult:
	return presentation.show_trip_reach(source, point)


func clear_trip_reach() -> void:
	presentation.clear_trip_reach()


# bind timers to this node so they stop with it
func _expire_transient_effects(sequence: CityMapPresentation.TransientEffectSequence, generation: int) -> void:
	presentation._expire_transient_effects(sequence, generation)


# bind timers to this node so they stop with it
func _show_transient_effect_frame(
	sequence: CityMapPresentation.TransientEffectSequence,
	frame: int,
	duration: float,
	generation: int
) -> void:
	presentation._show_transient_effect_frame(sequence, frame, duration, generation)


# bind timers to this node so they stop with it
func _show_shake_frame(
	frame: int, frames: int, duration: float, distance: float, generation: int
) -> void:
	presentation._show_shake_frame(frame, frames, duration, distance, generation)
