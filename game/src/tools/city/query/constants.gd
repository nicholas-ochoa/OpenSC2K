class_name QueryConstants
extends RefCounted

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const Presentation = preload("res://src/view/query_presentation.gd")

const FULL_MAP_SIZE := CityState.MAP_SIZE
const DETAIL_MAP_SIZE := 64
const FIRST_MICROSIM_LABEL := 51
const LAST_MICROSIM_LABEL := 200
const FIRST_BUILDING_WITH_UTILITIES := Tiles.SMALL_PARK
const MILITARY_ZONE := 7
const WATER_PUMP := Tiles.WATER_PUMP
const WATER_TOWER := Tiles.WATER_TOWER
const CITY_HALL := Tiles.CITY_HALL
const LIBRARY := Tiles.LIBRARY

# the first strict upper bound greater than xbld selects the name index
const GENERAL_NAME_UPPER_BOUNDS := [
	Tiles.RUBBLE_FIRST,
	Tiles.RADIOACTIVE_WASTE,
	Tiles.TREE_FIRST,
	Tiles.SMALL_PARK,
	Tiles.POWER_LINE_FIRST,
	Tiles.FIRST_ROAD,
	Tiles.RAIL_FIRST,
	Tiles.TUNNEL_FIRST,
	Tiles.ROAD_POWER_CROSSING_1,
	Tiles.RAIL_POWER_CROSSING_1,
	Tiles.HIGHWAY_STRAIGHT_1,
	Tiles.SUSPENSION_BRIDGE_1,
	Tiles.RAISING_BRIDGE_TOWER,
	Tiles.POWER_BRIDGE,
	Tiles.ONRAMP_FIRST,
	Tiles.HIGHWAY_SLOPE_FIRST,
	Tiles.HIGHWAY_BRIDGE,
	Tiles.RAIL_SUBWAY_FIRST,
	Tiles.DEVELOPED_FIRST,
	Tiles.MIDDLE_CLASS_HOMES_1X1_1,
	Tiles.LUXURY_HOMES_1X1_1,
	Tiles.COMMERCIAL_1X1_FIRST,
]

const MICROSIM_TYPE_BY_TILE := {
	Tiles.HYDRO_POWER_1: 21,
	Tiles.HYDRO_POWER_2: 21,
	Tiles.WIND_POWER: 20,
	Tiles.GAS_POWER: 1,
	Tiles.OIL_POWER: 1,
	Tiles.NUCLEAR_POWER: 1,
	Tiles.SOLAR_POWER: 1,
	Tiles.MICROWAVE_POWER: 1,
	Tiles.FUSION_POWER: 1,
	Tiles.COAL_POWER: 1,
	Tiles.CITY_HALL: 2,
	Tiles.HOSPITAL: 3,
	Tiles.POLICE_STATION: 4,
	Tiles.FIRE_STATION: 5,
	Tiles.MUSEUM: 23,
	Tiles.BIG_PARK: 22,
	Tiles.SCHOOL: 6,
	Tiles.STADIUM: 7,
	Tiles.PRISON: 8,
	Tiles.COLLEGE: 9,
	Tiles.ZOO: 10,
	Tiles.STATUE: 11,
	Tiles.SUBWAY_STATION: 19,
	Tiles.BUS_DEPOT: 17,
	Tiles.RAIL_STATION: 18,
	Tiles.MAYOR_HOUSE: 12,
	Tiles.WATER_TREATMENT: 13,
	Tiles.LIBRARY: 24,
	Tiles.MARINA: 25,
	Tiles.DESALINIZATION: 14,
	Tiles.PLYMOUTH_ARCOLOGY: 15,
	Tiles.FOREST_ARCOLOGY: 15,
	Tiles.DARCO_ARCOLOGY: 15,
	Tiles.LAUNCH_ARCOLOGY: 15,
	Tiles.LLAMA_DOME: 16,
}

const GRADE_NAMES := [
	"F",
	"D-",
	"D",
	"D+",
	"C-",
	"C",
	"C+",
	"B-",
	"B",
	"B+",
	"A-",
	"A",
	"A+",
]

const ZONE_NAMES := [
	"Unzoned",
	"Residential",
	"Residential",
	"Commercial",
	"Commercial",
	"Industrial",
	"Industrial",
	"Military",
	"Airport",
	"Seaport",
]

const ZONE_DENSITIES := [
	"",
	"low-density",
	"high-density",
	"low-density",
	"high-density",
	"low-density",
	"high-density",
	"",
	"",
	"",
]

const UNDERGROUND_NAMES := [
	"None",
	"Subway (LR)", "Subway (TB)", "Subway (HTB)", "Subway (LHR)",
	"Subway (THB)", "Subway (HLR)", "Subway (BR)", "Subway (BL)",
	"Subway (TL)", "Subway (TR)", "Subway (RTB)", "Subway (LBR)",
	"Subway (TLB)", "Subway (LTR)", "Subway (LTBR)",
	"Pipes (LR)", "Pipes (TB)", "Pipes (HTB)", "Pipes (LHR)",
	"Pipes (THB)", "Pipes (HLR)", "Pipes (BR)", "Pipes (BL)",
	"Pipes (TL)", "Pipes (TR)", "Pipes (RTB)", "Pipes (LBR)",
	"Pipes (TLB)", "Pipes (LTR)", "Pipes (LTBR)",
	"Crossover (PIPESTB_SUBWAYLR)", "Crossover (PIPESLR_SUBWAYTB)",
	"Unknown", "Missile Silo", "Subway Entrance",
]

const FLAG_LABELS := [
	[0x80, "powerable"], [0x40, "powered"], [0x20, "piped"],
	[0x10, "watered"], [0x08, "xvalmask"], [0x04, "water"],
	[0x02, "rotated"], [0x01, "saltwater"],
]

const THING_NAMES := [
	"None", "Airplane", "Helicopter", "Cargo ship", "Bulldozer",
	"Monster", "Explosion", "Police", "Fire", "Sailboat",
	"Train engine", "Train car", "Subway engine", "Subway car",
	"Military", "Tornado", "Maxis Man",
]

const DIRECTION_NAMES := [
	"North", "Northeast", "East", "Southeast",
	"South", "Southwest", "West", "Northwest",
]
