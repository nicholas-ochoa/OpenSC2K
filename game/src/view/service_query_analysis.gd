class_name ServiceQueryAnalysis
extends RefCounted

@warning_ignore_start("integer_division")


# display-only contribution of one station. never runs a simulation phase
static func inspect(city: CityState, point: Vector2i, all_stations := false) -> Dictionary:
	if city == null or city.index_of(point.x, point.y) < 0:
		return {"ok": false, "error": "Click a police or fire station."}

	var building := city.building_id(point.x, point.y)
	if building not in [PollutionPhase.POLICE_STATION, PollutionPhase.FIRE_STATION]:
		return {"ok": false, "error": "Click a police or fire station."}

	if all_stations:
		return _inspect_all(city, building)

	var site := TripReachAnalysis._building_site(city, point)
	var origin := Vector2i(-1, -1)
	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			var index := city.index_of(x, y)
			if index >= 0 and city.zones[index] & PollutionPhase.ZONE_BUILDING_ORIGIN:
				origin = Vector2i(x, y)

	if origin.x < 0:
		return {"ok": false, "error": "This station has no valid building origin."}

	var police := building == PollutionPhase.POLICE_STATION
	var funding := PollutionPhase._budget_funding(city, PollutionPhase.BUDGET_POLICE if police else PollutionPhase.BUDGET_FIRE)
	var factor := city.document.misc_i32(PollutionPhase.MISC_PRISON_BONUS) + 5 if police else 5
	var strength := (factor * funding) / 2
	var powered := bool(city.tile_flags[city.index_of(origin.x, origin.y)] & PollutionPhase.FLAG_POWERED)
	if not powered:
		strength = strength / 2

	var native := city.document.full_resolution_maps()
	var values := {}
	if native:
		var pattern := NativeGridMath.service_pattern(strength)
		for dx in range(-15, 16):
			for dy in range(-15, 16):
				var tile := origin + Vector2i(dx, dy)
				var value := clampi(pattern[(dx + 15) * 31 + dy + 15], 0, 255)
				if value > 0 and city.index_of(tile.x, tile.y) >= 0:
					values[tile] = value
	elif origin.x > 0 and origin.y > 0 and origin.x < city.map_size - 1 and origin.y < city.map_size - 1:
		var grid := PackedByteArray()
		var edge := city.map_size / 4
		grid.resize(edge * edge)
		var center := origin / 4
		PollutionPhase._add_service(grid, center.x, center.y, strength, city.map_size)
		for x in range(maxi(0, center.x - 3), mini(edge, center.x + 4)):
			for y in range(maxi(0, center.y - 3), mini(edge, center.y + 4)):
				if grid[x * edge + y] == 0:
					continue
				for dx in 4:
					for dy in 4:
						values[Vector2i(x * 4 + dx, y * 4 + dy)] = int(grid[x * edge + y])

	return {"ok": true, "origin": origin, "site": site, "values": values,
		"name": "Police Station" if police else "Fire Station", "funding": funding,
		"powered": powered, "native": native, "all_stations": false,
		"fire": not police, "sites": [site]}


static func _inspect_all(city: CityState, building: int) -> Dictionary:
	var result: Dictionary = {}
	var values := {}
	var sites: Array[Rect2i] = []
	var powered_count := 0
	for x in city.map_size:
		for y in city.map_size:
			var index := city.index_of(x, y)
			if city.buildings[index] != building or not city.zones[index] & PollutionPhase.ZONE_BUILDING_ORIGIN:
				continue
			var station := inspect(city, Vector2i(x, y))
			if not station.ok:
				continue
			if result.is_empty():
				result = station.duplicate()
			sites.append(station.site)
			powered_count += int(station.powered)
			for tile: Vector2i in station.values:
				values[tile] = mini(255, int(values.get(tile, 0)) + int(station.values[tile]))

	if result.is_empty():
		return {"ok": false, "error": "No valid stations of this type were found."}

	result.merge({"all_stations": true, "values": values, "sites": sites,
		"station_count": sites.size(), "powered_count": powered_count,
		"name": "All Fire Stations" if result.fire else "All Police Stations"}, true)
	return result
