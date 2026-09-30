class_name ScurkPlaceCommand
extends RefCounted

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const SpriteIds = preload("res://src/tools/scurk/scurk_sprite_ids.gd")
const PickCopy = preload("res://src/tools/scurk/scurk_pick_copy.gd")
# the chunks that a placement checks, in commit order
const PAYLOAD_IDS: PackedStringArray = ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]


static func placeable_large_ids(group: int) -> PackedInt32Array:
	var result := PackedInt32Array()

	if group == PickCopy.GROUP_ALL:
		for tile_id in SpriteIds.OBJECT_COUNT:
			result.append(SpriteIds.LARGE_FIRST + tile_id)

		return result

	result = PickCopy.group_large_ids(group)

	if group == PickCopy.GROUP_TRANSPORTATION:
		for tile_id in range(Tiles.POWER_LINE_FIRST, Tiles.DEVELOPED_FIRST):
			result.append(SpriteIds.LARGE_FIRST + tile_id)

	return result


static func is_placeable_tile(tile_id: int) -> bool:
	return tile_id >= 0 and tile_id < SpriteIds.OBJECT_COUNT


static func footprint(tile_id: int, selected: Vector2i) -> Rect2i:
	if not is_placeable_tile(tile_id):
		return Rect2i()

	return BuildingSites.footprint(selected, NativeCityTools.building_area(tile_id) if tile_id <= Tiles.MAX_ID else 1)


static func apply(
	city: CityState,
	tile_id: int,
	selected: Vector2i,
	process_random: SimRandom,
	selected_zone := 0,
	australian_locale := false
) -> EditCommandResult:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return EditCommandResult.failure("city is invalid")

	if not is_placeable_tile(tile_id):
		return EditCommandResult.failure("object is not available in Place & Print")

	if process_random == null:
		return EditCommandResult.failure("process random state is required")

	if tile_id > Tiles.MAX_ID:
		if selected.x < 0 or selected.y < 0 or selected.x >= map_edge or selected.y >= map_edge:
			return EditCommandResult.failure("object does not fit inside the map")

		var artwork := ScurkPlaceResult.new()
		artwork.ok = true
		artwork.command_type = "scurk_artwork"
		artwork.scurk_place_history = true
		artwork.old_stamps = ScurkArtworkStamp.copy_all(city.scurk_artwork_stamps)
		city.scurk_artwork_stamps.append(ScurkArtworkStamp.new(tile_id, selected))
		artwork.new_stamps = ScurkArtworkStamp.copy_all(city.scurk_artwork_stamps)

		return artwork

	var args := {
		"tile": tile_id,
		"point": selected,
		"selected_zone": selected_zone,
		"australian_locale": australian_locale,
	}
	var result: ScurkPlaceResult = NativeToolEdit.run("tool.scurk_place", city, args, PAYLOAD_IDS, process_random)

	if result.ok:
		result.retain_changed_payloads()

	return result


# undo any edit that scurk history owns
static func undo(
	city: CityState, command: EditCommandResult, process_random: SimRandom
) -> EditCommandResult:
	return _apply_history(city, command, process_random, false)


static func redo(
	city: CityState, command: EditCommandResult, process_random: SimRandom
) -> EditCommandResult:
	return _apply_history(city, command, process_random, true)


static func _apply_history(
	city: CityState,
	command: EditCommandResult,
	process_random: SimRandom,
	forward: bool
) -> EditCommandResult:
	if city == null or not city.is_valid():
		return EditCommandResult.failure("city is invalid")

	if not command.ok or not command.scurk_place_history:
		return EditCommandResult.failure("Place & Print command is invalid")

	if command.command_type == "scurk_artwork":
		var artwork := command as ScurkPlaceResult
		var expected := artwork.old_stamps if forward else artwork.new_stamps

		if not ScurkArtworkStamp.same_values(city.scurk_artwork_stamps, expected):
			return EditCommandResult.failure("artwork changed after this command")

		city.scurk_artwork_stamps = ScurkArtworkStamp.copy_all(artwork.new_stamps if forward else artwork.old_stamps)

		return EditCommandResult.undone(1)

	if command.tracks_random:
		if process_random == null:
			return EditCommandResult.failure("process random state is required")

		var expected_state := command.random_state_before if forward else command.random_state_after

		if process_random.state != expected_state:
			return EditCommandResult.failure(
				"process random state changed after this Place & Print command"
			)

	var changed_ids := command.changed_ids
	var source_payloads := command.old_payloads if forward else command.new_payloads
	var destination_payloads := command.new_payloads if forward else command.old_payloads

	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)

		if (
			chunk == null
			or not source_payloads.has(chunk_id)
			or chunk.decoded_payload != source_payloads[chunk_id]
		):
			return EditCommandResult.failure("city changed after this Place & Print command")

	if not BuildingState._apply_payloads(
		city, changed_ids, destination_payloads, source_payloads
	):
		return EditCommandResult.failure("cannot restore Place & Print changes")

	if command.tracks_random:
		process_random.state = command.random_state_after if forward else command.random_state_before

	return EditCommandResult.undone(maxi(command.tile_indices.size(), command.points.size()))


static func _group_is_placeable(group: int) -> bool:
	return (
		group >= 0
		and group < PickCopy.GROUP_TILE_IDS.size()
		and group != PickCopy.GROUP_ANIMATING_I
		and group != PickCopy.GROUP_ANIMATING_II
	)
