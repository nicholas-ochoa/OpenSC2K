class_name FileDialogFactory
extends RefCounted


static func city_open() -> FileDialog:
	return _create(
		FileDialog.FILE_MODE_OPEN_FILE,
		[
			["*.SC2, *.sc2", "SimCity 2000 cities"],
			["*.sc2x", "Experimental large cities"],
			["*.SCN, *.scn", "SimCity 2000 scenarios"],
		],
	)


static func city_save() -> FileDialog:
	return _create(
		FileDialog.FILE_MODE_SAVE_FILE,
		[["*.sc2, *.SC2", "SimCity 2000 cities"], ["*.sc2x", "Experimental large cities"]],
	)


static func tile_set_open() -> FileDialog:
	return _create(
		FileDialog.FILE_MODE_OPEN_FILE,
		[["*.MIF, *.mif", "SCURK tile sets"]],
	)


static func city_bitmap_save() -> FileDialog:
	return _create(
		FileDialog.FILE_MODE_SAVE_FILE,
		[["*.BMP, *.bmp", "Windows indexed bitmap"]],
	)


static func city_pdf_save() -> FileDialog:
	return _create(
		FileDialog.FILE_MODE_SAVE_FILE,
		[["*.PDF, *.pdf", "Printable PDF"]],
	)


static func _create(file_mode: int, filters: Array) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.theme = AppUiTheme.file_dialog()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = file_mode

	for filter in filters:
		dialog.add_filter(str(filter[0]), str(filter[1]))

	return dialog
