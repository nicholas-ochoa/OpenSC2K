class_name ApplicationScurkOutput
extends RefCounted


const ScurkCityOutput = preload("res://src/assets/scurk_city_output.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")

var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func _ensure_scurk_print() -> void:
	if app.scurk_print != null:
		return

	app.scurk_print = app.main_overlays.ensure_scurk_print()
	app.scurk_print.preview_options_changed.connect(_refresh_scurk_print_preview)
	app.scurk_print.save_pdf_requested.connect(_open_scurk_print_pdf_dialog)
	app.desktop_presentation.print_dialog = app.scurk_print
	app.scurk_print_pdf_dialog = preload("res://src/ui/shared/file_dialog_factory.gd").city_pdf_save()
	app.scurk_print.add_child(app.scurk_print_pdf_dialog)
	app.scurk_print_pdf_dialog.file_selected.connect(_save_scurk_city_pdf)


func _open_scurk_city_export() -> void:
	if app.document_state.city == null or app.scurk_place_print == null or not app.scurk_place_print.visible:
		return

	if app.map_view.zoom_percent() > 25:
		app.interface.show_error("Zoom out to 25% before you export a Place & Print city.")

		return

	var output_directory := ProjectSettings.globalize_path("user://scurk_exports")
	DirAccess.make_dir_recursive_absolute(output_directory)
	app.scurk_city_export_dialog.current_dir = output_directory
	var output_name := app.document_state.city.city_name().validate_filename()

	if output_name.is_empty():
		output_name = "CITY"

	app.scurk_city_export_dialog.current_file = output_name + "_SMALL.BMP"
	app.scurk_city_export_dialog.popup_centered_ratio(0.75)


func _export_scurk_city_bmp(path: String) -> void:
	if app.document_state.city == null:
		return

	var output_path := ProjectSettings.globalize_path(path).simplify_path()

	if output_path.get_extension().to_lower() != "bmp":
		output_path += ".BMP"

	if output_path == app.asset_state.reference_root or output_path.begins_with(app.asset_state.reference_root + "/"):
		app.interface.show_error("Choose a location outside the read-only original support-data directory.")

		return

	var options := _current_scurk_output_options()
	options["color"] = true
	var result := ScurkCityOutput.save_small_bmp(
		output_path,
		app.document_state.city,
		app.asset_state.palette_index_encoding,
		app.asset_state.palette,
		app.static_render.sprite_archive_for_view(IsometricRenderer.VIEW_SMALL),
		options
	)

	if not result.ok:
		app.interface.show_error("Cannot export the Place & Print city: %s" % result.error)

		return

	var message := "Exported the small Place & Print city to %s." % output_path
	app.scurk_place_print.set_status(message)
	app.status_label.theme_type_variation = ""
	app.status_label.text = message


func _open_scurk_print_dialog() -> void:
	if app.document_state.city == null:
		return

	app.scurk_workspace.ensure_scurk_place_print()
	_ensure_scurk_print()

	app.scurk_print.configure(
		app.document_state.city.city_name(), CityViewMode.key(app.view_state.overlay_mode), app.view_state.surface_visibility,
		app.view_state.show_underground_pipes, app.view_state.show_underground_water_mains
	)
	app.scurk_print.show_workspace()


func _refresh_scurk_print_preview(options: Dictionary) -> void:
	if app.document_state.city == null or app.scurk_print == null:
		return

	var result := ScurkCityOutput.render(
		app.document_state.city,
		app.asset_state.palette,
		app.static_render.sprite_archive_for_view(IsometricRenderer.VIEW_SMALL),
		IsometricRenderer.VIEW_SMALL,
		options
	)

	if not result.ok:
		app.scurk_print.set_status("Cannot prepare the print preview: %s" % result.error)

		return

	app.scurk_print.set_preview_image(result.image)


func _open_scurk_print_pdf_dialog(options: Dictionary) -> void:
	if app.document_state.city == null:
		return

	app.scurk_state.pending_print_options = options.duplicate(true)
	var output_directory := ProjectSettings.globalize_path("user://scurk_prints")
	DirAccess.make_dir_recursive_absolute(output_directory)
	app.scurk_print_pdf_dialog.current_dir = output_directory
	var output_name := app.document_state.city.city_name().validate_filename()

	if output_name.is_empty():
		output_name = "CITY"

	app.scurk_print_pdf_dialog.current_file = "%s_%dx.PDF" % [
		output_name, int(options.get("magnification", 1)),
	]
	app.scurk_print_pdf_dialog.popup_centered_ratio(0.75)


func _save_scurk_city_pdf(path: String) -> void:
	if app.document_state.city == null or app.scurk_state.pending_print_options.is_empty():
		return

	var output_path := ProjectSettings.globalize_path(path).simplify_path()

	if output_path.get_extension().to_lower() != "pdf":
		output_path += ".PDF"

	if output_path == app.asset_state.reference_root or output_path.begins_with(app.asset_state.reference_root + "/"):
		app.interface.show_error("Choose a location outside the read-only original support-data directory.")

		return

	var magnification := int(app.scurk_state.pending_print_options.get("magnification", 1))
	var grid := ScurkCityOutput.page_grid(magnification)

	if grid.is_empty():
		app.interface.show_error("The selected print magnification is invalid.")

		return

	var result := ScurkCityOutput.save_pdf(
		output_path,
		app.document_state.city,
		app.asset_state.palette,
		app.static_render.sprite_archive_for_view(int(grid.view_size)),
		app.scurk_state.pending_print_options
	)

	if not result.ok:
		app.interface.show_error("Cannot write the printable city: %s" % result.error)

		return

	var message := "Wrote %d printable city pages to %s." % [
		int(result.page_count), output_path,
	]
	app.scurk_print.set_status(message)
	app.scurk_place_print.set_status(message)
	app.status_label.theme_type_variation = ""
	app.status_label.text = message
	app.scurk_state.pending_print_options.clear()


func _current_scurk_output_options() -> Dictionary:
	return {
		"view": CityViewMode.key(app.view_state.overlay_mode),
		"color": true,
		"surface_visibility": app.view_state.surface_visibility.duplicate(),
		"show_pipes": app.view_state.show_underground_pipes,
		"show_water_mains": app.view_state.show_underground_water_mains,
	}
