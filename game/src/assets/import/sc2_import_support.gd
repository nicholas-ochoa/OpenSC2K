class_name Sc2ImportSupport
extends RefCounted
## Retain a usable Windows base when it is present in the selected source.


static func attach_windows_base(source: Sc2ImportSource, folder: String) -> String:
	var candidates := PackedStringArray([source.root])

	for resource in source.resources:
		if resource.source.get_file().to_upper() == "SIMCITY.EXE":
			var root := resource.source.get_base_dir()

			if root not in candidates:
				candidates.append(root)

	for candidate in candidates:
		if not OriginalGameInstaller.validate_install_root(candidate).ok:
			continue

		var support := folder.path_join("original")
		var copied := OriginalGameInstaller.install_from_executable(candidate.path_join("SIMCITY.EXE"), support)

		if not copied.ok:
			return "Graphics were converted, but the source support files could not be copied: " + copied.error

		var path := folder.path_join("pack.json")
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		manifest["original_data"] = "original"
		var temporary := folder.path_join("pack-with-support.json")
		var file := FileAccess.open(temporary, FileAccess.WRITE)

		if file == null:
			OriginalGameInstaller.remove_tree(support)
			return "Graphics were converted, but the support-file reference could not be saved."

		file.store_string(JSON.stringify(manifest, "\t"))
		file.flush()
		var error := file.get_error()
		file.close()

		if error != OK:
			DirAccess.remove_absolute(temporary)
			OriginalGameInstaller.remove_tree(support)
			return "Cannot finish the graphics support-file reference: " + error_string(error)

		if DirAccess.rename_absolute(temporary, path) != OK:
			DirAccess.remove_absolute(temporary)
			OriginalGameInstaller.remove_tree(support)
			return "Graphics were converted, but the support-file reference could not be attached."

		return ""

	return "No complete Windows support set was found. A pack with both city sprite size groups can run independently; missing interface artwork and text use built-in controls and messages."
