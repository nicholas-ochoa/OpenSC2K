class_name DebugCityTables
extends RefCounted
# Read the published city snapshot. Reuse cached scans; do not serialize or draw random values.

const FACILITIES = BuildingCommand.DEFAULT_MICROSIM_LABELS
const STAT_LABELS := {
	0xd1: ["Score", "Patients", "Staff", "Half funding"],
	0xd2: ["Funding", "Funded capacity", "Crime per tile", "Arrests"],
	0xd3: ["Funding", "Funded capacity", "Capacity / 16 + 1", "Annual random statistic"],
	0xd6: ["Score", "Students", "Staff", "Quarter funding"],
	0xd8: ["Type-specific byte", "Prisoners", "Funded capacity", "Prisoners / 100"],
	0xd9: ["Score", "Students", "Staff", "Funding"],
	0xe9: ["Type-specific byte", "Subway tile count", "Preserved statistic", "Annual passengers"],
	0xec: ["Type-specific byte", "Bus tile count / 4", "Bus tile count", "Annual passengers"],
	0xed: ["Type-specific byte", "Rail tile count / 4", "Preserved statistic", "Annual passengers"],
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


static func collect(kind: String, city: CityState, engine: SimulationEngine = null, include_empty := false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if city == null or not city.is_valid():
		return result

	match kind:
		"XMIC":
			var sites := city.microsim_sites()

			for id in city.microsim_count():
				var record := city.microsim(id)
				var tile := int(record.get("tile_id", 0))
				if tile == 0 and not include_empty:
					continue

				var fields: Array[Dictionary] = []
				fields.append(_field("tile_id", tile, "Type"))
				var labels: Array = STAT_LABELS.get(tile, ["Type-specific byte", "Type-specific statistic", "Type-specific statistic", "Type-specific statistic"])

				for index in 4:
					fields.append(_field("stat_%d" % index, record.get("stat_%d" % index, 0),
						labels[index]))

				var value: String = "Empty" if tile == 0 else FACILITIES.get(tile, "Facility 0x%02X" % tile)
				var label := city.label(OverlayData.facility_id(id))
				var site: Dictionary = sites.get(id, {})
				result.append({"id": str(id), "name": "Record %d" % id, "value": value, "raw": "0x%02X" % tile,
					"position": "Not on map" if site.is_empty() else "(%d, %d) %d×%d" % [site.x, site.y, site.width, site.height],
					"site": site, "detail": "-" if label.is_empty() or label == value else label,
					"empty": tile == 0, "fields": fields})
		"Objects":
			for id in city.thing_count():
				var record := city.thing(id)

				if record.type == 0 and not include_empty:
					continue

				var table := DebugObjectFields.table_cells(id, record, city)
				result.append({"id": str(id), "name": "Object %d" % id,
					"value": DebugObjectFields.type_name(record.type),
					"raw": "(%d, %d, %d)" % [record.x, record.y, record.z],
					"cells": table.cells, "tooltips": table.tooltips, "empty": record.type == 0,
					"site": {} if record.type == 0 or city.index_of(record.x, record.y) < 0
						else {"x": record.x, "y": record.y, "width": 1, "height": 1},
					"fields": [{"cells": table.raw, "tooltips": table.tooltips}]})

		"State":
			if engine != null:
				var fields: Array[Dictionary] = []

				for key in ENGINE_FIELDS:
					fields.append(_field(key, engine.get(key), ENGINE_DETAILS.get(key, "Published runtime state; not a worker's pending result")))

				for key in ["random", "game_random", "lfsr_random"]:
					var random: RefCounted = engine.get(key)

					if random != null:
						fields.append(_field(key + ".state", random.get("state"), "Current RNG state; read without advancing it"))

				result.append({"id": "engine", "name": "Simulation state", "value": "%d fields" % fields.size(), "fields": fields})

			var chunks: Array[Dictionary] = []

			for chunk in city.document.chunks:
				chunks.append(_field(chunk.chunk_id, chunk.decoded_payload.size(), "Decoded bytes; original bytes are not rewritten"))

			result.append({"id": "chunks", "name": "Save chunks", "value": "%d chunks" % chunks.size(), "fields": chunks})

	return result


static func _field(key: String, value: Variant, detail: String) -> Dictionary:
	return {"name": key, "value": str(value), "raw": ("-0x%X" % -value if value < 0 else "0x%X" % value) if value is int else "", "detail": detail}
