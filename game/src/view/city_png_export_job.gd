class_name CityPngExportJob
extends RefCounted
# render a whole city view to a png file on a worker thread

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const ScurkCityOutput = preload("res://src/assets/scurk_city_output.gd")
const ViewFilter = preload("res://src/view/city_view_filter.gd")

const STAGE_RENDER := "render"
const STAGE_WRITE := "write"

class Options extends RefCounted:
	var path := ""
	var view_size := Renderer.VIEW_LARGE
	var view := "city"
	var transparent_background := false
	var signs := true
	var moving_things := true


class Progress extends RefCounted:
	var stage := ""
	var fraction := 0.0


class Result extends FileWriteResult:
	var size := Vector2i.ZERO


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
func progress() -> Progress:
	_mutex.lock()
	var result := Progress.new()
	result.stage = _stage
	result.fraction = _fraction
	_mutex.unlock()

	return result


func run() -> Result:
	if city_snapshot == null or not city_snapshot.is_valid():
		return _failure("the city is not valid")

	var visibility := surface_visibility.duplicate()
	visibility.signs = include_signs
	var options := ScurkCityOutput.Options.new()
	options.view = render_mode
	options.surface_visibility.assign(visibility)
	options.moving_things = include_moving_things
	# fire, flood, riot, and toxic-cloud markers are city state, not traffic
	options.special_overlays = true
	options.show_pipes = show_underground_pipes
	options.show_water_mains = show_underground_water_mains
	options.transparent_background = transparent_background
	options.progress = _set_render_fraction
	var rendered := ScurkCityOutput.render(city_snapshot, palette, sprites, view_size, options)

	if not rendered.ok:
		return _failure(String(rendered.error))

	var image: Image = rendered.image
	_set_stage(STAGE_WRITE)

	if not transparent_background:
		image.convert(Image.FORMAT_RGB8)

	var error := image.save_png(path)

	if error != OK:
		return _failure("cannot write %s: %s" % [path, error_string(error)])

	var result := Result.new()
	result.ok = true
	result.error = ""
	result.path = path
	result.size = image.get_size()

	return result


func _set_render_fraction(value: float) -> void:
	_mutex.lock()
	_fraction = value
	_mutex.unlock()


func _set_stage(value: String) -> void:
	_mutex.lock()
	_stage = value
	_fraction = 0.0
	_mutex.unlock()


func _failure(message: String) -> Result:
	var result := Result.new()
	result.ok = false
	result.error = message
	result.path = path
	result.size = Vector2i.ZERO

	return result
