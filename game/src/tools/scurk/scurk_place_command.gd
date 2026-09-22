class_name ScurkPlaceCommand
extends RefCounted

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const Facilities = preload("res://src/model/facility_metadata.gd")

const Buildings = preload("res://src/tools/city/building_command.gd")
const PickCopy = preload("res://src/tools/scurk/scurk_pick_copy.gd")

const ROAD_FIRST := Tiles.FIRST_ROAD
const RADIOACTIVITY := Tiles.RADIOACTIVE_WASTE
const SMALL_PARK := Buildings.SMALL_PARK
const BIG_PARK := Buildings.BIG_PARK
const HYDRO_DAM_FIRST := Buildings.HYDRO_POWER_1
const HYDRO_DAM_LAST := Buildings.HYDRO_POWER_2
const MARINA := Buildings.MARINA
const STATUE := Buildings.STATUE
const WATER_PUMP := Buildings.WATER_PUMP
const SUBWAY_STATION := Buildings.SUBWAY_STATION
const FLAG_WATER := Sc2TileFlags.WATER
const FLAG_PIPED := Sc2TileFlags.PIPED
const FLAG_POWERED := Sc2TileFlags.POWERED
const FLAG_POWERABLE := Sc2TileFlags.POWERABLE
const STRUCTURE_FLAGS := Sc2TileFlags.STRUCTURE_MASK

const BUDGET_CATEGORY_BY_TILE := Facilities.BUDGET_CATEGORY_BY_TILE

const VARIABLE_ZONE_TILES := {
	Tiles.CONSTRUCTION_1X1_FIRST: 1,
	Tiles.CONSTRUCTION_1X1_LAST: 1,
	Tiles.ABANDONED_1X1_FIRST: 2,
	Tiles.DEVELOPED_1X1_LAST: 2,
	Tiles.CONSTRUCTION_2X2_FIRST: 2,
	Tiles.CONSTRUCTION_2X2_2: 2,
	Tiles.CONSTRUCTION_2X2_DENSE_FIRST: 2,
	Tiles.CONSTRUCTION_2X2_LAST: 2,
	Tiles.ABANDONED_2X2_FIRST: 2,
	Tiles.ABANDONED_2X2_2: 2,
	Tiles.ABANDONED_2X2_DENSE_FIRST: 2,
	Tiles.DEVELOPED_2X2_LAST: 1,
	Tiles.CONSTRUCTION_3X3_FIRST: 2,
	Tiles.CONSTRUCTION_3X3_LAST: 2,
	Tiles.ABANDONED_3X3_FIRST: 1,
	Tiles.DEVELOPED_3X3_LAST: 1,
}


static func placeable_large_ids(group: int) -> PackedInt32Array:
	var result := PackedInt32Array()

	if group == PickCopy.GROUP_ALL:
		for tile_id in 500:
			result.append(1000 + tile_id)

		return result

	result = PickCopy.group_large_ids(group)

	if group == 5:
		for tile_id in range(Tiles.POWER_LINE_FIRST, Tiles.DEVELOPED_FIRST):
			result.append(1000 + tile_id)

	return result


static func is_placeable_tile(tile_id: int) -> bool:
	return tile_id >= 0 and tile_id < 500


static func footprint(tile_id: int, selected: Vector2i) -> Rect2i:
	if not is_placeable_tile(tile_id):
		return Rect2i()

	return BuildingSites.footprint(selected, DemolishStructures.structure_area(tile_id) if tile_id <= Tiles.MAX_ID else 1)


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

	var area := DemolishStructures.structure_area(tile_id)
	var site := BuildingSites.footprint(selected, area)

	if not BuildingSites._footprint_is_in_bounds(site, area, map_edge):
		return EditCommandResult.failure("object does not fit inside the map")

	var old_payloads := BuildingState._city_payloads(city)

	if old_payloads.is_empty():
		return EditCommandResult.failure("required city data is missing or invalid")

	var changed_payloads := BuildingState._duplicate_payloads(old_payloads)
	var buildings: PackedByteArray = changed_payloads.XBLD
	var terrain: PackedByteArray = changed_payloads.XTER
	var zones: PackedByteArray = changed_payloads.XZON
	var flags: PackedByteArray = changed_payloads.XBIT
	var underground: PackedByteArray = changed_payloads.XUND
	var text_overlays: PackedByteArray = changed_payloads.XTXT
	var labels: PackedByteArray = changed_payloads.XLAB
	var microsims: PackedByteArray = changed_payloads.XMIC
	var misc: PackedByteArray = changed_payloads.MISC

	var site_error := _site_error(buildings, terrain, flags, site, tile_id, map_edge)

	if not site_error.is_empty():
		return EditCommandResult.failure(site_error)

	var process_random_state_before := process_random.state
	var overlay_id := BuildingFacilities.provision_microsim(
		microsims,
		labels,
		text_overlays,
		tile_id,
		city.current_year(),
		process_random,
		misc,
		australian_locale,
		true
	)
	var zone_id := _zone_for_tile(tile_id, zones, site, selected_zone, map_edge)
	var placed_flags := (
		FLAG_PIPED if tile_id == SMALL_PARK or tile_id == BIG_PARK else STRUCTURE_FLAGS
	)

	if tile_id < Tiles.DEVELOPED_FIRST:
		placed_flags = FLAG_POWERABLE if tile_id >= Tiles.POWER_LINE_FIRST else 0

	var tile_indices := PackedInt32Array()

	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			var index := x * map_edge + y
			NetworkState.replace_building(buildings, zones, misc, index, tile_id)
			zones[index] = zone_id
			flags[index] = (flags[index] & ~STRUCTURE_FLAGS) | placed_flags

			if overlay_id != 0:
				OverlayData.write(text_overlays, index, overlay_id)

			tile_indices.append(index)

	BuildingSites.set_corners(zones, site, area, city.compass_rotation(), map_edge)

	if tile_id == STATUE:
		flags[selected.x * map_edge + selected.y] &= ~FLAG_POWERABLE & 0xff
	elif tile_id == WATER_PUMP:
		BuildingUnderground._place_pipe(underground, terrain, zones, flags, misc, selected, map_edge)
	elif tile_id == SUBWAY_STATION:
		BuildingUnderground._place_subway_station(underground, terrain, zones, flags, misc, selected, map_edge)

	if BUDGET_CATEGORY_BY_TILE.has(tile_id):
		var budget_offset: int = (
			Buildings.MISC_BUDGETS
			+ int(BUDGET_CATEGORY_BY_TILE[tile_id]) * Buildings.BUDGET_RECORD_SIZE
		)
		BuildingState._write_u32_be(
			misc,
			budget_offset,
			BuildingState.read_u32_be(misc, budget_offset) + 1
		)

	var changed_ids := PackedStringArray()

	for chunk_id in ["XBLD", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	if not BuildingState._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		process_random.state = process_random_state_before

		return EditCommandResult.failure("cannot store Place & Print changes")

	var result := ScurkPlaceResult.new()
	result.ok = true
	result.command_type = "scurk_place_object"
	result.scurk_place_history = true
	result.tile_id = tile_id
	result.area = area
	result.site = site
	result.tile_indices = tile_indices
	result.zone_id = zone_id
	result.overlay_id = overlay_id
	result.changed_ids = changed_ids
	result.old_payloads = old_payloads
	result.new_payloads = changed_payloads
	result.tracks_random = true
	result.random_state_before = process_random_state_before
	result.random_state_after = process_random.state
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


static func _site_error(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	flags: PackedByteArray,
	site: Rect2i,
	tile_id: int,
	map_edge: int = 128,
) -> String:
	var marina_water_tiles := 0

	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			var index := x * map_edge + y
			var old_building := int(buildings[index])

			if (
				old_building >= ROAD_FIRST
				or old_building == RADIOACTIVITY
				or old_building == SMALL_PARK
			):
				return "site contains a protected tile"

			if tile_id == SMALL_PARK and old_building > Tiles.TREES_7:
				return "site contains a protected tile"

			var is_water := (flags[index] & FLAG_WATER) != 0

			if tile_id == MARINA:
				if is_water:
					marina_water_tiles += 1
			elif tile_id >= HYDRO_DAM_FIRST and tile_id <= HYDRO_DAM_LAST:
				if terrain[index] == TerrainTileIds.FLAT or not is_water:
					return "hydroelectric dam requires water terrain"
			elif tile_id >= Tiles.DEVELOPED_FIRST and (terrain[index] != TerrainTileIds.FLAT or is_water):
				return "site is not flat clear land"

	if tile_id == MARINA and (
		marina_water_tiles == 0
		or marina_water_tiles == site.size.x * site.size.y
	):
		return "marina must span land and water"

	return ""


static func _zone_for_tile(
	tile_id: int, zones: PackedByteArray, site: Rect2i, selected_zone: int,
	map_edge: int = 128,
) -> int:
	if VARIABLE_ZONE_TILES.has(tile_id):
		var result := (
			selected_zone
			if selected_zone >= 1 and selected_zone <= 9
			else int(VARIABLE_ZONE_TILES[tile_id])
		)

		for x in range(site.position.x, site.end.x):
			for y in range(site.position.y, site.end.y):
				var existing_zone := zones[x * map_edge + y] & 0x0f

				if existing_zone != 0:
					result = existing_zone

		return result

	if tile_id >= Tiles.DEVELOPED_FIRST and tile_id <= Tiles.RESIDENTIAL_1X1_LAST:
		return 1

	if tile_id >= Tiles.RESIDENTIAL_2X2_FIRST and tile_id <= Tiles.RESIDENTIAL_2X2_LAST or tile_id >= Tiles.RESIDENTIAL_3X3_FIRST and tile_id <= Tiles.RESIDENTIAL_3X3_LAST:
		return 2

	if tile_id >= Tiles.COMMERCIAL_1X1_FIRST and tile_id <= Tiles.COMMERCIAL_1X1_LAST:
		return 3

	if tile_id >= Tiles.COMMERCIAL_2X2_FIRST and tile_id <= Tiles.COMMERCIAL_2X2_LAST or tile_id >= Tiles.COMMERCIAL_3X3_FIRST and tile_id <= Tiles.COMMERCIAL_3X3_LAST:
		return 4

	if tile_id >= Tiles.INDUSTRIAL_1X1_FIRST and tile_id <= Tiles.INDUSTRIAL_1X1_LAST or tile_id >= Tiles.FACTORY_2X2_5 and tile_id <= Tiles.INDUSTRIAL_2X2_LAST:
		return 5

	if tile_id >= Tiles.INDUSTRIAL_2X2_FIRST and tile_id <= Tiles.FACTORY_2X2_4 or tile_id >= Tiles.INDUSTRIAL_3X3_FIRST and tile_id <= Tiles.INDUSTRIAL_3X3_LAST:
		return 6

	if tile_id in [Tiles.CONTROL_TOWER_2, Tiles.FIGHTER_JET, Tiles.PARKING_LOT_2, Tiles.TOP_SECRET, Tiles.MISSILE_SILO]:
		return 7

	if tile_id in [Tiles.CONTROL_TOWER_1, Tiles.AIRPORT_BUILDING_1, Tiles.AIRPORT_BUILDING_2, Tiles.TARMAC, Tiles.HANGAR_1, Tiles.RADAR, Tiles.PARKING_LOT_1, Tiles.HANGAR_2]:
		return 8

	if tile_id in [Tiles.CRANE, Tiles.LOADING_BAY, Tiles.CARGO_YARD]:
		return 9

	return 0


static func _group_is_placeable(group: int) -> bool:
	return (
		group >= 0
		and group < PickCopy.GROUP_TILE_IDS.size()
		and group != PickCopy.GROUP_ANIMATING_I
		and group != PickCopy.GROUP_ANIMATING_II
	)
