class_name OriginalTextLocalization
extends RefCounted
## Display-only translations of original text resources. Imported assets stay unchanged.


static func text(resource_id: int, fallback := "") -> String:
	var key := "SC2K text %d" % resource_id
	var translated := String(TranslationServer.translate(key, "original"))
	return fallback if translated == key else translated


static func library_texts(source: Dictionary) -> Dictionary:
	var result := source.duplicate()
	for resource_id: int in LibraryRuminateWindows.TEXT_RESOURCE_IDS:
		var value := text(resource_id, str(source.get(resource_id, "")))
		if not value.is_empty():
			result[resource_id] = value
	return result


static func scenario(description: String) -> String:
	var source := description.replace("\r\n", "\n").replace("\r", "\n").strip_edges()
	return String(TranslationServer.translate(source, "scenario"))
