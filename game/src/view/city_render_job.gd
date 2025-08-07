class_name CityRenderJob
extends RefCounted

const Renderer = preload("res://src/view/city_isometric_renderer.gd")

var city_snapshot: CityState
var index_palette: Sc2Palette
var sprites: Sc2SpriteArchive
var view_size := Renderer.VIEW_LARGE
var animation_phase := 0
var signature: Array = []
var epoch := 0


func run() -> Dictionary:
	var indexed := Renderer.create_image(
		city_snapshot, index_palette, sprites, view_size, animation_phase,
		false, true, false
	)
	if not indexed.ok:
		return {
			"ok": false,
			"error": indexed.error,
			"signature": signature,
			"view_size": view_size,
			"epoch": epoch,
		}
	var index_image: Image = indexed.image
	if view_size != Renderer.VIEW_LARGE:
		index_image.resize(
			Renderer.IMAGE_SIZE_LARGE.x,
			Renderer.IMAGE_SIZE_LARGE.y,
			Image.INTERPOLATE_NEAREST
		)
	return {
		"ok": true,
		"error": "",
		"index_image": index_image,
		"signature": signature,
		"view_size": view_size,
		"epoch": epoch,
	}
