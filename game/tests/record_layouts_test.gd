extends SceneTree
## Check record boundaries through public readers, writers, and graph updates.

@warning_ignore_start("integer_division")

var checks := 0
var failures := 0


func _initialize() -> void:
	_check_sizes()
	_check_thing_capacity_and_upgrade()
	_check_overlay_boundaries()
	_check_loaded_links_and_altitude()
	_check_labels_and_round_trip(128)
	_check_labels_and_round_trip(256)
	_check_microsim_fields()
	_check_graph_periods()
	print("Record layouts: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		push_error(message)


func _check_sizes() -> void:
	# Edge, XLAB bytes, XMIC bytes, XTHG bytes, XTXT bytes.
	for row in [[16, 6400, 1200, 480, 256], [128, 6400, 1200, 480, 16384],
		[256, 106150, 4800, 3840, 131072], [384, 112400, 10800, 8640, 294912],
		[512, 121150, 19200, 15360, 524288]]:
		var document := Sc2File.new()
		document.map_size = row[0]

		for index in 4:
			_check(document.decoded_size(["XLAB", "XMIC", "XTHG", "XTXT"][index]) == row[index + 1],
				"Version-two record capacity at map edge %d" % row[0])

		_check(document.decoded_size("XGRP") == 3328, "Graph payload size does not scale with the map")
		document.large_version = 1
		_check(document.decoded_size("XLAB") == 6400 and document.decoded_size("XMIC") == 1200,
			"Version one retains original label and facility capacities")
		_check(document.decoded_size("XTHG") == (960 if row[0] > 128 else 480),
			"Version one retains forty thing records with the existing plane width")


func _check_thing_capacity_and_upgrade() -> void:
	var document := EmptyCityTemplate.create(256)
	document.large_version = 1

	for id in ["XTXT", "XMIC", "XLAB", "XTHG"]:
		var chunk := document.find_chunk(id)
		chunk.expected_decoded_size = document.decoded_size(id)
		var bytes := PackedByteArray()
		bytes.resize(chunk.expected_decoded_size)
		_check(chunk.set_decoded_payload(bytes), "Create version-one record payload")

	var things := document.find_chunk("XTHG").decoded_payload.duplicate()

	for index in 480:
		things[index] = (index * 3 + 17) & 255
		things[480 + index] = (index * 7 + 11) & 255

	_check(document.find_chunk("XTHG").set_decoded_payload(things), "Store distinct low and high thing planes")
	_check(document.large_version == 1 and ThingData.count(things) == 40,
		"Version-one payload stores forty records in two separate planes")
	document.upgrade_large_limits()
	var expected := PackedByteArray()
	expected.resize(3840)

	for index in 480:
		expected[index] = things[index]
		expected[1920 + index] = things[480 + index]

	_check(document.find_chunk("XTHG").decoded_payload == expected,
		"Upgrade moves both original planes and zeroes new storage")
	var after := CityState.from_document(document)
	_check(after.thing_count() == 160 and after.thing(159) != null and after.thing(160) == null,
		"Version two expands the record count without treating planes as records")
	var saved: PackedByteArray = document.serialize().data
	var loaded := Sc2File.new()
	_check(loaded.parse(saved), "Parse the upgraded generated city")
	_check(loaded.find_chunk("XTHG").decoded_payload == expected and loaded.serialize(true).data == saved,
		"Upgraded planes survive a byte-exact save round trip")


func _check_overlay_boundaries() -> void:
	var boundaries := [-1, 0, 1, 49, 50, 51, 199, 200, 201, 239, 240, 241, 249, 250,
		251, 254, 255, 256, 4095, 4096, 8191, 8192, 65535]

	for id in boundaries:
		var sign: bool = (id >= 1 and id <= 50) or (id >= 4096 and id < 8192)
		var facility: bool = (id >= 51 and id <= 200) or (id >= 256 and id < 4096)
		var thing: bool = (id >= 201 and id <= 240) or id >= 8192
		_check(OverlayData.is_sign(id) == sign, "Sign boundary %d" % id)
		_check(OverlayData.is_facility(id) == facility, "Facility boundary %d" % id)
		_check(OverlayData.is_thing(id) == thing, "Thing boundary %d" % id)
		_check(OverlayData.blocks_thing(id) == (thing or (id >= 241 and id <= 255)),
			"Reserved marker boundary %d" % id)
		_check(OverlayData.valid_id(id, 128) == (id >= 0 and id <= 255), "Original overlay boundary %d" % id)

	# Facility record, overlay ID. Include the original/extended transition.
	for pair in [[0, 51], [149, 200], [150, 256], [599, 705], [2399, 2505]]:
		_check(OverlayData.facility_id(pair[0]) == pair[1], "Encode facility record")
		_check(OverlayData.facility_record(pair[1]) == pair[0], "Decode facility record")

	for pair in [[0, 201], [39, 240], [40, 8192], [159, 8311], [639, 8791]]:
		_check(OverlayData.thing_id(pair[0]) == pair[1], "Encode thing record")
		_check(OverlayData.thing_record(pair[1]) == pair[0], "Decode thing record")

	for row in [[256, 705, 4245, 8311, 200], [384, 1455, 4495, 8511, 450], [512, 2505, 4845, 8791, 800]]:
		for last in row.slice(1, 4):
			_check(OverlayData.valid_id(last, row[0]) and not OverlayData.valid_id(last + 1, row[0]),
				"Extended capacity boundary at edge %d" % row[0])

		var ids := OverlayData.sign_ids((row[2] + 1) * 25)
		_check(ids.size() == row[4] and ids[0] == 1 and ids[49] == 50 and ids[50] == 4096 and ids[-1] == row[2],
			"Sign allocation skips the reserved label ranges")

	var narrow := PackedByteArray()
	narrow.resize(19)
	var wide := PackedByteArray()
	wide.resize(131072)
	var expected := PackedInt32Array()
	var ids := [0, 1, 50, 51, 200, 201, 240, 241, 250, 255, 256, 4095, 4096, 4245, 4246, 8191, 8192, 65535, 2]

	for index in ids.size():
		OverlayData.write(wide, index, ids[index])
		_check(OverlayData.read(wide, index) == ids[index], "Wide overlay preserves both bytes")
		_check(wide[index] == (ids[index] & 255) and wide[65536 + index] == (ids[index] >> 8),
			"Wide overlay uses separate low and high planes")
		narrow[index] = ids[index] & 255

		if (ids[index] >= 1 and ids[index] <= 50) or (ids[index] >= 4096 and ids[index] < 8192):
			expected.append(index)

	_check(OverlayData.sign_indices(wide, 0, ids.size()) == expected, "Wide sign scan preserves reserved boundaries and the partial tail")
	var narrow_expected := PackedInt32Array()

	for index in narrow.size():
		if narrow[index] >= 1 and narrow[index] <= 50:
			narrow_expected.append(index)

	_check(OverlayData.sign_indices(narrow) == narrow_expected, "Original sign scan preserves its partial tail")
	_check(OverlayData.find(wide, 250) == 8 and OverlayData.occurrences(wide, 250) == 1,
		"Connection marker lookup uses the full overlay ID")


# A load rejects an extended link past the record capacity, at any tile.
func _check_loaded_links_and_altitude() -> void:
	for id in [705, 706]:
		var document := EmptyCityTemplate.create(256)
		var overlays := document.find_chunk("XTXT").decoded_payload
		OverlayData.write(overlays, 256 * 256 - 1, id)
		_check(document.find_chunk("XTXT").set_decoded_payload(overlays), "Write extended link")
		var altitude := document.find_chunk("ALTM").decoded_payload
		altitude[2 * 300] = 0x12
		altitude[2 * 300 + 1] = 0x34
		_check(document.find_chunk("ALTM").set_decoded_payload(altitude), "Write altitude word")
		var city := CityState.from_document(document)
		_check(city.is_valid() == (id == 705), "Extended link %d at the last tile of a 256 map" % id)

		if city.is_valid():
			_check(city.altitude_words.size() == 256 * 256 and city.altitude_words[300] == 0x1234, "Big-endian altitude words")


func _check_labels_and_round_trip(edge: int) -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(edge))
	var label_id := 1 if edge == 128 else 4096
	var offset := label_id * 25
	var labels := city.document.find_chunk("XLAB").decoded_payload.duplicate()

	for index in range(offset, offset + 25):
		labels[index] = 0xa5

	labels[offset] = 4
	labels[offset + 1] = 65
	labels[offset + 2] = 66
	labels[offset + 3] = 0
	labels[offset + 4] = 67
	_check(city.document.find_chunk("XLAB").set_decoded_payload(labels), "Store raw label bytes")
	_check(city.label(label_id) == "AB", "A zero byte ends the label before the declared length")
	labels[offset] = 255

	for index in range(1, 25):
		labels[offset + index] = 81

	_check(city.document.find_chunk("XLAB").set_decoded_payload(labels), "Store an overlong declared label")
	_check(city.label(label_id) == "Q".repeat(23), "Reader clamps text to the record capacity")
	_check(city.set_label(label_id, "ABCDEFGHIJKLMNOPQRSTUVWXYZ"), "Write an overlong label")
	labels = city.document.find_chunk("XLAB").decoded_payload
	_check(labels[offset] == 23 and labels[offset + 24] == 0, "Writer stores length and terminal zero")
	_check(city.label(label_id) == "ABCDEFGHIJKLMNOPQRSTUVW", "Writer truncates ASCII text to 23 bytes")
	var previous := labels.slice(offset, offset + 25)
	_check(city.set_label(label_id, "Hi"), "Shorten the label")
	labels = city.document.find_chunk("XLAB").decoded_payload
	_check(labels.slice(offset, offset + 4) == PackedByteArray([2, 72, 105, 0]), "Short label has its own terminator")
	_check(labels.slice(offset + 4, offset + 25) == previous.slice(4, 25), "Short writes preserve unknown trailing bytes")
	_check(city.set_label(label_id, ""), "Clear a label")
	_check(city.label(label_id).is_empty(), "Empty label reads empty")
	_check(not city.set_label(-1, "bad") and not city.set_label(labels.size() / 25, "bad"), "Label bounds reject writes")

	var unknown := Sc2Chunk.new()
	unknown.chunk_id = "ZREV"
	unknown.expected_decoded_size = 5
	unknown.is_compressed = false
	_check(unknown.set_decoded_payload(PackedByteArray([5, 0, 255, 42, 17])), "Create opaque chunk")
	city.document.chunks.append(unknown)
	city.document.rebuild_chunk_cache()
	var saved: PackedByteArray = city.document.serialize().data
	var loaded := Sc2File.new()
	_check(loaded.parse(saved), "Parse generated label fixture")
	_check(loaded.serialize(true).data == saved, "Record changes retain a byte-exact save round trip")
	_check(loaded.find_chunk("ZREV").decoded_payload == PackedByteArray([5, 0, 255, 42, 17]), "Opaque chunk survives the round trip")

	if edge > 128:
		for id in range(1, 51):
			_check(city.set_label(id, "Occupied"), "Occupy an original sign slot")

	var before: PackedByteArray = city.document.serialize().data
	var command := SignCommand.set_sign(city, Vector2i(4, 5), "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
	_check(command.ok and command.label_id == label_id and command.text == "ABCDEFGHIJKLMNOPQRSTUVW", "Sign command allocates the original or first extended slot")
	_check(SignCommand.undo(city, command).ok, "Undo sign command")
	_check(city.document.serialize().data == before, "Sign undo restores label tails and city bytes")


func _check_microsim_fields() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(16))
	var bytes := city.document.find_chunk("XMIC").decoded_payload.duplicate()
	var record := PackedByteArray([0xd1, 6, 0x12, 0x34, 0xab, 0xcd, 0xff, 0xfe])

	for index in 8:
		bytes[149 * 8 + index] = record[index]

	_check(city.document.find_chunk("XMIC").set_decoded_payload(bytes), "Store final original microsim record")
	var micro := city.microsim(149)
	_check(micro.tile_id == 0xd1 and micro.stat_0 == 6 and micro.stat_1 == 0x1234
		and micro.stat_2 == 0xabcd and micro.stat_3 == 0xfffe, "Read mixed-width big-endian microsim fields")
	_check(city.microsim(-1) == null and city.microsim(150) == null, "Microsim bounds remain unchanged")


func _check_graph_periods() -> void:
	# Ordinary month, half-year boundary, ordinary January, and five-year January.
	for age in [50, 150, 300, 1500]:
		var city := CityState.from_document(EmptyCityTemplate.create(16))
		_check(city.set_age_in_days(age), "Set graph date")
		var bytes := PackedByteArray()
		bytes.resize(3328)
		var current := PackedInt64Array()

		for series in 16:
			current.append(-1 if series == 15 else 0x90000000 + series)

			for index in 52:
				BinaryData.write_u32_be(bytes, (series * 52 + index) * 4, 0x80000000 + series * 256 + index)

		_check(city.document.find_chunk("XGRP").set_decoded_payload(bytes), "Store distinct graph history values")
		var result := GraphHistory.advance(city, current)
		_check(result.ok, "Advance graph histories")
		var stored := city.document.find_chunk("XGRP").decoded_payload
		var half_year: bool = age != 50
		var five_year: bool = age == 1500

		for series in 16:
			for index in 52:
				var fresh: bool = index == 0 or (index == 12 and half_year) or (index == 32 and five_year)
				var shifted: bool = (index > 0 and index < 12) or (index > 12 and index < 32 and half_year) or (index > 32 and five_year)
				var expected: int = current[series] & 0xffffffff if fresh else 0x80000000 + series * 256 + index - (1 if shifted else 0)
				_check(BinaryData.read_u32_be(stored, (series * 52 + index) * 4) == expected, "Graph period writes retain series boundaries")

			var graph := city.graph_series(series)
			_check(graph.year.size() == 12 and graph.decade.size() == 20 and graph.century.size() == 20,
				"Graph reader exposes the original period lengths")
			_check(graph.year[0] == (current[series] & 0xffffffff)
				and graph.decade[0] == ((current[series] & 0xffffffff) if half_year else 0x80000000 + series * 256 + 12)
				and graph.century[0] == ((current[series] & 0xffffffff) if five_year else 0x80000000 + series * 256 + 32),
				"Graph reader and writer agree on period starts")

		_check(city.graph_series(-1) == null and city.graph_series(16) == null, "Graph series bounds remain unchanged")
