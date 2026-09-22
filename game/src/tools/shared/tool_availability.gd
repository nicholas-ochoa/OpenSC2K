class_name ToolAvailability
extends RefCounted

class Result extends RefCounted:
	var ok: bool = false
	var error: String = ""
	var group_masks: PackedInt32Array
	var power_plant_mask: int = 0
	var released_inventions: PackedByteArray
	var arcology_count: int = 0
	var progression: int = 0
	var military_base_type: int = 0

	static func failure(message: String) -> Result:
		var result := Result.new()
		result.error = message

		return result


const MISC_PROGRESSION := Sc2MiscLayout.PROGRESSION
const MISC_GRANTED_REWARDS := Sc2MiscLayout.GRANTED_REWARDS
const MISC_INVENTION_YEARS := Sc2MiscLayout.INVENTION_YEARS
const MISC_ORDINANCES := Sc2MiscLayout.ORDINANCES
const INVENTION_COUNT := 17
const ARCOLOGY_FIRST_INVENTION := 12
const ARCOLOGY_LAST_INVENTION := 15
const ORDINANCE_NUCLEAR_FREE := OrdinanceIds.NUCLEAR_FREE_ZONE_MASK

# supplied executable table at 0x004e9560. the final three groups use direct
# actions and do not use these submenu masks
const BASE_GROUP_MASKS := [
	0x1f, 0x03, 0x03, 0x03, 0x07, 0x00,
	0x05, 0x05, 0x01, 0x03, 0x03, 0x03,
	0x0f, 0x0f, 0x1f, 0x00, 0x00, 0x00,
]

# power chooser order: coal, hydro, oil, gas, nuclear, wind, solar,
# microwave, and fusion
const BASE_POWER_PLANT_MASK := 0x07


static func inspect(city: CityState) -> Result:
	if city == null or not city.is_valid():
		return Result.failure("city is invalid")

	var chunk := city.document.find_chunk("MISC")

	if chunk == null or chunk.decoded_payload.size() != Sc2MiscLayout.SIZE:
		return Result.failure("MISC is missing or has the wrong size")

	return inspect_misc(chunk.decoded_payload)


static func inspect_misc(misc: PackedByteArray) -> Result:
	if misc.size() != Sc2MiscLayout.SIZE:
		return Result.failure("MISC has the wrong size")

	var group_masks := PackedInt32Array(BASE_GROUP_MASKS)
	var power_plant_mask := BASE_POWER_PLANT_MASK
	var released := PackedByteArray()
	released.resize(INVENTION_COUNT)

	for index in INVENTION_COUNT:
		released[index] = int(BinaryData.read_u32_be(misc, MISC_INVENTION_YEARS + index * 4) & 0xffff == 0)

	if released[0]:
		power_plant_mask |= 0x08

	if released[1] and (BinaryData.read_u32_be(misc, MISC_ORDINANCES) & ORDINANCE_NUCLEAR_FREE) == 0:
		power_plant_mask |= 0x10

	if released[2]:
		power_plant_mask |= 0x40

	if released[3]:
		power_plant_mask |= 0x20

	if released[4]:
		power_plant_mask |= 0x80

	if released[5]:
		power_plant_mask |= 0x100

	if released[6]:
		group_masks[8] |= 0x02

	if released[7]:
		group_masks[6] |= 0x0a

	if released[8]:
		group_masks[6] |= 0x10

	if released[9]:
		group_masks[7] |= 0x1a

	if released[10]:
		group_masks[4] |= 0x08

	if released[11]:
		group_masks[4] |= 0x10

	var arcology_count := 0

	for index in range(ARCOLOGY_FIRST_INVENTION, ARCOLOGY_LAST_INVENTION + 1):
		arcology_count += int(released[index])

	group_masks[5] = BinaryData.read_u32_be(misc, MISC_GRANTED_REWARDS) & 0xffff
	var progression := BinaryData.read_u32_be(misc, MISC_PROGRESSION) & 0xffff

	if progression >= 6 and arcology_count > 0:
		group_masks[5] |= 0x10

	var military_base_type := BinaryData.read_u32_be(misc, Sc2MiscLayout.MILITARY_BASE_TYPE) & 0xffff

	if military_base_type == 2 or military_base_type == 3 or military_base_type == 4:
		group_masks[2] |= 0x04

	var result := Result.new()
	result.ok = true
	result.group_masks = group_masks
	result.power_plant_mask = power_plant_mask
	result.released_inventions = released
	result.arcology_count = arcology_count
	result.progression = progression
	result.military_base_type = military_base_type
	result.error = ""

	return result


static func is_available(city: CityState, group_index: int, subtool_index: int) -> bool:
	var tool := ToolCatalog.tool(group_index, subtool_index)

	if tool == null:
		return false

	if group_index >= 15 or (group_index == 1 and subtool_index == 3):
		return true

	var result := inspect(city)

	if not result.ok:
		return false

	# dispatch capacity is prepared from live station and military counts. keep
	# those tools selectable here and let dispatchcommand report capacity
	if group_index == 2:
		return true

	if group_index == 3 and subtool_index >= 2:
		return (int(result.power_plant_mask) & (1 << (subtool_index - 2))) != 0

	if group_index == 5 and subtool_index >= 5:
		return (
			(int(result.group_masks[5]) & 0x10) != 0
			and subtool_index - 5 < int(result.arcology_count)
		)

	return (int(result.group_masks[group_index]) & (1 << subtool_index)) != 0


static func rebuild_reward_mask(misc: PackedByteArray) -> int:
	if misc.size() != Sc2MiscLayout.SIZE:
		return 0

	var mask := BinaryData.read_u32_be(misc, MISC_GRANTED_REWARDS)
	var progression := BinaryData.read_u32_be(misc, MISC_PROGRESSION) & 0xffff
	var arcology_count := 0

	for index in range(ARCOLOGY_FIRST_INVENTION, ARCOLOGY_LAST_INVENTION + 1):
		if (BinaryData.read_u32_be(misc, MISC_INVENTION_YEARS + index * 4) & 0xffff) == 0:
			arcology_count += 1

	if progression >= 6 and arcology_count > 0:
		mask |= 0x10

	BinaryData.write_u32_be(misc, MISC_GRANTED_REWARDS, mask)

	return mask
