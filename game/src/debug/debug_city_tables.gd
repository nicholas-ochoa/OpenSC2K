class_name DebugCityTables
extends RefCounted
# Read the published city snapshot. Reuse cached scans; do not serialize or draw random values.

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const FACILITIES = BuildingCommand.DEFAULT_MICROSIM_LABELS
const STAT_LABELS := {
	Tiles.HOSPITAL: ["Score", "Patients", "Staff", "Half funding"],
	Tiles.POLICE_STATION: ["Funding", "Funded capacity", "Crime per tile", "Arrests"],
	Tiles.FIRE_STATION: ["Funding", "Funded capacity", "Capacity / 16 + 1", "Annual random statistic"],
	Tiles.SCHOOL: ["Score", "Students", "Staff", "Quarter funding"],
	Tiles.PRISON: ["Type-specific byte", "Prisoners", "Funded capacity", "Prisoners / 100"],
	Tiles.COLLEGE: ["Score", "Students", "Staff", "Funding"],
	Tiles.SUBWAY_STATION: ["Type-specific byte", "Subway tile count", "Preserved statistic", "Annual passengers"],
	Tiles.BUS_DEPOT: ["Type-specific byte", "Bus tile count / 4", "Bus tile count", "Annual passengers"],
	Tiles.RAIL_STATION: ["Type-specific byte", "Rail tile count / 4", "Preserved statistic", "Annual passengers"],
}
# state tab rows in record order, with their descriptions. the tab sorts them by name
const ENGINE_FIELDS := {
	"developed_tiles": "Number of tiles with a zone or a structure at the last data-map scan. The value is -1 before the first scan.",
	"power_usage_percent": "Percentage of the power capacity in use at the last power scan. The value is -1 before the first scan.",
	"water_usage_percent": "Percentage of the water capacity in use at the last water scan. The value is -1 before the first scan.",
	"commerce_connections": "Number of connections to neighbor cities that increase commercial demand.",
	"industry_connections": "Number of connections to neighbor cities that increase industrial demand.",
	"bus_passengers": "Number of bus passengers since the last yearly update. The yearly update gives this number to the bus depots.",
	"rail_passengers": "Number of rail passengers since the last yearly update. The yearly update gives this number to the rail stations.",
	"subway_passengers": "Number of subway passengers since the last yearly update. The yearly update gives this number to the subway stations.",
	"mayor_approval": "Mayor approval from the last query of the mayor's house.",
	"ship_home": "The tile where the cargo ship returns. The value is (-1, -1) when the city has no cargo ship.",
	"pending_interaction": "The player prompt that stops the current day, for example the yearly budget. The value is empty when there is no prompt.",
	"terminal_state": "True when the game ended because of bankruptcy or a scenario result. When true, the simulation stops.",
	"active_disaster_type": "The ID of the active disaster. The value is 0 when no disaster is active.",
	"pending_disaster_type": "The ID of the disaster that starts after the next simulation day. The value is 0 when no disaster waits.",
	"pending_disaster_point": "The tile where the pending disaster starts.",
	"unsupported_disaster_type": "The ID of a disaster that did not start because the game does not support it yet. The value is 0 when there is no such disaster.",
	"disaster_map_counter": "Countdown for the active disaster. Each disaster tick decreases it by one.",
	"disaster_hurricane_counter": "Countdown for the hurricane wind and floods. Each disaster tick decreases it by one.",
}
# tile counts of the last building scan, reused until the building plane changes
static var _tile_count_key: Array = []
static var _tile_counts := PackedInt32Array()
static var _tile_constants := _make_tile_constants()
const RANDOM_FIELDS := {
	"random": "The state of the main random number generator.",
	"game_random": "The state of the second random number generator.",
	"lfsr_random": "The state of the linear feedback shift register (LFSR) random number generator.",
}


static func collect(kind: String, city: CityState, engine: SimulationEngine = null, include_empty := false) -> Array[DebugTableRecord]:
	var result: Array[DebugTableRecord] = []

	if city == null or not city.is_valid():
		return result

	match kind:
		"XMIC":
			var sites := city.microsim_sites()

			for id in city.microsim_count():
				var record := city.microsim(id)
				var tile := record.tile_id if record != null else 0
				if tile == BuildingTileIds.EMPTY and not include_empty:
					continue

				var fields: Array[DebugTableRecord] = []
				fields.append(_field("tile_id", tile, "Type"))
				var labels: Array = STAT_LABELS.get(tile, ["Type-specific byte", "Type-specific statistic", "Type-specific statistic", "Type-specific statistic"])

				for index in 4:
					fields.append(_field("stat_%d" % index, record.statistic(index) if record != null else 0,
						labels[index]))

				var value: String = "Empty" if tile == BuildingTileIds.EMPTY else FACILITIES.get(tile, "Facility 0x%02X" % tile)
				var label := city.label(OverlayData.facility_id(id))
				var site: CityRecords.Site = sites.get(id)
				var detail := "-" if label.is_empty() or label == value else label
				var row := DebugTableRecord.new()
				row.id = str(id)
				row.name = "Record %d" % id
				row.value = value
				row.raw = "0x%02X" % tile
				row.position = "Not on map" if site == null else "(%d, %d) %d×%d" % [site.x, site.y, site.width, site.height]
				row.site = site
				row.detail = detail
				# sort values per visible column, excluding the locate icon column
				row.sort = [id, value, tile, _site_sort(site), detail]
				row.empty = tile == BuildingTileIds.EMPTY
				row.fields = fields
				result.append(row)
		"Objects":
			for id in city.thing_count():
				var record := city.thing(id)

				if record.type == 0 and not include_empty:
					continue

				var table := DebugObjectFields.table_cells(id, record, city)
				var site := null if record.type == 0 or city.index_of(record.x, record.y) < 0 \
					else CityRecords.Site.new(record.x, record.y, 1, 1)
				var sort: Array = [id]

				for key: String in DebugObjectFields.COLUMNS:
					# translated columns sort by their visible text; the rest by stored value
					sort.append(table.cells[sort.size()] if key in DebugObjectFields.TRANSLATED else record.get(key))

				var row := DebugTableRecord.new()
				row.id = str(id)
				row.name = "Object %d" % id
				row.value = DebugObjectFields.type_name(record.type)
				row.raw = "(%d, %d, %d)" % [record.x, record.y, record.z]
				row.cells = table.cells
				row.tooltips = table.tooltips
				row.empty = record.type == 0
				row.site = site
				row.sort = sort
				var stored := DebugTableRecord.new()
				stored.cells = table.raw
				stored.tooltips = table.tooltips
				row.fields = [stored]
				result.append(row)

		"Tiles":
			var counts := tile_counts(city)

			for id in counts.size():
				var count := counts[id]

				var saved := city.document.misc_i32(Sc2MiscLayout.TILE_COUNTS + id * 4)

				if count == 0 and saved == 0 and not include_empty:
					continue

				var first := city.buildings.find(id) if count > 0 else -1
				var site := null if first < 0 else CityRecords.Site.new(first / city.map_size, first % city.map_size, 1, 1)
				var name := QueryStrings.tile_name(id)
				var row := DebugTableRecord.new()
				row.id = str(id)
				row.cells = ["%d (0x%02X)" % [id, id], _tile_constants[id], name, str(count), str(saved)]
				row.sort = [id, _tile_constants[id], name, count, saved]
				row.site = site
				row.empty = count == 0 and saved == 0

				if saved != count:
					row.warning = _count_difference(city, count, saved)

				result.append(row)

		"State":
			if engine != null:
				for key: String in ENGINE_FIELDS:
					result.append(_state_field(key, engine.get(key), ENGINE_FIELDS[key]))

				for key: String in RANDOM_FIELDS:
					var random: RefCounted = engine.get(key)

					if random != null:
						result.append(_state_field(key + ".state", random.get("state"), RANDOM_FIELDS[key]))

	return result


# records the game can use in a record table, or -1 for a table without a limit.
# the game never uses record 0 of XMIC or XTHG
static func record_limit(kind: String, city: CityState) -> int:
	if city == null:
		return -1

	match kind:
		"XMIC":
			return city.microsim_count() - 1
		"Objects":
			return city.thing_count() - 1

	return -1


# the number of tiles with each building id outside military zones. the result is shared; do not change it
static func tile_counts(city: CityState) -> PackedInt32Array:
	var key: Array = [city.get_instance_id(), city.chunk_revision("XBLD"), city.chunk_revision("XZON")]

	if key == _tile_count_key:
		return _tile_counts

	var counts := CityTileCounts.count(city)
	_tile_count_key = key
	_tile_counts = counts

	return counts


static func _count_difference(city: CityState, count: int, saved: int) -> String:
	var text := "The saved count is %d, but the map has %d.\n" % [saved, count]

	if CityTileCounts.exact(city):
		return text + "This SC2X city counts the map again at the start of each month. The next recount removes the difference."

	text += ("This city uses the original SimCity 2000 counts. Each tile change adds or subtracts one, and some changes skip " +
		"the count, so it drifts. Game rules use the saved count.")

	if city.map_size == 128 and saved >= 0x8000 and saved <= 0xffff:
		text += "\nThe count went below zero and wrapped as a 16-bit value. It is %d." % (saved - 0x10000)

	return text


# the first constant name for each building id. aliases follow the tile names
static func _make_tile_constants() -> PackedStringArray:
	var names := PackedStringArray()
	names.resize(Tiles.COUNT)
	var script: Script = Tiles
	var constants := script.get_script_constant_map()

	for key: String in constants:
		var value: Variant = constants[key]

		if value is int and value >= 0 and value < names.size() and names[value].is_empty():
			names[value] = key

	return names


# values sort in groups: numbers, then points, then other values as text.
# the hex column has no value for types other than numbers
static func _state_field(key: String, value: Variant, detail: String) -> DebugTableRecord:
	var result := _field(key, value, detail)
	var number: Variant = value if value is int else null
	var sort_value: Array = [0, value] if value is int else [1, value.x, value.y] if value is Vector2i else [2, str(value)]
	result.sort = [key, sort_value, number, detail]

	return result


static func _site_sort(site: CityRecords.Site) -> Variant:
	return null if site == null else [site.x, site.y, site.width * site.height]


static func _field(key: String, value: Variant, detail: String) -> DebugTableRecord:
	var result := DebugTableRecord.field(key, str(value),
		("-0x%X" % -value if value < 0 else "0x%X" % value) if value is int else "", detail)
	result.id = key

	return result
