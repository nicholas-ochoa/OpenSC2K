extends SceneTree
## Repeat a city across a larger map and save it as an SC2X version 4 city:
## godot --headless --path game --script res://tools/tile_sc2x_city.gd -- \
##   --input=CITY --output=NEW.sc2x --edge=2048 [--name="City name"]
## The map edge must be a whole multiple of the source edge. Each copy of an
## individual facility gets its own record, signs repeat with new IDs, and
## moving objects stay in the first copy. The tool never replaces a file.

@warning_ignore_start("integer_division")


func _init() -> void:
	var options := {}

	for argument in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() == 2 else ""

	var error := _run(str(options.get("input", "")), str(options.get("output", "")), int(options.get("edge", "0")),
		str(options.get("name", "")))

	if not error.is_empty():
		push_error(error)

	quit(0 if error.is_empty() else 1)


func _run(input: String, output: String, edge: int, city_name: String) -> String:
	if input.is_empty() or output.is_empty() or FileAccess.file_exists(output):
		return "Give --input and a new --output file"

	var source := Sc2File.load_path(input)

	if not source.is_valid():
		return source.parse_error

	if not source.is_sc2x():
		var converted := Sc2xDocument.from_legacy(source, input.get_file().get_basename())

		if not converted.ok:
			return converted.error

		source = converted.document

	var result := tile(source, edge)

	if not result.ok:
		return result.error

	var document := result.document

	if not city_name.is_empty():
		document.set_city_name(city_name)

	var saved := CityFileStore.save_copy(document, output, "")

	if not saved.ok:
		return saved.error

	var reloaded := Sc2File.load_path(saved.path)
	var city := CityState.from_document(reloaded)

	if not city.is_valid():
		return "The tiled city does not load: %s" % city.load_error

	print("%s: %d by %d, %d copies of %s, %d bytes" % [
		saved.path, edge, edge, (edge / Sc2File.load_path(input).map_size) ** 2, input.get_file(), saved.data.size()])

	return ""


# A working document of `edge` tiles that repeats `source`.
static func tile(source: Sc2File, edge: int) -> Sc2xDocument.ConversionResult:
	var small := source.map_size

	if not source.is_sc2x() or edge not in Sc2File.MAP_SIZES or edge < small or edge % small != 0:
		return Sc2xDocument.ConversionResult.failure("The map edge must be a supported multiple of %d" % small)

	var copies := edge / small
	var document := source.duplicate_document()
	document.map_size = edge
	document.source_path = ""
	document.sc2x_converted_from = ""
	document.sc2x_metadata.map_size = edge
	document.sc2x_metadata.legacy = {}

	for id in Sc2xDocument.DENSE_ENTRIES:
		var width := 1 if id == "XTXT" else Sc2xDocument.DENSE_ENTRIES[id]
		var planes := OverlayData.LAYERED_PLANES if id == "XTXT" else 1
		var data := source.find_chunk(id).decoded_payload
		var tiled := PackedByteArray()

		# the layered tile index repeats each of its planes
		for plane in planes:
			var plane_data := data.slice(plane * small * small, (plane + 1) * small * small) if planes > 1 else data
			tiled.append_array(_tile_plane(plane_data, small, copies, width))

		_replace(document, id, tiled, edge)

	var records := _copy_facilities(source, document, copies)

	if records.has("error"):
		return Sc2xDocument.ConversionResult.failure(records.error)

	_copy_links(source, document, copies, records)
	_copy_signs(source, document, copies)
	var misc := document.find_chunk("MISC").decoded_payload.duplicate()
	var scale := copies * copies

	for slot in 256:
		var offset := Sc2MiscLayout.TILE_COUNTS + slot * 4
		BinaryData.write_u32_be(misc, offset, (BinaryData.read_u32_be(misc, offset) * scale) & 0xffffffff)

	for slot in 16:
		var offset := Sc2MiscLayout.MILITARY_TILE_COUNTS + slot * 4
		BinaryData.write_u32_be(misc, offset, (BinaryData.read_u32_be(misc, offset) * scale) & 0xffffffff)

	document.find_chunk("MISC").set_decoded_payload(misc)
	_trim_things(document)
	document.rebuild_chunk_cache()
	var result := Sc2xDocument.ConversionResult.new()
	result.ok = true
	result.document = document

	return result


# An imported moving-object table can be larger than the profile of the new
# map. Drop its empty slots past the profile, as a new city does.
static func _trim_things(document: Sc2File) -> void:
	var things := document.find_chunk("XTHG").decoded_payload
	var count := ThingData.count(things)
	var capacity := int(Sc2xDocument.profile(document.map_size).get("things", count))
	var half := things.size() / 2

	if capacity >= count or capacity * Sc2ThingLayout.EXTENDED_RECORD_SIZE == ThingData.BASE_SIZE:
		return

	for record in range(capacity, count):
		var low := things.slice(record * Sc2ThingLayout.RECORD_SIZE, (record + 1) * Sc2ThingLayout.RECORD_SIZE)
		var high := things.slice(half + record * Sc2ThingLayout.RECORD_SIZE, half + (record + 1) * Sc2ThingLayout.RECORD_SIZE)

		if low.count(0) != low.size() or high.count(0) != high.size():
			return

	var bytes := capacity * Sc2ThingLayout.RECORD_SIZE
	var trimmed := things.slice(0, bytes)
	trimmed.append_array(things.slice(half, half + bytes))
	_replace(document, "XTHG", trimmed, document.map_size)
	document.sc2x_object_ids.resize(capacity)
	document.sc2x_object_kinds.resize(capacity)
	document.sc2x_object_names.resize(capacity)


# column-major planes: each target column repeats one source column
static func _tile_plane(data: PackedByteArray, small: int, copies: int, width: int) -> PackedByteArray:
	var column_bytes := small * width
	var result := PackedByteArray()

	for column_copy in copies:
		for x in small:
			var column := data.slice(x * column_bytes, (x + 1) * column_bytes)

			for row_copy in copies:
				result.append_array(column)

	return result


static func _replace(document: Sc2File, id: String, data: PackedByteArray, edge: int) -> void:
	var chunk := document.find_chunk(id)
	chunk.expected_decoded_size = Sc2xDocument._fixed_size(id, edge, data)
	chunk.set_decoded_payload(data, true)


# Each copy after the first gets new records for the individual facilities.
# Returns {copy: {old record: new record}}, or {"error": message}.
static func _copy_facilities(source: Sc2File, document: Sc2File, copies: int) -> Dictionary:
	var old_records := source.find_chunk("XMIC").decoded_payload
	var individual := PackedInt32Array()

	for record in range(BuildingCommand.MICROSIM_DYNAMIC_FIRST, old_records.size() / 8):
		if old_records[record * 8] != 0:
			individual.append(record)

	var needed := individual.size() * copies + BuildingCommand.MICROSIM_DYNAMIC_FIRST
	var capacity := maxi(maxi(old_records.size() / 8, needed), int(Sc2xDocument.profile(document.map_size).get("facilities", 0)))
	var records := old_records.duplicate()
	records.resize(capacity * 8)
	var old_labels := source.find_chunk("XLAB").decoded_payload
	var labels := _wide_labels(OverlayData.facility_id(capacity - 1))

	for id in Sc2LabelLayout.record_count(old_labels):
		Sc2LabelLayout.write(labels, id, Sc2LabelLayout.read(old_labels, id))

	var result := {}
	var next := old_records.size() / 8

	for copy in range(1, copies * copies):
		var mapping := {}

		for record in individual:
			while next < capacity and records[next * 8] != 0:
				next += 1

			if next >= capacity:
				return {"error": "The facility table is full"}

			for byte in 8:
				records[next * 8 + byte] = old_records[record * 8 + byte]

			Sc2LabelLayout.write(labels, OverlayData.facility_id(next), Sc2LabelLayout.read(old_labels, OverlayData.facility_id(record)))
			mapping[record] = next
			next += 1

		result[copy] = mapping

	_replace(document, "XMIC", records, document.map_size)
	_replace(document, "XLAB", labels, document.map_size)

	return result


# a wide label table through `last_id`; see Sc2LabelLayout.is_wide_table
static func _wide_labels(last_id: int) -> PackedByteArray:
	var count := maxi(last_id, 0xff) + 1

	if (count * Sc2LabelLayout.WIDE_RECORD_SIZE) % Sc2LabelLayout.RECORD_SIZE == 0:
		count += 1

	var labels := PackedByteArray()
	labels.resize(count * Sc2LabelLayout.WIDE_RECORD_SIZE)

	return labels


# Repeated tiles of the layered index: individual facilities link their own
# record in each copy, and a moving object stays in the first copy only.
static func _copy_links(source: Sc2File, document: Sc2File, copies: int, records: Dictionary) -> void:
	var small := source.map_size
	var edge := document.map_size
	var old_text := source.find_chunk("XTXT").decoded_payload
	var text := document.find_chunk("XTXT").decoded_payload.duplicate()

	for index in small * small:
		var object := OverlayData.object(old_text, index)
		var facility := OverlayData.facility(old_text, index)
		var individual := (OverlayData.is_facility(facility)
			and OverlayData.facility_record(facility) >= BuildingCommand.MICROSIM_DYNAMIC_FIRST)

		if object == 0 and not individual:
			continue

		for copy in range(1, copies * copies):
			var target := (index / small + (copy / copies) * small) * edge + index % small + (copy % copies) * small

			if object != 0:
				OverlayData.set_object(text, target, 0)

			if individual:
				OverlayData.set_facility(text, target, OverlayData.facility_id(int(records[copy][OverlayData.facility_record(facility)])))

	document.find_chunk("XTXT").set_decoded_payload(text)


static func _copy_signs(source: Sc2File, document: Sc2File, copies: int) -> void:
	var table: Dictionary = NativeSc2x.decode_signs(source.find_chunk("XSGN").decoded_payload, source.map_size)
	var ids := PackedInt64Array()
	var xs := PackedInt32Array()
	var ys := PackedInt32Array()
	var texts := PackedStringArray()
	var next_id: int = document.sc2x_metadata.next_sign_id

	for copy in copies * copies:
		for slot in table.ids.size():
			if int(table.ids[slot]) == 0:
				continue

			ids.append(table.ids[slot] if copy == 0 else next_id)
			next_id += int(copy != 0)
			xs.append(int(table.xs[slot]) + (copy / copies) * source.map_size)
			ys.append(int(table.ys[slot]) + (copy % copies) * source.map_size)
			texts.append(table.texts[slot])

	var capacity := maxi(ids.size(), int(Sc2xDocument.profile(document.map_size).get("signs", 0)))

	while ids.size() < capacity:
		ids.append(0)
		xs.append(0)
		ys.append(0)
		texts.append("")

	var encoded: Dictionary = NativeSc2x.encode_signs({
		"ids": ids, "xs": xs, "ys": ys, "texts": texts, "extension": table.extension,
	}, document.map_size)
	document.find_chunk("XSGN").set_decoded_payload(encoded.data)
	document.sc2x_metadata.next_sign_id = maxi(next_id, document.sc2x_metadata.next_sign_id)
