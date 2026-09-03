class_name PollutionPhase
extends PollutionValues


@warning_ignore_start("integer_division")


class Result extends PhaseResult:
	var pollution_total := 0
	var land_value_total := 0
	var crime_total := 0
	var developed_tiles := 0
	var city_center := Vector2i.ZERO


static func run(city: CityState) -> Result:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return failed("city is invalid")

	if city.document.full_resolution_maps():
		return NativeDataMapPhase.run(city)

	var span := SimulationTimingSpan.new(city.simulation_slice)
	span.mark("pollution sources")
	var misc_chunk := city.document.find_chunk("MISC")
	var traffic_chunk := city.document.find_chunk("XTRF")
	var pollution_chunk := city.document.find_chunk("XPLT")
	var land_value_chunk := city.document.find_chunk("XVAL")
	var crime_chunk := city.document.find_chunk("XCRM")
	var police_chunk := city.document.find_chunk("XPLC")
	var fire_chunk := city.document.find_chunk("XFIR")
	var population_chunk := city.document.find_chunk("XPOP")
	var growth_chunk := city.document.find_chunk("XROG")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != 4800:
		return failed("MISC is missing or has the wrong size")

	if traffic_chunk == null or traffic_chunk.decoded_payload.size() != ((map_edge / 2) * (map_edge / 2)):
		return failed("XTRF is missing or has the wrong size")

	if pollution_chunk == null or pollution_chunk.decoded_payload.size() != ((map_edge / 2) * (map_edge / 2)):
		return failed("XPLT is missing or has the wrong size")

	for checked in [
		[land_value_chunk, "XVAL", ((map_edge / 2) * (map_edge / 2))],
		[crime_chunk, "XCRM", ((map_edge / 2) * (map_edge / 2))],
		[police_chunk, "XPLC", (map_edge / 4) * (map_edge / 4)],
		[fire_chunk, "XFIR", (map_edge / 4) * (map_edge / 4)],
		[population_chunk, "XPOP", (map_edge / 4) * (map_edge / 4)],
		[growth_chunk, "XROG", (map_edge / 4) * (map_edge / 4)],
	]:
		if checked[0] == null or checked[0].decoded_payload.size() != checked[2]:
			return failed("%s is missing or has the wrong size" % checked[1])

	var maps := PollutionMaps.build(
		city, span, map_edge, traffic_chunk, pollution_chunk, crime_chunk,
		population_chunk, growth_chunk
	)

	span.mark("store maps and totals")

	for update in [
		[pollution_chunk, maps.pollution, "XPLT"],
		[land_value_chunk, maps.land_value, "XVAL"],
		[police_chunk, maps.police, "XPLC"],
		[fire_chunk, maps.fire, "XFIR"],
		[population_chunk, maps.population, "XPOP"],
		[growth_chunk, maps.growth, "XROG"],
		[crime_chunk, maps.crime, "XCRM"],
	]:
		if not update[0].set_decoded_payload(update[1]):
			return failed("cannot store updated %s data" % update[2])

	if not city.replace_tile_flags(maps.flags):
		return failed("cannot store updated XBIT data")

	for update in [
		[MISC_CITY_POLLUTION, maps.total],
		[MISC_CITY_LAND_VALUE, maps.land_value_total],
		[MISC_CITY_CRIME, maps.crime_total],
		[MISC_CITY_CENTER_X, maps.center_x * 2],
		[MISC_CITY_CENTER_Y, maps.center_y * 2],
	]:
		if not city.document.set_misc_u32(update[0], update[1]):
			return failed("cannot store MISC value 0x%x" % update[0])

	return totals(
		maps.total,
		maps.land_value_total,
		maps.crime_total,
		maps.developed_tiles,
		Vector2i(maps.center_x * 2, maps.center_y * 2),
		span.finish()
	)


# the legacy and native scans report the same totals
static func totals(
	pollution_total: int,
	land_value_total: int,
	crime_total: int,
	developed_tiles: int,
	city_center: Vector2i,
	timing: SimulationTiming = null
) -> Result:
	var result := Result.new()
	result.ok = true
	result.pollution_total = pollution_total
	result.land_value_total = land_value_total
	result.crime_total = crime_total
	result.developed_tiles = developed_tiles
	result.city_center = city_center
	result.timing = timing if timing != null else SimulationTiming.new()

	return result


static func failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result
