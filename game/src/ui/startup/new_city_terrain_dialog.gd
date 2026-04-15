class_name NewCityTerrainDialog
extends ColorRect

signal cancel_requested
signal build_requested
signal preview_requested
signal terrain_regeneration_requested

const NewCity = preload("res://src/model/new_city_setup.gd")
const NewTerrain = preload("res://src/model/new_city_terrain.gd")
const ClassicStyle = preload("res://src/ui/shared/classic_ui_style.gd")

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
@onready var panel: PanelContainer = $Center/NewCityDialog
var done_button: Button
var candidate_valid := false
var landscape_background: TextureRect
const LAYOUTS = NewTerrain.LAYOUTS
var native_maps_input: CheckBox
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


func _ready() -> void:
	# visible in the editor, closed at startup
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
	native_maps_input = get_node("Center/NewCityDialog/Content/Body/Fields/CityFields/NativeMapsInput")
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
	var feature_titles := {"crossing": "Intersecting rivers", "branch": "Y river",
		"rejoin": "Split and rejoin river", "bay": "Ocean bay", "island": "One large island", "islands": "Two islands"}
	for key in feature_titles:
		var check := CheckBox.new()
		check.text = feature_titles[key]
		$Center/NewCityDialog/Content/Body/Fields/TerrainFields/OceanRow.add_child(check)
		feature_inputs[key] = check
		check.toggled.connect(_feature_changed.bind(key))
	visibility_changed.connect(_visibility_changed)
	resized.connect(_clamp_panel)
	_build_busy_overlay()
	compatibility_input.toggled.connect(_compatibility_changed)
	$Center/NewCityDialog/Content/Body/Fields/CityFields/CityNameRow/RandomName.pressed.connect(_random_name)
	var title_bar: DialogTitleBar = $Center/NewCityDialog/Content/TitleBar
	title_bar.title_label.text = "New City"
	title_bar.close_requested.connect(cancel_requested.emit)
	size_input.item_selected.connect(func(_index: int) -> void: preview_requested.emit())

	for input in [city_name_input, mayor_name_input]:
		input.text_changed.connect(func(_text: String) -> void: preview_requested.emit())
	for input in [difficulty_input, year_input]:
		input.item_selected.connect(func(_index: int) -> void: preview_requested.emit())
	for check in [native_maps_input, ocean_input, river_input]:
		check.toggled.connect(func(_enabled: bool) -> void: preview_requested.emit())

	for slider in [hills_input, water_input, trees_input]:
		slider.value_changed.connect(func(_value: float) -> void: preview_requested.emit())

	$Center/NewCityDialog/Content/Body/Preview/Regenerate.pressed.connect(terrain_regeneration_requested.emit)
	$Center/NewCityDialog/Content/Buttons/Cancel.pressed.connect(cancel_requested.emit)
	$Center/NewCityDialog/Content/Buttons/Start.pressed.connect(build_requested.emit)
	terrain_icons["Hills"] = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/HillsRow/TerrainPreview")
	terrain_icons["Water"] = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/WaterRow/TerrainPreview")
	terrain_icons["Trees"] = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/TreesRow/TerrainPreview")
	hills_input.tooltip_text = "Original range: 0–47. Controls hill height. Landforms scale with map size."
	water_input.tooltip_text = "Original features: stepped sea level and downhill streams. Extra features: wider rivers or more ocean."
	trees_input.tooltip_text = "Original range: 0–47. Tree cluster count grows with the square of this value."
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


func _compatibility_changed(enabled: bool) -> void:
	size_input.disabled = enabled
	native_maps_input.disabled = enabled
	if enabled:
		size_input.select(0)
		native_maps_input.set_pressed_no_signal(false)
	preview_requested.emit()


func invalidate() -> void:
	candidate_valid = false
	generation_revision += 1
	done_button.disabled = true
	preview_status.text = "Settings changed. Click Regenerate Terrain."


func _random_name() -> void:
	var selected := selected_features()
	var feature := "classic"
	for key in ["islands", "island", "bay", "rejoin", "branch", "crossing"]:
		if key in selected:
			feature = key
			break
	city_name_input.text = CityNameGenerator.generate(feature)
	preview_requested.emit()


func selected_features() -> Array:
	var result: Array = []
	for key in feature_inputs:
		if feature_inputs[key].button_pressed:
			result.append(key)
	return result


func reset_features() -> void:
	for check in feature_inputs.values():
		check.set_pressed_no_signal(false)
	_feature_changed(false, "")


func _feature_changed(enabled: bool, key: String) -> void:
	if enabled and key in ["island", "islands"]:
		feature_inputs["islands" if key == "island" else "island"].set_pressed_no_signal(false)
	var island: bool = feature_inputs.island.button_pressed or feature_inputs.islands.button_pressed
	for check in [river_input, feature_inputs.crossing, feature_inputs.branch, feature_inputs.rejoin]:
		check.disabled = island
		if island:
			check.set_pressed_no_signal(false)
	preview_requested.emit()


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
	var label := Label.new()
	label.text = "Generating…"
	label.custom_minimum_size = Vector2(180, 48)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(label)
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
