class_name ScurkImageImport
extends RefCounted

static func load_path(path: String, palette: Sc2Palette) -> Dictionary:
	if path.get_extension().to_lower() == "bmp":
		return IndexedBmp.load_path(path, palette)
	if path.get_extension().to_lower() != "png":
		return {"ok": false, "error": "Select an indexed PNG or BMP image."}
	var decoded := IndexedPng.load_path(path, false)
	if not decoded.ok:
		return decoded
	if palette == null or not palette.is_valid():
		return {"ok": false, "error": "The city palette is not available."}
	var mapping := {}
	var remapped := 0
	var pixels: PackedInt32Array = decoded.pixels.duplicate()
	for index in pixels.size():
		var color_index := pixels[index]
		if color_index < 0:
			continue
		if not mapping.has(color_index):
			var color: Color = decoded.palette.color(color_index)
			mapping[color_index] = color_index if IndexedBmp._same_rgb(color, palette.color(color_index)) else IndexedBmp._nearest_palette_index(color, palette)
			if mapping[color_index] != color_index:
				remapped += 1
		pixels[index] = mapping[color_index]
	return {"ok": true, "error": "", "width": decoded.width, "height": decoded.height, "pixels": pixels, "remapped_color_count": remapped}
