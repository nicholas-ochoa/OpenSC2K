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


# a Windows folder supplies the data files. DOS and Macintosh records are converted
static func export_data_pack(source: Sc2ImportSource, folder: String, label: String, result: Sc2MediaImportResult) -> String:
	var root := data_root(source)
	var exporter := Sc2DataExport.new()

	if not root.is_empty():
		exporter.export_pack(root, folder, label + " Data", source.platform)
	else:
		exporter.export_records(source, folder, label + " Data")

	result.warnings.append_array(exporter.warnings)

	if exporter.error.is_empty():
		result.counts.data = exporter.count

	return exporter.error


# the folder with the Windows data files, for Windows 95 and Windows 3.x
static func data_root(source: Sc2ImportSource) -> String:
	var candidates := PackedStringArray([source.root])

	for resource in source.resources:
		for root in [resource.source.get_base_dir(), resource.source.get_base_dir().get_base_dir()]:
			if root not in candidates:
				candidates.append(root)

	for candidate in candidates:
		var complete := true

		for relative in DataPack.REQUIRED_FILES:
			complete = complete and Sc2ImportPath.has_file(candidate, relative)

		if complete:
			return candidate

	return ""


static func install_root(source: Sc2ImportSource) -> String:
	var candidates := PackedStringArray([source.root])

	for resource in source.resources:
		if Sc2ImportPath.key(resource.source.get_file()) == "SIMCITY.EXE":
			var root := resource.source.get_base_dir()

			if root not in candidates:
				candidates.append(root)

	for candidate in candidates:
		if OriginalGameInstaller.validate_install_root(candidate).ok:
			return candidate

	return ""
