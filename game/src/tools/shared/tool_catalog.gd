class_name ToolCatalog
extends RefCounted
## The city tool catalog. The native simulation library holds the table.

const MAX_SLOTS_PER_GROUP := 12

# the tool groups of the native catalog; see
# native/core/sim/src/sim/tools/catalog.rs. costs and square cursor areas are
# the supplied executable tables at 0x004dc140 and 0x004dc068. a zero area is
# a chooser or camera tool
static var GROUPS: Array[Group] = _groups()
# the Power Plants chooser values, by power subtool
static var POWER_PLANT_DETAILS: Dictionary[int, PowerPlantDetails] = _power_plant_details()


static func _groups() -> Array[Group]:
	var groups: Array[Group] = []

	for fields: Dictionary in NativeCityTools.tool_catalog():
		var entries: Array[Entry] = []

		for tool_fields: Dictionary in fields.tools:
			entries.append(Entry.new(tool_fields.id, tool_fields.name, tool_fields.cost, tool_fields.area))

		groups.append(Group.new(fields.id, fields.name, entries))

	return groups


static func _power_plant_details() -> Dictionary[int, PowerPlantDetails]:
	var plants: Dictionary[int, PowerPlantDetails] = {}

	for fields: Dictionary in NativeCityTools.power_plant_details():
		plants[fields.subtool] = PowerPlantDetails.new(
			fields.output_mw, fields.grid_capacity, fields.pollution, fields.service_life, fields.note
		)

	return plants


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
