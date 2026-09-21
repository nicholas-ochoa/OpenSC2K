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
const ENGINE_DETAILS := {
	"developed_tiles": "Cached developed-tile count; -1 means not calculated",
	"power_usage_percent": "Last power-use percentage; -1 means not calculated",
	"water_usage_percent": "Last water-use percentage; -1 means not calculated",
	"commerce_connections": "External connections used by commercial demand",
	"industry_connections": "External connections used by industrial demand",
	"bus_passengers": "Runtime bus passengers accumulated for annual XMIC update",
	"rail_passengers": "Runtime rail passengers accumulated for annual XMIC update",
	"subway_passengers": "Runtime subway passengers accumulated for annual XMIC update",
	"pending_interaction": "Player interaction blocking completion of the simulation day",
	"terminal_state": "Scenario or bankruptcy terminal-state flag",
	"ship_home": "Runtime cargo-ship home coordinates",
}
const ENGINE_FIELDS := [
	"developed_tiles", "power_usage_percent", "water_usage_percent", "commerce_connections",
	"industry_connections", "bus_passengers", "rail_passengers", "subway_passengers",
	"mayor_approval", "ship_home", "pending_interaction", "terminal_state",
	"active_disaster_type", "pending_disaster_type", "pending_disaster_point",
	"unsupported_disaster_type", "disaster_map_counter", "disaster_hurricane_counter",
]


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
				var fields: Array[DebugTableRecord] = []

				for key in ENGINE_FIELDS:
					fields.append(_field(key, engine.get(key), ENGINE_DETAILS.get(key, "Published runtime state; not a worker's pending result")))

				for key in ["random", "game_random", "lfsr_random"]:
					var random: RefCounted = engine.get(key)

					if random != null:
						fields.append(_field(key + ".state", random.get("state"), "Current RNG state; read without advancing it"))

				var row := DebugTableRecord.new()
				row.id = "engine"
				row.name = "Simulation state"
				row.value = "%d fields" % fields.size()
				row.fields = fields
				result.append(row)

			var chunks: Array[DebugTableRecord] = []

			for chunk in city.document.chunks:
				chunks.append(_field(chunk.chunk_id, chunk.decoded_payload.size(), "Decoded bytes; original bytes are not rewritten"))

			var row := DebugTableRecord.new()
			row.id = "chunks"
			row.name = "Save chunks"
			row.value = "%d chunks" % chunks.size()
			row.fields = chunks
			result.append(row)

	return result


static func _site_sort(site: CityRecords.Site) -> Variant:
	return null if site == null else [site.x, site.y, site.width * site.height]


static func _field(key: String, value: Variant, detail: String) -> DebugTableRecord:
	return DebugTableRecord.field(key, str(value),
		("-0x%X" % -value if value < 0 else "0x%X" % value) if value is int else "", detail)
