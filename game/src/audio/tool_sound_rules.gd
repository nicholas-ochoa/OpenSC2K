class_name ToolSoundRules
extends RefCounted

const SOUND_TRACTOR := 508
const SOUND_BUILD := 500
const SOUND_ERROR := 501
const SOUND_ZONE := 503
const SOUND_CENTER := 505
const SOUND_SERVICE := 506
const SOUND_FIRE_STATION := 509
const SOUND_TREE := 503
const SOUND_WATER := 511
const SOUND_REWARD := 513
const SOUND_POWER_LINE := 514
const SOUND_BUS_DEPOT := 521
const SOUND_PRISON := 522
const SOUND_EDUCATION := 523
const SOUND_RAIL_DEPOT := 524
const SOUND_MILITARY := 525
const SOUND_ZOO := 527


# The native simulation library holds the rules; see
# native/core/sim/src/sim/tools/sounds.rs
static func success_events(group_index: int, subtool_index: int) -> Array[int]:
	return _sounds(NativeCityTools.tool_success_sounds(group_index, subtool_index))


static func zone_success_events(zone_type: int) -> Array[int]:
	return _sounds(NativeCityTools.zone_success_sounds(zone_type))


static func failure_events(
	group_index: int, subtool_index: int, error: String = ""
) -> Array[int]:
	return _sounds(NativeCityTools.tool_failure_sounds(group_index, subtool_index, error))


static func _sounds(values: PackedInt32Array) -> Array[int]:
	var result: Array[int] = []
	result.assign(Array(values))

	return result
