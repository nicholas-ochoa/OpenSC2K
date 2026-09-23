class_name ScurkContextScene
extends RefCounted
## Builds a disposable city around the selected artwork.

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const UnderTiles = preload("res://src/tools/shared/underground_tile_ids.gd")
const MAP_SIZE := 16

enum Kind { BUILDING, ROAD, RAIL, POWER, HIGHWAY, UNDERGROUND, TERRAIN, LANDSCAPE, SUPPORT }

var city: CityState
var tile_id := 0
var kind := Kind.BUILDING
var target_sites: Array[Rect2i] = []


func build(selected_tile: int, footprint: int, networks: bool, neighbors: bool) -> void:
	tile_id = selected_tile
	kind = kind_for_tile(tile_id)
	city = CityState.from_document(EmptyCityTemplate.create(MAP_SIZE))
	target_sites.clear()
	for x in MAP_SIZE:
		for y in MAP_SIZE:
			city.set_tile_flag(x, y, Sc2TileFlags.POWERED, true)
	if kind == Kind.BUILDING:
		_build_neighborhood(footprint, networks, neighbors)
	elif kind in [Kind.ROAD, Kind.RAIL, Kind.POWER, Kind.HIGHWAY]:
		_build_network(networks, neighbors)
	elif kind == Kind.UNDERGROUND:
		_build_underground(networks, neighbors)
	else:
		_build_landscape(networks, neighbors)


static func kind_for_tile(tile: int) -> int:
	if (tile >= CityUndergroundView.TERRAIN_WIREFRAME_FIRST and tile <= CityUndergroundView.SUBWAY_AND_PIPE_FIRST + UnderTiles.SUBWAY_ENTRANCE) or (tile >= CityUndergroundView.SUBWAY_AND_PIPE_FIRST + UnderTiles.PIPE_FIRST + CityUndergroundView.WATERED_PIPE_OFFSET and tile <= CityUndergroundView.WATERED_TERRAIN):
		return Kind.UNDERGROUND
	if tile >= 0x100 and tile <= 0x122:
		return Kind.TERRAIN
	if tile > Tiles.MAX_ID:
		return Kind.SUPPORT
	if tile < Tiles.POWER_LINE_FIRST:
		return Kind.LANDSCAPE
	if tile <= Tiles.POWER_LINE_CROSSROADS or tile == Tiles.POWER_BRIDGE:
		return Kind.POWER
	if tile <= Tiles.ROAD_CROSSROADS:
		return Kind.ROAD
	if tile <= Tiles.RAIL_LAST or tile in [Tiles.RAIL_BRIDGE, Tiles.RAIL_BRIDGE_PYLON] or tile in range(Tiles.RAIL_SUBWAY_FIRST, Tiles.RAIL_SUBWAY_LAST + 1):
		return Kind.RAIL
	if tile in range(Tiles.HIGHWAY_STRAIGHT_1, Tiles.HIGHWAY_POWER_CROSSING_2 + 1) or tile in range(Tiles.ONRAMP_FIRST, Tiles.REINFORCED_HIGHWAY_BRIDGE + 1):
		return Kind.HIGHWAY
	if tile < Tiles.DEVELOPED_FIRST:
		return Kind.ROAD if tile <= Tiles.ROAD_RAIL_CROSSING_2 or tile >= Tiles.SUSPENSION_BRIDGE_1 else Kind.RAIL
	return Kind.BUILDING


static func zone_for_tile(tile: int) -> int:
	return ScurkPlaceCommand._zone_for_tile(tile, PackedByteArray(), Rect2i(), 0)


static func family_for_tile(tile: int) -> int:
	var zone := zone_for_tile(tile)
	if zone > 0:
		return (zone - 1) / 2 if zone <= 6 else zone
	for group in [ScurkPickCopy.GROUP_POWER, ScurkPickCopy.GROUP_SPECIAL, ScurkPickCopy.GROUP_TRANSPORTATION, ScurkPickCopy.GROUP_MISC]:
		if ScurkPickCopy.GROUP_TILE_IDS[group].has(tile):
			return 10 + group
	return 0


func _build_neighborhood(footprint: int, networks: bool, neighbors: bool) -> void:
	var primary := Rect2i(5, 5, footprint, footprint)
	target_sites.append(primary)
	_stamp(primary, tile_id)
	if neighbors:
		var distant := Rect2i(10, 10, footprint, footprint)
		target_sites.append(distant)
		_stamp(distant, tile_id)
		var candidates: Array[int] = []
		for candidate in range(Tiles.DEVELOPED_FIRST, Tiles.MAX_ID + 1):
			if candidate != tile_id and family_for_tile(candidate) == family_for_tile(tile_id) and DemolishStructures.structure_area(candidate) == footprint:
				candidates.append(candidate)
		if candidates.is_empty():
			candidates.append(tile_id)
		# The first neighbor touches the target. The others leave open ground.
		var positions := [Vector2i(5 - footprint, 5), Vector2i(5, 5 - footprint), Vector2i(1, 10), Vector2i(10, 1)]
		for index in positions.size():
			_stamp(Rect2i(positions[index], Vector2i.ONE * footprint), candidates[index % candidates.size()])
	if networks:
		for axis in [0, MAP_SIZE - 1]:
			_route(6, 0, Vector2i(axis, 0), Vector2i(axis, MAP_SIZE - 1))
			_route(6, 0, Vector2i(0, axis), Vector2i(MAP_SIZE - 1, axis))


func _build_network(networks: bool, neighbors: bool) -> void:
	var primary := Rect2i(7, 7, 1, 1)
	target_sites.append(primary)
	if neighbors:
		target_sites.append(Rect2i(10, 7, 1, 1))
	if networks:
		if kind == Kind.HIGHWAY:
			for x in range(2, 14):
				city.set_building_id(x, 7, Tiles.HIGHWAY_STRAIGHT_2)
				city.set_building_id(x, 8, Tiles.HIGHWAY_STRAIGHT_2)
		else:
			var group: int = {Kind.ROAD: 6, Kind.RAIL: 7, Kind.POWER: 3}[kind]
			_route(group, 0, Vector2i(2, 7), Vector2i(13, 7))
			_route(group, 0, Vector2i(7, 2), Vector2i(7, 13))
			if tile_id in [Tiles.ROAD_POWER_CROSSING_1, Tiles.ROAD_POWER_CROSSING_2, Tiles.RAIL_POWER_CROSSING_1, Tiles.RAIL_POWER_CROSSING_2]:
				_route(3, 0, Vector2i(10, 2), Vector2i(10, 13))
			elif tile_id in [Tiles.ROAD_RAIL_CROSSING_1, Tiles.ROAD_RAIL_CROSSING_2]:
				_route(7, 0, Vector2i(10, 2), Vector2i(10, 13))
	for site in target_sites:
		city.set_building_id(site.position.x, site.position.y, tile_id)


func _build_underground(networks: bool, neighbors: bool) -> void:
	target_sites.append(Rect2i(7, 7, 1, 1))
	if neighbors:
		target_sites.append(Rect2i(10, 7, 1, 1))
	if not networks:
		return
	var source := tile_id
	var watered := source >= CityUndergroundView.SUBWAY_AND_PIPE_FIRST + UnderTiles.PIPE_FIRST + CityUndergroundView.WATERED_PIPE_OFFSET
	if watered:
		source -= CityUndergroundView.WATERED_PIPE_OFFSET
	var pipe := source >= CityUndergroundView.SUBWAY_AND_PIPE_FIRST + UnderTiles.PIPE_FIRST
	var group := 4 if pipe else 7
	var subtool := 0 if pipe else 1
	_route(group, subtool, Vector2i(2, 7), Vector2i(13, 7))
	_route(group, subtool, Vector2i(7, 2), Vector2i(7, 13))
	if source <= CityUndergroundView.SUBWAY_AND_PIPE_FIRST or source >= CityUndergroundView.SUBWAY_AND_PIPE_FIRST + UnderTiles.PIPE_TB_SUBWAY_LR:
		_route(7, 1, Vector2i(3, 3), Vector2i(12, 3))
		_route(4, 0, Vector2i(3, 10), Vector2i(12, 10))
	if watered:
		for x in MAP_SIZE:
			for y in MAP_SIZE:
				city.set_tile_flag(x, y, Sc2TileFlags.PIPED, true)
				city.set_tile_flag(x, y, Sc2TileFlags.WATERED, true)


func _build_landscape(networks: bool, neighbors: bool) -> void:
	target_sites.append(Rect2i(7, 7, 1, 1))
	if neighbors:
		target_sites.append(Rect2i(10, 7, 1, 1))
	if kind == Kind.TERRAIN:
		for terrain in range(TerrainTileIds.CHANNEL_LAST + 1):
			if CityIsometricRenderer.terrain_sprite_id(terrain, false, 0) == tile_id:
				for x in range(3, 13):
					for y in range(3, 13):
						city.set_terrain_id(x, y, terrain)
				break
	elif kind == Kind.LANDSCAPE:
		if neighbors:
			for point in [Vector2i(6, 7), Vector2i(7, 5), Vector2i(5, 9), Vector2i(10, 9)]:
				city.set_building_id(point.x, point.y, Tiles.TREES_1 + (point.x + point.y) % 7 if tile_id >= Tiles.TREES_1 else Tiles.RUBBLE_1)
		for site in target_sites:
			city.set_building_id(site.position.x, site.position.y, tile_id)
	elif networks:
		_route(6, 0, Vector2i(2, 8), Vector2i(13, 8))


func _route(group: int, subtool: int, start: Vector2i, finish: Vector2i) -> void:
	NetworkCommand.apply(city, group, subtool, start, finish, -1, 0, true)


func _stamp(site: Rect2i, tile: int) -> void:
	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			city.set_building_id(x, y, tile)
			city.set_zone_id(x, y, zone_for_tile(tile))
	BuildingSites.set_corners(city.zones, site, site.size.x, 0, MAP_SIZE)
	city.document.find_chunk("XZON").set_decoded_payload(city.zones)
