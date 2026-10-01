class_name DebugCapture
extends RefCounted
## Saves the window image and a JSON file of the debug state into a new folder
## under debug_captures in the application data folder. The JSON holds the
## Debug window metrics, the camera, the hovered tile, the Tile Inspector text
## and the active debug views, so a later visual check can repeat the view.

const FOLDER := "debug_captures"


# the status text: the folder, or the reason for a failure
static func capture(app: CityApplication, state: DebugViewState, root := "") -> String:
	var folder := (root if not root.is_empty() else AppPaths.path(FOLDER)).path_join(_stamp())
	var error := DirAccess.make_dir_recursive_absolute(folder)

	if error != OK:
		return "Cannot make the debug capture folder: %s." % error_string(error)

	# a headless run has no window image
	var texture := app.get_viewport().get_texture() if app.is_inside_tree() and DisplayServer.get_name() != "headless" else null
	var image := texture.get_image() if texture != null else null
	var saved_image := image != null and not image.is_empty() and image.save_png(folder.path_join("screen.png")) == OK
	var file := FileAccess.open(folder.path_join("state.json"), FileAccess.WRITE)

	if file == null:
		return "Cannot write the debug capture state: %s." % error_string(FileAccess.get_open_error())

	file.store_string(JSON.stringify(state_record(app, state), "\t", false))
	file.close()

	return "Saved a debug capture%s to %s." % ["" if saved_image else " without a window image", folder]


static func state_record(app: CityApplication, state: DebugViewState) -> Dictionary:
	var record := {
		"time": Time.get_datetime_string_from_system(true),
		"metrics": _plain(app.debug.debug_metrics()),
		"debug_views": {
			"tile_layer": DebugTileLayers.title(state.tile_layer),
			"tile_values": state.tile_values,
			"change_baseline": CityDebugMenu.BASELINE_TITLES[state.change_baseline],
			"region_bounds": state.region_bounds,
			"region_repaints": state.region_repaints,
			"occluders": state.occluders,
			"sprite_bounds": state.sprite_bounds,
			"thing_paths": state.thing_paths,
			"performance_hud": state.performance_hud,
		},
	}
	var map := app.map_view

	if map != null:
		record.camera = {
			"zoom_percent": map.zoom_percent(), "center_tile": _point(map.center_tile()),
			"source_center": [map.source_center.x, map.source_center.y], "map_size": [map.size.x, map.size.y],
			"view": CityViewMode.key(app.view_state.overlay_mode),
		}
		record.hover_tile = _point(map.hover_tile)

		if map.debug_view.is_attached() and map.debug_view.inspector.visible:
			record.inspector = map.debug_view.inspector.text()

	var document := app.document_state.current_document

	if document != null:
		record.city_file = document.source_path

	return record


static func _stamp() -> String:
	return Time.get_datetime_string_from_system(false).replace(":", "-").replace("T", "_") + "_%03d" % (Time.get_ticks_msec() % 1000)


static func _point(value: Vector2i) -> Array:
	return [value.x, value.y]


# JSON keeps numbers, text, lists and dictionaries. other values become text
static func _plain(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}

		for key in value:
			result[str(key)] = _plain(value[key])

		return result

	if value is Array:
		return (value as Array).map(_plain)

	if value is bool or value is int or value is float or value is String:
		return value

	return str(value)
