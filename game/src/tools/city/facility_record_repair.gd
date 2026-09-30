class_name FacilityRecordRepair
extends RefCounted


# Repair SC2X facility records on activation. Parsing and simulation snapshots keep the saved bytes.

@warning_ignore_start("integer_division")

const Facilities = preload("res://src/model/facility_metadata.gd")


# ascending indices of every tile that holds a facility building
static func _facility_tiles(buildings: PackedByteArray) -> PackedInt32Array:
	var result := PackedInt32Array()

	for tile: int in Facilities.MICROSIM_TYPE_BY_TILE:
		var index := buildings.find(tile)

		while index >= 0:
			result.append(index)
			index = buildings.find(tile, index + 1)

	result.sort()

	return result


static func apply(city: CityState) -> Result:
	var result := Result.new()
	result.ok = true

	if city == null or not city.is_valid() or not city.document.is_extended():
		return result

	var document := city.document

	for id in ["XMIC", "XLAB", "XTHG", "MISC"]:
		var chunk := document.find_chunk(id)

		if chunk == null or chunk.decoded_payload.size() != document.decoded_size(id):
			return Result.failure("Cannot repair facility records: %s is missing or invalid." % id)

	var microsims := document.find_chunk("XMIC").decoded_payload.duplicate()
	var labels := document.find_chunk("XLAB").decoded_payload.duplicate()
	var things := document.find_chunk("XTHG").decoded_payload.duplicate()
	var text := city.text_overlays.duplicate()
	var misc := document.find_chunk("MISC").decoded_payload
	# local deterministic initialization must not consume the simulation rng
	var random := SimRandom.new(1)
	var rebuilt_shared: Dictionary[int, bool] = {}
	var edge := city.map_size
	var next_free := BuildingCommand.MICROSIM_DYNAMIC_FIRST
	# an sc2x version 4 city keeps its record budget during repair too
	var record_budget := BuildingFacilities.individual_record_budget(document)
	var active_records := BuildingFacilities.active_individual_records(microsims)

	# visit only facility tiles, in the original column-major order. a native
	# byte search finds them; a 4096-tile map has 16.7 million tiles
	for origin in _facility_tiles(city.buildings):
		var x := origin / edge
		var y := origin % edge
		var tile := int(city.buildings[origin])
		var kind := int(Facilities.MICROSIM_TYPE_BY_TILE[tile])

		var area := DemolishStructures.structure_area(tile)
		var site := Rect2i(x, y, area, area)

		if site.end.x > edge or site.end.y > edge:
			continue

		# the origin of a larger building carries its first corner flag. this
		# cheap test gives the same result as the full site match below
		if area > 1 and (city.zones[origin] & Sc2ZoneLayout.CORNERS_MASK) != Sc2ZoneLayout.CORNER_BOTTOM_LEFT[
				city.compass_rotation() & 3]:
			continue

		if area > 1 and not DemolishEffectsSites._site_matches(
			city.buildings, city.zones, site, tile, city.compass_rotation(), edge
		):
			continue

		var targets := PackedInt32Array()
		var has_record := false
		var blocked := false

		for sx in range(x, site.end.x):
			for sy in range(y, site.end.y):
				var index := sx * edge + sy
				var target := _overlay_target(text, things, index, edge)
				var existing_id := OverlayData.read(text, target) if target >= 0 else (
					ThingData.read(things, -target - 1) if target != -1 else -1
				)

				# a layered index: the facility layer, else a marker, blocks
				if OverlayData.is_layered(text):
					existing_id = OverlayData.facility(text, index)
					existing_id = existing_id if existing_id != 0 else OverlayData.marker(text, index)

				if OverlayData.is_facility(existing_id):
					var existing_record := OverlayData.facility_record(existing_id)
					var saved_tile := int(microsims[existing_record * 8]) if existing_record < city.microsim_count() else 0
					has_record = has_record or saved_tile == tile or (
						kind > 16 and saved_tile != BuildingTileIds.EMPTY and existing_record == kind - 16
					)

				if existing_id != 0:
					blocked = true
				else:
					targets.append(target)

		# preserve existing links, signs, disaster markers, and ambiguous data
		if has_record or blocked:
			continue

		var record := kind - 16
		var initialize := kind <= 16

		if kind <= 16:
			while next_free < city.microsim_count() and microsims[next_free * 8] != 0:
				next_free += 1

			if next_free == city.microsim_count() or (record_budget >= 0 and active_records >= record_budget):
				result.unfilled += 1
				continue

			record = next_free
			active_records += 1
		else:
			if microsims[record * 8] == 0:
				rebuilt_shared[record] = true

				for field in CityState.MICROSIM_RECORD_SIZE:
					microsims[record * 8 + field] = 0

			initialize = rebuilt_shared.has(record)

		var id := OverlayData.facility_id(record)

		if initialize:
			if microsims[record * 8] == 0:
				result.created += 1

			BuildingFacilities.provision_microsim(
				microsims, labels, text, tile, city.current_year(), random, misc, false, false, -1, next_free
			)

		for target in targets:
			if target >= 0:
				OverlayData.write(text, target, id)
			else:
				ThingData.write(things, -target - 1, id)

		result.linked += 1

	if result.linked > 0:
		for update in [["XMIC", microsims], ["XLAB", labels], ["XTHG", things]]:
			var chunk := document.find_chunk(update[0])

			if chunk.decoded_payload != update[1]:
				chunk.set_decoded_payload(update[1])

		if city.text_overlays != text:
			city.replace_text_overlays(text)

	return result


static func _overlay_target(
	text: PackedByteArray, things: PackedByteArray, index: int, edge: int
) -> int:
	var id := OverlayData.read(text, index)

	if not OverlayData.is_thing(id) or OverlayData.is_layered(text):
		return index

	var target := index
	var visited: Dictionary[int, bool] = {}

	while OverlayData.is_thing(id):
		var record := OverlayData.thing_record(id)

		if record <= 0 or record >= ThingData.count(things) or visited.has(record):
			return -1

		visited[record] = true
		var offset := record * 12

		if ThingData.read(things, offset) == 0 or (
			ThingData.read(things, offset + 3) != index / edge
			or ThingData.read(things, offset + 4) != index % edge
		):
			return -1

		target = -(offset + 10) - 1
		id = ThingData.read(things, offset + 10)

	return target


class Result extends RefCounted:
	var ok := false
	var error := ""
	var created := 0
	var linked := 0
	var unfilled := 0

	static func failure(message: String) -> Result:
		var result := Result.new()
		result.error = message

		return result
