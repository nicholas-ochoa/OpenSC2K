class_name ToolAvailability
extends RefCounted
## The tools that a city allows. The native simulation library holds the
## rules; see native/core/sim/src/sim/tools/availability.rs.

const MISC_PROGRESSION := Sc2MiscLayout.PROGRESSION
const MISC_GRANTED_REWARDS := Sc2MiscLayout.GRANTED_REWARDS
const MISC_INVENTION_YEARS := Sc2MiscLayout.INVENTION_YEARS
const MISC_ORDINANCES := Sc2MiscLayout.ORDINANCES
const INVENTION_COUNT := 17
const ORDINANCE_NUCLEAR_FREE := OrdinanceIds.NUCLEAR_FREE_ZONE_MASK
# MISC city mode 2. SIMCITY.EXE FUN_0040b250 disables the Emergency button
# in any other mode and moves a selected Emergency tool to Center
const DISASTER_CITY_MODE := 2


static func inspect(city: CityState) -> Result:
	if city == null or not city.is_valid():
		return Result.failure("city is invalid")

	var chunk := city.document.find_chunk("MISC")

	if chunk == null or chunk.decoded_payload.size() != Sc2MiscLayout.SIZE:
		return Result.failure("MISC is missing or has the wrong size")

	return inspect_misc(chunk.decoded_payload)


static func inspect_misc(misc: PackedByteArray) -> Result:
	var fields := NativeCityTools.tool_availability(misc)
	var result := Result.new()
	result.ok = fields.ok
	result.error = fields.error

	if result.ok:
		result.group_masks = fields.group_masks
		result.power_plant_mask = fields.power_plant_mask
		result.released_inventions = fields.released_inventions
		result.arcology_count = fields.arcology_count
		result.progression = fields.progression
		result.military_base_type = fields.military_base_type

	return result


static func is_dispatch_enabled(city: CityState) -> bool:
	return city != null and city.is_valid() and city.city_mode() == DISASTER_CITY_MODE


static func is_available(city: CityState, group_index: int, subtool_index: int) -> bool:
	var tool := ToolCatalog.tool(group_index, subtool_index)

	if tool == null or not DebugMode.allows_tool(group_index, subtool_index):
		return false

	var valid := city != null and city.is_valid()
	var chunk := city.document.find_chunk("MISC") if valid else null
	var misc := chunk.decoded_payload if chunk != null else PackedByteArray()

	return NativeCityTools.tool_available(misc, city.city_mode() if valid else 0, group_index, subtool_index)


class Result extends RefCounted:
	var ok: bool = false
	var error: String = ""
	var group_masks: PackedInt32Array
	var power_plant_mask: int = 0
	var released_inventions: PackedByteArray
	var arcology_count: int = 0
	var progression: int = 0
	var military_base_type: int = 0

	static func failure(message: String) -> Result:
		var result := Result.new()
		result.error = message

		return result
