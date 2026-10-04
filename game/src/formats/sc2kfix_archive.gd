class_name Sc2kfixArchive
extends RefCounted
## The SC2X save format of the sc2kfix plugin (version 1), internally called
## "sc2kfix". It is not the OpenSC2K SC2X version 4 format.
##
## A ZIP archive holds `META.json`, `current/MISC.json`, `current/XFIX.json`,
## and the runtime arrays of an original 128-tile city under `current/`.
## Runtime arrays are little-endian: ALTM words, XGRP values and the three
## words of each XMIC record are byte-swapped from the SC2 file layout. XLAB
## holds C strings instead of Pascal strings. The other arrays match the
## decoded SC2 chunks.
##
## MISC.json omits some MISC words and the scenario chunks. A save also writes
## `opensc2k/MISC` and `opensc2k/chunks/<ID>` entries, so a file that OpenSC2K
## writes and reads again keeps all its data. sc2kfix ignores them.

@warning_ignore_start("integer_division")

const MAGIC := "d77bc72e0a78e3f47700f3a2efc04bb2f49e75908547c7bcd495e5518831a0e7"
const VERSION := 1
const EDGE := 128
const META := "META.json"
const MISC := "current/MISC.json"
const XFIX := "current/XFIX.json"
const PRESERVED_MISC := "opensc2k/MISC"
const PRESERVED_PREFIX := "opensc2k/chunks/"
const PRESERVED_ORDER := "opensc2k/chunk_order"
const MAX_ARCHIVE_BYTES := 64 * 1024 * 1024
const MAX_DATA_BYTES := 64 * 1024 * 1024
const MISC_VERSION := 290
# the chunks of a city in the order of an original save. CNAM comes from META.json
const MAP_CHUNKS := [
	"ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XLAB", "XMIC", "XTHG", "XBIT",
	"XTRF", "XPLT", "XVAL", "XCRM", "XPLC", "XFIR", "XPOP", "XROG", "XGRP",
]
const BUDGET_NAMES := [
	"residential", "commercial", "industrial", "ordinances", "bonds", "police", "fire", "health",
	"schools", "colleges", "raods", "highways", "bridges", "rail", "subways", "tunnels",
]
const NEIGHBOR_NAMES := ["north", "east", "south", "west"]
const LABEL_SIZE := 25
const LABEL_TEXT := 24

enum Kind { I8, U8, I16, U16, I32, U32 }

# MISC word, JSON section, key, and the runtime type of sc2kfix
const FIELDS := [
	[1, "city", "mode", Kind.I16], [2, "city", "view_rotation", Kind.I16],
	[3, "city", "start_year", Kind.I16], [4, "city", "days", Kind.I32],
	[5, "city", "funds", Kind.I32], [6, "city", "bonds", Kind.I32],
	[7, "city", "difficulty", Kind.I16], [8, "city", "progression", Kind.I16],
	[9, "city", "value", Kind.I32], [10, "city", "land_value", Kind.I32],
	[11, "city", "crime", Kind.I32], [12, "city", "traffic_count", Kind.I32],
	[13, "city", "pollution", Kind.I32], [14, "city", "fame", Kind.I32],
	[15, "city", "advertising", Kind.I32], [16, "city", "garbage", Kind.U32],
	[17, "city", "workforce_percent", Kind.I32], [18, "city", "workforce_le", Kind.I32],
	[19, "city", "workforce_eq", Kind.I32], [20, "nation", "population", Kind.I32],
	[21, "nation", "value", Kind.I32], [22, "nation", "fed_rate", Kind.I16],
	[23, "nation", "economy_trend", Kind.I16], [24, "city", "weather_heat", Kind.U8],
	[25, "city", "weather_wind", Kind.U8], [26, "city", "weather_rain", Kind.U8],
	[27, "city", "weather_trend", Kind.U8], [29, "city", "old_res_pop", Kind.I32],
	[30, "city", "granted_rewards", Kind.I16], [911, "city", "year_end_flag", Kind.U8],
	[912, "city", "water_level", Kind.I16], [913, "city", "has_ocean", Kind.U8],
	[914, "city", "has_river", Kind.U8], [915, "city", "military_base_type", Kind.U8],
	[1000, "city", "ordinances", Kind.U32], [1001, "city", "unemployment", Kind.I32],
	[1018, "city", "xund_count", Kind.U16], [1019, "options", "speed", Kind.I16],
	[1020, "options", "auto_budget", Kind.I32], [1021, "options", "auto_goto", Kind.I32],
	[1022, "options", "sound", Kind.I32], [1023, "options", "music", Kind.I32],
	[1024, "options", "no_disasters", Kind.I32], [1025, "city", "newspaper_subscription", Kind.I32],
	[1026, "city", "newspaper_extra", Kind.I32], [1027, "city", "newspaper_choice", Kind.I16],
	[1028, "city", "screen_point", Kind.I32], [1029, "city", "screen_zoom", Kind.U16],
	[1030, "city", "center_x", Kind.I16], [1031, "city", "center_y", Kind.I16],
	[1032, "city", "arcology_population", Kind.I32], [1033, "city", "connection_tiles", Kind.I16],
	[1034, "city", "sports_teams", Kind.I16], [1035, "city", "population", Kind.U32],
	[1036, "city", "industrial_mix_bonus", Kind.I16],
	[1037, "city", "industrial_mix_pollution_bonus", Kind.I16],
	[1038, "city", "old_arrests", Kind.I16], [1039, "city", "prison_bonus", Kind.I16],
	[1040, "city", "disaster_object", Kind.I16], [1041, "city", "disaster_type", Kind.I16],
	[1042, "city", "disaster_active", Kind.I32], [1043, "city", "sewer_bonus", Kind.I16],
]
# MISC word, key, count, type of the city arrays
const ARRAYS := [
	[124, "tile_count", 256, Kind.U16], [380, "zone_pops", 8, Kind.U32],
	[388, "bond_data", 50, Kind.U16], [454, "demands", 8, Kind.I16],
	[462, "invention_years", 17, Kind.I16], [1002, "military_tile_count", 16, Kind.U16],
]
const RATIO_TABLES_WORD := 31
const RATIO_TABLES := ["pop_ratio_table", "eq_ratio_table", "le_ratio_table"]
const NEIGHBORS_WORD := 438
const BUDGETS_WORD := 479
const BUDGET_WORDS := 27
const PAPERS_WORD := 916
const PAPER_BYTES := 30
const NEWS_WORD := 946
const NEWS_COUNT := 9
# MISC word 28 is the triggered disaster. sc2kfix writes it and word 1041 to one
# key, so the key holds word 1041
const TRIGGERED_DISASTER_WORD := 28
const DISASTER_TYPE_WORD := 1041


class Archive extends RefCounted:
	var ok := false
	var error := ""
	var bytes := PackedByteArray()


# The first member of an sc2kfix archive is META.json. An OpenSC2K SC2X
# version 4 archive starts with metadata.json.
static func is_archive(bytes: PackedByteArray) -> bool:
	if not Sc2xDocument.is_archive(bytes) or bytes.size() < 30 + META.length():
		return false

	var name_size := bytes.decode_u16(26)

	return name_size == META.length() and bytes.slice(30, 30 + name_size).get_string_from_ascii() == META


# Fill `document` with the original city of an sc2kfix archive.
static func load_bytes(document: Sc2File, bytes: PackedByteArray) -> bool:
	var archive := ZipArchive.decode(bytes, MAX_ARCHIVE_BYTES, MAX_DATA_BYTES)

	if not archive.ok:
		return document._fail("The sc2kfix city archive is invalid: %s" % archive.error)

	var members := archive.members
	var meta: Variant = _json(members, META)

	if not meta is Dictionary or not meta.get("sc2x") is Dictionary or meta.sc2x.get("magic") != MAGIC:
		return document._fail("The sc2kfix city has no valid META.json.")

	if int(meta.sc2x.get("version", 0)) != VERSION:
		return document._fail("The sc2kfix city version %s is not supported." % str(meta.sc2x.get("version")))

	var game: Dictionary = meta.get("game") if meta.get("game") is Dictionary else {}

	if int(game.get("dimensions", EDGE)) != EDGE:
		return document._fail("An sc2kfix city must use a 128 × 128 map.")

	var misc_json: Variant = _json(members, MISC)

	if not misc_json is Dictionary:
		return document._fail("The sc2kfix city has no valid current/MISC.json.")

	document.map_size = EDGE
	document.large_version = 2
	var name := str(game.get("city_name", ""))
	var preserved_name: PackedByteArray = members.get(PRESERVED_PREFIX + "CNAM", PackedByteArray())

	if preserved_name.size() == Sc2File.DECODED_SIZES.CNAM:
		_add_chunk(document, "CNAM", preserved_name)

	if document.city_name() != name and not name.is_empty():
		document.add_city_name_chunk()
		document.set_city_name(name)

	_add_chunk(document, "MISC", _misc_from_json(misc_json, members.get(PRESERVED_MISC, PackedByteArray())))

	for id: String in MAP_CHUNKS:
		var path := "current/" + id
		var expected: int = Sc2File.DECODED_SIZES[id]

		if not members.has(path) or members[path].size() != expected:
			return document._fail("The sc2kfix city %s array is missing or has the wrong size." % id)

		# a chunk that OpenSC2K kept is exact while sc2kfix did not change it
		var preserved: PackedByteArray = members.get(PRESERVED_PREFIX + id, PackedByteArray())

		if preserved.size() == expected and _to_runtime(id, preserved) == members[path]:
			_add_chunk(document, id, preserved)
		else:
			_add_chunk(document, id, _from_runtime(id, members[path]))

	# a save adds the XFIX that sc2kfix requires. A city that had none keeps none
	var order: PackedByteArray = members.get(PRESERVED_ORDER, PackedByteArray())
	var added_xfix := not order.is_empty() and not order.get_string_from_ascii().split(",").has("XFIX")

	if members.has(XFIX) and not added_xfix:
		_add_chunk(document, "XFIX", members[XFIX])

	for path: String in archive.order:
		var id := path.trim_prefix(PRESERVED_PREFIX)

		if path.begins_with(PRESERVED_PREFIX) and id not in MAP_CHUNKS and id != "CNAM":
			_add_chunk(document, id, members[path])

	_restore_order(document, order)
	document.source_format = "sc2kfix"
	document.rebuild_chunk_cache()

	return true


# The chunk order of the file that OpenSC2K wrote, when it lists the same chunks.
static func _restore_order(document: Sc2File, order: PackedByteArray) -> void:
	var ids := order.get_string_from_ascii().split(",", false)

	if ids.size() != document.chunks.size():
		return

	var by_id: Dictionary[String, Sc2Chunk] = {}

	for chunk in document.chunks:
		by_id[chunk.chunk_id] = chunk

	if by_id.size() != ids.size():
		return

	var ordered: Array[Sc2Chunk] = []

	for id in ids:
		if not by_id.has(id):
			return

		ordered.append(by_id[id])

	document.chunks = ordered


# An sc2kfix archive of an original city. `timestamp` is the META.json time.
static func encode(document: Sc2File, timestamp: int) -> Archive:
	var result := Archive.new()

	if document == null or document.is_extended() or document.map_size != EDGE:
		result.error = "Only an original 128 × 128 city can use the sc2kfix format."

		return result

	var misc_chunk := document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != Sc2MiscLayout.SIZE:
		result.error = "The city has no valid MISC data."

		return result

	var names := PackedStringArray()
	var members: Dictionary[String, PackedByteArray] = {}
	var meta := {
		"sc2x": {"magic": MAGIC, "creator": "OpenSC2K", "timestamp": timestamp, "version": VERSION},
		"game": {"dimensions": EDGE, "city_name": document.city_name()},
	}
	_add_member(names, members, META, _json_bytes(meta))
	_add_member(names, members, MISC, _json_bytes(_misc_to_json(misc_chunk.decoded_payload)))

	for id: String in MAP_CHUNKS:
		var chunk := document.find_chunk(id)

		if chunk == null or chunk.decoded_payload.size() != int(Sc2File.DECODED_SIZES[id]):
			result.error = "The city has no valid %s data." % id

			return result

		_add_member(names, members, "current/" + id, _to_runtime(id, chunk.decoded_payload))

	var xfix := document.find_chunk("XFIX")
	_add_member(names, members, XFIX, xfix.decoded_payload if xfix != null else _json_bytes(_default_xfix(timestamp)))
	_add_member(names, members, PRESERVED_MISC, misc_chunk.decoded_payload)
	var order := PackedStringArray()

	for chunk in document.chunks:
		order.append(chunk.chunk_id)
		var id := chunk.chunk_id
		var exact := id in MAP_CHUNKS and _from_runtime(id, _to_runtime(id, chunk.decoded_payload)) == chunk.decoded_payload

		if id not in ["MISC", "XFIX"] and not exact:
			_add_member(names, members, PRESERVED_PREFIX + id, chunk.decoded_payload)

	_add_member(names, members, PRESERVED_ORDER, ",".join(order).to_ascii_buffer())

	var archive := ZipArchive.encode(names, members, MAX_ARCHIVE_BYTES, MAX_DATA_BYTES, true)

	if not archive.ok:
		result.error = archive.error

		return result

	result.ok = true
	result.bytes = archive.bytes

	return result


static func _add_member(names: PackedStringArray, members: Dictionary[String, PackedByteArray], path: String, bytes: PackedByteArray) -> void:
	if members.has(path):
		return

	names.append(path)
	members[path] = bytes.duplicate()


static func _add_chunk(document: Sc2File, id: String, decoded: PackedByteArray) -> void:
	var chunk := Sc2Chunk.new()
	chunk.chunk_id = id
	chunk.expected_decoded_size = document.decoded_size(id)
	chunk.is_compressed = chunk.expected_decoded_size >= 0 and not Sc2File.RAW_CHUNKS.has(id)
	chunk.decoded_payload = decoded.duplicate()
	chunk.is_dirty = true
	document.chunks.append(chunk)


# sc2kfix writes each JSON file with a terminating null byte
static func _json(members: Dictionary, path: String) -> Variant:
	if not members.has(path):
		return null

	var bytes: PackedByteArray = members[path]
	var end := bytes.size()

	while end > 0 and bytes[end - 1] == 0:
		end -= 1

	return JSON.parse_string(bytes.slice(0, end).get_string_from_utf8())


static func _json_bytes(value: Variant) -> PackedByteArray:
	var bytes := JSON.stringify(value).to_utf8_buffer()
	bytes.append(0)

	return bytes


static func _default_xfix(timestamp: int) -> Dictionary:
	return {
		"meta": {"creator": "OpenSC2K", "timestamp": timestamp, "porntipsguzzardo": false},
		"map": {"terrain_cosmetic_mode": 0, "tilesets": []},
	}


# The value of a MISC word as sc2kfix holds it at run time.
static func _typed(word: int, kind: Kind) -> int:
	match kind:
		Kind.I8:
			return (word & 0xff) - (0x100 if word & 0x80 else 0)
		Kind.U8:
			return word & 0xff
		Kind.I16:
			return (word & 0xffff) - (0x10000 if word & 0x8000 else 0)
		Kind.U16:
			return word & 0xffff
		Kind.I32:
			return (word & 0xffffffff) - (0x100000000 if word & 0x80000000 else 0)

	return word & 0xffffffff


static func _number(value: Variant) -> int:
	if value is bool:
		return 1 if value else 0

	if value is float or value is int:
		return int(value)

	return 0


static func _word(misc: PackedByteArray, word: int) -> int:
	return BinaryData.read_u32_be(misc, word * 4)


static func _set_word(misc: PackedByteArray, word: int, value: int) -> void:
	BinaryData.write_u32_be(misc, word * 4, value)


static func _misc_to_json(misc: PackedByteArray) -> Dictionary:
	var result := {"city": {}, "nation": {}, "options": {}, "neighbors": {}}

	for field: Array in FIELDS:
		result[field[1]][field[2]] = _typed(_word(misc, field[0]), field[3])

	for entry: Array in ARRAYS:
		var values := []

		for index in int(entry[2]):
			values.append(_typed(_word(misc, int(entry[0]) + index), entry[3]))

		result.city[entry[1]] = values

	for table in RATIO_TABLES.size():
		var values := []

		for index in 20:
			values.append(_typed(_word(misc, RATIO_TABLES_WORD + index * 3 + table), Kind.U32))

		result.city[RATIO_TABLES[table]] = values

	for neighbor in NEIGHBOR_NAMES.size():
		var word := NEIGHBORS_WORD + neighbor * 4
		result.neighbors[NEIGHBOR_NAMES[neighbor]] = {
			"name": _typed(_word(misc, word), Kind.I16),
			"population": _typed(_word(misc, word + 1), Kind.I32),
			"value": _typed(_word(misc, word + 2), Kind.I32),
			"fame": _typed(_word(misc, word + 3), Kind.I32),
		}

	var budgets := {}

	for budget in BUDGET_NAMES.size():
		var word := BUDGETS_WORD + budget * BUDGET_WORDS
		var counts := []
		var funds := []

		for month in 12:
			counts.append(_typed(_word(misc, word + 3 + month * 2), Kind.I32))
			funds.append(_typed(_word(misc, word + 4 + month * 2), Kind.I32))

		budgets[BUDGET_NAMES[budget]] = {
			"current_costs": _typed(_word(misc, word), Kind.I32),
			"funding_percent": _typed(_word(misc, word + 1), Kind.I32),
			"year_to_date_cost": _typed(_word(misc, word + 2), Kind.I32),
			"count_month": counts,
			"fund_month": funds,
		}

	result.city.budget = budgets
	var papers := []

	for index in PAPER_BYTES:
		papers.append(_typed(_word(misc, PAPERS_WORD + index), Kind.U8))

	result.city.newspaper_papers_array = papers
	result.city.newspaper_news_array = Array(_news_to_runtime(misc))

	return result


# Each runtime news record has two little-endian words and four bytes.
static func _news_to_runtime(misc: PackedByteArray) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(NEWS_COUNT * 8)

	for record in NEWS_COUNT:
		var word := NEWS_WORD + record * 6
		bytes.encode_u16(record * 8, _word(misc, word) & 0xffff)
		bytes.encode_u16(record * 8 + 2, _word(misc, word + 1) & 0xffff)

		for index in 4:
			bytes[record * 8 + 4 + index] = _word(misc, word + 2 + index) & 0xff

	return bytes


static func _misc_from_json(json: Dictionary, preserved: PackedByteArray) -> PackedByteArray:
	var misc := PackedByteArray()
	misc.resize(Sc2MiscLayout.SIZE)
	var has_base := preserved.size() == Sc2MiscLayout.SIZE

	if has_base:
		misc = preserved.duplicate()
	else:
		_set_word(misc, 0, MISC_VERSION)

	var triggered_disaster := _word(misc, TRIGGERED_DISASTER_WORD)
	var preserved_disaster := _typed(_word(misc, DISASTER_TYPE_WORD), Kind.I16)
	var sections := {}

	for section in ["city", "nation", "options", "neighbors"]:
		sections[section] = json.get(section) if json.get(section) is Dictionary else {}

	for field: Array in FIELDS:
		if sections[field[1]].has(field[2]):
			_store(misc, field[0], sections[field[1]][field[2]], field[3], has_base)

	# sc2kfix loads one disaster type into both words. A file that OpenSC2K wrote
	# keeps its triggered disaster while the current disaster is unchanged
	if not has_base or _typed(_word(misc, DISASTER_TYPE_WORD), Kind.I16) != preserved_disaster:
		triggered_disaster = _word(misc, DISASTER_TYPE_WORD)

	_set_word(misc, TRIGGERED_DISASTER_WORD, triggered_disaster)
	var city: Dictionary = sections.city

	for entry: Array in ARRAYS:
		var values: Variant = city.get(entry[1])

		if values is Array:
			for index in mini(values.size(), int(entry[2])):
				_store(misc, int(entry[0]) + index, values[index], entry[3], has_base)

	for table in RATIO_TABLES.size():
		var values: Variant = city.get(RATIO_TABLES[table])

		if values is Array:
			for index in mini(values.size(), 20):
				_store(misc, RATIO_TABLES_WORD + index * 3 + table, values[index], Kind.U32, has_base)

	for neighbor in NEIGHBOR_NAMES.size():
		var values: Variant = sections.neighbors.get(NEIGHBOR_NAMES[neighbor])

		if not values is Dictionary:
			continue

		var word := NEIGHBORS_WORD + neighbor * 4

		for key_index in 4:
			var key: String = ["name", "population", "value", "fame"][key_index]

			if values.has(key):
				_store(misc, word + key_index, values[key], Kind.I16 if key_index == 0 else Kind.I32, has_base)

	var budgets: Dictionary = city.get("budget") if city.get("budget") is Dictionary else {}

	for budget in BUDGET_NAMES.size():
		var values: Variant = budgets.get(BUDGET_NAMES[budget])

		if not values is Dictionary:
			continue

		var word := BUDGETS_WORD + budget * BUDGET_WORDS

		for key_index in 3:
			var key: String = ["current_costs", "funding_percent", "year_to_date_cost"][key_index]

			if values.has(key):
				_store(misc, word + key_index, values[key], Kind.I32, has_base)

		for list_index in 2:
			var months: Variant = values.get(["count_month", "fund_month"][list_index])

			if months is Array:
				for month in mini(months.size(), 12):
					_store(misc, word + 3 + month * 2 + list_index, months[month], Kind.I32, has_base)

	var papers: Variant = city.get("newspaper_papers_array")

	if papers is Array:
		for index in mini(papers.size(), PAPER_BYTES):
			_store(misc, PAPERS_WORD + index, _number(papers[index]) & 0xff, Kind.U8, has_base)

	var news: Variant = city.get("newspaper_news_array")

	if news is Array and news.size() >= NEWS_COUNT * 8:
		var bytes := PackedByteArray()

		for value: Variant in news.slice(0, NEWS_COUNT * 8):
			bytes.append(_number(value) & 0xff)

		for record in NEWS_COUNT:
			var word := NEWS_WORD + record * 6
			_store(misc, word, _typed(bytes.decode_u16(record * 8), Kind.I16), Kind.U16, has_base)
			_store(misc, word + 1, _typed(bytes.decode_u16(record * 8 + 2), Kind.I16), Kind.U16, has_base)

			for index in 4:
				_store(misc, word + 2 + index, bytes[record * 8 + 4 + index], Kind.U8, has_base)

	return misc


# Store a JSON value. A word of a file that OpenSC2K wrote keeps its other bits
# when sc2kfix holds the same value.
static func _store(misc: PackedByteArray, word: int, value: Variant, kind: Kind, has_base: bool) -> void:
	var number := _number(value)

	if has_base and _typed(_word(misc, word), kind) == _typed(number, kind):
		return

	_set_word(misc, word, number)


# The SC2 chunk of a runtime array, and the runtime array of an SC2 chunk.
static func _from_runtime(id: String, runtime: PackedByteArray) -> PackedByteArray:
	match id:
		"ALTM":
			return _swapped(runtime, 2, 0, 2)
		"XGRP":
			return _swapped(runtime, 4, 0, 4)
		"XMIC":
			return _swapped(runtime, 2, 2, Sc2MicrosimLayout.RECORD_SIZE)
		"XLAB":
			return _labels_to_pascal(runtime)

	return runtime.duplicate()


static func _to_runtime(id: String, decoded: PackedByteArray) -> PackedByteArray:
	match id:
		"ALTM", "XGRP", "XMIC":
			return _from_runtime(id, decoded)
		"XLAB":
			return _labels_to_c(decoded)

	return decoded.duplicate()


# Reverse each `width`-byte value from `first` to the end of every `stride`-byte record.
static func _swapped(source: PackedByteArray, width: int, first: int, stride: int) -> PackedByteArray:
	var bytes := source.duplicate()

	for record in range(0, bytes.size() - stride + 1, stride):
		for offset in range(record + first, record + stride, width):
			for index in width / 2:
				var other := offset + width - 1 - index
				var value := bytes[offset + index]
				bytes[offset + index] = bytes[other]
				bytes[other] = value

	return bytes


static func _labels_to_pascal(runtime: PackedByteArray) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(runtime.size())

	for record in range(0, runtime.size() - LABEL_SIZE + 1, LABEL_SIZE):
		var length := 0

		while length < LABEL_TEXT - 1 and runtime[record + length] != 0:
			length += 1

		if length == 0:
			continue

		bytes[record] = length

		for index in length:
			bytes[record + 1 + index] = runtime[record + index]

	return bytes


static func _labels_to_c(decoded: PackedByteArray) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(decoded.size())

	for record in range(0, decoded.size() - LABEL_SIZE + 1, LABEL_SIZE):
		var length := mini(decoded[record], LABEL_TEXT - 1)

		for index in length:
			bytes[record + index] = decoded[record + 1 + index]

	return bytes
