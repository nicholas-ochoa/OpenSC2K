class_name ImageClipboard
extends RefCounted

const TEMP_DIRECTORY := "user://clipboard"
const TEMP_FILENAME := "scurk-copy.png"


static func copy_indexed(
	width: int,
	height: int,
	pixels: PackedInt32Array,
	palette: Sc2Palette
) -> Dictionary:
	var converted := indexed_to_image(width, height, pixels, palette)
	if not converted.ok:
		return converted
	if DisplayServer.get_name() == "headless":
		return _failure("Image clipboard output is not available in headless mode.")
	var directory := ProjectSettings.globalize_path(TEMP_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK:
		return _failure(
			"Cannot create the clipboard directory: %s" % error_string(directory_error)
		)
	var path := directory.path_join(TEMP_FILENAME)
	var save_error: Error = converted.image.save_png(path)
	if save_error != OK:
		return _failure("Cannot create the clipboard image: %s" % error_string(save_error))
	var copied := _copy_png_path(path)
	DirAccess.remove_absolute(path)
	return copied


static func paste_indexed(palette: Sc2Palette) -> Dictionary:
	if DisplayServer.get_name() == "headless":
		return _failure("Image clipboard input is not available in headless mode.")
	if not DisplayServer.clipboard_has_image():
		return _failure("The system clipboard does not contain an image.")
	var image := DisplayServer.clipboard_get_image()
	if image == null or image.is_empty():
		return _failure("The system clipboard image cannot be read.")
	return image_to_indexed(image, palette)


static func indexed_to_image(
	width: int,
	height: int,
	pixels: PackedInt32Array,
	palette: Sc2Palette
) -> Dictionary:
	if width <= 0 or height <= 0 or pixels.size() != width * height:
		return _failure("Clipboard pixel count does not match its dimensions.")
	if palette == null or not palette.is_valid():
		return _failure("The SimCity 2000 palette is not available.")
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var index := pixels[y * width + x]
			if index < 0:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
			elif index < 256:
				var color := palette.color(index)
				color.a = 1.0
				image.set_pixel(x, y, color)
			else:
				return _failure("Clipboard image has an invalid palette index.")
	return {"ok": true, "error": "", "image": image}


static func image_to_indexed(image: Image, palette: Sc2Palette) -> Dictionary:
	if image == null or image.is_empty():
		return _failure("Clipboard image is empty.")
	if palette == null or not palette.is_valid():
		return _failure("The SimCity 2000 palette is not available.")
	var source: Image = image.duplicate()
	source.convert(Image.FORMAT_RGBA8)
	var width: int = source.get_width()
	var height: int = source.get_height()
	var pixels := PackedInt32Array()
	pixels.resize(width * height)
	var exact_indices := _exact_palette_indices(palette)
	var mapped_indices := {}
	var remapped_color_count := 0
	for y in height:
		for x in width:
			var color: Color = source.get_pixel(x, y)
			var pixel_offset: int = y * width + x
			if color.a < 0.5:
				pixels[pixel_offset] = -1
				continue
			var rgb_key := _rgb_key(color)
			if exact_indices.has(rgb_key):
				pixels[pixel_offset] = int(exact_indices[rgb_key])
				continue
			if not mapped_indices.has(rgb_key):
				mapped_indices[rgb_key] = _nearest_palette_index(color, palette)
				remapped_color_count += 1
			pixels[pixel_offset] = int(mapped_indices[rgb_key])
	return {
		"ok": true,
		"error": "",
		"width": width,
		"height": height,
		"pixels": pixels,
		"remapped_color_count": remapped_color_count,
	}


static func _copy_png_path(path: String) -> Dictionary:
	var command := _copy_command(OS.get_name(), path)
	if not command.ok:
		return command
	var output: Array = []
	var exit_code := OS.execute(
		command.executable, command.arguments, output, true
	)
	if exit_code != 0:
		var detail := "\n".join(PackedStringArray(output)).strip_edges()
		return _failure(
			"Cannot copy the image to the system clipboard%s"
			% [(": " + detail) if not detail.is_empty() else "."]
		)
	return {"ok": true, "error": ""}


static func _copy_command(platform: String, path: String) -> Dictionary:
	if platform == "macOS":
		var executable := "/usr/bin/osascript"
		if not FileAccess.file_exists(executable):
			return _failure("The macOS clipboard command is not available.")
		var escaped_path := path.replace("\\", "\\\\").replace("\"", "\\\"")
		return {
			"ok": true,
			"error": "",
			"executable": executable,
			"arguments": PackedStringArray([
				"-e",
				"set the clipboard to (read (POSIX file \"%s\") as «class PNGf»)"
				% escaped_path,
			]),
		}
	if platform == "Windows":
		var windows_root := OS.get_environment("SystemRoot")
		var executable := (
			windows_root.path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
			if not windows_root.is_empty()
			else "powershell.exe"
		)
		var escaped_path := path.replace("'", "''")
		var script := (
			"Add-Type -AssemblyName System.Windows.Forms; "
			+ "Add-Type -AssemblyName System.Drawing; "
			+ "$image=[System.Drawing.Image]::FromFile('%s'); " % escaped_path
			+ "try {[System.Windows.Forms.Clipboard]::SetImage($image)} "
			+ "finally {$image.Dispose()}"
		)
		return {
			"ok": true,
			"error": "",
			"executable": executable,
			"arguments": PackedStringArray([
				"-NoProfile", "-NonInteractive", "-STA", "-Command", script,
			]),
		}
	if platform == "Linux":
		var executable := _find_executable("xclip")
		if executable.is_empty():
			return _failure("Image clipboard output requires xclip on Linux.")
		return {
			"ok": true,
			"error": "",
			"executable": executable,
			"arguments": PackedStringArray([
				"-selection", "clipboard", "-target", "image/png", "-i", path,
			]),
		}
	return _failure("Image clipboard output is not supported on %s." % platform)


static func _find_executable(filename: String) -> String:
	for directory in OS.get_environment("PATH").split(":", false):
		var candidate := directory.path_join(filename)
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


static func _exact_palette_indices(palette: Sc2Palette) -> Dictionary:
	var indices := {}
	for index in 256:
		var key := _rgb_key(palette.color(index))
		if not indices.has(key):
			indices[key] = index
	return indices


static func _nearest_palette_index(source: Color, palette: Sc2Palette) -> int:
	var source_r := clampi(roundi(source.r * 255.0), 0, 255)
	var source_g := clampi(roundi(source.g * 255.0), 0, 255)
	var source_b := clampi(roundi(source.b * 255.0), 0, 255)
	var best_index := 0
	var best_distance := 0x7fffffff
	for index in 256:
		var target := palette.color(index)
		var delta_r := source_r - clampi(roundi(target.r * 255.0), 0, 255)
		var delta_g := source_g - clampi(roundi(target.g * 255.0), 0, 255)
		var delta_b := source_b - clampi(roundi(target.b * 255.0), 0, 255)
		var distance := delta_r * delta_r + delta_g * delta_g + delta_b * delta_b
		if distance < best_distance:
			best_index = index
			best_distance = distance
			if distance == 0:
				break
	return best_index


static func _rgb_key(color: Color) -> int:
	return (
		clampi(roundi(color.r * 255.0), 0, 255) << 16
		| clampi(roundi(color.g * 255.0), 0, 255) << 8
		| clampi(roundi(color.b * 255.0), 0, 255)
	)


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
