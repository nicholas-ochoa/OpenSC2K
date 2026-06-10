class_name BuildingConstants
extends RefCounted

const Availability = preload("res://src/tools/shared/tool_availability.gd")
const Power = preload("res://src/simulation/infrastructure/power_phase.gd")
const Water = preload("res://src/simulation/infrastructure/water_phase.gd")

const MISC_FUNDS := 0x0014
const MISC_ARCOLOGY_POPULATION := 0x1020
const MISC_NORMAL_POPULATION := 0x102c
const IMMEDIATE_UTILITY_POPULATION_LIMIT := 50_000_000
const MISC_TILE_COUNTS := 0x01f0
const MISC_BUDGETS := 0x077c
const MISC_SUBWAY_COUNT := 0x0fe8
const BUDGET_RECORD_SIZE := 0x006c
const BUDGET_CURRENT := {
	0xd1: 7,
	0xd2: 5,
	0xd3: 6,
	0xd6: 8,
	0xd9: 9,
}

const MILITARY_ZONE := 7
const FLAG_WATER := 0x04
const FLAG_PIPED := 0x20
const FLAG_POWERED := 0x40
const FLAG_POWERABLE := 0x80
const STRUCTURE_FLAGS := FLAG_PIPED | FLAG_POWERED | FLAG_POWERABLE
const ROAD_FIRST := 0x1d
const RADIOACTIVITY := 0x05
const SMALL_PARK := 0x0d
const BIG_PARK := 0xd5
const MARINA := 0xf8
const STATUE := 0xdb
const STADIUM := 0xd7
const WATER_PUMP := 0xdc
const SUBWAY_STATION := 0xe9
const UNDER_SUBWAY_FIRST := 0x01
const UNDER_SUBWAY_LAST := 0x0f
const UNDER_PIPE_FIRST := 0x10
const UNDER_PIPE_LAST := 0x1e
const UNDER_PIPE_SUBWAY_LR := 0x1f
const UNDER_PIPE_SUBWAY_TB := 0x20
const UNDER_UNKNOWN := 0x22
const UNDER_SUBWAY_ENTRANCE := 0x23
const MICROSIM_DYNAMIC_FIRST := 10
const MICROSIM_LABEL_BASE := 51
const MISC_STADIUM_TEAMS := 0x1028
const STADIUM_TEAM_COUNT := 5
const STADIUM_TEAM_LABEL_BASE := 0xfb
const DEFAULT_STADIUM_TEAM_NAMES := [
	"Llamas",
	"Alpacas",
	"Camels",
	"Dromedaries",
	"Army Ants",
]
const SOUND_NUISANCE := 0x200
const NUISANCE_BITMAP_ID := 403
const NUISANCE_STRING_ID := 106

const MICROSIM_TYPE_BY_TILE := {
	0xc6: 21,
	0xc7: 21,
	0xc8: 20,
	0xc9: 1,
	0xca: 1,
	0xcb: 1,
	0xcc: 1,
	0xcd: 1,
	0xce: 1,
	0xcf: 1,
	0xd0: 2,
	0xd1: 3,
	0xd2: 4,
	0xd3: 5,
	0xd4: 23,
	0xd5: 22,
	0xd6: 6,
	0xd7: 7,
	0xd8: 8,
	0xd9: 9,
	0xda: 10,
	0xdb: 11,
	0xe9: 19,
	0xec: 17,
	0xed: 18,
	0xf3: 12,
	0xf4: 13,
	0xf5: 24,
	0xf8: 25,
	0xfa: 14,
	0xfb: 15,
	0xfc: 15,
	0xfd: 15,
	0xfe: 15,
	0xff: 16,
}

const DEFAULT_MICROSIM_LABELS := {
	0xc6: "Hydro Power",
	0xc7: "Hydro Power",
	0xc8: "Wind Power",
	0xc9: "Gas Power",
	0xca: "Oil Power",
	0xcb: "Nuclear Power",
	0xcc: "Solar Power",
	0xcd: "Microwave Power",
	0xce: "Fusion Power",
	0xcf: "Coal Power",
	0xd0: "City Hall",
	0xd1: "Hospital",
	0xd2: "Police Station",
	0xd3: "Fire Station",
	0xd4: "Museum",
	0xd5: "SimPark System",
	0xd6: "School",
	0xd7: "Stadium",
	0xd8: "Prison",
	0xd9: "College",
	0xda: "Zoo",
	0xdb: "Statue",
	0xe9: "SimSubway",
	0xec: "SimBus System",
	0xed: "SimRail System",
	0xf3: "Mayor's House",
	0xf4: "Water Treatment",
	0xf5: "Library System",
	0xf8: "Marina",
	0xfa: "Desalinization",
	0xfb: "Plymouth Arco",
	0xfc: "Forest Arco",
	0xfd: "Darco",
	0xfe: "Launch Arco",
	0xff: "Llama Dome",
}

const TILE_BY_TOOL := {
	38: 0xcf,
	40: 0xca,
	41: 0xc9,
	42: 0xcb,
	43: 0xc8,
	44: 0xcc,
	45: 0xcd,
	46: 0xce,
	49: 0xdc,
	50: 0xeb,
	51: 0xf4,
	52: 0xfa,
	60: 0xf3,
	61: 0xd0,
	62: 0xdb,
	63: 0xff,
	65: 0xfb,
	66: 0xfc,
	67: 0xfd,
	68: 0xfe,
	76: 0xec,
	86: 0xed,
	87: 0xe9,
	144: 0xd6,
	145: 0xd9,
	146: 0xf5,
	147: 0xd4,
	156: 0xd2,
	157: 0xd3,
	158: 0xd1,
	159: 0xd8,
	168: 0x0d,
	169: 0xd5,
	170: 0xda,
	171: 0xd7,
	172: 0xf8,
}

const NUISANCE_TILES := {
	0xc9: true,
	0xca: true,
	0xcb: true,
	0xcf: true,
	0xd8: true,
	0xf4: true,
}

const CORNER_BOTTOM_LEFT := [0x10, 0x20, 0x40, 0x80]
const CORNER_BOTTOM_RIGHT := [0x20, 0x40, 0x80, 0x10]
const CORNER_TOP_LEFT := [0x40, 0x80, 0x10, 0x20]
const CORNER_TOP_RIGHT := [0x80, 0x10, 0x20, 0x40]
const NETWORK_SHAPES := [0, 0, 1, 6, 0, 0, 7, 11, 1, 9, 1, 10, 8, 13, 12, 14]
const FORCED_TERRAIN_SHAPES := [0, 2, 3, 4, 5, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1]
const FORCED_TERRAIN_MASKS := {
	1: true,
	2: true,
	3: true,
	4: true,
	9: true,
	10: true,
	11: true,
	12: true,
}
