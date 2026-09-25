class_name GeneratedCityFixture
extends RefCounted
## Independent city inputs. Change these inputs only during an explicit regeneration.

@warning_ignore_start("integer_division")

const SIZES := [128, 256, 384, 512]
const ROOT := "res://tests/fixtures/cities"
const DAYS := 5 * CityCalendar.DAYS_PER_YEAR
const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")


static func path(edge: int, root := ROOT) -> String:
	return root.path_join("generated-%d.%s" % [edge, "SC2" if edge == 128 else "sc2x"])


static func counts(city: CityState) -> Dictionary:
	var result := {"population": city.population(), "buildings": 0, "roads": 0, "rail": 0,
		"highways": 0, "onramps": 0, "bridges": 0, "tunnels": 0, "power_lines": 0,
		"subways": 0, "pipes": 0, "zones": 0, "signs": 0, "microsims": 0, "moving_objects": 0,
		"water": 0, "salt_water": 0, "trees": 0, "slopes": 0}
	var signs := {}
	var zone_types := {}
	var building_types := {}

	for index in city.buildings.size():
		var tile := int(city.buildings[index])
		result.buildings += int(tile >= Tiles.DEVELOPED_FIRST)
		result.roads += int(tile >= Tiles.FIRST_ROAD and tile <= Tiles.LAST_ROAD)
		result.rail += int(tile >= Tiles.RAIL_FIRST and tile <= Tiles.RAIL_LAST)
		result.highways += int(tile in [0x49, 0x4a] or (tile >= 0x61 and tile <= 0x69))
		result.onramps += int(tile >= Tiles.ONRAMP_FIRST and tile <= Tiles.ONRAMP_LAST)
		result.bridges += int(tile >= 0x51 and tile <= 0x5c or tile in [0x6a, 0x6b])
		result.tunnels += int(tile >= Tiles.TUNNEL_FIRST and tile <= Tiles.TUNNEL_LAST)
		result.power_lines += int(tile >= 0x0e and tile <= 0x1c)
		result.trees += int(tile >= Tiles.TREES_1 and tile <= Tiles.TREES_7)
		result.water += int(city.tile_flags[index] & Sc2TileFlags.WATER != 0)
		result.salt_water += int(city.tile_flags[index] & Sc2TileFlags.SALT_WATER != 0)
		result.slopes += int(city.terrain[index] > 0 and city.terrain[index] < 0x0e)
		var underground := int(city.underground[index])
		result.subways += int(underground >= 1 and underground <= 15 or underground in [31, 32, 35])
		result.pipes += int(underground >= 16 and underground <= 32)
		var zone := int(city.zones[index] & Sc2ZoneLayout.TYPE_MASK)
		result.zones += int(zone != 0)

		if zone != 0:
			zone_types[str(zone)] = int(zone_types.get(str(zone), 0)) + 1

		if tile >= Tiles.DEVELOPED_FIRST:
			building_types[str(tile)] = int(building_types.get(str(tile), 0)) + 1

		var overlay := OverlayData.read(city.text_overlays, index)

		if OverlayData.is_sign(overlay):
			signs[overlay] = true

	result.signs = signs.size()

	for record in city.microsim_count():
		result.microsims += int(city.microsim(record).tile_id != 0)

	for record in city.thing_count():
		result.moving_objects += int(city.thing(record).type != 0)

	result.zone_types = zone_types
	result.building_types = building_types
	return result


static func minimums(edge: int) -> Dictionary:
	return {"population": 1000, "buildings": 200, "roads": 200, "rail": 10,
		"highways": 16, "onramps": 2, "bridges": 1, "tunnels": 2, "power_lines": 20,
		"subways": 10, "pipes": 100, "zones": 300, "signs": 4, "microsims": 15,
		"moving_objects": 1, "water": edge, "salt_water": 1, "trees": 100, "slopes": 20}


static func validate(document: Sc2File, edge: int) -> Dictionary:
	assert(document.is_valid() and document.map_size == edge)
	assert(document.is_extended() == (edge != 128))

	if edge > 128:
		for id in Sc2File.HALF_MAP_CHUNKS + Sc2File.QUARTER_MAP_CHUNKS:
			assert(document.find_chunk(id).decoded_payload.size() == edge * edge)

	var city := CityState.from_document(document)
	assert(city.is_valid(), city.load_error)
	var saved := document.serialize()
	assert(saved.ok, saved.error)
	var loaded := Sc2File.new()
	assert(loaded.parse(saved.data) and loaded.serialize(true).data == saved.data)
	var repair := FacilityRecordRepair.apply(CityState.from_document(loaded))
	assert(repair.ok and repair.created == 0 and repair.linked == 0 and repair.unfilled == 0)
	assert(loaded.serialize(true).data == saved.data, "Facility repair must leave the fixture unchanged")
	var coverage := counts(city)

	for key in minimums(edge):
		assert(coverage[key] >= minimums(edge)[key], "%d %s: %s < %s" % [edge, key, coverage[key], minimums(edge)[key]])

	for zone in [1, 2, 3, 4, 5, 6, 8, 9]:
		assert(int(coverage.zone_types.get(str(zone), 0)) > 0, "Missing zone %d" % zone)

	# Each facility footprint must survive the five-year simulation.
	for tile in [Tiles.COAL_POWER, Tiles.OIL_POWER, Tiles.NUCLEAR_POWER, Tiles.SOLAR_POWER,
		Tiles.FUSION_POWER, Tiles.WATER_PUMP, Tiles.WATER_TOWER, Tiles.WATER_TREATMENT,
		Tiles.POLICE_STATION, Tiles.FIRE_STATION, Tiles.HOSPITAL, Tiles.SCHOOL, Tiles.COLLEGE,
		Tiles.LIBRARY, Tiles.MUSEUM, Tiles.PRISON, Tiles.STADIUM, Tiles.ZOO, Tiles.MARINA,
		Tiles.PLYMOUTH_ARCOLOGY, Tiles.FOREST_ARCOLOGY, Tiles.DARCO_ARCOLOGY, Tiles.LAUNCH_ARCOLOGY,
		Tiles.SUBWAY_STATION, Tiles.RAIL_STATION, Tiles.BUS_DEPOT, Tiles.RUNWAY, Tiles.SEAPORT_WAREHOUSE]:
		assert(int(coverage.building_types.get(str(tile), 0)) >= DemolishStructures.structure_area(tile) ** 2,
			"Missing facility or developed port: %d" % tile)

	assert(city.buildings.has(Tiles.HYDRO_POWER_1) or city.buildings.has(Tiles.HYDRO_POWER_2))
	assert(document.misc_u32(Sc2MiscLayout.NORMAL_POPULATION) >= 1000, "Zones must develop population")

	for id in ["XTRF", "XPLT", "XVAL", "XCRM", "XPOP"]:
		var values := document.find_chunk(id).decoded_payload
		assert(values.count(0) < values.size(), "Simulation must populate " + id)

	return coverage
