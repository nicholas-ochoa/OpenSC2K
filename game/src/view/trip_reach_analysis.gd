class_name TripReachAnalysis
extends RefCounted

@warning_ignore_start("integer_division")


static func inspect(city: CityState, clicked: Vector2i) -> Dictionary:
	if city == null or not city.is_valid() or city.index_of(clicked.x, clicked.y) < 0:
		return {"ok": false, "error": "Select a tile inside the city."}

	var origin := _growth_anchor(city, clicked)
	var index := city.index_of(origin.x, origin.y)
	var zone := int(city.zones[index]) & 15
	var rci := zone >= 1 and zone <= 6
	var tile := int(city.buildings[index])
	var density := GrowthDevelopment.density(tile) if tile >= 0x70 and tile <= 0xc5 else 0
	var limit := 75 if density == 1 else 100
	var start := -1

	if not rci:
		var mode := _network_mode(tile)

		if mode < 0 and TransportTripSteps._is_subway(int(city.underground[index])):
			mode = TransportTrip.SUBWAY_MODE

		if mode >= 0:
			start = (mode << (14 if city.map_size == 128 else 18)) | index

	var traffic := city.document.find_chunk("XTRF").decoded_payload

	if not TransportTripSearch.valid_inputs(city.buildings, city.zones, city.underground,
		city.text_overlays, city.altitude_words, traffic, city.map_size):
		return {"ok": false, "error": "Transport maps for this city have the wrong size."}

	var result := TransportTripSearch.trace(city.buildings, city.zones, city.underground,
		city.text_overlays, city.altitude_words, traffic, origin, zone if rci else 7,
		density, SimRandom.new(1), 100, city.map_size, true, start)
	_add_building_coverage(city, result, origin)
	var powered := GrowthDevelopment._has_power(city.tile_flags, origin.x, origin.y, city.map_size)
	var demand := city.document.misc_i32(0x0718 + ((zone - 1) / 2) * 4) if rci else 0
	var lines := PackedStringArray()
	if result.get("reachable", []).is_empty():
		lines.append("No transport access within three tiles.")
	elif not rci:
		lines.append("Network exploration. Select an RCI zone to check growth.")

	result.merge({"origin": origin, "clicked": clicked, "limit": limit,
		"summary": lines, "rci": rci, "powered": powered, "demand": demand}, true)
	return result


static func _network_mode(tile: int) -> int:
	if TransportTripSteps._is_highway_span(tile) or (tile >= 0x5d and tile <= 0x60):
		return TransportTrip.HIGHWAY_MODE
	if tile == 0xed:
		return TransportTrip.RAIL_STATION_MODE
	if tile == 0xe9:
		return TransportTrip.SUBWAY_STATION_MODE
	if tile == 0xec:
		return TransportTrip.BUS_STOP_MODE
	if TransportTripSteps._is_surface_road(tile):
		return TransportTrip.ROAD_MODE
	if TransportTripSteps._is_road_bridge(tile):
		return TransportTrip.ROAD_BRIDGE_MODE
	if TransportTripSteps._is_rail(tile):
		return TransportTrip.RAIL_MODE
	return -1


static func _growth_anchor(city: CityState, point: Vector2i) -> Vector2i:
	var tile := city.building_id(point.x, point.y)
	if tile < 0x70:
		return point
	var area := DemolishEffectsSites._building_area(tile)
	var site := DemolishEffectsSites._find_building_site(city.buildings, city.zones, point,
		tile, area, city.compass_rotation(), city.map_size)
	var mask: int = GrowthConstants.ANCHOR_MASKS[city.compass_rotation()]
	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			if city.zones[city.index_of(x, y)] & mask:
				return Vector2i(x, y)
	return point


static func _building_site(city: CityState, point: Vector2i) -> Rect2i:
	var tile := city.building_id(point.x, point.y)
	if tile < 0x70:
		return Rect2i(point, Vector2i.ONE)
	var site := DemolishEffectsSites._find_building_site(city.buildings, city.zones, point,
		tile, DemolishEffectsSites._building_area(tile), city.compass_rotation(), city.map_size)
	# partial buildings or missing corner flags have no complete footprint
	# keep their query coverage and marker on the actual tile, never a zero-area site
	return site if site.has_area() else Rect2i(point, Vector2i.ONE)


static func _cover_site(city: CityState, point: Vector2i, cost: int, tiles: Dictionary) -> void:
	var site := _building_site(city, point)
	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			var part := Vector2i(x, y)
			tiles[part] = mini(cost, int(tiles.get(part, cost)))


static func _add_building_coverage(city: CityState, result: Dictionary, origin: Vector2i) -> void:
	var destinations: Dictionary = result.get("destinations", {}).duplicate()
	for point: Vector2i in result.get("destinations", {}):
		if city.index_of(point.x, point.y) >= 0:
			_cover_site(city, point, int(destinations[point]), destinations)
	var access_tiles := {}
	for node: Dictionary in result.get("reachable", []):
		if int(node.mode) not in [TransportTrip.ROAD_MODE, TransportTrip.BUS_ROAD_MODE,
			TransportTrip.BUS_STOP_MODE, TransportTrip.BUS_RAIL_MODE,
			TransportTrip.RAIL_STATION_MODE, TransportTrip.SUBWAY_STATION_MODE]:
			continue
		for offset: Vector2i in TransportTrip.TRANSPORT_OFFSETS:
			var point: Vector2i = node.point + offset
			var index := city.index_of(point.x, point.y)
			if index >= 0 and ((city.zones[index] & 15) != 0 or city.buildings[index] >= 0x70):
				_cover_site(city, point, int(node.cost), access_tiles)
	var origin_tiles := {}
	_cover_site(city, origin, 0, origin_tiles)
	result.merge({"destinations": destinations, "access_tiles": access_tiles,
		"origin_tiles": origin_tiles}, true)
