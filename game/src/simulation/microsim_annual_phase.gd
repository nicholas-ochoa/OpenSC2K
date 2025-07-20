class_name MicrosimAnnualPhase
extends RefCounted

const MISC_SIZE := 4800
const MISC_TILE_COUNTS := 0x01f0
const MISC_BUDGETS := 0x077c
const MISC_ARCOLOGY_POPULATION := 0x1020
const MISC_NORMAL_POPULATION := 0x102c
const BUDGET_RECORD_SIZE := 0x006c
const BUDGET_FUNDING := 0x04
const BUDGET_SCHOOL := 8
const BUDGET_COLLEGE := 9

const TILE_SMALL_PARK := 0x0d
const TILE_HYDRO_ONE := 0xc6
const TILE_HYDRO_TWO := 0xc7
const TILE_WIND_POWER := 0xc8
const TILE_CITY_HALL := 0xd0
const TILE_MUSEUM := 0xd4
const TILE_BIG_PARK := 0xd5
const TILE_SUBWAY_STATION := 0xe9
const TILE_BUS_DEPOT := 0xec
const TILE_RAIL_STATION := 0xed
const TILE_LIBRARY := 0xf5


static func run(
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
	var counts := {
		"hydro": 0,
		"wind": 0,
		"city_hall": 0,
		"museum": 0,
		"park": 0,
		"library": 0,
	}
	var updated_subway := 0
	var updated_bus := 0
	var updated_rail := 0
	for record_id in range(1, CityState.MICROSIM_COUNT):
		var offset := record_id * CityState.MICROSIM_RECORD_SIZE
		match int(microsims[offset]):
			TILE_HYDRO_ONE, TILE_HYDRO_TWO:
				var hydro_count := _tile_count(misc, TILE_HYDRO_ONE) + _tile_count(misc, TILE_HYDRO_TWO)
				_write_u16_be(microsims, offset + 2, hydro_count)
				_write_u16_be(microsims, offset + 4, hydro_count * 20)
				counts.hydro += 1
			TILE_WIND_POWER:
				var wind_count := _tile_count(misc, TILE_WIND_POWER)
				_write_u16_be(microsims, offset + 2, wind_count)
				_write_u16_be(microsims, offset + 4, wind_count * 4)
				counts.wind += 1
			TILE_CITY_HALL:
				_write_u16_be(microsims, offset + 2, _population_cap(misc, 200, 900))
				counts.city_hall += 1
			TILE_MUSEUM:
				var museum_count := _tile_count(misc, TILE_MUSEUM)
				var college_funding := _budget_funding(misc, BUDGET_COLLEGE)
				_write_u16_be(
					microsims,
					offset + 2,
					_population_cap(misc, _to_i16(museum_count * college_funding * 4), 20)
				)
				_write_u16_be(
					microsims,
					offset + 4,
					_divide_toward_zero(college_funding, 10) * museum_count
				)
				counts.museum += 1
			TILE_BIG_PARK:
				var old_visitors := _read_u16_be(microsims, offset + 4)
				var park_visitors := mini(old_visitors * 412, 65000)
				park_visitors = mini(
					park_visitors,
					mini(int(_read_u32(misc, MISC_NORMAL_POPULATION) / 6), 65000)
				)
				_write_u16_be(microsims, offset + 2, park_visitors)
				var park_count := _tile_count(misc, TILE_SMALL_PARK) + _tile_count(misc, TILE_BIG_PARK)
				_write_u16_be(microsims, offset + 4, park_count)
				_write_u16_be(
					microsims,
					offset + 6,
					_population_cap(misc, int(park_count / 9), 120)
				)
				counts.park += 1
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
			TILE_LIBRARY:
				var library_count := _tile_count(misc, TILE_LIBRARY)
				var school_funding := _budget_funding(misc, BUDGET_SCHOOL)
				_write_u16_be(
					microsims,
					offset + 2,
					_population_cap(misc, _to_i16(library_count * school_funding * 4), 18)
				)
				var books := (
					_read_u16_be(microsims, offset + 4)
					+ (school_funding - 50) * library_count
				)
				if books > 0 and books < 32000:
					_write_u16_be(microsims, offset + 4, books)
				var population := maxi(_read_u32(misc, MISC_NORMAL_POPULATION), 1)
				var library_score := int(library_count * school_funding * 300 / population)
				microsims[offset + 1] = mini(library_score, 12) & 0xff
				counts.library += 1
	if not microsim_chunk.set_decoded_payload(microsims):
		return {"ok": false, "error": "cannot store annual microsimulation statistics"}
	return {
		"ok": true,
		"error": "",
		"updated_subway_records": updated_subway,
		"updated_bus_records": updated_bus,
		"updated_rail_records": updated_rail,
		"updated_hydro_records": counts.hydro,
		"updated_wind_records": counts.wind,
		"updated_city_hall_records": counts.city_hall,
		"updated_museum_records": counts.museum,
		"updated_park_records": counts.park,
		"updated_library_records": counts.library,
		"passenger_counters_reset": true,
		"complete": false,
	}


static func run_transit(
	city: CityState, bus_passengers: int, rail_passengers: int, subway_passengers: int
) -> Dictionary:
	return run(city, bus_passengers, rail_passengers, subway_passengers)


static func _tile_count(misc: PackedByteArray, tile_id: int) -> int:
	return _to_i16(_read_u32(misc, MISC_TILE_COUNTS + tile_id * 4))


static func _budget_funding(misc: PackedByteArray, budget_id: int) -> int:
	return _read_i32(
		misc, MISC_BUDGETS + budget_id * BUDGET_RECORD_SIZE + BUDGET_FUNDING
	)


static func _population_cap(misc: PackedByteArray, maximum: int, divisor: int) -> int:
	if divisor == 0:
		divisor = 100
	var arcology_count := 0
	for tile_id in range(0xfb, 0xff):
		arcology_count += _tile_count(misc, tile_id)
	arcology_count = _divide_toward_zero(arcology_count, 16)
	var arcology_adjustment := 0
	if arcology_count >= 141:
		arcology_adjustment = arcology_count * 20000 - 2800000
	var total_population := (
		arcology_adjustment
		+ _read_u32(misc, MISC_ARCOLOGY_POPULATION)
		+ _read_u32(misc, MISC_NORMAL_POPULATION)
	)
	var available := int(total_population / divisor) & 0xffff
	var signed_maximum := _to_i16(maximum)
	return signed_maximum if signed_maximum <= available else available


static func _read_u32(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func _read_i32(data: PackedByteArray, offset: int) -> int:
	var value := _read_u32(data, offset)
	return value - 0x100000000 if value >= 0x80000000 else value


static func _read_u16_be(data: PackedByteArray, offset: int) -> int:
	return (data[offset] << 8) | data[offset + 1]


static func _to_i16(value: int) -> int:
	var wrapped := value & 0xffff
	return wrapped - 0x10000 if wrapped >= 0x8000 else wrapped


static func _divide_toward_zero(value: int, divisor: int) -> int:
	if value >= 0:
		return int(value / divisor)
	return -int(-value / divisor)


static func _write_u16_be(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 8) & 0xff
	data[offset + 1] = value & 0xff
