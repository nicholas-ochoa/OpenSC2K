class_name QueryConstants
extends RefCounted

const Presentation = preload("res://src/view/query_presentation.gd")

const FULL_MAP_SIZE := CityState.MAP_SIZE
const DETAIL_MAP_SIZE := 64
const FIRST_MICROSIM_LABEL := 51
const LAST_MICROSIM_LABEL := 200
const FIRST_BUILDING_WITH_UTILITIES := 13
const MILITARY_ZONE := 7
const WATER_PUMP := 0xdc
const WATER_TOWER := 0xeb
const STADIUM_SPORT_RESOURCE_BASE := 786
const CITY_HALL := 0xd0
const LIBRARY := 0xf5
const CITY_HALL_ACTION_RESOURCE := 810
const LIBRARY_ACTION_RESOURCE := 811
const ANALYSIS_RESOURCE_BASE := 988
const GENERAL_NAME_RESOURCE_BASE := 593
const GENERAL_CLEAR_NAME_INDEX := 158
const GENERAL_SALT_WATER_NAME_INDEX := 159
const GENERAL_FRESH_WATER_NAME_INDEX := 160
const GENERAL_SAILBOAT_NAME_INDEX := 161

# the first strict upper bound greater than xbld selects the name index
const GENERAL_NAME_UPPER_BOUNDS := [
	0x01,
	0x05,
	0x06,
	0x0d,
	0x0e,
	0x1d,
	0x2c,
	0x3f,
	0x43,
	0x47,
	0x49,
	0x51,
	0x56,
	0x5c,
	0x5d,
	0x61,
	0x6a,
	0x6c,
	0x70,
	0x74,
	0x78,
	0x7c,
]

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

# each row contains the five windows string resource ids used by one xmic type
const MICROSIM_RESOURCE_IDS := [
	[-1, -1, -1, -1, -1],
	[960, 972, 916, -1, -1],
	[945, 929, -1, -1, -1],
	[925, 965, 943, 952, 920],
	[962, 941, 922, -1, 919],
	[951, 950, 970, -1, 919],
	[935, 974, 976, 952, 920],
	[936, 924, 958, 910, 982],
	[934, 956, 953, 948, 911],
	[938, 924, 976, 952, 920],
	[966, 918, 917, 963, -1],
	[954, 959, 928, 967, -1],
	[921, 928, 947, 944, -1],
	[937, -1, 978, 977, -1],
	[971, 973, 946, -1, 940],
	[942, 969, 930, -1, 940],
	[980, 979, 957, 939, 931],
	[932, 933, 964, 912, 901],
	[968, 964, -1, 912, 903],
	[975, 964, -1, 912, 904],
	[981, 961, -1, 913, 909],
	[955, 961, -1, 913, 908],
	[923, 915, 947, 912, 902],
	[923, 949, -1, 914, 907],
	[924, 927, 952, 914, 905],
	[926, -1, -1, 914, 906],
]

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
