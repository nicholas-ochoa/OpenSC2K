class_name DisasterEnd
extends RefCounted
# the work that the original does when the last disaster marker and object
# are gone (0x0045cf10): a summary story, the removal of the police, fire, and
# military units that the disaster sent, and a newspaper


# summary story type for each disaster type, from the switch at 0x0045d179
const STORY_TYPES := {
	1: 0x16, 12: 0x16,
	2: 0x17, 14: 0x17,
	3: 0x23, 13: 0x23,
	4: 0x20,
	5: 0x18, 18: 0x18,
	6: 0x1b,
	7: 0x1a,
	8: 0x1c,
	9: 0x1d,
	10: 0x1e,
	11: 0x1f,
	15: 0x21,
	16: 0x22,
	17: 0x19,
}

# units that leave the map at the disaster end
const DISPATCH_TYPES := [
	Sc2ThingLayout.Type.POLICE, Sc2ThingLayout.Type.FIRE, Sc2ThingLayout.Type.MILITARY,
]

# the original opens the first newspaper here, not the player's choice
const NEWSPAPER_PAPER := 0


class Result extends RefCounted:
	var ok := false
	var error := ""
	var news_items: Array[NewsEvent] = []
	var removed_units := 0


static func finish(city: CityState, disaster_type: int) -> Result:
	var result := Result.new()

	if city == null or not city.is_valid():
		result.error = "city is invalid"

		return result

	if STORY_TYPES.has(disaster_type):
		var damage_class := maxi(city.disaster_damage_class, 0)
		result.news_items.append(NewsEvent.new(int(STORY_TYPES[disaster_type]), damage_class & 0xff))

	city.disaster_damage_class = -1
	var removed := _remove_dispatched_units(city)

	if removed < 0:
		result.error = "cannot remove the dispatched units"

		return result

	result.removed_units = removed
	result.ok = true

	return result


# clear each map label of a police, fire, or military unit and the type of
# its record. the original keeps the other record fields
static func _remove_dispatched_units(city: CityState) -> int:
	var thing_chunk := city.document.find_chunk("XTHG")

	if thing_chunk == null or thing_chunk.decoded_payload.size() != city.document.decoded_size("XTHG"):
		return -1

	var things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	var text := city.text_overlays.duplicate()
	var record_count := ThingData.count(things)
	var removed := 0

	for index in OverlayData.count(text):
		if city.simulation_slice != null and (index & 1023) == 0:
			city.simulation_slice.checkpoint()

		var label := OverlayData.read(text, index)

		if not OverlayData.is_thing(label):
			continue

		var record := OverlayData.thing_record(label)

		if record < 0 or record >= record_count:
			continue

		var offset := record * CityState.THING_RECORD_SIZE

		if not ThingData.read(things, offset) in DISPATCH_TYPES:
			continue

		OverlayData.write(text, index, 0)
		ThingData.write(things, offset, Sc2ThingLayout.Type.NONE)
		removed += 1

	if removed == 0:
		return 0

	if not thing_chunk.set_decoded_payload(things):
		return -1

	if not city.replace_text_overlays(text):
		return -1

	return removed
