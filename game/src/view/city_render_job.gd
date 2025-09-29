class_name CityRenderJob
extends RefCounted

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const UndergroundView = preload("res://src/view/city_underground_view.gd")
const ViewFilter = preload("res://src/view/city_view_filter.gd")

var city_snapshot: CityState
var index_palette: Sc2Palette
var sprites: Sc2SpriteArchive
var view_size := Renderer.VIEW_LARGE
var animation_phase := 0
var signature: Array = []
var epoch := 0
var render_mode := "city"
var surface_visibility: Dictionary = ViewFilter.DEFAULT_VISIBILITY.duplicate()
var show_underground_pipes := true


func run() -> Dictionary:
	var indexed: Dictionary
	if render_mode == "underground":
		indexed = UndergroundView.create_image(
			city_snapshot, index_palette, sprites, view_size, false,
			show_underground_pipes
		)
	else:
		city_snapshot = ViewFilter.surface_copy(city_snapshot, surface_visibility)
		indexed = Renderer.create_image(
			city_snapshot, index_palette, sprites, view_size, animation_phase,
			false, true, false, false
		)
	if not indexed.ok:
		return {
			"ok": false,
			"error": indexed.error,
			"signature": signature,
			"view_size": view_size,
			"epoch": epoch,
			"render_mode": render_mode,
		}
	var index_image: Image = indexed.image
	if view_size != Renderer.VIEW_LARGE:
		index_image.resize(
			Renderer.IMAGE_SIZE_LARGE.x,
			Renderer.IMAGE_SIZE_LARGE.y,
			Image.INTERPOLATE_NEAREST
		)
	var occlusion_commands: Array[Dictionary] = []
	if render_mode == "city":
		occlusion_commands = Renderer.static_occlusion_commands(
			city_snapshot, sprites, view_size
		)
	return {
		"ok": true,
		"error": "",
		"index_image": index_image,
		"occlusion_commands": occlusion_commands,
		"signature": signature,
		"view_size": view_size,
		"epoch": epoch,
		"render_mode": render_mode,
		"display_city": city_snapshot,
	}
