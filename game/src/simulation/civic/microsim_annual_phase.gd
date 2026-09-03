class_name MicrosimAnnualPhase
extends MicrosimAnnualValues


@warning_ignore_start("integer_division")


class Result extends PhaseResult:
	var updated_subway_records := 0
	var updated_bus_records := 0
	var updated_rail_records := 0
	var updated_hydro_records := 0
	var updated_wind_records := 0
	var updated_city_hall_records := 0
	var updated_museum_records := 0
	var updated_park_records := 0
	var updated_library_records := 0
	var updated_hospital_records := 0
	var updated_police_records := 0
	var updated_fire_records := 0
	var updated_school_records := 0
	var updated_stadium_records := 0
	var updated_prison_records := 0
	var updated_college_records := 0
	var updated_power_records := 0
	var updated_zoo_records := 0
	var updated_statue_records := 0
	var updated_mayor_house_records := 0
	var updated_water_facility_records := 0
	var updated_marina_records := 0
	var updated_arcology_records := 0
	var updated_llamadome_records := 0
	var random_records_pending := 0
	var demolished_power_records: Array = []
	var expired_power_records: Array = []
	var arcology_launch_pending := false
	var arcology_launched := false
	var launch_arcology_records := 0
	var launched_structures := 0
	var passenger_counters_reset := true


static func run(
	city: CityState,
	bus_passengers: int,
	rail_passengers: int,
	subway_passengers: int,
	random: SimRandom = null,
	lfsr_random: SimLfsrRandom = null,
	game_random: GameLcgRandom = null,
	power_usage_percent := -1,
	water_usage_percent := -1,
	australian_locale := false,
	mayor_approval := 0
) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	if bus_passengers < 0 or rail_passengers < 0 or subway_passengers < 0:
		return _failed("passenger totals cannot be negative")

	var microsim_chunk := city.document.find_chunk("XMIC")
	var misc_chunk := city.document.find_chunk("MISC")

	if (
		microsim_chunk == null
		or microsim_chunk.decoded_payload.size()
		!= city.document.decoded_size("XMIC")
		or misc_chunk == null
		or misc_chunk.decoded_payload.size() != MISC_SIZE
	):
		return _failed("XMIC or MISC has the wrong size")

	var annual := MicrosimAnnualContext.new()
	annual.city = city
	annual.bus_passengers = bus_passengers
	annual.rail_passengers = rail_passengers
	annual.subway_passengers = subway_passengers
	annual.random = random
	annual.lfsr_random = lfsr_random
	annual.game_random = game_random
	annual.power_usage_percent = power_usage_percent
	annual.water_usage_percent = water_usage_percent
	annual.australian_locale = australian_locale
	annual.mayor_approval = mayor_approval
	annual.map_edge = city.map_size
	annual.span = SimulationTimingSpan.new(city.simulation_slice)
	annual.span.mark("prepare data")

	if not _prepare_payloads(annual):
		return _failed("annual map payloads are missing or invalid")

	annual.span.mark("facility records")
	_update_facility_records(annual)

	annual.span.mark("annual totals and arcology launch")
	if annual.random != null:
		_store_prison_and_school_totals(annual)

	if annual.lfsr_random != null:
		_store_arcology_population(annual)

		if annual.arcology_launch_pending and annual.random != null:
			_launch_arcologies(annual)

	annual.span.mark("compare payloads")
	var changed_ids := PackedStringArray()

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		if annual.changed_payloads[chunk_id] != annual.old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	annual.span.mark("store annual changes")
	if not BuildingState._apply_payloads(city, changed_ids, annual.changed_payloads, annual.old_payloads):
		return _failed("cannot store annual microsimulation changes")

	return _result(annual)


# copy the map payloads the annual records may change, and count the transit
# and prison tiles the records share. returns false when a payload is missing
static func _prepare_payloads(annual: MicrosimAnnualContext) -> bool:
	annual.old_payloads = BuildingState._city_payloads(annual.city)
	var altitude_chunk := annual.city.document.find_chunk("ALTM")

	if (
		annual.old_payloads.is_empty()
		or altitude_chunk == null
		or altitude_chunk.decoded_payload.size() != (annual.map_edge * annual.map_edge) * 2
	):
		return false

	annual.old_payloads.ALTM = altitude_chunk.decoded_payload.duplicate()
	annual.changed_payloads = BuildingState._duplicate_payloads(annual.old_payloads)
	annual.microsims = annual.changed_payloads.XMIC
	annual.misc = annual.changed_payloads.MISC
	annual.subway_count = _tile_count(annual.misc, TILE_SUBWAY_STATION, annual.map_edge)
	annual.bus_count = _tile_count(annual.misc, TILE_BUS_DEPOT, annual.map_edge)
	annual.rail_count = _tile_count(annual.misc, TILE_RAIL_STATION, annual.map_edge)
	annual.prison_count = _divide_toward_zero(_tile_count(annual.misc, TILE_PRISON, annual.map_edge), 16)
	annual.counts = {
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

	return true


# run each facility record's annual rule in record order
static func _update_facility_records(annual: MicrosimAnnualContext) -> void:
	for record_id in range(1, annual.microsims.size() / CityState.MICROSIM_RECORD_SIZE):
		if annual.city.simulation_slice != null:
			annual.city.simulation_slice.checkpoint()

		var offset := record_id * CityState.MICROSIM_RECORD_SIZE

		match int(annual.microsims[offset]):
			TILE_HYDRO_ONE, TILE_HYDRO_TWO:
				MicrosimAnnualUtilities.update_hydro_one(annual, record_id, offset)
			TILE_WIND_POWER:
				MicrosimAnnualUtilities.update_wind_power(annual, record_id, offset)
			var power_tile when power_tile >= TILE_POWER_FIRST and power_tile <= TILE_POWER_LAST:
				MicrosimAnnualUtilities.update_power(annual, record_id, offset, power_tile)
			TILE_CITY_HALL:
				MicrosimAnnualAmenities.update_city_hall(annual, record_id, offset)
			TILE_HOSPITAL:
				MicrosimAnnualServices.update_hospital(annual, record_id, offset)
			TILE_POLICE_STATION:
				MicrosimAnnualServices.update_police_station(annual, record_id, offset)
			TILE_FIRE_STATION:
				MicrosimAnnualServices.update_fire_station(annual, record_id, offset)
			TILE_MUSEUM:
				MicrosimAnnualAmenities.update_museum(annual, record_id, offset)
			TILE_BIG_PARK:
				MicrosimAnnualAmenities.update_big_park(annual, record_id, offset)
			TILE_SCHOOL:
				MicrosimAnnualServices.update_school(annual, record_id, offset)
			TILE_STADIUM:
				MicrosimAnnualAmenities.update_stadium(annual, record_id, offset)
			TILE_PRISON:
				MicrosimAnnualServices.update_prison(annual, record_id, offset)
			TILE_COLLEGE:
				MicrosimAnnualServices.update_college(annual, record_id, offset)
			TILE_ZOO:
				MicrosimAnnualAmenities.update_zoo(annual, record_id, offset)
			TILE_STATUE:
				MicrosimAnnualAmenities.update_statue(annual, record_id, offset)
			TILE_SUBWAY_STATION:
				MicrosimAnnualAmenities.update_subway_station(annual, record_id, offset)
			TILE_BUS_DEPOT:
				MicrosimAnnualAmenities.update_bus_depot(annual, record_id, offset)
			TILE_RAIL_STATION:
				MicrosimAnnualAmenities.update_rail_station(annual, record_id, offset)
			TILE_MAYOR_HOUSE:
				MicrosimAnnualAmenities.update_mayor_house(annual, record_id, offset)
			TILE_WATER_TREATMENT, TILE_DESALINIZATION:
				MicrosimAnnualUtilities.update_water_treatment(annual, record_id, offset)
			TILE_LIBRARY:
				MicrosimAnnualAmenities.update_library(annual, record_id, offset)
			TILE_MARINA:
				MicrosimAnnualAmenities.update_marina(annual, record_id, offset)
			var arcology_tile when arcology_tile >= TILE_ARCOLOGY_FIRST and arcology_tile <= TILE_ARCOLOGY_LAST:
				MicrosimAnnualUtilities.update_arcology(annual, record_id, offset, arcology_tile)
			TILE_LLAMADOME:
				MicrosimAnnualAmenities.update_llamadome(annual, record_id, offset)


# store the arrest total and prison bonus, and report a low school score
static func _store_prison_and_school_totals(annual: MicrosimAnnualContext) -> void:
	_write_u32(annual.misc, MISC_OLD_ARRESTS, annual.old_arrests)
	_write_u32(
		annual.misc,
		MISC_PRISON_BONUS,
		0
		if annual.prison_count < 1 or _divide_toward_zero(annual.prison_population, annual.prison_count) > 79
		else 1
	)

	if annual.low_school_score:
		annual.news_items.append({"type": NEWS_EDUCATION, "argument": 0})


# store the arcology population and decide whether the launch is due
static func _store_arcology_population(annual: MicrosimAnnualContext) -> void:
	_write_u32(annual.misc, MISC_ARCOLOGY_POPULATION, annual.arcology_population)
	annual.arcology_launch_pending = (
		_divide_toward_zero(_tile_count(annual.misc, TILE_LAUNCH_ARCOLOGY, annual.map_edge), 16) > 300
		and annual.arcology_population > 6000000
	)


# demolish every launch-marked structure, pay the launch bonus, and report
# the launch
static func _launch_arcologies(annual: MicrosimAnnualContext) -> void:
	annual.news_items.append({"type": NEWS_ARCOLOGY_LAUNCH_START, "argument": 0})
	var text_overlays: PackedByteArray = annual.changed_payloads.XTXT

	for x in annual.map_edge:
		for y in annual.map_edge:
			var map_index := x * annual.map_edge + y

			if int(OverlayData.read(text_overlays, map_index)) != 0xfe:
				continue

			var demolition := DemolishStructures.damage_structure_payloads(
				annual.city, annual.changed_payloads, Vector2i(x, y), annual.random, true
			)

			if demolition.changed:
				annual.next_effect_frame = DemolishEffectsSites.append_effect_sequence(
					annual.effect_events,
					demolition.effect_events,
					annual.next_effect_frame
				)
				annual.launched_structures += 1
				annual.sound_events.append(SOUND_EXPLOSION)

	_write_i32(
		annual.misc,
		MISC_FUNDS,
		_to_i32(_read_i32(annual.misc, MISC_FUNDS) + annual.launch_arcology_records * 100000)
	)
	annual.news_items.append({"type": NEWS_ARCOLOGY_LAUNCH_END, "argument": 0})
	annual.arcology_launched = true
	annual.arcology_launch_pending = false


static func _result(annual: MicrosimAnnualContext) -> Result:
	var result := Result.new()
	result.ok = true
	result.updated_subway_records = annual.updated_subway
	result.updated_bus_records = annual.updated_bus
	result.updated_rail_records = annual.updated_rail
	result.updated_hydro_records = annual.counts.hydro
	result.updated_wind_records = annual.counts.wind
	result.updated_city_hall_records = annual.counts.city_hall
	result.updated_museum_records = annual.counts.museum
	result.updated_park_records = annual.counts.park
	result.updated_library_records = annual.counts.library
	result.updated_hospital_records = annual.counts.hospital
	result.updated_police_records = annual.counts.police
	result.updated_fire_records = annual.counts.fire
	result.updated_school_records = annual.counts.school
	result.updated_stadium_records = annual.counts.stadium
	result.updated_prison_records = annual.counts.prison
	result.updated_college_records = annual.counts.college
	result.updated_power_records = annual.counts.power
	result.updated_zoo_records = annual.counts.zoo
	result.updated_statue_records = annual.counts.statue
	result.updated_mayor_house_records = annual.counts.mayor_house
	result.updated_water_facility_records = annual.counts.water_facility
	result.updated_marina_records = annual.counts.marina
	result.updated_arcology_records = annual.counts.arcology
	result.updated_llamadome_records = annual.counts.llamadome
	result.random_records_pending = annual.random_records_pending
	result.expired_power_records = annual.expired_power_records
	result.demolished_power_records = annual.demolished_power_records
	result.arcology_launch_pending = annual.arcology_launch_pending
	result.arcology_launched = annual.arcology_launched
	result.launch_arcology_records = annual.launch_arcology_records
	result.launched_structures = annual.launched_structures
	result.news_items = annual.news_items
	result.effect_events = annual.effect_events
	result.sound_events = annual.sound_events
	result.view_center_requests = annual.view_center_requests
	result.complete = (
		annual.random != null
		and annual.lfsr_random != null
		and annual.random_records_pending == 0
		and annual.expired_power_records.is_empty()
		and not annual.arcology_launch_pending
	)
	result.timing = annual.span.finish()

	return result


static func run_transit(
	city: CityState, bus_passengers: int, rail_passengers: int, subway_passengers: int
) -> Result:
	return run(city, bus_passengers, rail_passengers, subway_passengers, null)


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result
