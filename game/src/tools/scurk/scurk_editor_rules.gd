class_name ScurkEditorRules
extends RefCounted

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const VIEW_LARGE := 0
const VIEW_MEDIUM := 1
const VIEW_SMALL := 2


static func editable_large_sprite_ids(
	value: ScurkMif, base_large: Sc2SpriteArchive = null
) -> PackedInt32Array:
	var ids := PackedInt32Array()

	if value == null or not value.is_valid():
		return ids

	var seen := {}

	if base_large != null and base_large.is_valid():
		for entry in base_large.entries:
			if (
				entry.sprite_id < 1000
				or entry.sprite_id > 1499
				or seen.has(entry.sprite_id)
			):
				continue

			seen[entry.sprite_id] = true
			ids.append(entry.sprite_id)

	for entry in value.shapes:
		if (
			entry.sprite_id < 1000
			or entry.sprite_id > 1499
			or seen.has(entry.sprite_id)
		):
			continue

		seen[entry.sprite_id] = true
		ids.append(entry.sprite_id)

	ids.sort()

	return ids


static func view_sprite_id(large_sprite_id: int, view: int) -> int:
	if large_sprite_id < 1000 or large_sprite_id > 1499:
		return -1

	match view:
		VIEW_LARGE:
			return large_sprite_id
		VIEW_MEDIUM:
			return large_sprite_id - 500
		VIEW_SMALL:
			return large_sprite_id - 1000
		_:
			return -1


static func object_tile_id(large_sprite_id: int) -> int:
	return large_sprite_id - 1000 if large_sprite_id in range(1000, 1500) else -1


static func path_is_within(path: String, directory: String) -> bool:
	if path.is_empty() or directory.is_empty():
		return false

	var target := ProjectSettings.globalize_path(path).simplify_path()
	var root := ProjectSettings.globalize_path(directory).simplify_path().trim_suffix("/")

	return target == root or target.begins_with(root + "/")


static func sprite_role(tile_id: int) -> String:
	if tile_id >= Tiles.POWER_LINE_STRAIGHT_1 and tile_id <= Tiles.POWER_LINE_CROSSROADS:
		return "Power-line tile"

	if tile_id >= Tiles.ROAD_STRAIGHT_1 and tile_id <= Tiles.ROAD_CROSSROADS:
		return "Road tile"

	if tile_id >= Tiles.RAIL_STRAIGHT_1 and tile_id <= Tiles.RAIL_SLOPE_8:
		return "Rail tile"

	if tile_id >= Tiles.TUNNEL_ENTRANCE_1 and tile_id <= Tiles.RAIL_SUBWAY_ENTRANCE_4:
		return "Network crossing or bridge tile"

	if tile_id >= Tiles.RUBBLE_FIRST and tile_id <= Tiles.SMALL_PARK:
		return "Landscape tile"

	if tile_id >= Tiles.DEVELOPED_FIRST and tile_id <= Tiles.LLAMA_DOME:
		return "Building or zone tile"

	if tile_id >= 0x100 and tile_id <= 0x122:
		return "Terrain sprite"

	if (
		(tile_id >= 0x131 and tile_id <= 0x190)
		or (tile_id >= 0x1c2 and tile_id <= 0x1d3)
	):
		return "Underground pipe or subway sprite"

	if tile_id >= 0x167 and tile_id <= 0x1f3:
		return "Traffic, moving-object, or effect sprite"

	return "City support sprite"
