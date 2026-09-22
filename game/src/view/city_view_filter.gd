class_name CityViewFilter
extends RefCounted

# xthg types in the vehicles layer: airplanes, helicopters, cargo ships,
# sailboats, and surface and subway trains. disaster objects stay visible
const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const VEHICLE_THING_TYPES := [1, 2, 3, 9, 10, 11, 12, 13]
const DEFAULT_VISIBILITY := {
	"buildings": true,
	"networks": true,
	"water": true,
	"trees": true,
	"zones": true,
}


static func surface_copy(source: CityState, visibility: Dictionary) -> CityState:
	var map_edge: int = source.map_size if source != null else 128

	if source == null or not source.is_valid():
		return source

	var result := CityState.new()
	result.document = source.document
	result.map_size = source.map_size
	result.visible_altitude_levels = source.visible_altitude_levels
	source.copy_mirrors_to(result)
	result.object_altitude_overrides = source.object_altitude_overrides.duplicate()

	var show_buildings := bool(visibility.get("buildings", true))
	var show_networks := bool(visibility.get("networks", true))
	var show_water := bool(visibility.get("water", true))
	var show_trees := bool(visibility.get("trees", true))
	var show_zones := bool(visibility.get("zones", true))

	if show_buildings and show_networks and show_water and show_trees and show_zones:
		return result

	if not show_water:
		result.object_altitude_overrides.resize((map_edge * map_edge))
		result.object_altitude_overrides.fill(-1)

	for index in (map_edge * map_edge):
		var building := int(result.buildings[index])

		if not show_buildings and building >= Tiles.DEVELOPED_FIRST:
			result.buildings[index] = Tiles.EMPTY
		elif not show_networks and building >= Tiles.POWER_LINE_STRAIGHT_1 and building <= Tiles.RAIL_SUBWAY_ENTRANCE_4:
			result.buildings[index] = Tiles.EMPTY
		elif not show_trees and building >= Tiles.TREES_1 and building <= Tiles.TREES_7:
			result.buildings[index] = Tiles.EMPTY

		if not show_zones:
			result.zones[index] &= 0xf0

		if not show_water:
			if result.tile_flags[index] & 0x04:
				result.object_altitude_overrides[index] = (
					int(result.altitude_words[index]) >> 5
				) & 0x1f

			result.tile_flags[index] &= 0xfb
			var terrain := int(result.terrain[index])

			if terrain >= TerrainTileIds.DEEP_WATER_FIRST and terrain <= TerrainTileIds.WATER_RANGE_LAST:
				result.terrain[index] = mini(terrain & TerrainTileIds.SHAPE_MASK, TerrainTileIds.LAND_DRAW_LAST)

	return result


static func normalized(visibility: Dictionary) -> Dictionary:
	var result := DEFAULT_VISIBILITY.duplicate()

	for key in result:
		if visibility.has(key):
			result[key] = bool(visibility[key])

	return result
