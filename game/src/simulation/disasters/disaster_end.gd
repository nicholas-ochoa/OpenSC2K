class_name DisasterEnd
extends RefCounted
# the work that the original does when the last disaster marker and object
# are gone (0x0045cf10): a summary story, the removal of the police, fire, and
# military units that the disaster sent, and a newspaper

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
