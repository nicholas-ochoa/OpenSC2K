class_name BuildingConstants
extends BuildingTileIds

const UnderTiles = preload("res://src/tools/shared/underground_tile_ids.gd")

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

const MILITARY_ZONE := 7
const FLAG_WATER := 0x04
const FLAG_PIPED := 0x20
const FLAG_POWERED := 0x40
const FLAG_POWERABLE := 0x80
const STRUCTURE_FLAGS := FLAG_PIPED | FLAG_POWERED | FLAG_POWERABLE
const ROAD_FIRST := BuildingTileIds.FIRST_ROAD
const RADIOACTIVITY := BuildingTileIds.RADIOACTIVE_WASTE
const UNDER_SUBWAY_FIRST := UnderTiles.SUBWAY_FIRST
const UNDER_SUBWAY_LAST := UnderTiles.SUBWAY_LAST
const UNDER_PIPE_FIRST := UnderTiles.PIPE_FIRST
const UNDER_PIPE_LAST := UnderTiles.PIPE_LAST
const UNDER_PIPE_SUBWAY_LR := UnderTiles.PIPE_SUBWAY_ONE
const UNDER_PIPE_SUBWAY_TB := UnderTiles.PIPE_SUBWAY_TWO
const UNDER_UNKNOWN := UnderTiles.MISSILE_SILO
const UNDER_SUBWAY_ENTRANCE := UnderTiles.SUBWAY_ENTRANCE
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

const BUDGET_CURRENT := {
	HOSPITAL: 7,
	POLICE_STATION: 5,
	FIRE_STATION: 6,
	SCHOOL: 8,
	COLLEGE: 9,
}

const MICROSIM_TYPE_BY_TILE := {
	HYDRO_POWER_ONE: 21,
	HYDRO_POWER_TWO: 21,
	WIND_POWER: 20,
	GAS_POWER: 1,
	OIL_POWER: 1,
	NUCLEAR_POWER: 1,
	SOLAR_POWER: 1,
	MICROWAVE_POWER: 1,
	FUSION_POWER: 1,
	COAL_POWER: 1,
	CITY_HALL: 2,
	HOSPITAL: 3,
	POLICE_STATION: 4,
	FIRE_STATION: 5,
	MUSEUM: 23,
	BIG_PARK: 22,
	SCHOOL: 6,
	STADIUM: 7,
	PRISON: 8,
	COLLEGE: 9,
	ZOO: 10,
	STATUE: 11,
	SUBWAY_STATION: 19,
	BUS_DEPOT: 17,
	RAIL_STATION: 18,
	MAYOR_HOUSE: 12,
	WATER_TREATMENT: 13,
	LIBRARY: 24,
	MARINA: 25,
	DESALINIZATION: 14,
	PLYMOUTH_ARCOLOGY: 15,
	FOREST_ARCOLOGY: 15,
	DARCO_ARCOLOGY: 15,
	LAUNCH_ARCOLOGY: 15,
	LLAMA_DOME: 16,
}

const DEFAULT_MICROSIM_LABELS := {
	HYDRO_POWER_ONE: "Hydro Power",
	HYDRO_POWER_TWO: "Hydro Power",
	WIND_POWER: "Wind Power",
	GAS_POWER: "Gas Power",
	OIL_POWER: "Oil Power",
	NUCLEAR_POWER: "Nuclear Power",
	SOLAR_POWER: "Solar Power",
	MICROWAVE_POWER: "Microwave Power",
	FUSION_POWER: "Fusion Power",
	COAL_POWER: "Coal Power",
	CITY_HALL: "City Hall",
	HOSPITAL: "Hospital",
	POLICE_STATION: "Police Station",
	FIRE_STATION: "Fire Station",
	MUSEUM: "Museum",
	BIG_PARK: "SimPark System",
	SCHOOL: "School",
	STADIUM: "Stadium",
	PRISON: "Prison",
	COLLEGE: "College",
	ZOO: "Zoo",
	STATUE: "Statue",
	SUBWAY_STATION: "SimSubway",
	BUS_DEPOT: "SimBus System",
	RAIL_STATION: "SimRail System",
	MAYOR_HOUSE: "Mayor's House",
	WATER_TREATMENT: "Water Treatment",
	LIBRARY: "Library System",
	MARINA: "Marina",
	DESALINIZATION: "Desalinization",
	PLYMOUTH_ARCOLOGY: "Plymouth Arco",
	FOREST_ARCOLOGY: "Forest Arco",
	DARCO_ARCOLOGY: "Darco",
	LAUNCH_ARCOLOGY: "Launch Arco",
	LLAMA_DOME: "Llama Dome",
}

const TILE_BY_TOOL := {
	38: COAL_POWER,
	40: OIL_POWER,
	41: GAS_POWER,
	42: NUCLEAR_POWER,
	43: WIND_POWER,
	44: SOLAR_POWER,
	45: MICROWAVE_POWER,
	46: FUSION_POWER,
	49: WATER_PUMP,
	50: WATER_TOWER,
	51: WATER_TREATMENT,
	52: DESALINIZATION,
	60: MAYOR_HOUSE,
	61: CITY_HALL,
	62: STATUE,
	63: LLAMA_DOME,
	65: PLYMOUTH_ARCOLOGY,
	66: FOREST_ARCOLOGY,
	67: DARCO_ARCOLOGY,
	68: LAUNCH_ARCOLOGY,
	76: BUS_DEPOT,
	86: RAIL_STATION,
	87: SUBWAY_STATION,
	144: SCHOOL,
	145: COLLEGE,
	146: LIBRARY,
	147: MUSEUM,
	156: POLICE_STATION,
	157: FIRE_STATION,
	158: HOSPITAL,
	159: PRISON,
	168: SMALL_PARK,
	169: BIG_PARK,
	170: ZOO,
	171: STADIUM,
	172: MARINA,
}

const NUISANCE_TILES := {
	GAS_POWER: true,
	OIL_POWER: true,
	NUCLEAR_POWER: true,
	COAL_POWER: true,
	PRISON: true,
	WATER_TREATMENT: true,
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
