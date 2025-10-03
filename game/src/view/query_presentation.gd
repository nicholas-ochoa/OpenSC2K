class_name QueryPresentation
extends RefCounted

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const FIRST_THING_OVERLAY := 201
const LAST_THING_OVERLAY := 240
const SAILBOAT_TYPE := 9
const LARGE_SPRITE_BASE := 1000
const LARGE_SAILBOAT_NORTHEAST := 1380
const LARGE_VIEW := Renderer.VIEW_LARGE


static func sprite_id(city: CityState, info: Dictionary) -> int:
	if city == null or not city.is_valid() or not info.get("ok", false):
		return -1
	if info.get("kind", "") == "specific":
		var microsim: Dictionary = info.get("microsim", {})
		var facility_tile := int(microsim.get("tile_id", 0))
		return LARGE_SPRITE_BASE + facility_tile if facility_tile > 0 else -1

	var point: Vector2i = info.get("point", Vector2i(-1, -1))
	if city.index_of(point.x, point.y) < 0:
		return -1
	var building := city.building_id(point.x, point.y)
	var result := (
		LARGE_SPRITE_BASE + building
		if building != 0
		else Renderer.terrain_sprite_id(
			city.terrain_id(point.x, point.y), city.is_water(point.x, point.y)
		)
	)
	var overlay := city.text_overlay_id(point.x, point.y)
	if overlay >= FIRST_THING_OVERLAY and overlay <= LAST_THING_OVERLAY:
		var thing := city.thing(overlay - FIRST_THING_OVERLAY)
		if int(thing.get("type", 0)) == SAILBOAT_TYPE:
			result = LARGE_SAILBOAT_NORTHEAST
	return result


static func thing_sprite(
	city: CityState, point: Vector2i, thing: Dictionary, record := -1
) -> Dictionary:
	if city == null or not city.is_valid() or thing.is_empty():
		return {}
	var thing_type := int(thing.get("type", 0))
	if thing_type < 1 or thing_type >= Renderer.THING_SPRITES.size():
		return {}
	match thing_type:
		5:
			return {"sprite_id": Renderer.THING_SPRITES[5], "flip": false}
		7, 8, 14:
			var offset := int(Renderer.DISPATCH_SPRITE_OFFSETS.get(thing_type, 0))
			return {
				"sprite_id": LARGE_SPRITE_BASE + offset,
				"flip": false,
			}
		10, 11:
			return Renderer.train_sprite(city, point.x, point.y, thing)
		12, 13:
			return {
				"sprite_id": Renderer.THING_SPRITES[thing_type],
				"flip": false,
			}
		15:
			return Renderer.tornado_sprite(
				city, point.x, point.y, thing, max(record, 0), LARGE_VIEW
			)
		_:
			return Renderer.moving_thing_sprite(thing, LARGE_VIEW)
