class_name ToolCatalog
extends RefCounted

const MAX_SLOTS_PER_GROUP := 12

# power-plant output values are the nominal megawatt values stored in xmic
# grid capacity and pollution values are from the monthly power and pollution
# phases. the power group uses subtool indices 2 through 10
const POWER_PLANT_DETAILS := {
	2: {
		"output_mw": 200,
		"grid_capacity": "44 demand tiles",
		"pollution": 50,
		"service_life": "50 years",
		"note": "Can be blocked by nearby residential zones.",
	},
	3: {
		"output_mw": 20,
		"grid_capacity": "40 demand tiles",
		"pollution": 0,
		"service_life": "No age limit",
		"note": "Must be built on an unused waterfall tile.",
	},
	4: {
		"output_mw": 220,
		"grid_capacity": "48 demand tiles",
		"pollution": 25,
		"service_life": "50 years",
		"note": "Can be blocked by nearby residential zones.",
	},
	5: {
		"output_mw": 50,
		"grid_capacity": "11 demand tiles",
		"pollution": 10,
		"service_life": "50 years",
		"note": "Can be blocked by nearby residential zones.",
	},
	6: {
		"output_mw": 500,
		"grid_capacity": "111 demand tiles",
		"pollution": 2,
		"service_life": "50 years",
		"note": "The Nuclear-Free ordinance disables this plant.",
	},
	7: {
		"output_mw": 4,
		"grid_capacity": "Varies with altitude and wind",
		"pollution": 0,
		"service_life": "No age limit",
		"note": "Higher land and stronger wind increase grid capacity.",
	},
	8: {
		"output_mw": 50,
		"grid_capacity": "5 to 14 demand tiles; varies with rain",
		"pollution": 0,
		"service_life": "50 years",
		"note": "Drier weather increases grid capacity.",
	},
	9: {
		"output_mw": 1600,
		"grid_capacity": "355 demand tiles",
		"pollution": 0,
		"service_life": "50 years",
		"note": "A microwave disaster can start at this plant.",
	},
	10: {
		"output_mw": 2500,
		"grid_capacity": "555 demand tiles",
		"pollution": 2,
		"service_life": "50 years",
		"note": "This plant becomes available after its invention.",
	},
}

# costs and square cursor areas are confirmed from the supplied executable
# tables at 0x004dc140 and 0x004dc068. a zero area is a chooser or camera tool
const GROUPS := [
	{"id": "bulldozer", "name": "Bulldozer", "tools": [
		["demolish", "Demolish", 1, 1],
		["level", "Level Terrain", 25, 1],
		["raise", "Raise Terrain", 25, 1],
		["lower", "Lower Terrain", 25, 1],
		["dezone", "De-zone", 1, 1],
	]},
	{"id": "nature", "name": "Landscape", "tools": [
		["trees", "Trees", 3, 1],
		["water", "Water", 100, 1],
	]},
	{"id": "dispatch", "name": "Dispatch", "tools": [
		["police", "Police", 0, 1],
		["fire", "Fire", 0, 1],
		["military", "Military", 0, 1],
		["recall", "Cancel Dispatch", 0, 0],
	]},
	{"id": "power", "name": "Power", "tools": [
		["wires", "Power Lines", 2, 1],
		["plants", "Power Plants", 0, 0],
		["coal", "Coal Power Plant", 4000, 4],
		["hydro", "Hydroelectric Power Plant", 400, 1],
		["oil", "Oil Power Plant", 6600, 4],
		["gas", "Gas Power Plant", 2000, 4],
		["nuclear", "Nuclear Power Plant", 15000, 4],
		["wind", "Wind Power Plant", 100, 1],
		["solar", "Solar Power Plant", 1300, 4],
		["microwave", "Microwave Power Plant", 28000, 4],
		["fusion", "Fusion Power Plant", 40000, 4],
	]},
	{"id": "water", "name": "Water", "tools": [
		["pipes", "Water Pipes", 3, 1],
		["pump", "Water Pump", 100, 1],
		["tower", "Water Tower", 250, 2],
		["treatment", "Water Treatment Plant", 500, 2],
		["desalinization", "Desalinization Plant", 1000, 3],
	]},
	{"id": "rewards", "name": "Rewards", "tools": [
		["mayors_house", "Mayor's House", 0, 2],
		["city_hall", "City Hall", 0, 3],
		["statue", "Statue", 0, 1],
		["llama_dome", "Braun Llama Dome", 0, 4],
		["arcologies", "Arcologies", 0, 0],
		["plymouth", "Plymouth Arcology", 100000, 4],
		["forest", "Forest Arcology", 120000, 4],
		["darco", "Darco Arcology", 150000, 4],
		["launch", "Launch Arcology", 200000, 4],
	]},
	{"id": "roads", "name": "Roads", "tools": [
		["road", "Road", 10, 1],
		["highway", "Highway", 100, 2],
		["tunnel", "Tunnel", 150, 1],
		["onramp", "On-ramp", 25, 1],
		["bus_depot", "Bus Depot", 250, 2],
	]},
	{"id": "rail", "name": "Rail", "tools": [
		["rail", "Rail", 25, 1],
		["subway", "Subway", 100, 1],
		["rail_depot", "Rail Depot", 500, 2],
		["subway_station", "Subway Station", 250, 1],
		["subway_to_rail", "Subway-to-Rail Connection", 250, 1],
	]},
	{"id": "ports", "name": "Ports", "tools": [
		["seaport", "Seaport", 150, 1],
		["airport", "Airport", 250, 1],
	]},
	{"id": "residential", "name": "Residential", "tools": [
		["light", "Light Residential", 5, 1],
		["dense", "Dense Residential", 10, 1],
	]},
	{"id": "commercial", "name": "Commercial", "tools": [
		["light", "Light Commercial", 5, 1],
		["dense", "Dense Commercial", 10, 1],
	]},
	{"id": "industrial", "name": "Industrial", "tools": [
		["light", "Light Industrial", 5, 1],
		["dense", "Dense Industrial", 10, 1],
	]},
	{"id": "education", "name": "Education", "tools": [
		["school", "School", 250, 3],
		["college", "College", 1000, 4],
		["library", "Library", 500, 2],
		["museum", "Museum", 1000, 3],
	]},
	{"id": "services", "name": "City Services", "tools": [
		["police_station", "Police Station", 500, 3],
		["fire_station", "Fire Station", 500, 3],
		["hospital", "Hospital", 500, 3],
		["prison", "Prison", 3000, 4],
	]},
	{"id": "parks", "name": "Recreation", "tools": [
		["small_park", "Small Park", 20, 1],
		["big_park", "Big Park", 150, 3],
		["zoo", "Zoo", 3000, 4],
		["stadium", "Stadium", 5000, 4],
		["marina", "Marina", 1000, 3],
	]},
	{"id": "signs", "name": "Signs", "tools": [
		["sign", "Place Sign", 0, 1],
	]},
	{"id": "query", "name": "Query", "tools": [
		["query", "Query", 0, 1],
	]},
	{"id": "centering", "name": "Center", "tools": [
		["center", "Center View", 0, 0],
	]},
]


static func group(group_index: int) -> Dictionary:
	if group_index < 0 or group_index >= GROUPS.size():
		return {}
	return GROUPS[group_index]


static func tool(group_index: int, subtool_index: int) -> Dictionary:
	var group_entry := group(group_index)
	if group_entry.is_empty() or subtool_index < 0 or subtool_index >= group_entry.tools.size():
		return {}
	var source: Array = group_entry.tools[subtool_index]
	return {
		"group_index": group_index,
		"subtool_index": subtool_index,
		"table_index": group_index * MAX_SLOTS_PER_GROUP + subtool_index,
		"group_id": group_entry.id,
		"group_name": group_entry.name,
		"id": source[0],
		"name": source[1],
		"cost": source[2],
		"area": source[3],
	}


static func all_tools() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for group_index in GROUPS.size():
		for subtool_index in GROUPS[group_index].tools.size():
			result.append(tool(group_index, subtool_index))
	return result


static func power_plant_details(subtool_index: int) -> Dictionary:
	return POWER_PLANT_DETAILS.get(subtool_index, {}).duplicate()
