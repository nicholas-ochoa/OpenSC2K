class_name QueryConstants
extends RefCounted

const Facilities = preload("res://src/model/facility_metadata.gd")
const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const Presentation = preload("res://src/view/query_presentation.gd")

const FULL_MAP_SIZE := CityState.MAP_SIZE
const DETAIL_MAP_SIZE := 64
const FIRST_MICROSIM_LABEL := 51
const LAST_MICROSIM_LABEL := 200
const FIRST_BUILDING_WITH_UTILITIES := Tiles.SMALL_PARK
const MILITARY_ZONE := Sc2ZoneLayout.MILITARY
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

const MICROSIM_TYPE_BY_TILE := Facilities.MICROSIM_TYPE_BY_TILE

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
	[Sc2TileFlags.POWERABLE, "powerable"], [Sc2TileFlags.POWERED, "powered"], [Sc2TileFlags.PIPED, "piped"],
	[Sc2TileFlags.WATERED, "watered"], [Sc2TileFlags.MARK, "xvalmask"], [Sc2TileFlags.WATER, "water"],
	[Sc2TileFlags.FLIPPED, "rotated"], [Sc2TileFlags.SALT_WATER, "saltwater"],
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
