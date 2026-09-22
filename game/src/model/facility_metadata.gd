class_name FacilityMetadata
extends RefCounted
## Facility types and budget categories shared by placement, query, and repair.

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

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

const BUDGET_CATEGORY_BY_TILE := {
	Tiles.HOSPITAL: Sc2BudgetLayout.HEALTH,
	Tiles.POLICE_STATION: Sc2BudgetLayout.POLICE,
	Tiles.FIRE_STATION: Sc2BudgetLayout.FIRE,
	Tiles.SCHOOL: Sc2BudgetLayout.SCHOOL,
	Tiles.COLLEGE: Sc2BudgetLayout.COLLEGE,
}
