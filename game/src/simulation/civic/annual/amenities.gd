class_name MicrosimAnnualAmenities
extends MicrosimAnnualValues
# update amenities records without changing record or random-call order

@warning_ignore_start("integer_division")


static func update_city_hall(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	_write_u16_be(annual.microsims, offset + 2, _population_cap(annual.misc, 200, 900, annual.map_edge))
	annual.counts.city_hall += 1


static func update_museum(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	var museum_count := _tile_count(annual.misc, TILE_MUSEUM, annual.map_edge)
	var college_funding := _budget_funding(annual.misc, BUDGET_COLLEGE)
	_write_u16_be(
		annual.microsims,
		offset + 2,
		_population_cap(annual.misc, _to_i16(museum_count * college_funding * 4), 20, annual.map_edge)
	)
	_write_u16_be(
		annual.microsims,
		offset + 4,
		_divide_toward_zero(college_funding, 10) * museum_count
	)
	annual.counts.museum += 1


static func update_big_park(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	var old_visitors := _read_u16_be(annual.microsims, offset + 4)
	var park_visitors := mini(old_visitors * 412, 65000)
	park_visitors = mini(
		park_visitors,
		mini(int(_read_u32(annual.misc, MISC_NORMAL_POPULATION) / 6), 65000)
	)
	_write_u16_be(annual.microsims, offset + 2, park_visitors)
	var park_count := _tile_count(annual.misc, TILE_SMALL_PARK, annual.map_edge) + _tile_count(annual.misc, TILE_BIG_PARK, annual.map_edge)
	_write_u16_be(annual.microsims, offset + 4, park_count)
	_write_u16_be(
		annual.microsims,
		offset + 6,
		_population_cap(annual.misc, int(park_count / 9), 120, annual.map_edge)
	)
	annual.counts.park += 1


static func update_stadium(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	if annual.random == null:
		annual.random_records_pending += 1
		return

	var stadium_count := maxi(_tile_count(annual.misc, TILE_STADIUM, annual.map_edge), 1)
	var stadium_visitors := _divide_toward_zero(
		_adjusted_population(annual.misc, annual.map_edge), stadium_count
	)

	if stadium_visitors > 25000:
		stadium_visitors = 25000 - (annual.random.next_u15() & 0xff)

	stadium_visitors = _population_cap(annual.misc, _to_i16(stadium_visitors), 5, annual.map_edge)
	_write_u16_be(
		annual.microsims, offset + 2, stadium_visitors + (annual.random.next_u15() & 0xff)
	)
	annual.microsims[offset + 1] = ((annual.random.next_u15() & 0x1f) + 9) & 0xff
	annual.counts.stadium += 1


static func update_zoo(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	if annual.game_random == null:
		annual.random_records_pending += 1
		return

	annual.microsims[offset + 1] = annual.game_random.next_mod(100) & 0xff
	_write_u16_be(annual.microsims, offset + 2, annual.game_random.next_mod(100))
	_write_u16_be(annual.microsims, offset + 4, annual.game_random.next_mod(100))
	_write_u16_be(annual.microsims, offset + 6, annual.game_random.next_mod(100))
	annual.counts.zoo += 1


static func update_statue(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	if annual.random == null:
		annual.random_records_pending += 1
		return

	_write_u16_be(annual.microsims, offset + 4, annual.random.next_u15() % 42)
	annual.counts.statue += 1


static func update_subway_station(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	_write_u16_be(annual.microsims, offset + 2, annual.subway_count)
	_write_u16_be(annual.microsims, offset + 6, annual.subway_passengers)
	annual.updated_subway += 1


static func update_bus_depot(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	_write_u16_be(annual.microsims, offset + 2, int(annual.bus_count / 4))
	_write_u16_be(annual.microsims, offset + 4, annual.bus_count)
	_write_u16_be(annual.microsims, offset + 6, annual.bus_passengers)
	annual.updated_bus += 1


static func update_rail_station(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	_write_u16_be(annual.microsims, offset + 2, int(annual.rail_count / 4))
	_write_u16_be(annual.microsims, offset + 6, annual.rail_passengers)
	annual.updated_rail += 1


static func update_mayor_house(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	_write_u16_be(annual.microsims, offset + 4, annual.mayor_approval)

	if _read_u16_be(annual.microsims, offset + 6) != 0:
		_write_u16_be(annual.microsims, offset + 6, _read_u16_be(annual.microsims, offset + 6) - 1)
		annual.microsims[offset + 1] = (int(annual.microsims[offset + 1]) + 1) & 0xff

	annual.counts.mayor_house += 1


static func update_library(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	var library_count := _tile_count(annual.misc, TILE_LIBRARY, annual.map_edge)
	var school_funding := _budget_funding(annual.misc, BUDGET_SCHOOL)
	_write_u16_be(
		annual.microsims,
		offset + 2,
		_population_cap(annual.misc, _to_i16(library_count * school_funding * 4), 18, annual.map_edge)
	)
	var books := (
		_read_u16_be(annual.microsims, offset + 4)
		+ (school_funding - 50) * library_count
	)

	if books > 0 and books < 32000:
		_write_u16_be(annual.microsims, offset + 4, books)

	var population := maxi(_read_u32(annual.misc, MISC_NORMAL_POPULATION), 1)
	var library_score := int((library_count * school_funding * 300) / population)
	annual.microsims[offset + 1] = mini(library_score, 12) & 0xff
	annual.counts.library += 1


static func update_marina(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	if annual.lfsr_random == null:
		annual.random_records_pending += 1
		return

	_write_u16_be(
		annual.microsims,
		offset + 2,
		_population_cap(
			annual.misc,
			_to_i16(annual.lfsr_random.next_mod(20) + _tile_count(annual.misc, TILE_MARINA, annual.map_edge) * 8),
			150, annual.map_edge
		)
	)
	annual.counts.marina += 1


static func update_llamadome(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	if annual.random == null:
		annual.random_records_pending += 1
		return

	if annual.australian_locale:
		_write_u16_be(
			annual.microsims,
			offset + 2,
			(annual.random.next_u15() & 0x3ff)
			+ (_read_u32(annual.misc, MISC_NORMAL_POPULATION) >> 3)
		)
		annual.microsims[offset + 1] = annual.random.next_u15() & 0x7f
		_write_u16_be(annual.microsims, offset + 4, (annual.random.next_u15() & 0x7f) + 10)
	else:
		annual.microsims[offset + 1] = annual.random.next_u15() & 0xff
		var dome_population: int = (
			(_read_u32(annual.misc, MISC_NORMAL_POPULATION) >> 3)
			+ (annual.random.next_u15() & 0x3ff)
		)
		_write_u16_be(annual.microsims, offset + 2, dome_population)
		_write_u16_be(
			annual.microsims, offset + 4, (annual.random.next_u15() & 0x7f) + (dome_population >> 3)
		)
		_write_u16_be(
			annual.microsims, offset + 6, (annual.random.next_u15() & 0x3f) + (dome_population >> 4)
		)

	annual.counts.llamadome += 1
