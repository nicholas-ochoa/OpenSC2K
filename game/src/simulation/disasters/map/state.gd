class_name DisasterMapState
extends DisasterMapConstants


static func _collapse_structure(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	_tile: int,
	random: SimRandom,
	lfsr_random: SimLfsrRandom
) -> void:
	DisasterMapDamage.burn_structure(
		city,
		payloads.ALTM,
		payloads.XBLD,
		payloads.XTER,
		payloads.XZON,
		payloads.XUND,
		payloads.XBIT,
		payloads.XTXT,
		payloads.XLAB,
		payloads.XMIC,
		payloads.MISC,
		point,
		random,
		lfsr_random
	)


static func _building_site(
	city: CityState, payloads: Dictionary, point: Vector2i, tile: int
) -> Rect2i:
	var map_edge: int = city.map_size if city != null else 128
	var area: int = DemolishEffectsSites._building_area(tile)

	return DemolishEffectsSites._find_building_site(
		payloads.XBLD, payloads.XZON, point, tile, area, city.compass_rotation(), map_edge
	)


static func _place_toxic_marker(text: PackedByteArray, point: Vector2i, map_edge: int = 128) -> bool:
	var index := _index(point, map_edge)

	if index < 0 or (OverlayData.read(text, index) != 0 and not OverlayData.is_sign(OverlayData.read(text, index))):
		return false

	OverlayData.write(text, index, TOXIC_OVERLAY)

	return true


static func _clear_riot_marker(text: PackedByteArray, point: Vector2i, map_edge: int = 128) -> bool:
	var index := _index(point, map_edge)

	if index < 0:
		return false

	var marker := int(OverlayData.read(text, index))

	if marker != RIOT_OVERLAY_FORWARD and marker != RIOT_OVERLAY_REVERSE:
		return false

	OverlayData.write(text, index, 0)

	return true


static func _seed_special_toxic(
	payloads: Dictionary, site: Rect2i, point: Vector2i,
	map_edge: int = 128,
) -> int:
	if site.size == Vector2i.ZERO:
		site = Rect2i(point, Vector2i.ONE)

	var changed := 0

	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			var index := x * map_edge + y

			if OverlayData.read(payloads.XTXT, index) < 51:
				OverlayData.write(payloads.XTXT, index, TOXIC_OVERLAY)
				changed += 1

	return changed


static func _spawn_explosion(
	text: PackedByteArray,
	things: PackedByteArray,
	point: Vector2i,
	height: int,
	state: int,
	goal: int,
	map_edge: int = 128,
) -> bool:
	var index := _index(point, map_edge)

	if index < 0 or OverlayData.blocks_thing(OverlayData.read(text, index)):
		return false

	var record := 0

	for checked_record in range(1, ThingData.count(things)):
		if ThingData.read(things, checked_record * CityState.THING_RECORD_SIZE) == 0:
			record = checked_record
			break

	if record == 0:
		return false

	var offset := record * CityState.THING_RECORD_SIZE
	ThingData.write(things, offset, TYPE_EXPLOSION)
	ThingData.write(things, offset + 1, 0)
	ThingData.write(things, offset + 2, state)
	ThingData.write(things, offset + 3, point.x)
	ThingData.write(things, offset + 4, point.y)
	ThingData.write(things, offset + 5, height)
	ThingData.write(things, offset + 6, 8)
	ThingData.write(things, offset + 7, 8)
	ThingData.write(things, offset + 10, OverlayData.read(text, index))
	ThingData.write(things, offset + 11, goal)
	OverlayData.write(text, index, OverlayData.thing_id(record))

	return true


static func _map_payloads(city: CityState) -> Dictionary[String, PackedByteArray]:
	var result: Dictionary[String, PackedByteArray] = {}

	for chunk_id in MAP_CHUNK_SIZES:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or chunk.decoded_payload.size() != city.document.decoded_size(chunk_id):
			return {}

		result[chunk_id] = chunk.decoded_payload.duplicate()

	return result


static func _duplicate_payloads(payloads: Dictionary) -> Dictionary[String, PackedByteArray]:
	var result: Dictionary[String, PackedByteArray] = {}

	for chunk_id in payloads:
		result[chunk_id] = payloads[chunk_id].duplicate()

	return result


static func _payloads_changed(original: Dictionary, payloads: Dictionary) -> bool:
	for chunk_id in MAP_CHUNK_SIZES:
		if payloads[chunk_id] != original[chunk_id]:
			return true

	return false


static func _apply_map_payloads(
	city: CityState, original: Dictionary, payloads: Dictionary
) -> bool:
	var applied := PackedStringArray()

	for chunk_id in MAP_CHUNK_SIZES:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		if payloads[chunk_id] == original[chunk_id]:
			continue

		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not chunk.set_decoded_payload(payloads[chunk_id]):
			for rollback_id in applied:
				city.document.find_chunk(rollback_id).set_decoded_payload(original[rollback_id])

			city.resync_mirrors(CityState.MIRRORED_CHUNKS)

			return false

		applied.append(chunk_id)

	city.resync_mirrors(CityState.MIRRORED_CHUNKS)

	return true


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	if point.x < 0 or point.y < 0 or point.x >= map_edge or point.y >= map_edge:
		return -1

	return point.x * map_edge + point.y


static func _altitude_word(altitude: PackedByteArray, index: int) -> int:
	return (altitude[index * 2] << 8) | altitude[index * 2 + 1]
