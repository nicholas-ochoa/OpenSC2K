class_name NewCityTerrainDialog
extends ColorRect

signal cancel_requested
signal build_requested
signal preview_requested
signal terrain_regeneration_requested

const NewCity = preload("res://src/model/new_city_setup.gd")
const NewTerrain = preload("res://src/model/new_city_terrain.gd")

var city_name_input: LineEdit
var mayor_name_input: LineEdit
var difficulty_input: OptionButton
var year_input: OptionButton
var size_input: OptionButton
var compatibility_input: CheckBox
var feature_inputs: Dictionary = {}
var generating := false
var generation_revision := 0
var _dragging := false
var _peek := false
var _drag_offset := Vector2.ZERO
var _busy_overlay: Control
var _busy_spinner: Control
@onready var panel: PanelContainer = $Center/NewCityDialog
var done_button: Button
var candidate_valid := false
var landscape_background: TextureRect
const LAYOUTS = NewTerrain.LAYOUTS
const RIVER_FEATURES := ["delta", "meander", "crossing", "branch", "rejoin", "valley"]
const OCEAN_FEATURES := ["bay", "delta", "peninsula", "island", "islands", "cliffs"]
const EXCLUSIVE_GROUPS := [["island", "islands", "peninsula"],
	["plateau", "ridge", "rolling", "basin"], ["valley", "canyon", "basin"], ["lake", "lakes"], ["plateau", "island"], ["plateau", "islands"]]
const FEATURE_TOOLTIPS := {
	"ocean": "Put ocean along the edge of the map.",
	"river": "Put a river across the map.",
	"bay": "Cut a bay into the coast.",
	"meander": "Make the river bend from side to side.",
	"branch": "Split the river into two branches.",
	"rejoin": "Split the river around land, then join it again.",
	"crossing": "Add a second river that flows into the first river.",
	"delta": "Split the river into channels where it flows into the ocean.",
	"lake": "Add one lake.",
	"lakes": "Add two lakes.",
	"plateau": "Raise a large area of high, flat land.",
	"ridge": "Add a long line of high land across the map.",
	"valley": "Put the river in a low valley between higher land.",
	"rolling": "Make low, smooth hills across the map.",
	"basin": "Make a low area with higher land around it.",
	"canyon": "Cut a deep, narrow canyon across the map. A canyon replaces the river.",
	"cliffs": "Put steep, high land along the coast.",
	"island": "Put the land on one island in the ocean. An island has no river.",
	"islands": "Put the land on two islands in the ocean. Islands have no river.",
	"peninsula": "Make a strip of land that goes out into the ocean.",
}
var ocean_input: CheckBox
var river_input: CheckBox
var hills_input: HSlider
var water_input: HSlider
var trees_input: HSlider
var hills_value: Label
var water_value: Label
var trees_value: Label
var preview_view: TextureRect
var preview_status: Label
var preview_timer: Timer
var terrain_icons: Dictionary = {}
var control_graphics: CityUiGraphics


class SetupOptions extends RefCounted:
	var city_name := ""
	var mayor_name := ""
	var difficulty := 0
	var starting_year := 0


func reset_fields(default_mayor: String) -> void:
	preview_view.texture = null
	landscape_background.texture = null
	compatibility_input.set_pressed_no_signal(false)
	compatibility_changed(false)
	city_name_input.text = "New City"
	mayor_name_input.text = default_mayor
	difficulty_input.select(0)
	year_input.select(0)
	reset_features()
	ocean_input.button_pressed = NewTerrain.DEFAULT_OCEAN
	river_input.button_pressed = NewTerrain.DEFAULT_RIVER
	hills_input.value = NewTerrain.DEFAULT_HILLS
	water_input.value = NewTerrain.DEFAULT_WATER
	trees_input.value = NewTerrain.DEFAULT_TREES
	_update_slider_labels()


func focus_city_name() -> void:
	city_name_input.grab_focus()
	city_name_input.select_all()


func setup_options() -> SetupOptions:
	var options := SetupOptions.new()
	options.city_name = city_name_input.text
	options.mayor_name = mayor_name_input.text
	options.difficulty = difficulty_input.get_selected_id()
	options.starting_year = year_input.get_selected_id()
	return options


func terrain_options() -> NewCityTerrain.Options:
	var options := NewCityTerrain.Options.new()
	options.features.assign(selected_features())
	options.smooth_slopes = true
	options.size = size_input.get_selected_id()
	options.ocean = ocean_input.button_pressed
	options.river = river_input.button_pressed
	options.hills = roundi(hills_input.value)
	options.water = roundi(water_input.value)
	options.trees = roundi(trees_input.value)
	return OriginalCompatibility.terrain_options(options, compatibility_input.button_pressed)


func show_preview(landscape: Image, minimap: Image, status: String) -> void:
	landscape_background.texture = ImageTexture.create_from_image(landscape)
	preview_view.texture = ImageTexture.create_from_image(minimap)
	candidate_valid = true
	done_button.disabled = false
	preview_status.text = status


func _update_slider_labels() -> void:
	hills_value.text = str(roundi(hills_input.value))
	water_value.text = str(roundi(water_input.value))
	trees_value.text = str(roundi(trees_input.value))


func _slider_changed(_value: float) -> void:
	_update_slider_labels()
	preview_requested.emit()


func _ready() -> void:
	hide()
	landscape_background = TextureRect.new()
	landscape_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	landscape_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	landscape_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	landscape_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	landscape_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(landscape_background)
	move_child(landscape_background, 0)
	city_name_input = get_node("Center/NewCityDialog/Content/Body/Fields/CityFields/CityNameRow/CityNameInput")
	mayor_name_input = get_node("Center/NewCityDialog/Content/Body/Fields/CityFields/MayorNameInput")
	difficulty_input = get_node("Center/NewCityDialog/Content/Body/Fields/CityFields/DifficultyInput")
	year_input = get_node("Center/NewCityDialog/Content/Body/Fields/CityFields/YearInput")
	size_input = get_node("Center/NewCityDialog/Content/Body/Fields/CityFields/SizeInput")
	ocean_input = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/OceanRow/OceanInput")
	river_input = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/OceanRow/RiverInput")
	hills_input = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/HillsInputGroup/HillsInput")
	water_input = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/WaterInputGroup/WaterInput")
	trees_input = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/TreesInputGroup/TreesInput")
	hills_value = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/HillsInputGroup/HillsValue")
	water_value = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/WaterInputGroup/WaterValue")
	trees_value = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/TreesInputGroup/TreesValue")
	preview_view = get_node("Center/NewCityDialog/Content/Body/Preview/PreviewFrame/TerrainPreview")
	preview_status = get_node("Center/NewCityDialog/Content/Body/Preview/PreviewStatus")
	preview_timer = get_node("PreviewTimer")
	compatibility_input = $Center/NewCityDialog/Content/Buttons/CompatibilityInput
	done_button = $Center/NewCityDialog/Content/Buttons/Start
	var feature_titles := {"meander": "Meandering River", "delta": "River Delta", "peninsula": "Peninsula", "crossing": "Intersecting rivers", "branch": "Forked River",
		"rejoin": "Split and rejoin river", "bay": "Ocean bay", "island": "Single Island", "islands": "Two islands", "plateau": "Plateau", "ridge": "Mountain Ridge",
		"valley": "River Valley", "rolling": "Rolling Hills", "basin": "Basin", "canyon": "Canyon", "cliffs": "Coastal Cliffs", "lake": "Single Lake", "lakes": "Two Lakes"}
	for key in feature_titles:
		var check := CheckBox.new()
		check.text = feature_titles[key]
		$Center/NewCityDialog/Content/Body/Fields/TerrainFields/OceanRow.add_child(check)
		feature_inputs[key] = check
		check.toggled.connect(_feature_changed.bind(key))
	var feature_grid: GridContainer = $Center/NewCityDialog/Content/Body/Fields/TerrainFields/OceanRow
	var ordered_checks := [ocean_input, feature_inputs.bay, river_input, feature_inputs.meander,
		feature_inputs.branch, feature_inputs.rejoin, feature_inputs.crossing, feature_inputs.delta,
		feature_inputs.lake, feature_inputs.lakes, feature_inputs.plateau, feature_inputs.ridge, feature_inputs.valley, feature_inputs.rolling,
		feature_inputs.basin, feature_inputs.canyon, feature_inputs.cliffs,
		feature_inputs.island, feature_inputs.islands, feature_inputs.peninsula]
	for index in ordered_checks.size():
		feature_grid.move_child(ordered_checks[index], index)
	ocean_input.tooltip_text = FEATURE_TOOLTIPS.ocean
	_compact_feature_rows()
	theme_changed.connect(_compact_feature_rows)
	_refresh_feature_constraints()
	ocean_input.minimum_size_changed.connect(_align_features_label)
	_align_features_label()
	visibility_changed.connect(_visibility_changed)
	resized.connect(_clamp_panel)
	_build_busy_overlay()
	compatibility_input.toggled.connect(compatibility_changed)
	$Center/NewCityDialog/Content/Body/Fields/CityFields/CityNameRow/RandomName.pressed.connect(_random_name)
	var title_bar: DialogTitleBar = $Center/NewCityDialog/Content/TitleBar
	title_bar.title_label.text = "New City"
	title_bar.close_requested.connect(cancel_requested.emit)
	size_input.item_selected.connect(func(_index: int) -> void: preview_requested.emit())
	ocean_input.toggled.connect(_feature_changed.bind("ocean"))
	river_input.toggled.connect(_feature_changed.bind("river"))

	for slider in [hills_input, water_input, trees_input]:
		slider.value_changed.connect(_slider_changed)

	$Center/NewCityDialog/Content/Body/Preview/Regenerate.pressed.connect(terrain_regeneration_requested.emit)
	$Center/NewCityDialog/Content/Buttons/Cancel.pressed.connect(cancel_requested.emit)
	$Center/NewCityDialog/Content/Buttons/Start.pressed.connect(build_requested.emit)
	terrain_icons["Hills"] = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/HillsRow/TerrainPreview")
	terrain_icons["Water"] = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/WaterRow/TerrainPreview")
	terrain_icons["Trees"] = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/TreesRow/TerrainPreview")
	hills_input.tooltip_text = "The height of the hills."
	water_input.tooltip_text = "The sea level and the number of streams. With terrain features, rivers are wider and there is more ocean."
	trees_input.tooltip_text = "The number of tree groups."
	set_control_graphics(control_graphics)


func set_control_graphics(graphics: CityUiGraphics) -> void:
	control_graphics = graphics

	for label in terrain_icons:
		var role: String = {"Hills": "hills", "Water": "water_amount", "Trees": "trees_amount"}[label]
		var image: Image = null if graphics == null else graphics.terrain_icon(role)
		var view: TextureRect = terrain_icons[label]
		view.texture = null
		view.visible = image != null

		if image != null:
			image.convert(Image.FORMAT_RGBA8)
			var background := image.get_pixel(0, 0)

			for y in image.get_height():
				for x in image.get_width():
					if image.get_pixel(x, y).is_equal_approx(background):
						image.set_pixel(x, y, Color.TRANSPARENT)

			view.texture = ImageTexture.create_from_image(image)


# an SC2 city uses only the original 128 × 128 map
func compatibility_changed(enabled: bool) -> void:
	for index in size_input.item_count:
		size_input.set_item_disabled(index, enabled and size_input.get_item_id(index) != 128)

	if enabled:
		size_input.select(size_input.get_item_index(128))

	preview_requested.emit()


func invalidate() -> void:
	candidate_valid = false
	generation_revision += 1
	done_button.disabled = true
	preview_status.text = "Settings changed. Click Regenerate Terrain."


func _random_name() -> void:
	var selected := selected_features()
	var feature := "classic"
	for key in ["islands", "island", "lake", "lakes", "plateau", "ridge", "valley", "rolling", "basin", "canyon", "cliffs", "delta", "peninsula", "bay", "meander", "rejoin", "branch", "crossing"]:
		if key in selected:
			feature = key
			break
	city_name_input.text = CityNameGenerator.generate(feature)


func selected_features() -> Array[String]:
	var result: Array[String] = []
	for key in feature_inputs:
		if feature_inputs[key].button_pressed:
			result.append(key)
	return result


func reset_features() -> void:
	for check in feature_inputs.values():
		check.set_pressed_no_signal(false)
	_feature_changed(false, "")


func _feature_changed(enabled: bool, key: String) -> void:
	if enabled:
		for group in EXCLUSIVE_GROUPS:
			if key in group:
				for other in group:
					if other != key:
						feature_inputs[other].set_pressed_no_signal(false)
		if key in ["island", "islands", "canyon"]:
			river_input.set_pressed_no_signal(false)
			for dependent in RIVER_FEATURES:
				feature_inputs[dependent].set_pressed_no_signal(false)
		if key == "river" or key in RIVER_FEATURES:
			feature_inputs.canyon.set_pressed_no_signal(false)
		if key in RIVER_FEATURES:
			river_input.set_pressed_no_signal(true)
		if key in OCEAN_FEATURES:
			ocean_input.set_pressed_no_signal(true)
	elif key in ["ocean", "river"]:
		for dependent in (OCEAN_FEATURES if key == "ocean" else RIVER_FEATURES):
			feature_inputs[dependent].set_pressed_no_signal(false)
	_refresh_feature_constraints()
	preview_requested.emit()


func _refresh_feature_constraints() -> void:
	var island_key := "island" if feature_inputs.island.button_pressed else "islands"
	var island: bool = feature_inputs[island_key].button_pressed
	var canyon: bool = feature_inputs.canyon.button_pressed
	var river_blocker: String = "Canyon" if canyon else (feature_inputs[island_key].text if island else "")
	river_input.disabled = not river_blocker.is_empty()
	river_input.tooltip_text = _feature_tooltip("river", river_blocker)
	for key in feature_inputs:
		var reason := ""
		if (island or canyon) and key in RIVER_FEATURES:
			reason = river_blocker
		for group in EXCLUSIVE_GROUPS:
			if key in group:
				for other in group:
					if other != key and feature_inputs[other].button_pressed:
						reason = feature_inputs[other].text
		var check: CheckBox = feature_inputs[key]
		check.disabled = not reason.is_empty()
		check.tooltip_text = _feature_tooltip(key, reason)


# the feature description, then why it is unavailable or what it also enables
func _feature_tooltip(key: String, blocker: String) -> String:
	var lines: Array[String] = [FEATURE_TOOLTIPS[key]]

	if not blocker.is_empty():
		lines.append("Unavailable while %s is selected. Clear it first." % blocker)
	else:
		if key in RIVER_FEATURES:
			lines.append("Also enables River.")

		if key in OCEAN_FEATURES:
			lines.append("Also enables Ocean.")

	return "\n".join(lines)


func _build_busy_overlay() -> void:
	_busy_overlay = Control.new()
	_busy_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_busy_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_busy_overlay.add_child(center)
	var box := PanelContainer.new()
	box.theme_type_variation = "PanelPadding8_8_8_8"
	center.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_busy_spinner = preload("res://src/ui/shared/loading_spinner.gd").new()
	_busy_spinner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_busy_spinner)
	var label := Label.new()
	label.text = "Generating…"
	label.custom_minimum_size = Vector2(140, 48)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	_busy_overlay.hide()


func set_generating(value: bool) -> void:
	generating = value
	_busy_overlay.visible = value
	if value:
		preview_status.text = "Generating…"


func _visibility_changed() -> void:
	panel.modulate.a = 1.0
	_busy_overlay.modulate.a = 1.0
	color.a = 0.22
	_peek = false
	_dragging = false
	if visible:
		panel.reset_size()
		panel.position = ((size - panel.size) * 0.5).round()
		_center_panel.call_deferred()


func _center_panel() -> void:
	panel.reset_size()
	panel.position = ((size - panel.size) * 0.5).round()
	_clamp_panel()


func _clamp_panel() -> void:
	if panel == null:
		return
	panel.position = panel.position.clamp(Vector2.ZERO, (size - panel.size).max(Vector2.ZERO)).round()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		panel.modulate.a = 1.0
		_busy_overlay.modulate.a = 1.0
		color.a = 0.22
		_peek = false
		_dragging = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if not event.pressed or panel.get_global_rect().has_point(event.position):
				_peek = event.pressed
				panel.modulate.a = 0.0 if _peek else 1.0
				_busy_overlay.modulate.a = panel.modulate.a
				color.a = 0.0 if _peek else 0.22
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var title: DialogTitleBar = $Center/NewCityDialog/Content/TitleBar
			if event.pressed and title.get_global_rect().has_point(event.position) and not title.close_button.get_global_rect().has_point(event.position):
				_dragging = true
				_drag_offset = event.position - panel.global_position
				get_viewport().set_input_as_handled()
			elif not event.pressed and _dragging:
				_dragging = false
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		panel.global_position = event.position - _drag_offset
		_clamp_panel()
		get_viewport().set_input_as_handled()
	if _peek:
		get_viewport().set_input_as_handled()


func _align_features_label() -> void:
	var label: Label = $Center/NewCityDialog/Content/Body/Fields/TerrainFields/FeaturesLabel
	label.custom_minimum_size.y = ocean_input.get_combined_minimum_size().y


func _compact_feature_rows() -> void:
	for check in ocean_input.get_parent().get_children():
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			var style: StyleBox = check.get_theme_stylebox(state).duplicate()
			style.content_margin_top = 1
			style.content_margin_bottom = 1
			check.add_theme_stylebox_override(state, style)
