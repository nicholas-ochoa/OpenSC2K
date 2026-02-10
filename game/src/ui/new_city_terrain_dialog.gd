class_name NewCityTerrainDialog
extends ColorRect

signal cancel_requested
signal build_requested
signal preview_requested
signal terrain_regeneration_requested

const NewCity = preload("res://src/model/new_city_setup.gd")
const NewTerrain = preload("res://src/model/new_city_terrain.gd")
const ClassicStyle = preload("res://src/ui/classic_ui_style.gd")

var city_name_input: LineEdit
var mayor_name_input: LineEdit
var difficulty_input: OptionButton
var year_input: OptionButton
var size_input: OptionButton
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
	name = "NewCityOverlay"
	color = Color(0.0, 0.0, 0.0, 0.22)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 910
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "NewCityDialog"
	panel.custom_minimum_size = Vector2(820, 600)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override(
		"panel",
		ClassicStyle.create_box(Color("c0c0c0"), Color("404040"), 2, 8, 8)
	)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	_add_title_bar(column)

	var content := HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	column.add_child(content)
	_build_city_and_terrain_fields(content)
	_build_preview(content)
	_add_action_buttons(column)

	preview_timer = Timer.new()
	preview_timer.one_shot = true
	preview_timer.wait_time = 0.12
	add_child(preview_timer)
	set_control_graphics(control_graphics)


func _add_title_bar(column: VBoxContainer) -> void:
	var title_bar := DialogTitleBar.new("New City")
	title_bar.close_requested.connect(func() -> void: cancel_requested.emit())
	column.add_child(title_bar)


func _build_city_and_terrain_fields(content: HBoxContainer) -> void:
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(340, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	content.add_child(left)
	var details_heading := Label.new()
	details_heading.text = "City Details"
	details_heading.add_theme_font_size_override("font_size", 16)
	left.add_child(details_heading)

	var city_grid := GridContainer.new()
	city_grid.columns = 2
	city_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	city_grid.add_theme_constant_override("h_separation", 12)
	city_grid.add_theme_constant_override("v_separation", 8)
	left.add_child(city_grid)
	for label_text in ["City Name", "Mayor Name", "Difficulty", "Starting Year", "Map Size"]:
		_add_city_field(city_grid, label_text)
	native_maps_input = CheckBox.new()
	native_maps_input.text = "Per-tile data maps"
	native_maps_input.button_pressed = true
	native_maps_input.tooltip_text = "Calculate land value, pollution, crime, traffic and services for each tile. Uses SC2X saves, which the original game cannot open."
	native_maps_input.toggled.connect(func(_enabled: bool) -> void: preview_requested.emit())
	left.add_child(native_maps_input)

	left.add_child(HSeparator.new())
	var terrain_heading := Label.new()
	terrain_heading.text = "Terrain"
	terrain_heading.add_theme_font_size_override("font_size", 16)
	left.add_child(terrain_heading)
	var terrain_grid := GridContainer.new()
	terrain_grid.columns = 2
	terrain_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	terrain_grid.add_theme_constant_override("h_separation", 12)
	terrain_grid.add_theme_constant_override("v_separation", 8)
	left.add_child(terrain_grid)
	_add_feature_fields(terrain_grid)
	_add_terrain_slider(terrain_grid, "Hills")
	_add_terrain_slider(terrain_grid, "Water")
	_add_terrain_slider(terrain_grid, "Trees")
	var terrain_note := Label.new()
	terrain_note.hide()
	terrain_note.modulate = Color(0.72, 0.72, 0.72)
	left.add_child(terrain_note)


func _add_city_field(grid: GridContainer, label_text: String) -> void:
	var field_label := Label.new()
	field_label.text = label_text
	field_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	field_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(field_label)
	match label_text:
		"City Name":
			city_name_input = LineEdit.new()
			city_name_input.max_length = 30
			city_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(city_name_input)
		"Mayor Name":
			mayor_name_input = LineEdit.new()
			mayor_name_input.max_length = 23
			mayor_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(mayor_name_input)
		"Difficulty":
			difficulty_input = OptionButton.new()
			difficulty_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			difficulty_input.add_item("Easy — $20,000", 1)
			difficulty_input.add_item("Medium — $10,000", 2)
			difficulty_input.add_item("Hard — $10,000 bond at 3%", 3)
			grid.add_child(difficulty_input)
		"Map Size":
			size_input = OptionButton.new()
			for edge in Sc2File.MAP_SIZES:
				size_input.add_item("%d × %d%s" % [edge, edge, " (experimental)" if edge > 128 else ""], edge)
			size_input.tooltip_text = "Larger cities use .sc2x files. They cannot open in the original game."
			size_input.item_selected.connect(func(_index: int) -> void: preview_requested.emit())
			grid.add_child(size_input)
		"Starting Year":
			year_input = OptionButton.new()
			year_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for starting_year in NewCity.STARTING_YEARS:
				year_input.add_item(str(starting_year), starting_year)
			grid.add_child(year_input)


func _add_feature_fields(grid: GridContainer) -> void:
	var features_label := Label.new()
	features_label.text = "Features"
	features_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(features_label)
	var features := HBoxContainer.new()
	features.add_theme_constant_override("separation", 16)
	ocean_input = CheckBox.new()
	ocean_input.text = "Ocean"
	ocean_input.toggled.connect(func(_enabled: bool) -> void: preview_requested.emit())
	features.add_child(ocean_input)
	river_input = CheckBox.new()
	river_input.text = "River"
	river_input.toggled.connect(func(_enabled: bool) -> void: preview_requested.emit())
	features.add_child(river_input)
	grid.add_child(features)


func _add_terrain_slider(grid: GridContainer, label_text: String) -> void:
	var heading := HBoxContainer.new()
	heading.alignment = BoxContainer.ALIGNMENT_END
	grid.add_child(heading)
	var icon := TextureRect.new()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(18, 19)
	heading.add_child(icon)
	terrain_icons[label_text] = icon
	var terrain_label := Label.new()
	terrain_label.text = label_text
	terrain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	terrain_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(terrain_label)
	var slider_row := HBoxContainer.new()
	slider_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_row.add_theme_constant_override("separation", 8)
	var slider := HSlider.new()
	slider.min_value = NewTerrain.MIN_SLIDER
	slider.max_value = NewTerrain.MAX_SLIDER
	slider.step = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(_value: float) -> void: preview_requested.emit())
	slider_row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(30, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.hide()
	slider_row.add_child(value_label)
	match label_text:
		"Hills":
			hills_input = slider
			hills_value = value_label
		"Water":
			water_input = slider
			water_value = value_label
		"Trees":
			trees_input = slider
			trees_value = value_label
	grid.add_child(slider_row)


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


func _build_preview(content: HBoxContainer) -> void:
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(320, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	content.add_child(right)
	var preview_heading := Label.new()
	preview_heading.text = "Terrain Preview"
	preview_heading.add_theme_font_size_override("font_size", 16)
	preview_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(preview_heading)
	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(320, 320)
	preview_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right.add_child(preview_panel)
	preview_view = TextureRect.new()
	preview_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_panel.add_child(preview_view)
	preview_status = Label.new()
	preview_status.text = "Generating terrain..."
	preview_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(preview_status)
	var make_terrain_button := Button.new()
	make_terrain_button.text = "Regenerate Terrain"
	make_terrain_button.pressed.connect(
		func() -> void: terrain_regeneration_requested.emit()
	)
	right.add_child(make_terrain_button)


func _add_action_buttons(column: VBoxContainer) -> void:
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	column.add_child(button_row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(spacer)
	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(80, 30)
	cancel_button.pressed.connect(func() -> void: cancel_requested.emit())
	button_row.add_child(cancel_button)
	var build_button := Button.new()
	build_button.text = "Edit This Landscape"
	build_button.custom_minimum_size = Vector2(210, 30)
	build_button.pressed.connect(func() -> void: build_requested.emit())
	button_row.add_child(build_button)
