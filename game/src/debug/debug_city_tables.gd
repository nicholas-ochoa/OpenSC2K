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
# state tab rows in display order, with their descriptions
const ENGINE_FIELDS := {
	"developed_tiles": "Developed tiles found by the last map scan. -1 until the first scan.",
	"power_usage_percent": "Percent of power capacity in use at the last power update. -1 until the first update.",
	"water_usage_percent": "Percent of water capacity in use at the last water update. -1 until the first update.",
	"commerce_connections": "Connections to neighbor cities that add to commercial demand.",
	"industry_connections": "Connections to neighbor cities that add to industrial demand.",
	"bus_passengers": "Bus passengers counted since the last yearly update. The yearly update writes them to the bus depots.",
	"rail_passengers": "Rail passengers counted since the last yearly update. The yearly update writes them to the rail stations.",
	"subway_passengers": "Subway passengers counted since the last yearly update. The yearly update writes them to the subway stations.",
	"mayor_approval": "Mayor approval from the last update of the mayor's house.",
	"ship_home": "Tile that the cargo ship returns to. (-1, -1) if the city has no cargo ship.",
	"pending_interaction": "Player prompt that stops the current day, such as the yearly budget. Empty if there is no prompt.",
	"terminal_state": "True after the game ends from bankruptcy or a scenario result. The simulation then stops.",
	"active_disaster_type": "ID of the disaster in progress. 0 if there is no disaster.",
	"pending_disaster_type": "ID of the disaster that starts on the next day. 0 if there is no disaster.",
	"pending_disaster_point": "Tile where the pending disaster starts.",
	"unsupported_disaster_type": "ID of a disaster that could not start because it is not supported yet. 0 if there is none.",
	"disaster_map_counter": "Countdown for the active disaster. It decreases by one on each disaster tick.",
	"disaster_hurricane_counter": "Countdown for hurricane wind and floods. It decreases by one on each disaster tick.",
}
const RANDOM_FIELDS := {
	"random": "State of the main random number generator.",
	"game_random": "State of the second random number generator.",
	"lfsr_random": "State of the shift-register random number generator.",
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

		"State":
			if engine != null:
				for key: String in ENGINE_FIELDS:
					result.append(_field(key, engine.get(key), ENGINE_FIELDS[key]))

				for key: String in RANDOM_FIELDS:
					var random: RefCounted = engine.get(key)

					if random != null:
						result.append(_field(key + ".state", random.get("state"), RANDOM_FIELDS[key]))

	return result


static func _site_sort(site: CityRecords.Site) -> Variant:
	return null if site == null else [site.x, site.y, site.width * site.height]


static func _field(key: String, value: Variant, detail: String) -> DebugTableRecord:
	var result := DebugTableRecord.field(key, str(value),
		("-0x%X" % -value if value < 0 else "0x%X" % value) if value is int else "", detail)
	result.id = key

	return result
