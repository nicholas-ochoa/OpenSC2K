class_name CityPngExportDialog
extends ConfirmationDialog


signal export_requested(options: CityPngExportJob.Options)

const ExportJob = preload("res://src/view/city_png_export_job.gd")
const FileDialogs = preload("res://src/ui/shared/file_dialog_factory.gd")
const NumberFormat = preload("res://src/ui/shared/display_number_format.gd")
const VIEWS := [["City", "city"], ["Underground", "underground"]]
const SURFACE_ONLY_TOOLTIP := "The underground view has no signs or moving things."

var folder_input: LineEdit
var browse_button: Button
var file_name_input: LineEdit
var graphics_selector: OptionButton
var view_selector: OptionButton
var background_check: CheckBox
var signs_check: CheckBox
var moving_things_check: CheckBox
var summary_label: Label
var folder_dialog: FileDialog

var _city_name := ""
var _map_edge := 128
var _protected_folder := ""
var _file_name_chosen := false
var _updating := false


func _ready() -> void:
	hide()
	theme = AppUiTheme.current()
	folder_input = $Fields/Grid/FolderRow/FolderInput
	browse_button = $Fields/Grid/FolderRow/BrowseButton
	file_name_input = $Fields/Grid/FileNameInput
	graphics_selector = $Fields/Grid/GraphicsSelector
	view_selector = $Fields/Grid/ViewSelector
	background_check = $Fields/Grid/IncludeChecks/BackgroundCheck
	signs_check = $Fields/Grid/IncludeChecks/SignsCheck
	moving_things_check = $Fields/Grid/IncludeChecks/MovingThingsCheck
	summary_label = $Fields/Summary

	for index in AppSettingsStore.GRAPHICS_SIZES.size():
		graphics_selector.add_item(AppSettingsStore.GRAPHICS_SIZES[index], index)

	for index in VIEWS.size():
		view_selector.add_item(VIEWS[index][0], index)

	folder_dialog = FileDialogs.folder_select()
	folder_dialog.title = "Select Export Folder"
	add_child(folder_dialog)
	folder_dialog.dir_selected.connect(_select_folder)
	browse_button.pressed.connect(_browse_folder)
	folder_input.text_changed.connect(_refresh.unbind(1))
	file_name_input.text_changed.connect(_choose_file_name)
	graphics_selector.item_selected.connect(_refresh_name.unbind(1))
	view_selector.item_selected.connect(_choose_view)
	confirmed.connect(_confirm)


# set the defaults from the current city window
func configure(
	city_name: String, folder: String, map_edge: int, graphics_size: int, view: String,
	show_signs: bool, protected_folder := ""
) -> void:
	_updating = true
	_city_name = city_name
	_map_edge = map_edge
	_protected_folder = protected_folder.simplify_path()
	_file_name_chosen = false
	folder_input.text = folder
	graphics_selector.select(clampi(graphics_size, 0, AppSettingsStore.GRAPHICS_SIZES.size() - 1))
	view_selector.select(1 if view == "underground" else 0)
	background_check.button_pressed = true
	signs_check.button_pressed = show_signs
	moving_things_check.button_pressed = true
	_updating = false
	_choose_view(view_selector.selected)


func show_options() -> void:
	popup_centered()
	file_name_input.grab_focus()


func options() -> CityPngExportJob.Options:
	var surface := _surface_view()

	var result := CityPngExportJob.Options.new()
	result.path = output_path()
	result.view_size = graphics_selector.get_selected_id()
	result.view = String(VIEWS[view_selector.get_selected_id()][1])
	result.transparent_background = not background_check.button_pressed
	result.signs = surface and signs_check.button_pressed
	result.moving_things = surface and moving_things_check.button_pressed

	return result


func output_path() -> String:
	var file_name := file_name_input.text.strip_edges()

	if not file_name.is_empty() and file_name.get_extension().to_lower() != "png":
		file_name += ".png"

	return folder_input.text.strip_edges().path_join(file_name).simplify_path()


func output_size() -> Vector2i:
	return ExportJob.output_size(_map_edge, graphics_selector.get_selected_id())


# return why the current options cannot export, or an empty string
func validation_error() -> String:
	var folder := folder_input.text.strip_edges()
	var file_name := file_name_input.text.strip_edges()

	if folder.is_empty():
		return "Choose a folder."

	if not DirAccess.dir_exists_absolute(folder):
		return "The folder does not exist."

	if not _protected_folder.is_empty() and (folder.simplify_path() == _protected_folder or folder.simplify_path().begins_with(_protected_folder + "/")):
		return "The original game data folder is read-only. Choose another folder."

	if file_name.is_empty():
		return "Enter a file name."

	if file_name.validate_filename() != file_name:
		return "The file name contains characters that are not allowed."

	return ""


func _surface_view() -> bool:
	return String(VIEWS[view_selector.get_selected_id()][1]) == "city"


func _refresh() -> void:
	if _updating:
		return

	var error := validation_error()
	get_ok_button().disabled = not error.is_empty()
	var size := output_size()
	var text := "Image size: %s × %s pixels." % [NumberFormat.format(size.x), NumberFormat.format(size.y)]

	if not error.is_empty():
		text = error
	elif FileAccess.file_exists(output_path()):
		text += " A file with this name exists. Export replaces it."

	summary_label.text = text


func _refresh_name() -> void:
	if _updating:
		return

	if not _file_name_chosen:
		var base := _city_name.validate_filename().strip_edges()
		file_name_input.text = "%s_%s_%s.png" % [
			base if not base.is_empty() else "CITY",
			String(VIEWS[view_selector.get_selected_id()][1]).to_upper(),
			String(AppSettingsStore.GRAPHICS_SIZES[graphics_selector.get_selected_id()]).to_upper(),
		]

	_refresh()


func _choose_view(_index: int) -> void:
	var surface := _surface_view()

	for check in [signs_check, moving_things_check]:
		check.disabled = not surface
		check.tooltip_text = "" if surface else SURFACE_ONLY_TOOLTIP

	_refresh_name()


func _choose_file_name(_text: String) -> void:
	_file_name_chosen = true
	_refresh()


func _browse_folder() -> void:
	var folder := folder_input.text.strip_edges()

	if DirAccess.dir_exists_absolute(folder):
		folder_dialog.current_dir = folder

	folder_dialog.popup_centered_ratio(0.75)


func _select_folder(path: String) -> void:
	folder_input.text = path
	_refresh()


func _confirm() -> void:
	if validation_error().is_empty():
		export_requested.emit(options())
