class_name Sc2MediaImporter
extends RefCounted
## Convert requested categories independently. Preserve every successful pack.

const CATEGORIES := ["graphics", "sound", "music"]


static func import_assets(path: String, packs_root: String, categories: PackedStringArray = PackedStringArray(["graphics", "sound", "music"])) -> Sc2MediaImportResult:
	var result := Sc2MediaImportResult.new()

	if categories.is_empty():
		result.error = "Select at least one asset type."
		return result

	for category in categories:
		if category not in CATEGORIES:
			result.error = "Unknown asset type: " + category
			return result

	var source := Sc2ImportSource.scan(path)
	result.platform = source.platform
	result.warnings = source.warnings.duplicate()

	if not source.error.is_empty():
		result.error = source.error
		return result

	var destination := ProjectSettings.globalize_path(packs_root).simplify_path()

	if destination == source.root or destination.begins_with(source.root + "/") or source.root.begins_with(destination + "/"):
		result.error = "Choose an import destination separate from the source game folder."
		return result

	var label := "SimCity 2000 — " + source.platform
	var unique := "%s-%d-%d-%d" % [source.platform.validate_filename().replace(" ", "-"), Time.get_unix_time_from_system(), OS.get_process_id(), Time.get_ticks_usec()]
	var target := destination.path_join(unique)
	var stage := target + ".staging"

	if DirAccess.dir_exists_absolute(stage) or DirAccess.dir_exists_absolute(target) or DirAccess.make_dir_recursive_absolute(stage) != OK:
		result.error = "Cannot create a new import folder."
		return result

	for category in CATEGORIES:
		if category not in categories:
			continue

		if category == "graphics":
			var graphics := Sc2ImportGraphics.export_pack(source, stage.path_join(category), label)
			result.warnings.append_array(graphics.warnings)

			if graphics.error.is_empty():
				result.counts[category] = graphics.count
				var support_warning := Sc2ImportSupport.attach_windows_base(source, stage.path_join(category))

				if not support_warning.is_empty():
					result.warnings.append(support_warning)
			else:
				result.failures[category] = graphics.error

			continue

		_import_audio(source, category, stage.path_join(category), label, result)

	if result.counts.is_empty():
		OriginalGameInstaller.remove_tree(stage)
		result.error = "No requested assets could be imported."
		return result

	if DirAccess.rename_absolute(stage, target) != OK:
		OriginalGameInstaller.remove_tree(stage)
		result.error = "Cannot finish the imported pack folder."
		result.counts.clear()
		return result

	result.root = target
	result.ok = true
	result.partial = not result.failures.is_empty() or not result.warnings.is_empty()

	for category in result.counts:
		result.set(category, target.path_join(category + "/pack.json"))

	return result


static func _import_audio(source: Sc2ImportSource, category: String, folder: String, label: String, result: Sc2MediaImportResult) -> void:
	var first := 500 if category == "sound" else 10000
	var last := 529 if category == "sound" else 10018
	var entries: Dictionary = {}
	var origins: Dictionary = {}
	var extension := "wav" if category == "sound" else "mid"

	for resource in source.resources:
		# Resource IDs are scoped to a type. Mac sounds can use music-range IDs.
		if (resource.type in ["snd ", "WAVE"] and category != "sound") or (resource.type == "MIDI" and category != "music"):
			continue

		var id := resource.id if resource.type in ["snd ", "MIDI", "WAVE"] else -1

		var stem := resource.name.get_file().get_basename()

		var source_extension := resource.name.get_extension().to_lower()

		if id < 0 and stem.is_valid_int() and source_extension in ["wav", "mid", "midi", "voc", "xmi"]:
			id = int(stem)

		if id < first or id > last:
			continue

		var bytes := resource.bytes
		var conversion: AssetBytesResult

		if category == "sound" and source_extension == "voc":
			conversion = Sc2ImportVoc.convert(bytes)
		elif category == "music" and source_extension == "xmi":
			conversion = Sc2ImportXmi.convert(bytes)

		if conversion != null:
			if not conversion.ok:
				result.warnings.append("%s %d: %s" % [category.capitalize(), id, conversion.error])
				continue

			bytes = conversion.bytes

		if category == "sound" and resource.type == "snd ":
			var converted := Sc2ImportAudio.mac_sound(bytes)

			if not converted.ok:
				result.warnings.append("Sound %d: %s" % [id, converted.error])
				continue

			bytes = converted.bytes

		if category == "sound":
			if bytes.size() < 12 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF" or bytes.slice(8, 12).get_string_from_ascii() != "WAVE" or AudioStreamWAV.load_from_buffer(bytes) == null:
				result.warnings.append("Sound %d is not a readable WAV file." % id)
				continue
		else:
			var midi := StandardMidiFile.new()

			if not midi.parse(bytes):
				result.warnings.append("Music %d: %s" % [id, midi.parse_error])
				continue

		if entries.has(str(id)):
			# Keep deterministic first-source precedence; report conflicting copies.
			var prior := FileAccess.get_file_as_bytes(folder.path_join(entries[str(id)]))

			if prior != bytes:
				result.warnings.append("More than one %s asset has ID %d. Kept the first readable copy." % [category, id])
			continue

		var name := "%d.%s" % [id, extension]
		var write_error := _write(folder.path_join(name), bytes)

		if not write_error.is_empty():
			result.failures[category] = write_error
			OriginalGameInstaller.remove_tree(folder)
			return

		entries[str(id)] = name
		origins[str(id)] = {"container": resource.source.get_file(), "record": resource.name}

	if entries.is_empty():
		result.failures[category] = "No convertible %s assets with known game IDs were found." % category
		OriginalGameInstaller.remove_tree(folder)
		return

	var manifest := {"format": "opensc2k-" + category, "version": 1, "name": label + " " + category.capitalize(), "source_platform": source.platform, "files": entries, "source_assets": origins}
	var write_error := _write(folder.path_join("pack.json"), JSON.stringify(manifest, "\t").to_utf8_buffer())

	if write_error.is_empty():
		write_error = MediaPack.load_folder(folder, category).error

	if not write_error.is_empty():
		result.failures[category] = write_error
		OriginalGameInstaller.remove_tree(folder)
		return

	result.counts[category] = entries.size()

	if entries.size() < last - first + 1:
		result.warnings.append("%s contains %d of %d standard asset IDs. Missing entries need assets from the base game." % [category.capitalize(), entries.size(), last - first + 1])


static func _write(path: String, bytes: PackedByteArray) -> String:
	if FileAccess.file_exists(path) or DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return "Cannot create import file: " + path.get_file()

	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		return "Cannot write import file: " + path.get_file()

	file.store_buffer(bytes)
	file.flush()

	return "" if file.get_error() == OK else "Cannot finish import file: " + path.get_file()
