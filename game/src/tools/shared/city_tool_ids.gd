class_name CityToolIds
extends RefCounted
## Stable city tool indices for catalog entries and availability tables.
## SCURK object groups use a separate set of IDs.

enum Group {
	BULLDOZER = 0, LANDSCAPE = 1, DISPATCH = 2, POWER = 3, WATER = 4,
	REWARDS = 5, ROADS = 6, RAIL = 7, PORTS = 8, RESIDENTIAL = 9,
	COMMERCIAL = 10, INDUSTRIAL = 11, EDUCATION = 12, SERVICES = 13,
	RECREATION = 14, SIGNS = 15, QUERY = 16, CENTERING = 17,
}

enum Bulldozer {
	DEMOLISH = 0, LEVEL = 1, RAISE = 2, LOWER = 3, DEZONE = 4,
	STRETCH = 5, RAISE_SEA = 6, LOWER_SEA = 7,
}

enum Landscape { TREES = 0, WATER = 1, STREAM = 2, FOREST = 3 }

enum Dispatch { POLICE = 0, FIRE = 1, MILITARY = 2, RECALL = 3 }

enum Power {
	WIRES = 0, PLANTS = 1, COAL = 2, HYDRO = 3, OIL = 4, GAS = 5,
	NUCLEAR = 6, WIND = 7, SOLAR = 8, MICROWAVE = 9, FUSION = 10,
}

enum Water { PIPES = 0, PUMP = 1, TOWER = 2, TREATMENT = 3, DESALINIZATION = 4 }

enum Rewards {
	MAYORS_HOUSE = 0, CITY_HALL = 1, STATUE = 2, LLAMA_DOME = 3,
	ARCOLOGIES = 4, PLYMOUTH = 5, FOREST = 6, DARCO = 7, LAUNCH = 8,
}

enum Roads { ROAD = 0, HIGHWAY = 1, TUNNEL = 2, ONRAMP = 3, BUS_DEPOT = 4 }

enum Rail { RAIL = 0, SUBWAY = 1, RAIL_DEPOT = 2, SUBWAY_STATION = 3, SUBWAY_TO_RAIL = 4 }

enum Ports { SEAPORT = 0, AIRPORT = 1 }

enum Residential { LIGHT = 0, DENSE = 1 }

enum Commercial { LIGHT = 0, DENSE = 1 }

enum Industrial { LIGHT = 0, DENSE = 1 }

enum Education { SCHOOL = 0, COLLEGE = 1, LIBRARY = 2, MUSEUM = 3 }

enum Services { POLICE_STATION = 0, FIRE_STATION = 1, HOSPITAL = 2, PRISON = 3 }

enum Recreation { SMALL_PARK = 0, BIG_PARK = 1, ZOO = 2, STADIUM = 3, MARINA = 4 }

enum Signs { SIGN = 0 }

enum Query { QUERY = 0, TRIP_REACH = 1 }

enum Centering { CENTER = 0 }
