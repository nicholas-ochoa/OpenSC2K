class_name NetworkTileMembership
extends RefCounted

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const UnderTiles = preload("res://src/tools/shared/underground_tile_ids.gd")


static func surface_road(tile: int) -> bool:
	return (
		(tile >= Tiles.FIRST_ROAD and tile <= Tiles.LAST_ROAD)
		or (tile >= Tiles.TUNNEL_FIRST and tile <= Tiles.ROAD_RAIL_CROSSING_2)
		or tile == Tiles.HIGHWAY_ROAD_CROSSING_1
		or tile == Tiles.HIGHWAY_ROAD_CROSSING_2
		or (tile >= Tiles.ONRAMP_FIRST and tile <= Tiles.ONRAMP_LAST)
	)


static func rail(tile: int) -> bool:
	return (
		(tile >= Tiles.RAIL_FIRST and tile <= Tiles.RAIL_LAST)
		or (tile >= Tiles.ROAD_RAIL_CROSSING_1 and tile <= Tiles.RAIL_POWER_CROSSING_2)
		or (tile >= Tiles.RAIL_SUBWAY_FIRST and tile <= Tiles.RAIL_SUBWAY_LAST)
		or tile == Tiles.HIGHWAY_RAIL_CROSSING_1
		or tile == Tiles.HIGHWAY_RAIL_CROSSING_2
	)


static func subway(tile: int) -> bool:
	return (
		(tile > UnderTiles.EMPTY and tile < UnderTiles.PIPE_FIRST)
		or tile == UnderTiles.PIPE_TB_SUBWAY_LR
		or tile == UnderTiles.PIPE_LR_SUBWAY_TB
		or tile == UnderTiles.MISSILE_SILO
		or tile == UnderTiles.SUBWAY_ENTRANCE
	)
