class_name CityViewFilter
extends RefCounted

const DEFAULT_VISIBILITY := {
	"buildings": true,
	"networks": true,
	"water": true,
	"trees": true,
	"zones": true,
}


static func surface_copy(source: CityState, visibility: Dictionary) -> CityState:
	if source == null or not source.is_valid():
		return source
	var result := CityState.new()
	result.document = source.document
	result.altitude_words = source.altitude_words.duplicate()
	result.terrain = source.terrain.duplicate()
	result.buildings = source.buildings.duplicate()
	result.zones = source.zones.duplicate()
	result.underground = source.underground.duplicate()
	result.text_overlays = source.text_overlays.duplicate()
	result.tile_flags = source.tile_flags.duplicate()

	var show_buildings := bool(visibility.get("buildings", true))
	var show_networks := bool(visibility.get("networks", true))
	var show_water := bool(visibility.get("water", true))
	var show_trees := bool(visibility.get("trees", true))
	var show_zones := bool(visibility.get("zones", true))
	for index in CityState.TILE_COUNT:
		var building := int(result.buildings[index])
		if not show_buildings and building >= 0x70:
			result.buildings[index] = 0
		elif not show_networks and building >= 0x0e and building <= 0x6f:
			result.buildings[index] = 0
		elif not show_trees and building >= 0x06 and building <= 0x0c:
			result.buildings[index] = 0
		if not show_zones:
			result.zones[index] &= 0xf0
		if not show_water:
			result.tile_flags[index] &= 0xfb
			var terrain := int(result.terrain[index])
			if terrain >= 0x10 and terrain <= 0x1e:
				result.terrain[index] = terrain - 0x10
	return result


static func normalized(visibility: Dictionary) -> Dictionary:
	var result := DEFAULT_VISIBILITY.duplicate()
	for key in result:
		if visibility.has(key):
			result[key] = bool(visibility[key])
	return result
