class_name CityRecords
extends RefCounted
# Read names, labels, facility records, moving objects, graphs, and facility sites.

@warning_ignore_start("integer_division")


static func city_name(city: CityState) -> String:
	return city.document.city_name()


static func display_name(city: CityState) -> String:
	var name := city.city_name()

	if name.is_empty():
		name = city.document.source_path.get_file().get_basename()

	return name if not name.is_empty() else "New City"


static func mayor_name(city: CityState) -> String:
	return city.label(0)


# an sc2x version 4 working document keeps wide utf-8 records; see Sc2LabelLayout
static func label(city: CityState, label_id: int) -> String:
	var chunk := city.document.find_chunk("XLAB")

	if chunk == null or chunk.decoded_payload.size() != city.document.decoded_size("XLAB"):
		return ""

	return Sc2LabelLayout.read(chunk.decoded_payload, label_id)


static func sign_texts(city: CityState) -> Dictionary[int, String]:
	if CitySignTable.uses_table(city):
		return CitySignTable.texts_by_tile(city)

	var result: Dictionary[int, String] = {}

	for index in OverlayData.sign_indices(city.text_overlays):
		var text := label(city, OverlayData.read(city.text_overlays, index))

		if not text.is_empty():
			result[index] = text

	return result


static func set_label(city: CityState, label_id: int, value: String) -> bool:
	var chunk := city.document.find_chunk("XLAB")

	if chunk == null or chunk.decoded_payload.size() != city.document.decoded_size("XLAB"):
		return false

	var changed := chunk.decoded_payload.duplicate()

	if not Sc2LabelLayout.write(changed, label_id, value, false):
		return false

	return chunk.set_decoded_payload(changed)


static func microsim(city: CityState, microsim_id: int) -> Microsim:
	if microsim_id < 0 or microsim_id >= city.document.decoded_size("XMIC") / CityState.MICROSIM_RECORD_SIZE:
		return null

	var chunk := city.document.find_chunk("XMIC")

	if chunk == null:
		return null

	var offset := microsim_id * CityState.MICROSIM_RECORD_SIZE

	var result := Microsim.new()
	result.tile_id = int(chunk.decoded_payload[offset + Sc2MicrosimLayout.TILE_ID])
	result.stat_0 = int(chunk.decoded_payload[offset + Sc2MicrosimLayout.STAT_0])
	result.stat_1 = BinaryData.read_u16_be(chunk.decoded_payload, offset + Sc2MicrosimLayout.STAT_1)
	result.stat_2 = BinaryData.read_u16_be(chunk.decoded_payload, offset + Sc2MicrosimLayout.STAT_2)
	result.stat_3 = BinaryData.read_u16_be(chunk.decoded_payload, offset + Sc2MicrosimLayout.STAT_3)

	return result


# null for a record outside xthg
static func thing(city: CityState, thing_id: int) -> ThingRecord:
	var chunk := city.document.find_chunk("XTHG")

	if chunk == null or thing_id < 0 or thing_id >= ThingData.count(chunk.decoded_payload):
		return null

	return ThingRecord.read(chunk.decoded_payload, thing_id * CityState.THING_RECORD_SIZE)


static func graph_series(city: CityState, graph_id: int) -> GraphSeries:
	if graph_id < 0 or graph_id >= CityState.GRAPH_COUNT:
		return null

	var chunk := city.document.find_chunk("XGRP")

	if chunk == null:
		return null

	var values := PackedInt64Array()
	var offset := graph_id * Sc2GraphLayout.SERIES_SIZE

	for index in CityState.GRAPH_VALUE_COUNT:
		values.append(BinaryData.read_u32_be(chunk.decoded_payload, offset + index * Sc2GraphLayout.VALUE_SIZE))

	var result := GraphSeries.new()
	result.year = values.slice(Sc2GraphLayout.YEAR_OFFSET, Sc2GraphLayout.DECADE_OFFSET)
	result.decade = values.slice(Sc2GraphLayout.DECADE_OFFSET, Sc2GraphLayout.CENTURY_OFFSET)
	result.century = values.slice(Sc2GraphLayout.CENTURY_OFFSET, Sc2GraphLayout.VALUES_PER_SERIES)

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

	if key == city.microsim_site_cache_key:
		return city.microsim_site_cache

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

	city.microsim_site_cache = {}

	for record in records:
		var at := record * 5

		if bounds[at + 4] > 0:
			city.microsim_site_cache[record] = Site.new(bounds[at], bounds[at + 1], bounds[at + 2] - bounds[at] + 1,
				bounds[at + 3] - bounds[at + 1] + 1, bounds[at + 4])

	city.microsim_site_cache_key = key

	return city.microsim_site_cache


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
