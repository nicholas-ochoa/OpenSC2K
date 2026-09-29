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


static func finish(city: CityState, disaster_type: int) -> Result:
	if city == null or not city.is_valid():
		var result := Result.new()
		result.error = "city is invalid"

		return result

	return NativeSimulationBridge.run("disaster_end", city, null, null, null, {"disaster_type": disaster_type}).result


class Result extends RefCounted:
	var ok := false
	var error := ""
	var news_items: Array[NewsEvent] = []
	var removed_units := 0
