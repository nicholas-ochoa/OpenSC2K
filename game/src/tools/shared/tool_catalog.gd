class_name ToolCatalog
extends RefCounted

class Entry extends RefCounted:
	var id: String
	var name: String
	var cost: int
	var area: int

	func _init(value_id: String = "", value_name: String = "", value_cost: int = 0, value_area: int = 0) -> void:
		id = value_id
		name = value_name
		cost = value_cost
		area = value_area


class Group extends RefCounted:
	var id: String
	var name: String
	var tools: Array[Entry]

	func _init(value_id: String, value_name: String, value_tools: Array[Entry]) -> void:
		id = value_id
		name = value_name
		tools = value_tools


class Tool extends Entry:
	var group_index: int
	var subtool_index: int
	var table_index: int
	var group_id: String
	var group_name: String


class PowerPlantDetails extends RefCounted:
	var output_mw: int
	var grid_capacity: String
	var pollution: int
	var service_life: String
	var note: String

	func _init(output: int, capacity: String, pollution_factor: int, lifetime: String, description: String) -> void:
		output_mw = output
		grid_capacity = capacity
		pollution = pollution_factor
		service_life = lifetime
		note = description

	func copy() -> PowerPlantDetails:
		return PowerPlantDetails.new(output_mw, grid_capacity, pollution, service_life, note)


const MAX_SLOTS_PER_GROUP := 12

# power-plant output values are the nominal megawatt values stored in xmic
# grid capacity and pollution values are from the monthly power and pollution
# phases. the power group uses subtool indices 2 through 10
static var POWER_PLANT_DETAILS: Dictionary[int, PowerPlantDetails] = {
	2: PowerPlantDetails.new(
		200, "44 demand tiles", 50, "50 years",
		"Can be blocked by nearby residential zones."
	),
	3: PowerPlantDetails.new(
		20, "40 demand tiles", 0, "No age limit",
		"Must be built on an unused waterfall tile."
	),
	4: PowerPlantDetails.new(
		220, "48 demand tiles", 25, "50 years",
		"Can be blocked by nearby residential zones."
	),
	5: PowerPlantDetails.new(
		50, "11 demand tiles", 10, "50 years",
		"Can be blocked by nearby residential zones."
	),
	6: PowerPlantDetails.new(
		500, "111 demand tiles", 2, "50 years",
		"The Nuclear-Free ordinance disables this plant."
	),
	7: PowerPlantDetails.new(
		4, "Varies with altitude and wind", 0, "No age limit",
		"Higher land and stronger wind increase grid capacity."
	),
	8: PowerPlantDetails.new(
		50, "5 to 14 demand tiles; varies with rain", 0, "50 years",
		"Drier weather increases grid capacity."
	),
	9: PowerPlantDetails.new(
		1600, "355 demand tiles", 0, "50 years",
		"A microwave disaster can start at this plant."
	),
	10: PowerPlantDetails.new(
		2500, "555 demand tiles", 2, "50 years",
		"This plant becomes available after its invention."
	),
}

# costs and square cursor areas are confirmed from the supplied executable
# tables at 0x004dc140 and 0x004dc068. a zero area is a chooser or camera tool
static var GROUPS: Array[Group] = [
	Group.new("bulldozer", "Bulldozer", [
		Entry.new("demolish", "Demolish", 1, 1),
		Entry.new("level", "Level Terrain", 25, 1),
		Entry.new("raise", "Raise Terrain", 25, 1),
		Entry.new("lower", "Lower Terrain", 25, 1),
		Entry.new("dezone", "De-zone", 1, 1),
		Entry.new("stretch", "Stretch Terrain", 0, 1),
		Entry.new("raise_sea", "Raise Sea Level", 0, 0),
		Entry.new("lower_sea", "Lower Sea Level", 0, 0),
	]),
	Group.new("nature", "Landscape", [
		Entry.new("trees", "Trees", 3, 1),
		Entry.new("water", "Water", 100, 1),
		Entry.new("stream", "Place Stream", 0, 1),
		Entry.new("forest", "Place Forest", 3, 7),
	]),
	Group.new("dispatch", "Dispatch", [
		Entry.new("police", "Police", 0, 1),
		Entry.new("fire", "Fire", 0, 1),
		Entry.new("military", "Military", 0, 1),
		Entry.new("recall", "Cancel Dispatch", 0, 0),
	]),
	Group.new("power", "Power", [
		Entry.new("wires", "Power Lines", 2, 1),
		Entry.new("plants", "Power Plants", 0, 0),
		Entry.new("coal", "Coal Power Plant", 4000, 4),
		Entry.new("hydro", "Hydroelectric Power Plant", 400, 1),
		Entry.new("oil", "Oil Power Plant", 6600, 4),
		Entry.new("gas", "Gas Power Plant", 2000, 4),
		Entry.new("nuclear", "Nuclear Power Plant", 15000, 4),
		Entry.new("wind", "Wind Power Plant", 100, 1),
		Entry.new("solar", "Solar Power Plant", 1300, 4),
		Entry.new("microwave", "Microwave Power Plant", 28000, 4),
		Entry.new("fusion", "Fusion Power Plant", 40000, 4),
	]),
	Group.new("water", "Water", [
		Entry.new("pipes", "Water Pipes", 3, 1),
		Entry.new("pump", "Water Pump", 100, 1),
		Entry.new("tower", "Water Tower", 250, 2),
		Entry.new("treatment", "Water Treatment Plant", 500, 2),
		Entry.new("desalinization", "Desalinization Plant", 1000, 3),
	]),
	Group.new("rewards", "Rewards", [
		Entry.new("mayors_house", "Mayor's House", 0, 2),
		Entry.new("city_hall", "City Hall", 0, 3),
		Entry.new("statue", "Statue", 0, 1),
		Entry.new("llama_dome", "Braun Llama Dome", 0, 4),
		Entry.new("arcologies", "Arcologies", 0, 0),
		Entry.new("plymouth", "Plymouth Arcology", 100000, 4),
		Entry.new("forest", "Forest Arcology", 120000, 4),
		Entry.new("darco", "Darco Arcology", 150000, 4),
		Entry.new("launch", "Launch Arcology", 200000, 4),
	]),
	Group.new("roads", "Roads", [
		Entry.new("road", "Road", 10, 1),
		Entry.new("highway", "Highway", 100, 2),
		Entry.new("tunnel", "Tunnel", 150, 1),
		Entry.new("onramp", "On-ramp", 25, 1),
		Entry.new("bus_depot", "Bus Depot", 250, 2),
	]),
	Group.new("rail", "Rail", [
		Entry.new("rail", "Rail", 25, 1),
		Entry.new("subway", "Subway", 100, 1),
		Entry.new("rail_depot", "Rail Depot", 500, 2),
		Entry.new("subway_station", "Subway Station", 250, 1),
		Entry.new("subway_to_rail", "Subway-to-Rail Connection", 250, 1),
	]),
	Group.new("ports", "Ports", [
		Entry.new("seaport", "Seaport", 150, 1),
		Entry.new("airport", "Airport", 250, 1),
	]),
	Group.new("residential", "Residential", [
		Entry.new("light", "Light Residential", 5, 1),
		Entry.new("dense", "Dense Residential", 10, 1),
	]),
	Group.new("commercial", "Commercial", [
		Entry.new("light", "Light Commercial", 5, 1),
		Entry.new("dense", "Dense Commercial", 10, 1),
	]),
	Group.new("industrial", "Industrial", [
		Entry.new("light", "Light Industrial", 5, 1),
		Entry.new("dense", "Dense Industrial", 10, 1),
	]),
	Group.new("education", "Education", [
		Entry.new("school", "School", 250, 3),
		Entry.new("college", "College", 1000, 4),
		Entry.new("library", "Library", 500, 2),
		Entry.new("museum", "Museum", 1000, 3),
	]),
	Group.new("services", "City Services", [
		Entry.new("police_station", "Police Station", 500, 3),
		Entry.new("fire_station", "Fire Station", 500, 3),
		Entry.new("hospital", "Hospital", 500, 3),
		Entry.new("prison", "Prison", 3000, 4),
	]),
	Group.new("parks", "Recreation", [
		Entry.new("small_park", "Small Park", 20, 1),
		Entry.new("big_park", "Big Park", 150, 3),
		Entry.new("zoo", "Zoo", 3000, 4),
		Entry.new("stadium", "Stadium", 5000, 4),
		Entry.new("marina", "Marina", 1000, 3),
	]),
	Group.new("signs", "Signs", [
		Entry.new("sign", "Place Sign", 0, 1),
	]),
	Group.new("query", "Query", [
		Entry.new("query", "Query", 0, 1),
		Entry.new("trip_reach", "Trip Query", 0, 1),
		Entry.new("service_query", "Service Query", 0, 1),
	]),
	Group.new("centering", "Center", [
		Entry.new("center", "Center View", 0, 0),
	]),
]


static func group(group_index: int) -> Group:
	if group_index < 0 or group_index >= GROUPS.size():
		return null

	return GROUPS[group_index]


static func tool(group_index: int, subtool_index: int) -> Tool:
	var group_entry := group(group_index)

	if group_entry == null or subtool_index < 0 or subtool_index >= group_entry.tools.size():
		return null

	var source := group_entry.tools[subtool_index]
	var result := Tool.new()
	result.group_index = group_index
	result.subtool_index = subtool_index
	result.table_index = group_index * MAX_SLOTS_PER_GROUP + subtool_index
	result.group_id = group_entry.id
	result.group_name = group_entry.name
	result.id = source.id
	result.name = source.name
	result.cost = source.cost
	result.area = source.area

	return result


static func all_tools() -> Array[Tool]:
	var result: Array[Tool] = []

	for group_index in GROUPS.size():
		for subtool_index in GROUPS[group_index].tools.size():
			result.append(tool(group_index, subtool_index))

	return result


static func power_plant_details(subtool_index: int) -> PowerPlantDetails:
	var details: PowerPlantDetails = POWER_PLANT_DETAILS.get(subtool_index)

	return details.copy() if details != null else null
