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
var layout_input: OptionButton
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
	layout_input = $Center/NewCityDialog/Content/Body/Fields/TerrainFields/LayoutInput
	done_button = $Center/NewCityDialog/Content/Buttons/Start
	for title in ["Original features", "Intersecting rivers", "Y river", "Split and rejoin river", "Ocean bay", "One large island", "Two large islands"]:
		layout_input.add_item(title)
	layout_input.item_selected.connect(func(_index: int) -> void:
		var classic := layout_input.selected == 0
		ocean_input.disabled = not classic
		river_input.disabled = not classic
		if not classic:
			ocean_input.set_pressed_no_signal(LAYOUTS[layout_input.selected] in ["bay", "island", "islands"])
			river_input.set_pressed_no_signal(not ocean_input.button_pressed)
		preview_requested.emit())
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
	water_input.tooltip_text = "Original layout: stepped sea level and downhill streams. New layouts: wider rivers or more ocean."
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
	done_button.disabled = true
	preview_status.text = "Settings changed. Click Regenerate Terrain."


func _random_name() -> void:
	city_name_input.text = CityNameGenerator.generate(LAYOUTS[layout_input.selected])
	preview_requested.emit()


func show_landscape(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive) -> void:
	var rendered := CityIsometricRenderer.create_image(city, palette, sprites,
		CityIsometricRenderer.VIEW_SMALL, 0, false, false, false, false)
	if rendered.get("ok", false):
		landscape_background.texture = ImageTexture.create_from_image(rendered.image)
