class_name FacilityRecordRepair
extends RefCounted
# Repair SC2X facility records on activation. Parsing and simulation snapshots keep the saved bytes.

@warning_ignore_start("integer_division")

const Facilities = preload("res://src/model/facility_metadata.gd")


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

	for x in edge:
		for y in edge:
			var tile := int(city.buildings[x * edge + y])
			var kind := int(Facilities.MICROSIM_TYPE_BY_TILE.get(tile, 0))

			if kind == 0:
				continue

			var area := DemolishStructures.structure_area(tile)
			var site := Rect2i(x, y, area, area)

			if site.end.x > edge or site.end.y > edge:
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
					var id := OverlayData.read(text, target) if target >= 0 else (
						ThingData.read(things, -target - 1) if target != -1 else -1
					)

					if OverlayData.is_facility(id):
						var record := OverlayData.facility_record(id)
						var saved_tile := int(microsims[record * 8]) if record < city.microsim_count() else 0
						has_record = has_record or saved_tile == tile or (
							kind > 16 and saved_tile != BuildingTileIds.EMPTY and record == kind - 16
						)

					if id != 0:
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

				if next_free == city.microsim_count():
					result.unfilled += 1
					continue

				record = next_free
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
					microsims, labels, text, tile, city.current_year(), random, misc
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
