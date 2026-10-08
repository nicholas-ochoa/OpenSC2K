class_name CityLightFade
extends RefCounted
## One presentation clock and first-visible timestamps shared by all artwork sizes.

const DURATION := 0.65
var clock := 0.0
var starts: Dictionary[Vector2i, float] = {}


func reset() -> void:
	clock = 0.0
	starts.clear()


func advance(elapsed: float) -> void:
	clock += maxf(elapsed, 0.0)


func birth(tile: Vector2i, edge: int, rotation: int) -> float:
	# Saved arrays rotate with the map. Keep the first-visible record in the
	# original orientation so rotating or switching artwork never restarts it.
	for turn in posmod(rotation, 4):
		tile = Vector2i(edge - 1 - tile.y, tile.x)
	if not starts.has(tile):
		starts[tile] = clock
	return starts[tile]
