class_name ScenarioGraphics
extends RefCounted
# key by pict bytes so renaming the city doesn't change its picture
# display-only replacements keyed by pict bytes, independent of file names

var error := ""
var records: Array[Dictionary] = []
var images: Dictionary = {}


static func load_manifest(value: Variant, read_png: Callable, palette: Sc2Palette) -> ScenarioGraphics:
	var result := ScenarioGraphics.new()
	result._load(value, read_png, palette)
	return result


static func render(scenario: ScenarioState, palette: Sc2Palette, graphics: ScenarioGraphics = null) -> Dictionary:
	if graphics != null:
		var picture := scenario.picture_indices()
		var chunk := scenario.document.find_chunk("PICT")
		if picture.ok and chunk != null:
			var key := fingerprint(chunk.decoded_payload)
			var image: Image = graphics.images.get(key)
			if image != null and image.get_size() == Vector2i(picture.width, picture.height):
				return {"ok": true, "image": image, "width": picture.width, "height": picture.height, "error": "", "replacement": true}
	var original := scenario.picture_image(palette)
	original.replacement = false
	return original


static func fingerprint(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _load(value: Variant, read_png: Callable, palette: Sc2Palette) -> void:
	if not value is Array or value.is_empty():
		error = "scenario_pictures must be a nonempty array"
		return
	var ids := {}
	for record in value:
		if not record is Dictionary or not record.get("id") is String or str(record.id).strip_edges().is_empty():
			error = "Scenario picture requires a nonempty string id"
			return
		var key: Variant = record.get("pict_sha256")
		if not _valid_hash(key):
			error = "Scenario picture requires a lowercase PICT SHA-256"
			return
		if ids.has(record.id) or images.has(key):
			error = "Scenario picture IDs and PICT hashes must be unique"
			return
		var png: Dictionary = read_png.call(record.get("png"))
		if not png.get("ok", false):
			error = "Cannot read scenario picture %s" % record.id
			return
		if png.pixels.has(-1) or png.palette.colors != palette.colors:
			error = "Scenario pictures must be opaque and use the ordered scenario palette"
			return
		images[key] = Sc2SpriteArchive.entry_from_indices(0, png.width, png.height, png.pixels).create_image(palette).image
		ids[record.id] = true
		records.append(record.duplicate(true))


static func _valid_hash(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true
