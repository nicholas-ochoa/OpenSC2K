class_name BuildingConstants
extends BuildingTileIds

const Topology = preload("res://src/model/network_topology.gd")
const Facilities = preload("res://src/model/facility_metadata.gd")
const UnderTiles = preload("res://src/tools/shared/underground_tile_ids.gd")

const Availability = preload("res://src/tools/shared/tool_availability.gd")
const Power = preload("res://src/simulation/infrastructure/power_phase.gd")
const Water = preload("res://src/simulation/infrastructure/water_phase.gd")

const MISC_FUNDS := Sc2MiscLayout.FUNDS
const MISC_ARCOLOGY_POPULATION := Sc2MiscLayout.ARCOLOGY_POPULATION
const MISC_NORMAL_POPULATION := Sc2MiscLayout.NORMAL_POPULATION
const IMMEDIATE_UTILITY_POPULATION_LIMIT := 50_000_000
const MISC_TILE_COUNTS := Sc2MiscLayout.TILE_COUNTS
const MISC_BUDGETS := Sc2MiscLayout.BUDGETS
const MISC_SUBWAY_COUNT := Sc2MiscLayout.SUBWAY_COUNT
const BUDGET_RECORD_SIZE := Sc2BudgetLayout.RECORD_SIZE

const MILITARY_ZONE := Sc2ZoneLayout.MILITARY
const FLAG_WATER := Sc2TileFlags.WATER
const FLAG_PIPED := Sc2TileFlags.PIPED
const FLAG_POWERED := Sc2TileFlags.POWERED
const FLAG_POWERABLE := Sc2TileFlags.POWERABLE
const STRUCTURE_FLAGS := FLAG_PIPED | FLAG_POWERED | FLAG_POWERABLE
const ROAD_FIRST := BuildingTileIds.FIRST_ROAD
const RADIOACTIVITY := BuildingTileIds.RADIOACTIVE_WASTE
const UNDER_SUBWAY_FIRST := UnderTiles.SUBWAY_FIRST
const UNDER_SUBWAY_LAST := UnderTiles.SUBWAY_LAST
const UNDER_PIPE_FIRST := UnderTiles.PIPE_FIRST
const UNDER_PIPE_LAST := UnderTiles.PIPE_LAST
const UNDER_PIPE_SUBWAY_LR := UnderTiles.PIPE_TB_SUBWAY_LR
const UNDER_PIPE_SUBWAY_TB := UnderTiles.PIPE_LR_SUBWAY_TB
const UNDER_MISSILE_SILO := UnderTiles.MISSILE_SILO
const UNDER_SUBWAY_ENTRANCE := UnderTiles.SUBWAY_ENTRANCE
const MICROSIM_DYNAMIC_FIRST := 10
const MICROSIM_LABEL_BASE := 51
const MISC_STADIUM_TEAMS := Sc2MiscLayout.STADIUM_TEAMS
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
const NUISANCE_OBJECTION := "Your citizens urge you to\r\n reconsider the placement\r\nof this facility"

const BUDGET_CATEGORY_BY_TILE := Facilities.BUDGET_CATEGORY_BY_TILE

const MICROSIM_TYPE_BY_TILE := Facilities.MICROSIM_TYPE_BY_TILE

const DEFAULT_MICROSIM_LABELS := {
	HYDRO_POWER_1: "Hydro Power",
	HYDRO_POWER_2: "Hydro Power",
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

const CORNER_BOTTOM_LEFT := Sc2ZoneLayout.CORNER_BOTTOM_LEFT
const CORNER_BOTTOM_RIGHT := Sc2ZoneLayout.CORNER_BOTTOM_RIGHT
const CORNER_TOP_LEFT := Sc2ZoneLayout.CORNER_TOP_LEFT
const CORNER_TOP_RIGHT := Sc2ZoneLayout.CORNER_TOP_RIGHT
const NETWORK_SHAPES := Topology.SHAPE_OFFSET_BY_CONNECTION_MASK
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
