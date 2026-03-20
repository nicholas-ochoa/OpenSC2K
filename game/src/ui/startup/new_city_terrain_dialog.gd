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
	city_name_input = get_node("Center/NewCityDialog/Content/Body/Fields/CityFields/LineEdit1")
	mayor_name_input = get_node("Center/NewCityDialog/Content/Body/Fields/CityFields/LineEdit2")
	difficulty_input = get_node("Center/NewCityDialog/Content/Body/Fields/CityFields/OptionButton1")
	year_input = get_node("Center/NewCityDialog/Content/Body/Fields/CityFields/OptionButton2")
	size_input = get_node("Center/NewCityDialog/Content/Body/Fields/CityFields/OptionButton3")
	native_maps_input = get_node("Center/NewCityDialog/Content/Body/Fields/CheckBox1")
	ocean_input = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/HBoxContainer1/CheckBox1")
	river_input = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/HBoxContainer1/CheckBox2")
	hills_input = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/HBoxContainer3/HSlider1")
	water_input = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/HBoxContainer5/HSlider1")
	trees_input = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/HBoxContainer7/HSlider1")
	hills_value = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/HBoxContainer3/Label1")
	water_value = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/HBoxContainer5/Label1")
	trees_value = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/HBoxContainer7/Label1")
	preview_view = get_node("Center/NewCityDialog/Content/Body/Preview/PanelContainer1/TextureRect1")
	preview_status = get_node("Center/NewCityDialog/Content/Body/Preview/Label2")
	preview_timer = get_node("PreviewTimer")
	var title_bar: DialogTitleBar = $Center/NewCityDialog/Content/TitleBar
	title_bar.title_label.text = "New City"
	title_bar.close_requested.connect(cancel_requested.emit)
	size_input.item_selected.connect(func(_index: int) -> void: preview_requested.emit())

	for check in [native_maps_input, ocean_input, river_input]:
		check.toggled.connect(func(_enabled: bool) -> void: preview_requested.emit())

	for slider in [hills_input, water_input, trees_input]:
		slider.value_changed.connect(func(_value: float) -> void: preview_requested.emit())

	$Center/NewCityDialog/Content/Body/Preview/Regenerate.pressed.connect(terrain_regeneration_requested.emit)
	$Center/NewCityDialog/Content/Buttons/Cancel.pressed.connect(cancel_requested.emit)
	$Center/NewCityDialog/Content/Buttons/Start.pressed.connect(build_requested.emit)
	terrain_icons["Hills"] = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/HBoxContainer2/TextureRect1")
	terrain_icons["Water"] = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/HBoxContainer4/TextureRect1")
	terrain_icons["Trees"] = get_node("Center/NewCityDialog/Content/Body/Fields/TerrainFields/HBoxContainer6/TextureRect1")
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
