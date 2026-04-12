class_name CityNameGenerator
extends RefCounted

const DATA_PATH := "res://data/city_names.json"


static func generate(layout := "classic", random: RandomNumberGenerator = null,
	path := DATA_PATH) -> String:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return "New Grove"
	if random == null:
		random = RandomNumberGenerator.new()
		random.randomize()
	if not data.get("patterns", []) is Array or not data.get("features", {}) is Dictionary:
		return "New Grove"
	var patterns: Array = data.get("patterns", ["{root} {suffix}"]).duplicate()
	var features: Dictionary = data.get("features", {})
	# feature patterns have three times their normal selection weight
	for repeat in 3:
		if features.get(layout, []) is Array:
			patterns.append_array(features.get(layout, []))
	if patterns.is_empty():
		return "New Grove"
	for attempt in 30:
		var value := str(patterns[random.randi_range(0, patterns.size() - 1)])
		for key in ["prefix", "root", "suffix"]:
			if not data.get(key, []) is Array:
				return "New Grove"
			var parts: Array = data.get(key, ["Grove"])
			if parts.is_empty():
				return "New Grove"
			value = value.replace("{" + key + "}", str(parts[random.randi_range(0, parts.size() - 1)]))
		value = value.strip_edges()
		if value.length() <= 30 and not value.is_empty():
			return value
	return "New Grove"
