class_name NativeTileDraws
extends RefCounted
## The native painter's draws of single tiles, for rule checks in tests.


# the draws of the tile in painter order. each draw has its sprite, mirror,
# position and size
static func of(city: CityState, sprites: Sc2SpriteArchive, view: int, x: int, y: int,
		mode := CityViewMode.Mode.CITY, pipes := true, subways := true, mains := true) -> Array[CityGpuDrawList.Draw]:
	var context := CityGpuBuildContext.new()
	var failure := context.prepare(city, Sc2Palette.index_encoding(), sprites, view, mode, pipes, subways, mains, 0, false)
	assert(failure.is_empty(), failure)

	return context.tile_draw_list([Vector2i(x, y)]).draws


# the sprite IDs of the tile's draws
static func sprite_ids(city: CityState, sprites: Sc2SpriteArchive, view: int, x: int, y: int,
		mode := CityViewMode.Mode.CITY, pipes := true, subways := true, mains := true) -> PackedInt32Array:
	var ids := PackedInt32Array()

	for draw in of(city, sprites, view, x, y, mode, pipes, subways, mains):
		ids.append(draw.sprite_id)

	return ids
