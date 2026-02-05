class_name ToolSoundRules
extends RefCounted

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
const SOUND_ZOO := 527


static func success_events(group_index: int, subtool_index: int) -> Array[int]:
	match group_index:
		1:
			if subtool_index == 0:
				return [SOUND_TREE]
			if subtool_index == 1:
				return [SOUND_WATER]
		2:
			if subtool_index == 1:
				return [SOUND_FIRE_STATION]
			if subtool_index in [0, 2]:
				return [SOUND_SERVICE]
		3:
			if subtool_index == 0:
				return [SOUND_POWER_LINE]
			if subtool_index >= 2 and subtool_index <= 10:
				return [SOUND_BUILD]
		4:
			if subtool_index >= 0 and subtool_index <= 4:
				return [SOUND_BUILD]
		5:
			if subtool_index != 4 and subtool_index >= 0 and subtool_index <= 8:
				return [SOUND_REWARD]
		6:
			if subtool_index == 4:
				return [SOUND_BUS_DEPOT]
			if subtool_index >= 0 and subtool_index <= 3:
				return [SOUND_BUILD]
		7:
			if subtool_index == 2:
				return [SOUND_RAIL_DEPOT, SOUND_BUILD]
			if subtool_index >= 0 and subtool_index <= 4:
				return [SOUND_BUILD]
		8, 9, 10, 11:
			return [SOUND_ZONE]
		12:
			return [SOUND_EDUCATION]
		13:
			match subtool_index:
				0, 2:
					return [SOUND_SERVICE]
				1:
					return [SOUND_FIRE_STATION]
				3:
					return [SOUND_PRISON]
		14:
			if subtool_index == 2:
				return [SOUND_ZOO]
			if subtool_index >= 0 and subtool_index <= 4:
				return [SOUND_REWARD]
		17:
			return [SOUND_CENTER]
	return []


static func zone_success_events(zone_type: int) -> Array[int]:
	if zone_type >= 1 and zone_type <= 9:
		return [SOUND_ZONE]
	return []


static func failure_events(
	group_index: int, subtool_index: int, error: String = ""
) -> Array[int]:
	if group_index == 1:
		if error == "insufficient funds":
			return [SOUND_ERROR]
		return []
	if group_index < 3 or group_index > 14:
		return []
	if (group_index == 3 and subtool_index == 1) or (group_index == 5 and subtool_index == 4):
		return []
	return [SOUND_ERROR]
