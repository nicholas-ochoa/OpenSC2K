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
const SOUND_ZOO := 527


static func success_events(group_index: int, subtool_index: int) -> Array[int]:
	match group_index:
		CityToolIds.Group.LANDSCAPE:
			if subtool_index in [CityToolIds.Landscape.TREES, CityToolIds.Landscape.FOREST]:
				return [SOUND_TREE]

			if subtool_index == CityToolIds.Landscape.WATER:
				return [SOUND_WATER]
		CityToolIds.Group.DISPATCH:
			if subtool_index == CityToolIds.Dispatch.FIRE:
				return [SOUND_FIRE_STATION]

			if subtool_index in [CityToolIds.Dispatch.POLICE, CityToolIds.Dispatch.MILITARY]:
				return [SOUND_SERVICE]
		CityToolIds.Group.POWER:
			if subtool_index == CityToolIds.Power.WIRES:
				return [SOUND_POWER_LINE]

			if subtool_index >= CityToolIds.Power.COAL and subtool_index <= CityToolIds.Power.FUSION:
				return [SOUND_BUILD]
		CityToolIds.Group.WATER:
			if subtool_index >= CityToolIds.Water.PIPES and subtool_index <= CityToolIds.Water.DESALINIZATION:
				return [SOUND_BUILD]
		CityToolIds.Group.REWARDS:
			if subtool_index != CityToolIds.Rewards.ARCOLOGIES and subtool_index >= CityToolIds.Rewards.MAYORS_HOUSE and subtool_index <= CityToolIds.Rewards.LAUNCH:
				return [SOUND_REWARD]
		CityToolIds.Group.ROADS:
			if subtool_index == CityToolIds.Roads.BUS_DEPOT:
				return [SOUND_BUS_DEPOT]

			if subtool_index >= CityToolIds.Roads.ROAD and subtool_index <= CityToolIds.Roads.ONRAMP:
				return [SOUND_BUILD]
		CityToolIds.Group.RAIL:
			if subtool_index == CityToolIds.Rail.RAIL_DEPOT:
				return [SOUND_RAIL_DEPOT, SOUND_BUILD]

			if subtool_index >= CityToolIds.Rail.RAIL and subtool_index <= CityToolIds.Rail.SUBWAY_TO_RAIL:
				return [SOUND_BUILD]
		CityToolIds.Group.PORTS, CityToolIds.Group.RESIDENTIAL, CityToolIds.Group.COMMERCIAL, CityToolIds.Group.INDUSTRIAL:
			return [SOUND_ZONE]
		CityToolIds.Group.EDUCATION:
			return [SOUND_EDUCATION]
		CityToolIds.Group.SERVICES:
			match subtool_index:
				CityToolIds.Services.POLICE_STATION, CityToolIds.Services.HOSPITAL:
					return [SOUND_SERVICE]
				CityToolIds.Services.FIRE_STATION:
					return [SOUND_FIRE_STATION]
				CityToolIds.Services.PRISON:
					return [SOUND_PRISON]
		CityToolIds.Group.RECREATION:
			if subtool_index == CityToolIds.Recreation.ZOO:
				return [SOUND_ZOO]

			if subtool_index >= CityToolIds.Recreation.SMALL_PARK and subtool_index <= CityToolIds.Recreation.MARINA:
				return [SOUND_REWARD]
		CityToolIds.Group.CENTERING:
			return [SOUND_CENTER]

	return []


static func zone_success_events(zone_type: int) -> Array[int]:
	if zone_type >= 1 and zone_type <= 9:
		return [SOUND_ZONE]

	return []


static func failure_events(
	group_index: int, subtool_index: int, error: String = ""
) -> Array[int]:
	if group_index == CityToolIds.Group.LANDSCAPE:
		if error == "insufficient funds":
			return [SOUND_ERROR]

		return []

	if group_index < CityToolIds.Group.POWER or group_index > CityToolIds.Group.RECREATION:
		return []

	if (group_index == CityToolIds.Group.POWER and subtool_index == CityToolIds.Power.PLANTS) or (group_index == CityToolIds.Group.REWARDS and subtool_index == CityToolIds.Rewards.ARCOLOGIES):
		return []

	return [SOUND_ERROR]
