class_name CityRenderJob
extends RefCounted

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const UndergroundView = preload("res://src/view/city_underground_view.gd")
const ViewFilter = preload("res://src/view/city_view_filter.gd")

class Result extends RefCounted:
	var ok := false
	var error := ""
	var index_image: Image
	var occlusion_commands: Array[Dictionary] = []
	var signature: Array = []
	var view_size := Renderer.VIEW_LARGE
	var epoch := 0
	var render_mode := CityViewMode.Mode.CITY
	var display_city: CityState


var city_snapshot: CityState
var index_palette: Sc2Palette
var sprites: Sc2SpriteArchive
var view_size := Renderer.VIEW_LARGE
var animation_phase := 0
var signature: Array = []
var epoch := 0
var render_mode := CityViewMode.Mode.CITY
var surface_visibility: Dictionary = ViewFilter.DEFAULT_VISIBILITY.duplicate()
var show_underground_water_mains := true
var show_underground_pipes := true
var show_underground_subways := true


func run() -> Result:
	var indexed: AssetImageResult

	if render_mode == CityViewMode.Mode.UNDERGROUND:
		indexed = UndergroundView.create_image(
			city_snapshot, index_palette, sprites, view_size, false,
			show_underground_pipes, show_underground_subways, show_underground_water_mains
		)
	else:
		city_snapshot = ViewFilter.surface_copy(city_snapshot, surface_visibility)
		indexed = Renderer.create_image(
			city_snapshot, index_palette, sprites, view_size, animation_phase,
			false, true, false, false
		)

	if not indexed.ok:
		var result := Result.new()
		result.ok = false
		result.error = indexed.error
		result.signature = signature
		result.view_size = view_size
		result.epoch = epoch
		result.render_mode = render_mode

		return result

	var index_image: Image = indexed.image

	if view_size != Renderer.VIEW_LARGE:
		index_image.resize(
			Renderer.output_size_for_view(Renderer.VIEW_LARGE, city_snapshot.map_size).x,
			Renderer.output_size_for_view(Renderer.VIEW_LARGE, city_snapshot.map_size).y,
			Image.INTERPOLATE_NEAREST
		)

	var occlusion_commands: Array[Dictionary] = []

	if render_mode == CityViewMode.Mode.CITY:
		occlusion_commands = Renderer.static_occlusion_commands(
			city_snapshot, sprites, view_size
		)

	var result := Result.new()
	result.ok = true
	result.error = ""
	result.index_image = index_image
	result.occlusion_commands = occlusion_commands
	result.signature = signature
	result.view_size = view_size
	result.epoch = epoch
	result.render_mode = render_mode
	result.display_city = city_snapshot

	return result
