class_name DebugCityTables
extends RefCounted
# Read the published city snapshot without map scans, serialization, or random draws.

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
			for id in city.microsim_count():
				var record := city.microsim(id)
				var tile := int(record.get("tile_id", 0))
				if tile == 0 and not include_empty:
					continue

				var fields: Array[Dictionary] = []
				fields.append(_field("tile_id", tile, "Type byte at +0"))
				var labels: Array = STAT_LABELS.get(tile, ["Type-specific byte", "Type-specific statistic", "Type-specific statistic", "Type-specific statistic"])

				for index in 4:
					fields.append(_field("stat_%d" % index, record.get("stat_%d" % index, 0),
						"%s; %s" % [labels[index], "byte at +1" if index == 0 else "unsigned 16-bit big-endian at +%d" % (index * 2)]))

				result.append({"id": str(id), "name": "Record %d" % id,
					"value": "Empty" if tile == 0 else FACILITIES.get(tile, "Facility 0x%02X" % tile),
					"raw": "0x%02X" % tile, "detail": "XMIC +0x%04X • %s" % [id * 8, city.label(OverlayData.facility_id(id))],
					"empty": tile == 0, "fields": fields})
		"Objects":
			for id in city.thing_count():
				var record := city.thing(id)

				if record.type == 0 and not include_empty:
					continue

				var fields := DebugObjectFields.fields(record, city)
				var position := "(%d, %d, %d)" % [record.x, record.y, record.z]
				result.append({"id": str(id), "name": "Object %d" % id,
					"value": DebugObjectFields.type_name(record.type), "raw": position,
					"cells": ["Object %d" % id,
						DebugObjectFields.numeric(record.type, DebugObjectFields.type_name(record.type)),
						DebugObjectFields.numeric(record.state, DebugObjectFields.state(record, city)),
						position,
						DebugObjectFields.numeric(record.direction, DebugObjectFields.direction(record)),
						DebugObjectFields.numeric(record.goal, DebugObjectFields.goal(record, city))],
					"empty": record.type == 0, "fields": fields})

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
