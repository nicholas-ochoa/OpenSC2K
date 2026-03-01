class_name MicrosimAnnualPhase
extends RefCounted

const MISC_SIZE := 4800
const MISC_CITY_CRIME := 0x002c
const MISC_RAW_POPULATION := 0x007c
const MISC_DEMOGRAPHIC_RECORD_SIZE := 0x000c
const MISC_FUNDS := 0x0014
const MISC_TILE_COUNTS := 0x01f0
const MISC_BUDGETS := 0x077c
const MISC_AUTO_GOTO := 0x0ff4
const MISC_NO_DISASTERS := 0x1000
const MISC_ARCOLOGY_POPULATION := 0x1020
const MISC_NORMAL_POPULATION := 0x102c
const MISC_OLD_ARRESTS := 0x1038
const MISC_PRISON_BONUS := 0x103c
const BUDGET_RECORD_SIZE := 0x006c
const BUDGET_FUNDING := 0x04
const BUDGET_POLICE := 5
const BUDGET_FIRE := 6
const BUDGET_HEALTH := 7
const BUDGET_SCHOOL := 8
const BUDGET_COLLEGE := 9
const POWER_PLANT_COSTS := {
	0xc9: 2000,
	0xca: 6600,
	0xcb: 15000,
	0xcc: 1300,
	0xcd: 28000,
	0xce: 40000,
	0xcf: 4000,
}

const TILE_SMALL_PARK := 0x0d
const TILE_HYDRO_ONE := 0xc6
const TILE_HYDRO_TWO := 0xc7
const TILE_WIND_POWER := 0xc8
const TILE_POWER_FIRST := 0xc9
const TILE_POWER_LAST := 0xcf
const TILE_CITY_HALL := 0xd0
const TILE_HOSPITAL := 0xd1
const TILE_POLICE_STATION := 0xd2
const TILE_FIRE_STATION := 0xd3
const TILE_MUSEUM := 0xd4
const TILE_BIG_PARK := 0xd5
const TILE_SCHOOL := 0xd6
const TILE_STADIUM := 0xd7
const TILE_PRISON := 0xd8
const TILE_COLLEGE := 0xd9
const TILE_ZOO := 0xda
const TILE_STATUE := 0xdb
const TILE_SUBWAY_STATION := 0xe9
const TILE_BUS_DEPOT := 0xec
const TILE_RAIL_STATION := 0xed
const TILE_MAYOR_HOUSE := 0xf3
const TILE_WATER_TREATMENT := 0xf4
const TILE_LIBRARY := 0xf5
const TILE_MARINA := 0xf8
const TILE_DESALINIZATION := 0xfa
const TILE_ARCOLOGY_FIRST := 0xfb
const TILE_ARCOLOGY_LAST := 0xfe
const TILE_LAUNCH_ARCOLOGY := 0xfe
const TILE_LLAMADOME := 0xff
const NEWS_POWER_PLANT := 0x24
const NEWS_EDUCATION := 0x26
const NEWS_ARCOLOGY_LAUNCH_START := 0x211
const NEWS_ARCOLOGY_LAUNCH_END := 0x212
const SOUND_EXPLOSION := 504


static func run(
	city: CityState,
	bus_passengers: int,
	rail_passengers: int,
	subway_passengers: int,
	random = null,
	lfsr_random = null,
	game_random = null,
	power_usage_percent := -1,
	water_usage_percent := -1,
	australian_locale := false,
	mayor_approval := 0
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if bus_passengers < 0 or rail_passengers < 0 or subway_passengers < 0:
		return {"ok": false, "error": "passenger totals cannot be negative"}

	var microsim_chunk := city.document.find_chunk("XMIC")
	var misc_chunk := city.document.find_chunk("MISC")

	if (
		microsim_chunk == null
		or microsim_chunk.decoded_payload.size()
		!= city.document.decoded_size("XMIC")
		or misc_chunk == null
		or misc_chunk.decoded_payload.size() != MISC_SIZE
	):
		return {"ok": false, "error": "XMIC or MISC has the wrong size"}

	var old_payloads := BuildingCommand._city_payloads(city)
	var altitude_chunk := city.document.find_chunk("ALTM")

	if (
		old_payloads.is_empty()
		or altitude_chunk == null
		or altitude_chunk.decoded_payload.size() != (map_edge * map_edge) * 2
	):
		return {"ok": false, "error": "annual map payloads are missing or invalid"}

	old_payloads.ALTM = altitude_chunk.decoded_payload.duplicate()
	var changed_payloads := BuildingCommand._duplicate_payloads(old_payloads)
	var microsims: PackedByteArray = changed_payloads.XMIC
	var misc: PackedByteArray = changed_payloads.MISC
	var subway_count := _tile_count(misc, TILE_SUBWAY_STATION, map_edge)
	var bus_count := _tile_count(misc, TILE_BUS_DEPOT, map_edge)
	var rail_count := _tile_count(misc, TILE_RAIL_STATION, map_edge)
	var counts := {
		"hydro": 0,
		"wind": 0,
		"city_hall": 0,
		"museum": 0,
		"park": 0,
		"library": 0,
		"hospital": 0,
		"police": 0,
		"fire": 0,
		"school": 0,
		"stadium": 0,
		"prison": 0,
		"college": 0,
		"power": 0,
		"zoo": 0,
		"statue": 0,
		"mayor_house": 0,
		"water_facility": 0,
		"marina": 0,
		"arcology": 0,
		"llamadome": 0,
	}
	var old_arrests := 0
	var prison_population := 0
	var prison_count := _divide_toward_zero(_tile_count(misc, TILE_PRISON, map_edge), 16)
	var news_items := []
	var random_records_pending := 0
	var low_school_score := false
	var expired_power_records := []
	var demolished_power_records := []
	var arcology_population := 0
	var arcology_launch_pending := false
	var launch_arcology_records := 0
	var launched_structures := 0
	var arcology_launched := false
	var sound_events := []
	var view_center_requests := []
	var effect_events: Array[Dictionary] = []
	var next_effect_frame := 0
	var updated_subway := 0
	var updated_bus := 0
	var updated_rail := 0

	for record_id in range(1, IntegerMath.div_trunc(microsims.size(), CityState.MICROSIM_RECORD_SIZE)):
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var offset := record_id * CityState.MICROSIM_RECORD_SIZE

		match int(microsims[offset]):
			TILE_HYDRO_ONE, TILE_HYDRO_TWO:
				var hydro_count := _tile_count(misc, TILE_HYDRO_ONE, map_edge) + _tile_count(misc, TILE_HYDRO_TWO, map_edge)
				_write_u16_be(microsims, offset + 2, hydro_count)
				_write_u16_be(microsims, offset + 4, hydro_count * 20)
				counts.hydro += 1
			TILE_WIND_POWER:
				var wind_count := _tile_count(misc, TILE_WIND_POWER, map_edge)
				_write_u16_be(microsims, offset + 2, wind_count)
				_write_u16_be(microsims, offset + 4, wind_count * 4)
				counts.wind += 1
			var power_tile when power_tile >= TILE_POWER_FIRST and power_tile <= TILE_POWER_LAST:
				if not _has_process_random(random):
					random_records_pending += 1
					continue

				microsims[offset + 1] = (int(microsims[offset + 1]) + 1) & 0xff
				var power_random: int = random.next_u15()

				if power_usage_percent >= 0:
					_write_u16_be(
						microsims, offset + 4, (power_random & 0x07) + power_usage_percent
					)
				else:
					random_records_pending += 1

				if int(microsims[offset + 1]) > 48:
					news_items.append({"type": NEWS_POWER_PLANT, "argument": power_tile + 0x37})

				if int(microsims[offset + 1]) > 50:
					var location := _find_microsim_location(changed_payloads.XTXT, record_id, map_edge, city.simulation_slice)

					if not location.is_empty():
						var plant_cost: int = POWER_PLANT_COSTS.get(power_tile, 0)
						var funds := _read_i32(misc, MISC_FUNDS)

						if _read_u32(misc, MISC_NO_DISASTERS) != 0 and funds >= plant_cost:
							_write_i32(misc, MISC_FUNDS, funds - plant_cost)
							microsims[offset + 1] = 0
						else:
							var expired_record := {
								"record": record_id,
								"tile": power_tile,
								"x": location.x,
								"y": location.y,
							}
							var demolition := DemolishCommand.damage_structure_payloads(
								city, changed_payloads, Vector2i(location.x, location.y), random, true
							)

							if demolition.get("changed", false):
								next_effect_frame = DemolishCommand.append_effect_sequence(
									effect_events,
									demolition.get("effect_events", []),
									next_effect_frame
								)
								demolished_power_records.append(expired_record)
								sound_events.append(SOUND_EXPLOSION)

								if _read_u32(misc, MISC_AUTO_GOTO) != 0:
									view_center_requests.append(Vector2i(location.x, location.y))
							else:
								expired_power_records.append(expired_record)

				counts.power += 1
			TILE_CITY_HALL:
				_write_u16_be(microsims, offset + 2, _population_cap(misc, 200, 900, map_edge))
				counts.city_hall += 1
			TILE_HOSPITAL:
				if not _has_process_random(random):
					random_records_pending += 1
					continue

				var health_funding := _budget_funding(misc, BUDGET_HEALTH)
				_write_u16_be(microsims, offset + 6, _divide_toward_zero(health_funding, 2))
				var hospital_divisor := _divide_toward_zero(_tile_count(misc, TILE_HOSPITAL, map_edge), 9) * 25
				hospital_divisor = maxi(hospital_divisor, 1)
				var hospital_patients: int = (
					_divide_toward_zero(_read_u32(misc, MISC_NORMAL_POPULATION), hospital_divisor)
					+ (random.next_u15() & 0x0f)
				)

				if hospital_patients > 1000:
					hospital_patients = (random.next_u15() & 0x7f) + 1000

				var hospital_capacity := _population_cap(misc, _to_i16(hospital_patients), 30, map_edge)
				_write_u16_be(microsims, offset + 2, hospital_capacity)
				var hospital_quality: int = (
					health_funding
					+ (random.next_u15() & 0x07)
					+ int(microsims[offset + 1]) * 2
					- 24
				)
				hospital_quality = maxi(hospital_quality, 0)
				var hospital_staff := _population_cap(misc, _to_i16(hospital_quality), 120, map_edge)
				_write_u16_be(microsims, offset + 4, hospital_staff)
				microsims[offset + 1] = _service_score(hospital_capacity * 10, hospital_staff, 5)
				counts.hospital += 1
			TILE_POLICE_STATION:
				if not _has_process_random(random):
					random_records_pending += 1
					continue

				var police_funding := _budget_funding(misc, BUDGET_POLICE)
				microsims[offset + 1] = police_funding & 0xff
				_write_u16_be(
					microsims,
					offset + 2,
					_population_cap(misc, _to_i16(police_funding * 2), 90, map_edge)
				)
				var police_count := maxi(_tile_count(misc, TILE_POLICE_STATION, map_edge), 1)
				var crime_per_station := _divide_toward_zero(
					_read_u32(misc, MISC_CITY_CRIME), police_count
				)
				_write_u16_be(microsims, offset + 4, crime_per_station)
				var arrest_divisor := maxi(5 - _read_u32(misc, MISC_PRISON_BONUS), 1)
				var arrests: int = (
					(random.next_u15() & 0x0f)
					+ _divide_toward_zero(crime_per_station, arrest_divisor)
				)
				_write_u16_be(microsims, offset + 6, arrests)
				old_arrests = mini(old_arrests + (arrests & 0xffff), 0xffff)
				counts.police += 1
			TILE_FIRE_STATION:
				if not _has_process_random(random):
					random_records_pending += 1
					continue

				var fire_funding := _budget_funding(misc, BUDGET_FIRE)
				microsims[offset + 1] = fire_funding & 0xff
				var fire_capacity := _population_cap(
					misc, _to_i16(_divide_toward_zero(fire_funding, 2)), 70, map_edge
				)
				_write_u16_be(microsims, offset + 2, fire_capacity)
				_write_u16_be(microsims, offset + 4, ((fire_capacity & 0xffff) >> 4) + 1)
				_write_u16_be(microsims, offset + 6, (random.next_u15() % 20) + 2)
				counts.fire += 1
			TILE_MUSEUM:
				var museum_count := _tile_count(misc, TILE_MUSEUM, map_edge)
				var college_funding := _budget_funding(misc, BUDGET_COLLEGE)
				_write_u16_be(
					microsims,
					offset + 2,
					_population_cap(misc, _to_i16(museum_count * college_funding * 4), 20, map_edge)
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
					mini(int(IntegerMath.div_trunc(_read_u32(misc, MISC_NORMAL_POPULATION), 6)), 65000)
				)
				_write_u16_be(microsims, offset + 2, park_visitors)
				var park_count := _tile_count(misc, TILE_SMALL_PARK, map_edge) + _tile_count(misc, TILE_BIG_PARK, map_edge)
				_write_u16_be(microsims, offset + 4, park_count)
				_write_u16_be(
					microsims,
					offset + 6,
					_population_cap(misc, int(IntegerMath.div_trunc(park_count, 9)), 120, map_edge)
				)
				counts.park += 1
			TILE_SCHOOL:
				if not _has_process_random(random):
					random_records_pending += 1
					continue

				var school_funding := _budget_funding(misc, BUDGET_SCHOOL)
				var school_funding_quarter := _divide_toward_zero(school_funding, 4)
				_write_u16_be(microsims, offset + 6, school_funding_quarter)

				if (school_funding_quarter & 0xffff) < 20:
					news_items.append({"type": NEWS_EDUCATION, "argument": 0})

				var school_count := maxi(
					_divide_toward_zero(_tile_count(misc, TILE_SCHOOL, map_edge), 9), 1
				)
				var school_students: int = (
					_divide_toward_zero(
						_raw_population(misc, 1) + _raw_population(misc, 2), school_count
					)
					+ (random.next_u15() & 0x0f)
				)

				if school_students > 1500:
					school_students = (random.next_u15() & 0xff) + 1500

				var school_capacity := _population_cap(misc, _to_i16(school_students), 20, map_edge)
				_write_u16_be(microsims, offset + 2, school_capacity)
				var school_quality: int = (
					(random.next_u15() & 0x07)
					+ _divide_toward_zero(school_funding * 6, 10)
					+ int(microsims[offset + 1])
					- 12
				)
				school_quality = maxi(school_quality, 0)
				var school_staff := _population_cap(misc, _to_i16(school_quality), 100, map_edge)
				_write_u16_be(microsims, offset + 4, school_staff)
				var school_score := _service_score(school_capacity, school_staff, 3, 15, 52)
				microsims[offset + 1] = school_score
				low_school_score = low_school_score or school_score < 4
				counts.school += 1
			TILE_STADIUM:
				if not _has_process_random(random):
					random_records_pending += 1
					continue

				var stadium_count := maxi(_tile_count(misc, TILE_STADIUM, map_edge), 1)
				var stadium_visitors := _divide_toward_zero(
					_adjusted_population(misc, map_edge), stadium_count
				)

				if stadium_visitors > 25000:
					stadium_visitors = 25000 - (random.next_u15() & 0xff)

				stadium_visitors = _population_cap(misc, _to_i16(stadium_visitors), 5, map_edge)
				_write_u16_be(
					microsims, offset + 2, stadium_visitors + (random.next_u15() & 0xff)
				)
				microsims[offset + 1] = ((random.next_u15() & 0x1f) + 9) & 0xff
				counts.stadium += 1
			TILE_PRISON:
				if not _has_process_random(random):
					random_records_pending += 1
					continue

				var prison_divisor := maxi(prison_count, 1)
				var prisoners := (
					_read_u16_be(microsims, offset + 2)
					- _divide_toward_zero(_read_u16_be(microsims, offset + 2), 4)
					+ _divide_toward_zero(_read_u32(misc, MISC_OLD_ARRESTS), prison_divisor)
				)

				if prisoners > 10000:
					prisoners = (random.next_u15() & 0x3ff) + 10000

				_write_u16_be(
					microsims, offset + 2, _population_cap(misc, _to_i16(prisoners), 20, map_edge)
				)
				var police_funding := _budget_funding(misc, BUDGET_POLICE)
				_write_u16_be(
					microsims,
					offset + 4,
					_population_cap(misc, _to_i16(police_funding * 3), 120, map_edge)
				)
				var prison_stat := _divide_toward_zero(prisoners, 100)
				_write_u16_be(microsims, offset + 6, prison_stat)
				prison_population += _to_i16(prison_stat)

				if not city.document.is_extended():
					prison_population &= 0xffff

				if prison_stat < 91:
					microsims[offset + 1] = 0
				else:
					var prison_range := (
						prison_stat - 90 + _divide_toward_zero(100 - police_funding, 10)
					)
					microsims[offset + 1] = random.next_u15() % prison_range

				counts.prison += 1
			TILE_COLLEGE:
				if not _has_process_random(random):
					random_records_pending += 1
					continue

				var college_funding := _budget_funding(misc, BUDGET_COLLEGE)
				_write_u16_be(microsims, offset + 6, college_funding)
				var college_count := maxi(
					_divide_toward_zero(_tile_count(misc, TILE_COLLEGE, map_edge), 16), 1
				)
				var college_students: int = (
					_divide_toward_zero(_raw_population(misc, 3), college_count)
					+ (random.next_u15() & 0x1f)
				)

				if college_students > 5000:
					college_students = (random.next_u15() & 0x1ff) + 5000

				var college_capacity := _population_cap(misc, _to_i16(college_students), 30, map_edge)
				_write_u16_be(microsims, offset + 2, college_capacity)
				var college_quality: int = (
					(random.next_u15() & 0x0f)
					+ college_funding * 2
					+ int(microsims[offset + 1]) * 4
					- 48
				)
				college_quality = maxi(college_quality, 0)
				var college_staff := _population_cap(misc, _to_i16(college_quality), 100, map_edge)
				_write_u16_be(microsims, offset + 4, college_staff)
				microsims[offset + 1] = _service_score(college_capacity * 4, college_staff, 5)
				counts.college += 1
			TILE_ZOO:
				if not _has_game_random(game_random):
					random_records_pending += 1
					continue

				microsims[offset + 1] = game_random.next_mod(100) & 0xff
				_write_u16_be(microsims, offset + 2, game_random.next_mod(100))
				_write_u16_be(microsims, offset + 4, game_random.next_mod(100))
				_write_u16_be(microsims, offset + 6, game_random.next_mod(100))
				counts.zoo += 1
			TILE_STATUE:
				if not _has_process_random(random):
					random_records_pending += 1
					continue

				_write_u16_be(microsims, offset + 4, random.next_u15() % 42)
				counts.statue += 1
			TILE_SUBWAY_STATION:
				_write_u16_be(microsims, offset + 2, subway_count)
				_write_u16_be(microsims, offset + 6, subway_passengers)
				updated_subway += 1
			TILE_BUS_DEPOT:
				_write_u16_be(microsims, offset + 2, int(IntegerMath.div_trunc(bus_count, 4)))
				_write_u16_be(microsims, offset + 4, bus_count)
				_write_u16_be(microsims, offset + 6, bus_passengers)
				updated_bus += 1
			TILE_RAIL_STATION:
				_write_u16_be(microsims, offset + 2, int(IntegerMath.div_trunc(rail_count, 4)))
				_write_u16_be(microsims, offset + 6, rail_passengers)
				updated_rail += 1
			TILE_MAYOR_HOUSE:
				_write_u16_be(microsims, offset + 4, mayor_approval)

				if _read_u16_be(microsims, offset + 6) != 0:
					_write_u16_be(microsims, offset + 6, _read_u16_be(microsims, offset + 6) - 1)
					microsims[offset + 1] = (int(microsims[offset + 1]) + 1) & 0xff

				counts.mayor_house += 1
			TILE_WATER_TREATMENT, TILE_DESALINIZATION:
				if not _has_process_random(random):
					random_records_pending += 1
					continue

				var water_first: int = random.next_u15()
				var water_second: int = random.next_u15()
				var water_third: int = random.next_u15()

				if water_usage_percent >= 0:
					microsims[offset + 1] = ((water_first & 0x07) + water_usage_percent) & 0xff
				else:
					random_records_pending += 1

				_write_u16_be(microsims, offset + 2, water_second % 100)
				_write_u16_be(
					microsims,
					offset + 4,
					mini(
						(water_third & 0x1f) + 135,
						_divide_toward_zero(_read_u32(misc, MISC_NORMAL_POPULATION), 50)
					)
				)
				counts.water_facility += 1
			TILE_LIBRARY:
				var library_count := _tile_count(misc, TILE_LIBRARY, map_edge)
				var school_funding := _budget_funding(misc, BUDGET_SCHOOL)
				_write_u16_be(
					microsims,
					offset + 2,
					_population_cap(misc, _to_i16(library_count * school_funding * 4), 18, map_edge)
				)
				var books := (
					_read_u16_be(microsims, offset + 4)
					+ (school_funding - 50) * library_count
				)

				if books > 0 and books < 32000:
					_write_u16_be(microsims, offset + 4, books)

				var population := maxi(_read_u32(misc, MISC_NORMAL_POPULATION), 1)
				var library_score := int(IntegerMath.div_trunc(library_count * school_funding * 300, population))
				microsims[offset + 1] = mini(library_score, 12) & 0xff
				counts.library += 1
			TILE_MARINA:
				if not _has_lfsr_random(lfsr_random):
					random_records_pending += 1
					continue

				_write_u16_be(
					microsims,
					offset + 2,
					_population_cap(
						misc,
						_to_i16(lfsr_random.next_mod(20) + _tile_count(misc, TILE_MARINA, map_edge) * 8),
						150, map_edge
					)
				)
				counts.marina += 1
			var arcology_tile when arcology_tile >= TILE_ARCOLOGY_FIRST and arcology_tile <= TILE_ARCOLOGY_LAST:
				if not _has_lfsr_random(lfsr_random):
					random_records_pending += 1
					continue

				var arcology_count := maxi(_arcology_count(misc, map_edge), 1)
				var arcology_capacity := _population_cap(
					misc,
					_to_i16(_divide_toward_zero(_read_u16_be(microsims, offset + 2) * 1000, 10)),
					arcology_count * 20, map_edge
				) & 0xffff
				var tax_effect := (
					_divide_toward_zero(
						60
						- _budget_funding(misc, 0)
						- _budget_funding(misc, 1)
						- _budget_funding(misc, 2),
						6
					)
					+ int(microsims[offset + 1])
				)
				var arcology_growth := mini((tax_effect * 5 - 50) * 40, arcology_capacity)
				var next_population := (
					arcology_growth
					+ _divide_toward_zero(_read_u16_be(microsims, offset + 4), 50)
					+ _read_u16_be(microsims, offset + 4)
				)
				next_population = mini(
					next_population, _read_u16_be(microsims, offset + 2) * 1000
				)
				var arcology_record_population := (
					_to_i16(lfsr_random.next_mask(0x3f)) + _to_i16(next_population)
				)
				_write_u16_be(microsims, offset + 4, arcology_record_population)
				arcology_population = _to_i32(
					arcology_population + (arcology_record_population & 0xffff)
				)

				if arcology_tile == TILE_LAUNCH_ARCOLOGY:
					launch_arcology_records += 1

				counts.arcology += 1
			TILE_LLAMADOME:
				if not _has_process_random(random):
					random_records_pending += 1
					continue

				if australian_locale:
					_write_u16_be(
						microsims,
						offset + 2,
						(random.next_u15() & 0x3ff)
						+ (_read_u32(misc, MISC_NORMAL_POPULATION) >> 3)
					)
					microsims[offset + 1] = random.next_u15() & 0x7f
					_write_u16_be(microsims, offset + 4, (random.next_u15() & 0x7f) + 10)
				else:
					microsims[offset + 1] = random.next_u15() & 0xff
					var dome_population: int = (
						(_read_u32(misc, MISC_NORMAL_POPULATION) >> 3)
						+ (random.next_u15() & 0x3ff)
					)
					_write_u16_be(microsims, offset + 2, dome_population)
					_write_u16_be(
						microsims, offset + 4, (random.next_u15() & 0x7f) + (dome_population >> 3)
					)
					_write_u16_be(
						microsims, offset + 6, (random.next_u15() & 0x3f) + (dome_population >> 4)
					)

				counts.llamadome += 1

	if _has_process_random(random):
		_write_u32(misc, MISC_OLD_ARRESTS, old_arrests)
		_write_u32(
			misc,
			MISC_PRISON_BONUS,
			0
			if prison_count < 1 or _divide_toward_zero(prison_population, prison_count) > 79
			else 1
		)

		if low_school_score:
			news_items.append({"type": NEWS_EDUCATION, "argument": 0})

	if _has_lfsr_random(lfsr_random):
		_write_u32(misc, MISC_ARCOLOGY_POPULATION, arcology_population)
		arcology_launch_pending = (
			_divide_toward_zero(_tile_count(misc, TILE_LAUNCH_ARCOLOGY, map_edge), 16) > 300
			and arcology_population > 6000000
		)

		if arcology_launch_pending and _has_process_random(random):
			news_items.append({"type": NEWS_ARCOLOGY_LAUNCH_START, "argument": 0})
			var text_overlays: PackedByteArray = changed_payloads.XTXT

			for x in map_edge:
				for y in map_edge:
					var map_index := x * map_edge + y

					if int(OverlayData.read(text_overlays, map_index)) != 0xfe:
						continue

					var demolition := DemolishCommand.damage_structure_payloads(
						city, changed_payloads, Vector2i(x, y), random, true
					)

					if demolition.get("changed", false):
						next_effect_frame = DemolishCommand.append_effect_sequence(
							effect_events,
							demolition.get("effect_events", []),
							next_effect_frame
						)
						launched_structures += 1
						sound_events.append(SOUND_EXPLOSION)

			_write_i32(
				misc,
				MISC_FUNDS,
				_to_i32(_read_i32(misc, MISC_FUNDS) + launch_arcology_records * 100000)
			)
			news_items.append({"type": NEWS_ARCOLOGY_LAUNCH_END, "argument": 0})
			arcology_launched = true
			arcology_launch_pending = false

	var changed_ids := PackedStringArray()

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	if not BuildingCommand._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		return {"ok": false, "error": "cannot store annual microsimulation changes"}

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
		"updated_hospital_records": counts.hospital,
		"updated_police_records": counts.police,
		"updated_fire_records": counts.fire,
		"updated_school_records": counts.school,
		"updated_stadium_records": counts.stadium,
		"updated_prison_records": counts.prison,
		"updated_college_records": counts.college,
		"updated_power_records": counts.power,
		"updated_zoo_records": counts.zoo,
		"updated_statue_records": counts.statue,
		"updated_mayor_house_records": counts.mayor_house,
		"updated_water_facility_records": counts.water_facility,
		"updated_marina_records": counts.marina,
		"updated_arcology_records": counts.arcology,
		"updated_llamadome_records": counts.llamadome,
		"random_records_pending": random_records_pending,
		"expired_power_records": expired_power_records,
		"demolished_power_records": demolished_power_records,
		"arcology_launch_pending": arcology_launch_pending,
		"arcology_launched": arcology_launched,
		"launch_arcology_records": launch_arcology_records,
		"launched_structures": launched_structures,
		"news_items": news_items,
		"effect_events": effect_events,
		"sound_events": sound_events,
		"view_center_requests": view_center_requests,
		"passenger_counters_reset": true,
		"complete": (
			_has_process_random(random)
			and _has_lfsr_random(lfsr_random)
			and random_records_pending == 0
			and expired_power_records.is_empty()
			and not arcology_launch_pending
		),
	}


static func run_transit(
	city: CityState, bus_passengers: int, rail_passengers: int, subway_passengers: int
) -> Dictionary:
	return run(city, bus_passengers, rail_passengers, subway_passengers, null)


static func _tile_count(misc: PackedByteArray, tile_id: int, map_edge: int = 128) -> int:
	var value := _read_u32(misc, MISC_TILE_COUNTS + tile_id * 4)

	return _to_i16(value) if map_edge == 128 else value


static func _budget_funding(misc: PackedByteArray, budget_id: int) -> int:
	return _read_i32(
		misc, MISC_BUDGETS + budget_id * BUDGET_RECORD_SIZE + BUDGET_FUNDING
	)


static func _raw_population(misc: PackedByteArray, cohort: int) -> int:
	return _read_u32(misc, MISC_RAW_POPULATION + cohort * MISC_DEMOGRAPHIC_RECORD_SIZE)


static func _has_process_random(random) -> bool:
	return random != null and random.has_method("next_u15")


static func _has_lfsr_random(random) -> bool:
	return random != null and random.has_method("next_mask") and random.has_method("next_mod")


static func _has_game_random(random) -> bool:
	return random != null and random.has_method("next_mod")


static func _find_microsim_location(text_overlays: PackedByteArray, record_id: int, map_edge: int = 128, budget: SimulationSliceBudget = null) -> Dictionary:
	if OverlayData.count(text_overlays) != map_edge * map_edge:
		return {}

	var text_id := OverlayData.facility_id(record_id)

	for x in map_edge:
		if budget != null:
			budget.checkpoint()

		for y in map_edge:
			if int(OverlayData.read(text_overlays, x * map_edge + y)) == text_id:
				if x == 0 and y == 0:
					return {}

				return {"x": x, "y": y}

	return {}


static func _arcology_count(misc: PackedByteArray, map_edge: int = 128) -> int:
	var count := 0

	for tile_id in range(TILE_ARCOLOGY_FIRST, TILE_ARCOLOGY_LAST + 1):
		count += _tile_count(misc, tile_id, map_edge)

	return _divide_toward_zero(count, 16)


static func _service_score(
	numerator: int, denominator: int, slope: int, best_limit := 50, zero_limit := 111
) -> int:
	var safe_denominator := denominator & 0xffff

	if safe_denominator == 0:
		safe_denominator = 1

	var ratio := _divide_toward_zero(numerator, safe_denominator)

	if ratio < best_limit:
		return 12

	if ratio < zero_limit:
		return _divide_toward_zero(zero_limit - 1 - ratio, slope)

	return 0


static func _adjusted_population(misc: PackedByteArray, map_edge: int = 128) -> int:
	var arcology_count := 0

	for tile_id in range(0xfb, 0xff):
		arcology_count += _tile_count(misc, tile_id, map_edge)

	arcology_count = _divide_toward_zero(arcology_count, 16)
	var adjustment := 0

	if arcology_count > 140:
		adjustment = (arcology_count * 5 - 700) * 4000

	return (
		_read_u32(misc, MISC_ARCOLOGY_POPULATION)
		+ adjustment
		+ _read_u32(misc, MISC_NORMAL_POPULATION)
	)


static func _population_cap(misc: PackedByteArray, maximum: int, divisor: int, map_edge: int = 128) -> int:
	if divisor == 0:
		divisor = 100

	var arcology_count := 0

	for tile_id in range(0xfb, 0xff):
		arcology_count += _tile_count(misc, tile_id, map_edge)

	arcology_count = _divide_toward_zero(arcology_count, 16)
	var arcology_adjustment := 0

	if arcology_count >= 141:
		arcology_adjustment = arcology_count * 20000 - 2800000

	var total_population := (
		arcology_adjustment
		+ _read_u32(misc, MISC_ARCOLOGY_POPULATION)
		+ _read_u32(misc, MISC_NORMAL_POPULATION)
	)
	var available := int(IntegerMath.div_trunc(total_population, divisor)) & (0xffff if map_edge == 128 else 0xffffffff)
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


static func _to_i32(value: int) -> int:
	var wrapped := value & 0xffffffff

	return wrapped - 0x100000000 if wrapped >= 0x80000000 else wrapped


static func _write_u32(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 24) & 0xff
	data[offset + 1] = (value >> 16) & 0xff
	data[offset + 2] = (value >> 8) & 0xff
	data[offset + 3] = value & 0xff


static func _write_i32(data: PackedByteArray, offset: int, value: int) -> void:
	_write_u32(data, offset, value & 0xffffffff)


static func _divide_toward_zero(value: int, divisor: int) -> int:
	if value >= 0:
		return int(IntegerMath.div_trunc(value, divisor))

	return -int(IntegerMath.div_trunc(-value, divisor))


static func _write_u16_be(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 8) & 0xff
	data[offset + 1] = value & 0xff
