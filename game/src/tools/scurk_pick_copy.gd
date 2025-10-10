class_name ScurkPickCopy
extends RefCounted

const GROUP_RESIDENTIAL := 0
const GROUP_COMMERCIAL := 1
const GROUP_INDUSTRIAL := 2
const GROUP_SPECIAL := 3
const GROUP_POWER := 4
const GROUP_TRANSPORTATION := 5
const GROUP_MISC := 6
const GROUP_ANIMATING_I := 7
const GROUP_ANIMATING_II := 8
const GROUP_CONSTRUCTION := 9
const GROUP_ALL := 10

const GROUP_NAMES := [
	"Residential",
	"Commercial",
	"Industrial",
	"Special",
	"Power",
	"Transportation",
	"Misc",
	"Animating I",
	"Animating II",
	"Construction",
	"All",
]

# original.mif stores these objects in group order. each value is an eight-bit
# city tile id. add 1000 to select its large-view sprite
const GROUP_TILE_IDS := [
	[
		174, 175, 176, 177, 140, 141, 142, 143, 144, 145, 146, 147,
		112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123,
	],
	[
		178, 180, 181, 182, 179, 183, 184, 185, 186, 187, 148, 149,
		151, 153, 150, 152, 154, 155, 156, 157, 124, 127, 125, 126,
		128, 129, 130, 131,
	],
	[
		188, 159, 189, 190, 191, 192, 193, 158, 160, 161, 162, 163,
		164, 165, 132, 134, 133, 135,
	],
	[
		251, 252, 253, 254, 255, 208, 209, 210, 211, 212, 213, 13,
		214, 215, 216, 217, 218, 219, 220, 244, 250, 243, 245, 247,
		235, 248,
	],
	[198, 199, 200, 201, 202, 203, 204, 205, 206, 207],
	[
		194, 195, 166, 167, 168, 169, 136, 137, 138, 139, 170, 171,
		172, 173, 196, 197, 233, 236, 237, 224, 240, 242,
	],
	[227, 221, 222, 225, 238, 230, 234, 232, 246, 228, 229, 226],
	[499, 498, 497, 496, 495, 494, 493, 399, 398, 397, 396, 395, 394, 393, 392],
	[387, 388, 389, 391, 390, 373, 372, 371, 370, 369, 363, 362, 361, 360, 359],
	[231, 239, 241, 249, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12, 5],
]


static func group_large_ids(group: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if group == GROUP_ALL:
		for group_index in GROUP_TILE_IDS.size():
			result.append_array(_large_ids_for_tiles(GROUP_TILE_IDS[group_index]))
		return result
	if group < 0 or group >= GROUP_TILE_IDS.size():
		return result
	return _large_ids_for_tiles(GROUP_TILE_IDS[group])


static func copy_objects(
	working: ScurkMif,
	source: ScurkMif,
	large_ids: PackedInt32Array,
	base_large: Sc2SpriteArchive,
	base_small_medium: Sc2SpriteArchive
) -> Dictionary:
	if working == null or not working.is_valid():
		return _failure("The working object set is invalid.")
	if source == null or not source.is_valid():
		return _failure("The source object set is invalid.")
	if source == working:
		return _failure("The source and working object sets must be different.")
	if base_large == null or not base_large.is_valid():
		return _failure("The original large sprites are not available.")
	if base_small_medium == null or not base_small_medium.is_valid():
		return _failure("The original small and medium sprites are not available.")

	var prepared: Array[Dictionary] = []
	var seen := {}
	for large_id in large_ids:
		if large_id < 1000 or large_id > 1499:
			return _failure("Object sprite %d is outside the SCURK range." % large_id)
		if seen.has(large_id):
			continue
		seen[large_id] = true
		for view in 3:
			var sprite_id := large_id - view * 500
			var entry := resolved_entry(
				source, sprite_id, base_large, base_small_medium
			)
			if entry == null:
				return _failure("Source sprite %d is missing." % sprite_id)
			var decoded := entry.decode_indices()
			if not decoded.ok:
				return _failure(decoded.error)
			prepared.append({
				"sprite_id": sprite_id,
				"width": entry.width,
				"height": entry.height,
				"pixels": decoded.pixels,
			})

	for shape in prepared:
		var changed := working.set_shape_indices(
			shape.sprite_id, shape.width, shape.height, shape.pixels
		)
		if not changed.ok:
			return _failure(changed.error)
	return {
		"ok": true,
		"error": "",
		"object_count": seen.size(),
		"shape_count": prepared.size(),
	}


static func resolved_entry(
	tile_set: ScurkMif,
	sprite_id: int,
	base_large: Sc2SpriteArchive,
	base_small_medium: Sc2SpriteArchive
) -> Sc2SpriteArchive.SpriteEntry:
	if tile_set == null:
		return null
	var entry := tile_set.overrides.find_sprite(sprite_id)
	if entry != null:
		return entry
	var base := base_large if sprite_id >= 1000 else base_small_medium
	entry = base.find_sprite(sprite_id) if base != null else null
	if entry != null:
		return entry
	return tile_set.archive.find_sprite(sprite_id)


static func _large_ids_for_tiles(tile_ids: Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	for tile_id in tile_ids:
		result.append(1000 + int(tile_id))
	return result


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
		"object_count": 0,
		"shape_count": 0,
	}
