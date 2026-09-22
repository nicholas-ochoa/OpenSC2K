extends SceneTree

const ROAD := [29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 63, 64, 65, 66, 67, 68, 69, 70, 75, 76, 93, 94, 95, 96]
const RAIL := [44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 69, 70, 71, 72, 77, 78, 108, 109, 110, 111]
const SUBWAY := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 31, 32, 34, 35]


func _initialize() -> void:
	for tile in 256:
		assert(NetworkTileMembership.surface_road(tile) == (tile in ROAD))
		assert(NetworkTileMembership.rail(tile) == (tile in RAIL))
		assert(NetworkTileMembership.subway(tile) == (tile in SUBWAY))
	print("PASS: network membership for all byte tile IDs")
	quit()
