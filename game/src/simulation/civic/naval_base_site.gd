class_name NavalBaseSite
extends RefCounted

const INLAND_STEPS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const LENGTH := 10
const DEPTH := 4


static func find(city: CityState) -> Rect2i:
	if city.document.misc_u32(0x0e44) == 0:
		return Rect2i()
	var edge := city.map_size
	for turn in 4:
		var inland: Vector2i = INLAND_STEPS[(city.compass_rotation() + turn) & 3]
		var along := Vector2i(-inland.y, inland.x)
		for x in range(1, edge - 1):
			if city.simulation_slice != null:
				city.simulation_slice.checkpoint()
			for y in range(1, edge - 1):
				var shore := Vector2i(x, y)
				if not _clear_land(city, shore) or not _salt_water(city, shore - inland):
					continue
				var site := _candidate(city, shore, inland, along)
				if site.has_area():
					return site
	return Rect2i()


static func _candidate(city: CityState, shore: Vector2i, inland: Vector2i, along: Vector2i) -> Rect2i:
	var altitude := city.land_altitude(shore.x, shore.y)
	# a land tile at each end keeps the ten developed columns off the shore ends
	for column in range(-1, LENGTH + 1):
		var point := shore + along * column
		if not _clear_land(city, point) or city.land_altitude(point.x, point.y) != altitude:
			return Rect2i()
		if not _salt_water(city, point - inland):
			return Rect2i()
	for column in LENGTH:
		for row in DEPTH:
			var point := shore + along * column + inland * row
			if not _clear_land(city, point) or city.land_altitude(point.x, point.y) != altitude:
				return Rect2i()
	var last := shore + along * (LENGTH - 1) + inland * (DEPTH - 1)
	return Rect2i(shore.min(last), (shore - last).abs() + Vector2i.ONE)


static func _clear_land(city: CityState, point: Vector2i) -> bool:
	var index := city.index_of(point.x, point.y)
	if index < 0:
		return false
	return city.buildings[index] < BuildingTileIds.SMALL_PARK and city.buildings[index] != BuildingTileIds.RADIOACTIVE_WASTE \
		and city.terrain[index] == TerrainTileIds.FLAT and (city.tile_flags[index] & 4) == 0 \
		and (city.zones[index] & 15) == 0 and city.underground[index] == UndergroundTileIds.EMPTY


static func _salt_water(city: CityState, point: Vector2i) -> bool:
	var index := city.index_of(point.x, point.y)
	return index >= 0 and (city.tile_flags[index] & 5) == 5
