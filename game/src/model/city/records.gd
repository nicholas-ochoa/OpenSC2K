class_name CityRecords
extends RefCounted
# Read names, labels, facility records, moving objects, graphs, and facility sites.

@warning_ignore_start("integer_division")


class Site extends RefCounted:
	var x: int
	var y: int
	var width: int
	var height: int
	var tiles: int

	func _init(left: int, top: int, columns: int, rows: int, tile_count := 0) -> void:
		x = left
		y = top
		width = columns
		height = rows
		tiles = tile_count


class Microsim extends RefCounted:
	var tile_id := BuildingTileIds.EMPTY
	var stat_0 := 0
	var stat_1 := 0
	var stat_2 := 0
	var stat_3 := 0

	func statistic(index: int) -> int:
		match index:
			0:
				return stat_0
			1:
				return stat_1
			2:
				return stat_2
			3:
				return stat_3

		return 0


class GraphSeries extends RefCounted:
	var year := PackedInt64Array()
	var decade := PackedInt64Array()
	var century := PackedInt64Array()

	func values_for_period(period: String) -> PackedInt64Array:
		match period:
			"year":
				return year
			"decade":
				return decade
			"century":
				return century

		return PackedInt64Array()


static func city_name(city: CityState) -> String:
	return city.document.city_name()


static func display_name(city: CityState) -> String:
	var name := city.city_name()

	if name.is_empty():
		name = city.document.source_path.get_file().get_basename()

	return name if not name.is_empty() else "New City"


static func mayor_name(city: CityState) -> String:
	return city.label(0)


static func label(city: CityState, label_id: int) -> String:
	if label_id < 0 or label_id >= city.document.decoded_size("XLAB") / CityState.LABEL_RECORD_SIZE:
		return ""

	var chunk := city.document.find_chunk("XLAB")

	if chunk == null:
		return ""

	var offset := label_id * CityState.LABEL_RECORD_SIZE
	var declared_length: int = mini(chunk.decoded_payload[offset], 23)
	var start := offset + 1
	var end := start

	while end < start + declared_length and chunk.decoded_payload[end] != 0:
		end += 1

	return chunk.decoded_payload.slice(start, end).get_string_from_ascii()


static func set_label(city: CityState, label_id: int, value: String) -> bool:
	if label_id < 0 or label_id >= city.document.decoded_size("XLAB") / CityState.LABEL_RECORD_SIZE:
		return false

	var chunk := city.document.find_chunk("XLAB")

	if chunk == null:
		return false

	var encoded := value.to_ascii_buffer()

	if encoded.size() > 23:
		encoded = encoded.slice(0, 23)

	var changed := chunk.decoded_payload.duplicate()
	var offset := label_id * CityState.LABEL_RECORD_SIZE
	changed[offset] = encoded.size()

	for index in encoded.size():
		changed[offset + 1 + index] = encoded[index]

	changed[offset + 1 + encoded.size()] = 0

	return chunk.set_decoded_payload(changed)


static func microsim(city: CityState, microsim_id: int) -> Microsim:
	if microsim_id < 0 or microsim_id >= city.document.decoded_size("XMIC") / CityState.MICROSIM_RECORD_SIZE:
		return null

	var chunk := city.document.find_chunk("XMIC")

	if chunk == null:
		return null

	var offset := microsim_id * CityState.MICROSIM_RECORD_SIZE

	var result := Microsim.new()
	result.tile_id = int(chunk.decoded_payload[offset])
	result.stat_0 = int(chunk.decoded_payload[offset + 1])
	result.stat_1 = city._read_u16_be(chunk.decoded_payload, offset + 2)
	result.stat_2 = city._read_u16_be(chunk.decoded_payload, offset + 4)
	result.stat_3 = city._read_u16_be(chunk.decoded_payload, offset + 6)

	return result


# null for a record outside xthg
static func thing(city: CityState, thing_id: int) -> ThingRecord:
	if thing_id < 0 or thing_id >= city.document.decoded_size("XTHG") / (24 if city.map_size > 128 else 12):
		return null

	var chunk := city.document.find_chunk("XTHG")

	if chunk == null:
		return null

	return ThingRecord.read(chunk.decoded_payload, thing_id * CityState.THING_RECORD_SIZE)


static func graph_series(city: CityState, graph_id: int) -> GraphSeries:
	if graph_id < 0 or graph_id >= CityState.GRAPH_COUNT:
		return null

	var chunk := city.document.find_chunk("XGRP")

	if chunk == null:
		return null

	var values := PackedInt64Array()
	var offset := graph_id * CityState.GRAPH_VALUE_COUNT * 4

	for index in CityState.GRAPH_VALUE_COUNT:
		values.append(city._read_u32_be(chunk.decoded_payload, offset + index * 4))

	var result := GraphSeries.new()
	result.year = values.slice(0, 12)
	result.decade = values.slice(12, 32)
	result.century = values.slice(32, 52)

	return result


static func thing_count(city: CityState) -> int:
	return ThingData.count(city.document.find_chunk("XTHG").decoded_payload)


static func microsim_count(city: CityState) -> int:
	return city.document.decoded_size("XMIC") / CityState.MICROSIM_RECORD_SIZE


# map footprint of one xmic record, or null when
# no tile links to it. xmic stores no position, so this is derived from xtxt,
# following moving things that temporarily cover a facility tile


static func microsim_site(city: CityState, microsim_id: int) -> Site:
	return city.microsim_sites().get(microsim_id)


static func microsim_sites(city: CityState) -> Dictionary[int, Site]:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id(),
		"CityState microsim site cache is main-thread only")
	var text := city.document.find_chunk("XTXT")
	var things := city.document.find_chunk("XTHG")
	var key := [text.get_instance_id(), text.mutation_revision,
		things.get_instance_id() if things != null else 0, things.mutation_revision if things != null else -1]

	if key == city._microsim_sites_key:
		return city._microsim_sites

	var overlays := text.decoded_payload
	var tile_count := city.map_size * city.map_size
	var wide := overlays.size() != tile_count
	var thing_data := things.decoded_payload if things != null else PackedByteArray()
	var thing_records := ThingData.count(thing_data)
	var records := city.microsim_count()
	# per record: min x, min y, max x, max y, tile count
	var bounds := PackedInt32Array()
	bounds.resize(records * 5)

	for index in tile_count:
		var id := int(overlays[index])

		if wide:
			id |= int(overlays[tile_count + index]) << 8

		if id < 51:
			continue

		var x := index / city.map_size
		var y := index % city.map_size
		var hops := 0

		while OverlayData.is_thing(id) and hops < thing_records:
			var offset := OverlayData.thing_record(id) * CityState.THING_RECORD_SIZE

			if offset <= 0 or offset >= thing_records * CityState.THING_RECORD_SIZE or (
				ThingData.read(thing_data, offset) == 0
				or ThingData.read(thing_data, offset + 3) != x or ThingData.read(thing_data, offset + 4) != y
			):
				break

			id = ThingData.read(thing_data, offset + 10)
			hops += 1

		if not OverlayData.is_facility(id):
			continue

		var record := OverlayData.facility_record(id)

		if record >= records:
			continue

		var at := record * 5

		if bounds[at + 4] == 0:
			bounds[at] = x
			bounds[at + 1] = y
			bounds[at + 2] = x
			bounds[at + 3] = y
		else:
			bounds[at] = mini(bounds[at], x)
			bounds[at + 1] = mini(bounds[at + 1], y)
			bounds[at + 2] = maxi(bounds[at + 2], x)
			bounds[at + 3] = maxi(bounds[at + 3], y)

		bounds[at + 4] += 1

	city._microsim_sites = {}

	for record in records:
		var at := record * 5

		if bounds[at + 4] > 0:
			city._microsim_sites[record] = Site.new(bounds[at], bounds[at + 1], bounds[at + 2] - bounds[at] + 1,
				bounds[at + 3] - bounds[at + 1] + 1, bounds[at + 4])

	city._microsim_sites_key = key

	return city._microsim_sites
