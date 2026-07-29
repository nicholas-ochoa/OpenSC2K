class_name BuildingSites
extends BuildingConstants



static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return TILE_BY_TOOL.has(group_index * ToolCatalog.MAX_SLOTS_PER_GROUP + subtool_index)


static func tile_for_tool(group_index: int, subtool_index: int) -> int:
	return int(TILE_BY_TOOL.get(
		group_index * ToolCatalog.MAX_SLOTS_PER_GROUP + subtool_index, 0
	))


# the pointer isn't the footprint origin for the bigger buildings
static func footprint(selected: Vector2i, area: int) -> Rect2i:
	if area < 1 or area > 4:
		return Rect2i()

	var origin := selected

	if area > 2:
		origin -= Vector2i.ONE

	return Rect2i(origin, Vector2i(area, area))


# checks the site without changing the city or consuming random state


static func preview_valid(city: CityState, group: int, subtool: int, point: Vector2i) -> bool:
	return preview_error(city, group, subtool, point).is_empty()


static func preview_error(city: CityState, group: int, subtool: int, point: Vector2i) -> String:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not supports_tool(group, subtool):
		return "No building tool is selected."

	if not Availability.is_available(city, group, subtool):
		return "This building is not available in this city."

	var tool := ToolCatalog.tool(group, subtool)

	if city.funds() < int(tool.cost):
		return "Insufficient funds."

	var site := footprint(point, int(tool.area))

	if not _footprint_is_in_bounds(site, int(tool.area), map_edge):
		return "The building footprint extends outside the map."

	var check := _check_site(city.buildings, city.terrain, city.zones, city.tile_flags, site, tile_for_tool(group, subtool), map_edge)

	return String(check.get("error", ""))


static func _footprint_is_in_bounds(site: Rect2i, area: int, map_edge: int = 128) -> bool:
	if site.size != Vector2i(area, area):
		return false

	if area == 1:
		return site.position.x >= 0 and site.position.y >= 0 and site.end.x <= map_edge and site.end.y <= map_edge

	return site.position.x >= 1 and site.position.y >= 1 and site.end.x <= (map_edge - 1) and site.end.y <= (map_edge - 1)


static func _check_site(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	site: Rect2i,
	tile_id: int,
	map_edge: int = 128,
) -> Dictionary:
	var marina_water_tiles := 0

	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			var index := x * map_edge + y
			var old_building := int(buildings[index])

			if old_building >= ROAD_FIRST or old_building == RADIOACTIVITY or old_building == SMALL_PARK:
				return {"ok": false, "error": "site contains a protected tile"}

			if tile_id == SMALL_PARK and old_building > 0x0c:
				return {"ok": false, "error": "site contains a protected tile"}

			if (zones[index] & 0x0f) == MILITARY_ZONE:
				return {"ok": false, "error": "site is in a military zone"}

			var is_water := (flags[index] & FLAG_WATER) != 0

			if tile_id == MARINA and is_water:
				marina_water_tiles += 1
			elif terrain[index] != 0 or is_water:
				return {"ok": false, "error": "site is not clear"}

	if tile_id == MARINA and (marina_water_tiles == 0 or marina_water_tiles == site.size.x * site.size.y):
		return {"ok": false, "error": "marina must span land and water"}

	return {"ok": true, "error": ""}


static func _count_nearby_residential(
	zones: PackedByteArray, selected: Vector2i, area: int,
	map_edge: int = 128,
) -> int:
	var count := 0

	for x in range(maxi(selected.x - 8, 0), mini(selected.x + area + 8, map_edge)):
		for y in range(maxi(selected.y - 8, 0), mini(selected.y + area + 8, map_edge)):
			var zone := zones[x * map_edge + y] & 0x0f

			if zone == 1 or zone == 2:
				count += 1

	return count


# The zone and building corner flags share one byte.
static func set_corners(zones: PackedByteArray, site: Rect2i, area: int, rotation: int, map_edge: int = 128) -> void:
	if area == 1:
		var index := site.position.x * map_edge + site.position.y
		zones[index] = (zones[index] & 0x0f) | 0xf0

		return

	var far := site.end - Vector2i.ONE
	var view := rotation & 3
	var bottom_left := site.position.x * map_edge + site.position.y
	var bottom_right := far.x * map_edge + site.position.y
	var top_left := far.x * map_edge + far.y
	var top_right := site.position.x * map_edge + far.y
	zones[bottom_left] = (zones[bottom_left] & 0x0f) | CORNER_BOTTOM_LEFT[view]
	zones[bottom_right] = (zones[bottom_right] & 0x0f) | CORNER_BOTTOM_RIGHT[view]
	zones[top_left] = (zones[top_left] & 0x0f) | CORNER_TOP_LEFT[view]
	zones[top_right] = (zones[top_right] & 0x0f) | CORNER_TOP_RIGHT[view]
