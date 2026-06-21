class_name PollutionConstants
extends RefCounted

const MAP_SIZE := 64
const SERVICE_MAP_SIZE := 32
const FULL_MAP_SIZE := CityState.MAP_SIZE
const VALUE_COUNT := MAP_SIZE * MAP_SIZE
const MISC_CITY_POLLUTION := 0x0034
const MISC_CITY_LAND_VALUE := 0x0028
const MISC_CITY_CRIME := 0x002c
const MISC_BUDGETS := 0x077c
const MISC_BUDGET_RECORD_SIZE := 0x006c
const MISC_ORDINANCES := 0x0fa0
const MISC_CITY_CENTER_X := 0x1018
const MISC_CITY_CENTER_Y := 0x101c
const MISC_POLLUTION_BONUS := 0x1034
const MISC_PRISON_BONUS := 0x103c
const MISC_TREATMENT_SUFFICIENT := 0x104c
const CLEAN_INDUSTRY_ORDINANCE := 0x00080000
const POLICE_COVERAGE_ORDINANCE := 0x00000800
const FIRE_COVERAGE_ORDINANCE := 0x00000010
const CRIME_REDUCTION_ORDINANCE := 0x00000004
const RADIOACTIVITY := 0x05
const FIRST_TREE := 0x06
const SMALL_PARK := 0x0d
const FIRST_ROAD := 0x1d
const FIRST_POLLUTING_BUILDING := 0x70
const BIG_PARK := 0xd5
const POLICE_STATION := 0xd2
const FIRE_STATION := 0xd3
const FIRST_POWER_PLANT := 0xc6
const FIRST_ARCOLOGY := 0xfb
const LAST_ARCOLOGY := 0xfe
const FLAG_WATER := 0x04
const FLAG_MARK := 0x08
const FLAG_WATERED := 0x10
const FLAG_POWERED := 0x40
const ZONE_BUILDING_ORIGIN := 0x80
const BUDGET_POLICE := 5
const BUDGET_FIRE := 6

const LAND_VALUE_HALVED := {
	0x8a: true, 0x8b: true,
	0xaa: true, 0xab: true, 0xac: true, 0xad: true,
	0xc4: true, 0xc5: true,
}

# nonzero bytes from the supplied executable table at 0x004e95b8
const BUILDING_POLLUTION := {
	0x84: 6, 0x85: 6, 0x86: 6, 0x87: 6,
	0x9e: 12, 0x9f: 12, 0xa0: 12, 0xa1: 12,
	0xa2: 18, 0xa3: 18, 0xa4: 18, 0xa5: 18,
	0xbc: 24, 0xbd: 24, 0xbe: 24, 0xbf: 24, 0xc0: 24, 0xc1: 24,
	0xc9: 10, 0xca: 25, 0xcb: 2, 0xce: 2, 0xcf: 50,
	0xd7: 4, 0xd8: 10, 0xdc: 2, 0xdd: 10, 0xde: 10, 0xdf: 10,
	0xe0: 5, 0xe3: 5, 0xe4: 5, 0xe5: 5, 0xe6: 10, 0xe7: 10,
	0xe9: 5, 0xec: 3, 0xed: 4, 0xee: 2, 0xef: 2, 0xf0: 2, 0xf1: 2,
	0xf2: 10, 0xf4: 10, 0xf6: 5, 0xfb: 25, 0xfc: 10, 0xfd: 12, 0xfe: 15,
}
