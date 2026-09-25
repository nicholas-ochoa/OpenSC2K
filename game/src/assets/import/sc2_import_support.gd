class_name Sc2ImportSupport
extends RefCounted
## attach selected windows resources and game data during import


static func attach_runtime_data(source: Sc2ImportSource, folder: String, result: Sc2MediaImportResult) -> String:
	var candidate := install_root(source)

	if not candidate.is_empty():
		var path := folder.path_join("pack.json")
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var exporter := Sc2RuntimeExport.new()
		exporter.export_data(candidate, folder, manifest)

		if not exporter.error.is_empty():
			return exporter.error

		var file := FileAccess.open(path, FileAccess.WRITE)

		if file == null:
			return "Cannot save the imported runtime resources."

		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()
		result.counts.graphics += exporter.count
		return GameAssetSource.load_source("", "folder", folder).error

	if source.platform.begins_with("Windows"):
		result.warnings.append("The source is incomplete. Imported the available graphics; some interface or supporting data is missing.")

	return ""


# only a complete Windows installation supplies the game data files
static func export_data_pack(source: Sc2ImportSource, folder: String, label: String, result: Sc2MediaImportResult) -> String:
	var candidate := install_root(source)

	if candidate.is_empty():
		return "Game data needs a complete Windows SimCity 2000 installation."

	var exporter := Sc2DataExport.new()
	exporter.export_pack(candidate, folder, label + " Data", source.platform)

	if exporter.error.is_empty():
		result.counts.data = exporter.count

	return exporter.error


static func install_root(source: Sc2ImportSource) -> String:
	var candidates := PackedStringArray([source.root])

	for resource in source.resources:
		if resource.source.get_file().to_upper() == "SIMCITY.EXE":
			var root := resource.source.get_base_dir()

			if root not in candidates:
				candidates.append(root)

	for candidate in candidates:
		if OriginalGameInstaller.validate_install_root(candidate).ok:
			return candidate

	return ""
