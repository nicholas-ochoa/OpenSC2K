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
	result.visible_altitude_levels = source.visible_altitude_levels
	result.altitude_words = source.altitude_words.duplicate()
	result.terrain = source.terrain.duplicate()
	result.buildings = source.buildings.duplicate()
	result.zones = source.zones.duplicate()
	result.underground = source.underground.duplicate()
	result.text_overlays = source.text_overlays.duplicate()
	result.tile_flags = source.tile_flags.duplicate()
	result.object_altitude_overrides = source.object_altitude_overrides.duplicate()

	var show_buildings := bool(visibility.get("buildings", true))
	var show_networks := bool(visibility.get("networks", true))
	var show_water := bool(visibility.get("water", true))
	var show_trees := bool(visibility.get("trees", true))
	var show_zones := bool(visibility.get("zones", true))
	if not show_water:
		result.object_altitude_overrides.resize(CityState.TILE_COUNT)
		result.object_altitude_overrides.fill(-1)
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
			if result.tile_flags[index] & 0x04:
				result.object_altitude_overrides[index] = (
					int(result.altitude_words[index]) >> 5
				) & 0x1f
			result.tile_flags[index] &= 0xfb
			var terrain := int(result.terrain[index])
			if terrain >= 0x10 and terrain <= 0x4f:
				result.terrain[index] = mini(terrain & 0x0f, 0x0e)
	return result


static func normalized(visibility: Dictionary) -> Dictionary:
	var result := DEFAULT_VISIBILITY.duplicate()
	for key in result:
		if visibility.has(key):
			result[key] = bool(visibility[key])
	return result
