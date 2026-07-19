class_name CityPngExportJob
extends RefCounted
# render a whole city view to a png file on a worker thread

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const ScurkCityOutput = preload("res://src/assets/scurk_city_output.gd")
const ViewFilter = preload("res://src/view/city_view_filter.gd")

const STAGE_RENDER := "render"
const STAGE_WRITE := "write"

var city_snapshot: CityState
var palette: Sc2Palette
var sprites: Sc2SpriteArchive
var view_size := Renderer.VIEW_LARGE
var render_mode := "city"
var transparent_background := false
var include_signs := true
var include_moving_things := true
var surface_visibility: Dictionary = ViewFilter.DEFAULT_VISIBILITY.duplicate()
var show_underground_pipes := true
var show_underground_water_mains := true
var path := ""
var thread: Thread

var _mutex := Mutex.new()
var _stage := STAGE_RENDER
var _fraction := 0.0


# output size in pixels. the export draws each graphics size 1:1
static func output_size(map_edge: int, graphics_size: int) -> Vector2i:
	return Renderer.output_size_for_view(graphics_size, map_edge)


func start() -> Error:
	thread = Thread.new()

	return thread.start(run, Thread.PRIORITY_LOW)


# return the current stage and its completed fraction. safe from any thread
func progress() -> Dictionary:
	_mutex.lock()
	var result := {"stage": _stage, "fraction": _fraction}
	_mutex.unlock()

	return result


func run() -> Dictionary:
	if city_snapshot == null or not city_snapshot.is_valid():
		return _failure("the city is not valid")

	var visibility := surface_visibility.duplicate()
	visibility.signs = include_signs
	var rendered := ScurkCityOutput.render(city_snapshot, palette, sprites, view_size, {
		"view": render_mode,
		"surface_visibility": visibility,
		"moving_things": include_moving_things,
		# fire, flood, riot, and toxic-cloud markers are city state, not traffic
		"special_overlays": true,
		"show_pipes": show_underground_pipes,
		"show_water_mains": show_underground_water_mains,
		"transparent_background": transparent_background,
		"progress": _set_render_fraction,
	})

	if not rendered.ok:
		return _failure(String(rendered.error))

	var image: Image = rendered.image
	_set_stage(STAGE_WRITE)

	if not transparent_background:
		image.convert(Image.FORMAT_RGB8)

	var error := image.save_png(path)

	if error != OK:
		return _failure("cannot write %s: %s" % [path, error_string(error)])

	return {"ok": true, "error": "", "path": path, "size": image.get_size()}


func _set_render_fraction(value: float) -> void:
	_mutex.lock()
	_fraction = value
	_mutex.unlock()


func _set_stage(value: String) -> void:
	_mutex.lock()
	_stage = value
	_fraction = 0.0
	_mutex.unlock()


func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message, "path": path, "size": Vector2i.ZERO}
