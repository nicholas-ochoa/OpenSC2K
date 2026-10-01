# gdstyle:ignore-file=quality/max-class-variables
class_name MicrosimAnnualPhase
extends MicrosimAnnualValues


@warning_ignore_start("integer_division")


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
	result.notice_ids = annual.notice_ids
	result.effect_events = annual.effect_events
	result.sound_events = SoundEvent.from_ids(annual.sound_events)
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


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


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
	mayor_approval := 0,
	stage_launch := false
) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	return NativeSimulationBridge.run("microsim_annual", city, random, lfsr_random, game_random, {
		"bus_passengers": bus_passengers, "rail_passengers": rail_passengers,
		"subway_passengers": subway_passengers, "has_random": random != null,
		"has_lfsr": lfsr_random != null, "has_game": game_random != null,
		"power_usage_percent": power_usage_percent, "water_usage_percent": water_usage_percent,
		"australian_locale": australian_locale, "mayor_approval": mayor_approval,
		"stage_launch": stage_launch}).result


# demolish one batch of a staged arcology launch. the last batch requests
# the second launch notice
static func launch_batch(city: CityState, random: SimRandom) -> LaunchBatch:
	if city == null or not city.is_valid():
		var failed := LaunchBatch.new()
		failed.error = "city is invalid"

		return failed

	return NativeSimulationBridge.run("arcology_launch.batch", city, random, null, null).result


class LaunchBatch extends PhaseResult:
	var launched_structures := 0
	var remaining_structures := 0
	var map_changed := false


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
	var demolished_power_records: Array[PowerPlantExpiry] = []
	var expired_power_records: Array[PowerPlantExpiry] = []
	var arcology_launch_pending := false
	var arcology_launched := false
	var launch_arcology_records := 0
	var launched_structures := 0
	# true when the launch arcologies wait for launch_batch
	var arcology_launch_staged := false
	var passenger_counters_reset := true
