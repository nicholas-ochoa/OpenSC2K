extends SceneTree

const PeBitmap = preload("res://src/assets/pe_bitmap_resource.gd")


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()

	if arguments.is_empty():
		printerr("Usage: godot --headless --path game --script res://tools/list_pe_bitmaps.gd -- PE_FILE")
		quit(2)

		return

	var path := ProjectSettings.globalize_path(arguments[0])
	var show_patterns := arguments.has("--patterns")
	var requested_ids := PackedInt32Array()
	var output_directory := ""

	for argument in arguments.slice(1):
		if str(argument).begins_with("--output-dir="):
			output_directory = ProjectSettings.globalize_path(
				str(argument).trim_prefix("--output-dir=")
			)
		elif str(argument).is_valid_int():
			requested_ids.append(int(argument))

	var listed := PeBitmap.list_numeric_bitmap_ids(path)

	if not listed.ok:
		printerr(listed.error)
		quit(1)

		return

	if not output_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(output_directory)

	for resource_id in listed.ids:
		if not requested_ids.is_empty() and not requested_ids.has(resource_id):
			continue

		var dib := PeBitmap.load_numeric_dib(path, resource_id)
		var loaded := PeBitmap.load_numeric(path, resource_id)

		if not loaded.ok:
			print("%d: %s" % [resource_id, loaded.error])
			continue

		var image: Image = loaded.image
		print("%d: %d x %d, format %d, %d bpp, compression %d" % [
			resource_id, image.get_width(), image.get_height(),
			image.get_format(), dib.bits_per_pixel, dib.compression,
		])

		if not output_directory.is_empty():
			var output_path := output_directory.path_join("%d.png" % resource_id)
			var save_error := image.save_png(output_path)

			if save_error != OK:
				printerr("Cannot save %s: %s" % [output_path, error_string(save_error)])

		if show_patterns and image.get_width() == 8 and image.get_height() == 8:
			var first := image.get_pixel(0, 0)
			var colors: Array[String] = []

			for y in 8:
				for x in 8:
					var color_hex := image.get_pixel(x, y).to_html()

					if not colors.has(color_hex):
						colors.append(color_hex)

			print("  colors: " + ", ".join(colors))

			for y in 8:
				var row := ""

				for x in 8:
					row += "#" if image.get_pixel(x, y) == first else "."

				print("  " + row)

			if dib.bits_per_pixel == 8 and dib.compression == 0:
				var dib_bytes: PackedByteArray = dib.bytes
				var color_count: int = dib.color_count if dib.color_count > 0 else 256
				var pixel_offset := 40 + color_count * 4
				var row_stride := int((image.get_width() + 3) / 4) * 4

				for y in 8:
					var source_y := 7 - y
					var indices: Array[String] = []

					for x in 8:
						indices.append("%02X" % dib_bytes[pixel_offset + source_y * row_stride + x])

					print("  indices: " + " ".join(indices))

	quit()
