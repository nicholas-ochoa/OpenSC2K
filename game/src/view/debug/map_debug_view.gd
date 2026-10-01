class_name CityMapDebugView
extends RefCounted
## The debug nodes of the city map: the tile layer, the overlay lines, the map
## labels, the Tile Inspector, the layer key and the performance HUD. The
## application fills them. `sync` runs in each map draw and places them after
## a pan or zoom; it does not build content.

const PANEL_MARGIN := Vector2(12, 12)

var map: CityMapControl
var tile_layer: CityDebugTileLayer
var overlay: CityDebugOverlayCanvas
var labels: CityDebugLabelCanvas
var inspector: CityTileInspectorPanel
var legend: CityDebugLegendPanel
var hud: CityPerformanceHud
# the Tile Inspector follows the pointer, or stays on a pinned tile
var inspector_active := false
var pinned_tile := Vector2i(-1, -1)
# makes the inspector text for a tile
var inspector_text := Callable()
# a new value refreshes the inspector text of the same tile
var inspector_revision := 0
var legend_summary := ""


func _init(control: CityMapControl) -> void:
	map = control


func is_attached() -> bool:
	return tile_layer != null


func attach() -> void:
	if is_attached():
		return

	tile_layer = CityDebugTileLayer.new()
	map.add_child(tile_layer)
	overlay = CityDebugOverlayCanvas.new()
	map.add_child(overlay)
	labels = CityDebugLabelCanvas.new()
	map.add_child(labels)
	legend = CityDebugLegendPanel.new()
	map.add_child(legend)
	hud = CityPerformanceHud.new()
	map.add_child(hud)
	inspector = CityTileInspectorPanel.new()
	map.add_child(inspector)
	sync()


func sync() -> void:
	if not is_attached():
		return

	var scale := map.camera._view_scale()
	var offset := map.camera._draw_offset(scale)
	var map_view := map.data_view_mode == CityViewMode.Mode.NONE and map.city_source != null
	tile_layer.position = offset
	tile_layer.scale = Vector2.ONE * scale
	tile_layer.visible = map_view and (tile_layer.layer != DebugTileLayers.Layer.NONE or tile_layer.grid) and tile_layer.mesh != null
	overlay.set_view_transform(scale, offset)
	overlay.visible = map.city_source != null
	labels.size = map.size
	labels.set_view_transform(scale, offset)
	labels.visible = map_view
	var space := map_space()
	legend.show_layer(tile_layer.layer if map_view else DebugTileLayers.Layer.NONE, legend_summary)
	legend.position = Vector2(space.position.x + PANEL_MARGIN.x, space.end.y - legend.size.y - PANEL_MARGIN.y)
	hud.position = Vector2(space.end.x - hud.size.x - PANEL_MARGIN.x, space.position.y + PANEL_MARGIN.y)
	_sync_inspector(scale, offset)


func _sync_inspector(scale: float, offset: Vector2) -> void:
	var tile := pinned_tile if pinned_tile.x >= 0 else map.hover_tile

	if not inspector_active or map.city == null or tile.x < 0 or not inspector_text.is_valid() or map.camera.is_panning():
		inspector.close()

		return

	var anchor := map.get_local_mouse_position()

	if pinned_tile.x >= 0:
		anchor = offset + tile_center(map.city, pinned_tile) * scale

	inspector.show_text([tile, inspector_revision], inspector_text.bind(tile), anchor, map.size)


# the map area beside the tool and status panels, in map coordinates
func map_space() -> Rect2:
	var workspace := map.get_parent()
	var space := workspace.get_node_or_null("Page/Content/MapSpace") as Control if workspace != null else null

	if space == null:
		return Rect2(Vector2.ZERO, map.size)

	return Rect2(space.global_position - map.global_position, space.size)


# the center of a tile top, in source pixels
static func tile_center(city: CityState, point: Vector2i) -> Vector2:
	var center := Vector2.ZERO

	for corner in CityIsometricRenderer.terrain_surface_polygon(city, point.x, point.y):
		center += corner * 0.25

	return center


# point pairs around a tile top, for a line set
static func tile_outline(city: CityState, point: Vector2i) -> PackedVector2Array:
	var polygon := CityIsometricRenderer.terrain_surface_polygon(city, point.x, point.y)
	var result := PackedVector2Array()

	for index in polygon.size():
		result.append(polygon[index])
		result.append(polygon[(index + 1) % polygon.size()])

	return result
