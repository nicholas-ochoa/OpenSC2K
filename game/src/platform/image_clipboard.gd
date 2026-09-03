class_name ImageClipboard
extends RefCounted

const IndexedBitmap = preload("res://src/assets/indexed_bmp.gd")

const TEMP_DIRECTORY := "user://clipboard"
const TEMP_PNG_FILENAME := "scurk-copy.png"
const TEMP_BMP_FILENAME := "scurk-copy.bmp"
const TEMP_DIB_FILENAME := "scurk-copy.dib"


class Result extends RefCounted:
	var ok := false
	var error := ""

	static func failure(message: String) -> Result:
		var result := Result.new()
		result.error = message

		return result


class Command extends Result:
	var executable := ""
	var arguments := PackedStringArray()

	static func rejected(message: String) -> Command:
		var result := Command.new()
		result.error = message

		return result


static func copy_indexed(
	width: int,
	height: int,
	pixels: PackedInt32Array,
	palette: Sc2Palette
) -> Result:
	if DisplayServer.get_name() == "headless":
		return Result.failure("Image clipboard output is not available in headless mode.")

	var platform := OS.get_name()
	var directory := ProjectSettings.globalize_path(TEMP_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)

	if directory_error != OK:
		return Result.failure(
			"Cannot create the clipboard directory: %s" % error_string(directory_error)
		)

	var path := ""

	if platform == "macOS":
		var converted := indexed_to_image(width, height, pixels, palette)

		if not converted.ok:
			return Result.failure(converted.error)

		path = directory.path_join(TEMP_PNG_FILENAME)
		var save_error: Error = converted.image.save_png(path)

		if save_error != OK:
			return Result.failure(
				"Cannot create the clipboard image: %s" % error_string(save_error)
			)
	else:
		var encoded := IndexedBitmap.encode(width, height, pixels, palette)

		if not encoded.ok:
			return Result.failure(encoded.error)

		var payload: PackedByteArray = encoded.bytes
		path = directory.path_join(TEMP_BMP_FILENAME)

		if platform == "Windows":
			var dib := IndexedBitmap.bmp_to_dib(payload)

			if not dib.ok:
				return Result.failure(dib.error)

			payload = dib.bytes
			path = directory.path_join(TEMP_DIB_FILENAME)

		var write_result := _write_bytes(path, payload)

		if not write_result.ok:
			return write_result

	var copied := _copy_path(platform, path)
	DirAccess.remove_absolute(path)

	return copied


static func paste_indexed(palette: Sc2Palette) -> IndexedImageResult:
	if DisplayServer.get_name() == "headless":
		return IndexedImageResult.failure("Image clipboard input is not available in headless mode.")

	var platform := OS.get_name()

	if platform == "Windows" or platform == "Linux":
		var native := _paste_native_indexed(platform, palette)

		if native.ok:
			return native

	if not DisplayServer.clipboard_has_image():
		return IndexedImageResult.failure("The system clipboard does not contain an image.")

	var image := DisplayServer.clipboard_get_image()

	if image == null or image.is_empty():
		return IndexedImageResult.failure("The system clipboard image cannot be read.")

	return image_to_indexed(image, palette)


static func indexed_to_image(
	width: int,
	height: int,
	pixels: PackedInt32Array,
	palette: Sc2Palette
) -> AssetImageResult:
	if width <= 0 or height <= 0 or pixels.size() != width * height:
		return AssetImageResult.failure("Clipboard pixel count does not match its dimensions.")

	if palette == null or not palette.is_valid():
		return AssetImageResult.failure("The SimCity 2000 palette is not available.")

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
				return AssetImageResult.failure("Clipboard image has an invalid palette index.")

	var result := AssetImageResult.new()
	result.ok = true
	result.error = ""
	result.image = image

	return result


static func image_to_indexed(image: Image, palette: Sc2Palette) -> IndexedImageResult:
	if image == null or image.is_empty():
		return IndexedImageResult.failure("Clipboard image is empty.")

	if palette == null or not palette.is_valid():
		return IndexedImageResult.failure("The SimCity 2000 palette is not available.")

	var source: Image = image.duplicate()
	source.convert(Image.FORMAT_RGBA8)
	var width: int = source.get_width()
	var height: int = source.get_height()
	var pixels := PackedInt32Array()
	pixels.resize(width * height)
	var exact_indices := _exact_palette_indices(palette)
	var mapped_indices: Dictionary[int, int] = {}
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

	var result := IndexedImageResult.new()
	result.ok = true
	result.error = ""
	result.width = width
	result.height = height
	result.pixels = pixels
	result.remapped_color_count = remapped_color_count

	return result


static func _copy_path(platform: String, path: String) -> Result:
	var command := _copy_command(platform, path)

	if not command.ok:
		return command

	var output: Array = []
	var exit_code := OS.execute(
		command.executable, command.arguments, output, true
	)

	if exit_code != 0:
		var detail := "\n".join(PackedStringArray(output)).strip_edges()

		return Result.failure(
			"Cannot copy the image to the system clipboard%s"
			% [(": " + detail) if not detail.is_empty() else "."]
		)

	var result := Result.new()
	result.ok = true
	result.error = ""

	return result


static func _copy_command(
	platform: String, path: String, linux_executable := ""
) -> Command:
	if platform == "macOS":
		var executable := "/usr/bin/osascript"

		if not FileAccess.file_exists(executable):
			return Command.rejected("The macOS clipboard command is not available.")

		var escaped_path := path.replace("\\", "\\\\").replace("\"", "\\\"")

		var result := Command.new()
		result.ok = true
		result.error = ""
		result.executable = executable
		result.arguments = PackedStringArray([
			"-e",
			"set the clipboard to (read (POSIX file \"%s\") as «class PNGf»)"
			% escaped_path,
		])

		return result

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
			+ "$bytes=[System.IO.File]::ReadAllBytes('%s'); " % escaped_path
			+ "$stream=[System.IO.MemoryStream]::new($bytes,$false); "
			+ "$data=[System.Windows.Forms.DataObject]::new(); "
			+ "$data.SetData([System.Windows.Forms.DataFormats]::Dib,$stream); "
			+ "try {[System.Windows.Forms.Clipboard]::SetDataObject($data,$true)} "
			+ "finally {$stream.Dispose()}"
		)

		var result := Command.new()
		result.ok = true
		result.error = ""
		result.executable = executable
		result.arguments = PackedStringArray([
			"-NoProfile", "-NonInteractive", "-STA", "-Command", script,
		])

		return result

	if platform == "Linux":
		var executable: String = linux_executable

		if executable.is_empty():
			executable = _find_executable("xclip")

		if executable.is_empty():
			return Command.rejected("Image clipboard output requires xclip on Linux.")

		var result := Command.new()
		result.ok = true
		result.error = ""
		result.executable = executable
		result.arguments = PackedStringArray([
			"-selection", "clipboard", "-target", "image/bmp", "-i", path,
		])

		return result

	return Command.rejected("Image clipboard output is not supported on %s." % platform)


static func _paste_native_indexed(platform: String, palette: Sc2Palette) -> IndexedImageResult:
	var directory := ProjectSettings.globalize_path(TEMP_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)

	if directory_error != OK:
		return IndexedImageResult.failure(
			"Cannot create the clipboard directory: %s" % error_string(directory_error)
		)

	var path := directory.path_join(
		TEMP_DIB_FILENAME if platform == "Windows" else TEMP_BMP_FILENAME
	)
	var command := _paste_command(platform, path)

	if not command.ok:
		return IndexedImageResult.failure(command.error)

	DirAccess.remove_absolute(path)
	var output: Array = []
	var exit_code := OS.execute(command.executable, command.arguments, output, true)

	if exit_code != 0 or not FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

		return IndexedImageResult.failure("The system clipboard does not contain indexed image data.")

	var bytes := FileAccess.get_file_as_bytes(path)
	var read_error := FileAccess.get_open_error()
	DirAccess.remove_absolute(path)

	if read_error != OK:
		return IndexedImageResult.failure("Cannot read the indexed clipboard data.")

	var decoded := (
		IndexedBitmap.decode_dib(bytes)
		if platform == "Windows"
		else IndexedBitmap.decode(bytes)
	)

	if not decoded.ok:
		return IndexedImageResult.failure(decoded.error)

	var mapped := IndexedBitmap.map_to_palette(decoded, palette)

	if not mapped.ok:
		return IndexedImageResult.failure(mapped.error)

	var result := IndexedImageResult.new()
	result.ok = true
	result.error = ""
	result.width = decoded.width
	result.height = decoded.height
	result.pixels = mapped.pixels
	result.remapped_color_count = mapped.remapped_color_count

	return result


static func _paste_command(
	platform: String, path: String, linux_executable := ""
) -> Command:
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
			+ "$value=[System.Windows.Forms.Clipboard]::GetData("
			+ "[System.Windows.Forms.DataFormats]::Dib); "
			+ "if ($null -eq $value) {exit 3}; "
			+ "if ($value -is [System.IO.MemoryStream]) {$bytes=$value.ToArray()} "
			+ "elseif ($value -is [byte[]]) {$bytes=$value} else {exit 4}; "
			+ "[System.IO.File]::WriteAllBytes('%s',$bytes)" % escaped_path
		)

		var result := Command.new()
		result.ok = true
		result.error = ""
		result.executable = executable
		result.arguments = PackedStringArray([
			"-NoProfile", "-NonInteractive", "-STA", "-Command", script,
		])

		return result

	if platform == "Linux":
		var executable: String = linux_executable

		if executable.is_empty():
			executable = _find_executable("xclip")

		if executable.is_empty():
			return Command.rejected("Indexed clipboard input requires xclip on Linux.")

		var result := Command.new()
		result.ok = true
		result.error = ""
		result.executable = "/bin/sh"
		result.arguments = PackedStringArray([
			"-c",
			"%s -selection clipboard -target image/bmp -o > %s"
			% [_shell_quote(executable), _shell_quote(path)],
		])

		return result

	return Command.rejected("Indexed clipboard input is not supported on %s." % platform)


static func _write_bytes(path: String, bytes: PackedByteArray) -> Result:
	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		return Result.failure(
			"Cannot create the clipboard image: %s"
			% error_string(FileAccess.get_open_error())
		)

	file.store_buffer(bytes)
	var write_error := file.get_error()
	file.close()

	if write_error != OK:
		return Result.failure(
			"Cannot write the clipboard image: %s" % error_string(write_error)
		)

	var result := Result.new()
	result.ok = true
	result.error = ""

	return result


static func _shell_quote(value: String) -> String:
	return "'" + value.replace("'", "'\"'\"'") + "'"


static func _find_executable(filename: String) -> String:
	for directory in OS.get_environment("PATH").split(":", false):
		var candidate := directory.path_join(filename)

		if FileAccess.file_exists(candidate):
			return candidate

	return ""


static func _exact_palette_indices(palette: Sc2Palette) -> Dictionary[int, int]:
	var indices: Dictionary[int, int] = {}

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
