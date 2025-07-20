class_name MicrosimAnnualPhase
extends RefCounted

const MISC_SIZE := 4800
const MISC_TILE_COUNTS := 0x01f0
const TILE_SUBWAY_STATION := 0xe9
const TILE_BUS_DEPOT := 0xec
const TILE_RAIL_STATION := 0xed


static func run_transit(
	city: CityState, bus_passengers: int, rail_passengers: int, subway_passengers: int
) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if bus_passengers < 0 or rail_passengers < 0 or subway_passengers < 0:
		return {"ok": false, "error": "passenger totals cannot be negative"}
	var microsim_chunk := city.document.find_chunk("XMIC")
	var misc_chunk := city.document.find_chunk("MISC")
	if (
		microsim_chunk == null
		or microsim_chunk.decoded_payload.size()
		!= CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE
		or misc_chunk == null
		or misc_chunk.decoded_payload.size() != MISC_SIZE
	):
		return {"ok": false, "error": "XMIC or MISC has the wrong size"}
	var microsims: PackedByteArray = microsim_chunk.decoded_payload.duplicate()
	var misc: PackedByteArray = misc_chunk.decoded_payload
	var subway_count := _tile_count(misc, TILE_SUBWAY_STATION)
	var bus_count := _tile_count(misc, TILE_BUS_DEPOT)
	var rail_count := _tile_count(misc, TILE_RAIL_STATION)
	var updated_subway := 0
	var updated_bus := 0
	var updated_rail := 0
	for record_id in range(1, CityState.MICROSIM_COUNT):
		var offset := record_id * CityState.MICROSIM_RECORD_SIZE
		match int(microsims[offset]):
			TILE_SUBWAY_STATION:
				_write_u16_be(microsims, offset + 2, subway_count)
				_write_u16_be(microsims, offset + 6, subway_passengers)
				updated_subway += 1
			TILE_BUS_DEPOT:
				_write_u16_be(microsims, offset + 2, int(bus_count / 4))
				_write_u16_be(microsims, offset + 4, bus_count)
				_write_u16_be(microsims, offset + 6, bus_passengers)
				updated_bus += 1
			TILE_RAIL_STATION:
				_write_u16_be(microsims, offset + 2, int(rail_count / 4))
				_write_u16_be(microsims, offset + 6, rail_passengers)
				updated_rail += 1
	if not microsim_chunk.set_decoded_payload(microsims):
		return {"ok": false, "error": "cannot store annual transit statistics"}
	return {
		"ok": true,
		"error": "",
		"updated_subway_records": updated_subway,
		"updated_bus_records": updated_bus,
		"updated_rail_records": updated_rail,
		"passenger_counters_reset": true,
		"complete": false,
	}


static func _tile_count(misc: PackedByteArray, tile_id: int) -> int:
	return _read_u32(misc, MISC_TILE_COUNTS + tile_id * 4) & 0xffff


static func _read_u32(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func _write_u16_be(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 8) & 0xff
	data[offset + 1] = value & 0xff
