class_name VisualEnhancementsTab
extends VBoxContainer
## Presentation-only navigation and display units; saved options retain their original units.

signal changed
signal reload_requested
signal export_requested

const SECTIONS := [
	["Day & Night", "Set the time of day and the appearance of the night.",
		["day_enabled", "day_mode", "day_hour", "day_seconds", "day_lut_strength", "night_strength"]],
	["Lighting", "Building, vehicle and street lights. Keep lights on during the day with the daytime override.",
		["brightmaps", "night_daytime_enabled", "night_light_strength", "night_ambient", "night_glow", "night_ground"]],
	["Seasons", "Follow the city calendar, run a visual cycle or choose one season.",
		["season_enabled", "season_mode", "season_fixed", "season_seconds", "season_transition", "season_lut_strength"]],
	["Weather & Clouds", "Weather and clouds have separate switches. Fixed weather can show snow in any season.",
		["weather_enabled", "weather_mode", "weather_fixed", "weather_seconds", "weather_transition", "weather_strength", "weather_lut_strength", "weather_fog_enabled", "cloud_enabled", "cloud_density", "cloud_shadow_strength", "cloud_speed"]],
	["Environment", "Water reflections, waves, coastal surf and underwater terrain. Seasonal water colors require Seasons.",
		["water_reflections", "water_waves_enabled", "water_topography", "season_water_strength"]],
	["Traffic & Movement", "Decorative cars and pedestrians, plus smoother movement for existing vehicles.",
		["life_cars_enabled", "life_car_amount", "life_people_enabled", "life_people_amount", "traffic_vehicles_enabled", "traffic_shadows_enabled"]],
	["Disaster Effects", "Extra effects for disasters and demolition. These settings do not change disaster frequency, damage or emergency response.",
		["disaster_enabled", "disaster_strength", "disaster_blending", "disaster_crowds", "disaster_dust", "disaster_lights", "disaster_motion", "disaster_shake"]],
	["Animation", "Shared timing for visual cycles and animated effects. Cycle durations use Turtle speed when linked; otherwise they use real time.",
		["speed_link", "pause_freezes"]],
	["Custom Graphics", "Optional files for custom colors and lights. Standard effects work without these fields.",
		["lut_path", "brightmap_folder"]],
]
const PERCENT_FIELDS := ["day_lut_strength", "night_strength", "season_transition", "season_lut_strength",
	"season_water_strength", "weather_strength", "weather_lut_strength", "cloud_density", "cloud_shadow_strength",
	"disaster_strength", "disaster_lights", "disaster_shake"]
const LABELS := {
	"disaster_enabled": "Enhanced disaster visuals", "disaster_strength": "Additional effect intensity",
	"disaster_crowds": "Animated riot crowds", "disaster_lights": "Fire and impact lighting",
	"disaster_shake": "Earthquake camera shake",
	"pause_freezes": "Pause environment cycles with the game",
	"day_mode": "Time source", "day_hour": "Fixed hour (0â€“24)", "day_seconds": "Day cycle duration",
	"day_lut_strength": "Time-of-day color strength", "night_strength": "Night darkness",
	"brightmaps": "Building and vehicle lights", "night_light_strength": "Light brightness",
	"season_seconds": "Year cycle duration", "season_transition": "Season blend duration", "season_lut_strength": "Season color strength",
	"weather_seconds": "Weather change interval", "weather_transition": "Weather blend duration",
	"weather_strength": "Weather intensity", "weather_lut_strength": "Weather color strength",
	"life_car_amount": "Car density", "life_people_amount": "Pedestrian density",
	"lut_path": "Custom color filter (LUT PNG)", "brightmap_folder": "Custom light masks (brightmaps)",
}
const HINTS := {
	"disaster_blending": "Blend animation frames for fire, toxic clouds, floods, tornadoes, smoke, explosion clouds and demolition dust. Fire also fades in and out. The initial explosion flash stays immediate. Does not change disaster behavior.",
	"night_daytime_enabled": "Keep building brightmaps, glow, street lamps, junction signals and vehicle lights on at any hour, even with the day-night cycle off. Daylight colors and individual light strengths stay unchanged.",
	"night_ambient": "Cool fill light reveals dark surfaces at night. Window and vehicle light brightness stays separate.",
	"night_glow": "Soft colored light around visible brightmaps. Zero keeps only the sharp original lights.",
	"night_ground": "Street lamps, warm road lighting, cosmetic junction signals and selected shop approaches. Signals do not control traffic. Zero disables these lights.",
	"traffic_vehicles_enabled": "Smooth movement of helicopters, airplanes, ships, sailboats and trains.",
	"water_waves_enabled": "Moving waves and breaking surf along the terrain shoreline. Turn off for a still water surface.",
	"disaster_enabled": "Enable additional presentation effects. Turning this off restores the original disaster visuals; disasters still occur.",
	"disaster_strength": "Intensity of added visual effects. At 0%, added crowds, dust and lighting are off. Tornado smoothing and camera shake remain separate.",
	"disaster_crowds": "Animated riot crowds use the city pedestrian artwork. Does not change population, riot spread or treatment targets.",
	"disaster_dust": "Dust from demolition and damage. Dust from player demolition continues to settle while the game is paused.",
	"disaster_motion": "Smooth the displayed tornado movement between completed simulation positions. Does not change its route or damage.",
	"disaster_lights": "Local fire and impact lighting. Requires enhanced disaster visuals and effect intensity above 0%.",
	"disaster_shake": "Strength of earthquake camera movement. Set to 0% to remove camera shake while enhanced disaster visuals are enabled.",
	"pause_freezes": "Pause day, season, water and enhanced disaster animations. Weather, clouds and weather sounds always pause with the game. Dust from player demolition can continue.",
	"weather_fixed": "Fixed weather can show snow in any season. Game weather and automatic weather show snow only in winter.",
	"day_hour": "24-hour time in quarter-hour steps: 7.5 means 07:30.",
	"day_seconds": "Seconds for one complete day/night cycle. The Animation section controls speed and pause behavior.",
	"season_seconds": "Seconds for one complete visual year. The city calendar is unchanged.",
	"season_transition": "Part of each season used to blend into the next season. Higher values make the transition longer.",
	"weather_seconds": "Time between automatic weather selections. The Animation section controls speed; weather always stops while the game is paused.",
	"day_lut_strength": "Strength of the time-of-day color filter. 0% disables this filter.",
	"season_lut_strength": "Strength of seasonal color filters. 0% disables these filters.",
	"weather_lut_strength": "Strength of weather color filters. 0% disables these filters.",
	"season_water_strength": "Strength of the seasonal water tint. Enable Seasons to use this setting.",
	"cloud_density": "Amount of decorative cloud coverage.",
	"cloud_speed": "Multiplier for cloud movement. 1Ã— is the standard speed; 0Ã— stops movement.",
	"life_car_amount": "Decorative car density. 1Ã— is the standard amount; does not change simulated traffic.",
	"life_people_amount": "Decorative pedestrian density. 1Ã— is the standard amount; does not change population.",
	"night_light_strength": "Brightness of building and vehicle lights. 100% uses the original brightness; 0% turns the lights off without changing night colors.",
	"brightmap_folder": "Leave empty for the included standard light masks. Custom folders replace the standard set. Relative to the data folder, for example brightmaps-standard. Absolute paths are also supported. Requires active lighting.",
	"lut_path": "Optional PNG lookup table (LUT) for custom color grading. Leave empty for standard colors.",
}

var controls: Dictionary = {}
var filling := false
var profile_folder := ""
var pages: Array[VBoxContainer] = []
var category_buttons: Array[Button] = []
var page_scroll: ScrollContainer


func _ready() -> void:
	name = "Visual Enhancements"
	add_theme_constant_override("separation", 10)
	var introduction := _help("Visual effects only. Changes apply immediately.")
	introduction.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(introduction)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	add_child(body)
	var navigation_scroll := ScrollContainer.new()
	navigation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	navigation_scroll.follow_focus = true
	navigation_scroll.custom_minimum_size.x = 164
	body.add_child(navigation_scroll)
	var navigation := VBoxContainer.new()
	navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation_scroll.add_child(navigation)
	body.add_child(VSeparator.new())
	page_scroll = ScrollContainer.new()
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_scroll.follow_focus = true
	page_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(page_scroll)
	var page_stack := VBoxContainer.new()
	page_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.add_child(page_stack)
	var group := ButtonGroup.new()
	for section in SECTIONS:
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 8)
		page_stack.add_child(page)
		pages.append(page)
		var heading := Label.new()
		heading.text = section[0]
		heading.add_theme_font_size_override("font_size", get_theme_font_size("font_size") + 3)
		page.add_child(heading)
		page.add_child(_help(section[1]))
		page.add_child(HSeparator.new())
		for key: String in section[2]:
			for field in VisualEnhancementOptions.FIELDS:
				if field[0] == key:
					_add_field(page, field)
		var button := Button.new()
		button.text = section[0]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(select_category.bind(pages.size() - 1))
		navigation.add_child(button)
		category_buttons.append(button)
	var asset_buttons := HFlowContainer.new()
	pages[-1].add_child(asset_buttons)
	_add_button(asset_buttons, "Reload brightmaps", func() -> void:
		_changed()
		reload_requested.emit())
	_add_button(asset_buttons, "Export PNG templates", func() -> void:
		_changed()
		export_requested.emit())
	pages[-1].add_child(_help("Reload after editing light masks. Export creates PNG templates for painting your own lights."))
	add_child(HSeparator.new())
	var actions := HFlowContainer.new()
	add_child(actions)
	_add_button(actions, "Disable all", _disable_all)
	_add_button(actions, "Use defaults", func() -> void:
		show_values({})
		changed.emit())
	actions.get_child(0).tooltip_text = "Turn off all visual enhancements. Keep effect strengths and custom file paths."
	actions.get_child(1).tooltip_text = "Reset all visual enhancements, including custom file paths, to their defaults."
	select_category(0)
	show_values({})


func _help(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.theme_type_variation = &"HelpLabel"
	return label


func _add_button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)


func _add_field(page: VBoxContainer, field: Array) -> void:
	var key: String = field[0]
	var title: String = LABELS.get(key, field[1])
	var row: BoxContainer = VBoxContainer.new() if field[2] == "path" else HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	page.add_child(row)
	if field[2] != "bool":
		var label := _help(title)
		label.theme_type_variation = &""
		row.add_child(label)
	var control: Control
	match field[2]:
		"bool":
			var check := CheckBox.new()
			check.text = title
			check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			check.toggled.connect(func(_v: bool) -> void: _changed())
			control = check
		"choice":
			var choice := OptionButton.new()
			for item in field[4]:
				choice.add_item("Automatic cycle" if item == "Visual automation" else item)
			choice.fit_to_longest_item = false
			choice.item_selected.connect(func(_v: int) -> void: _changed())
			control = choice
		"number":
			var spin := SpinBox.new()
			var scale := _display_scale(key)
			spin.min_value = float(field[4]) * scale
			spin.max_value = float(field[5]) * scale
			spin.step = float(field[6]) * scale
			if key in PERCENT_FIELDS or key in ["night_light_strength", "night_ambient", "night_glow", "night_ground"]:
				spin.suffix = "%"
			elif key.ends_with("_seconds") or key == "weather_transition":
				spin.suffix = "s"
			elif key in ["cloud_speed", "life_car_amount", "life_people_amount"]:
				spin.suffix = "Ã—"
			spin.value_changed.connect(func(_v: float) -> void: _changed())
			control = spin
		"path":
			var edit := LineEdit.new()
			edit.placeholder_text = "Optional â€” leave empty for standard effects"
			edit.text_submitted.connect(func(_v: String) -> void: _changed())
			edit.focus_exited.connect(_changed)
			control = edit
	if field[2] in ["number", "choice"]:
		control.custom_minimum_size.x = 155
	control.tooltip_text = HINTS.get(key, "")
	row.tooltip_text = control.tooltip_text
	row.add_child(control)
	controls[key] = control


func select_category(index: int) -> void:
	for i in pages.size():
		pages[i].visible = i == index
		category_buttons[i].set_pressed_no_signal(i == index)
	page_scroll.scroll_vertical = 0


func _display_scale(key: String) -> float:
	return 100.0 if key in PERCENT_FIELDS else 1.0


func _disable_all() -> void:
	var values := selected_values()
	for key in values:
		if str(key).ends_with("_enabled"):
			values[key] = false
	values.water_reflections = 0
	values.water_topography = false
	show_values(values)
	changed.emit()


func _changed() -> void:
	if not filling:
		_update_availability()
		changed.emit()


func _update_availability() -> void:
	var values := selected_values()
	for key: String in controls:
		var available := true
		if key.begins_with("disaster_") and key != "disaster_enabled":
			available = values.disaster_enabled
		elif key.begins_with("season_") and key != "season_enabled":
			available = values.season_enabled
		elif (key.begins_with("day_") and key != "day_enabled") or key.begins_with("night_") or key in ["brightmaps", "brightmap_folder"]:
			available = values.day_enabled
		elif key.begins_with("weather_") and key != "weather_enabled":
			available = values.weather_enabled
		elif key.begins_with("cloud_") and key != "cloud_enabled":
			available = values.cloud_enabled
		match key:
			"disaster_crowds", "disaster_dust", "disaster_lights":
				available = available and values.disaster_strength > 0.0
			"season_fixed":
				available = available and values.season_mode == 2
			"season_seconds":
				available = available and values.season_mode == 1
			"season_transition":
				available = available and values.season_mode != 2
			"day_hour":
				available = available and values.day_mode == 1
			"day_seconds":
				available = available and values.day_mode == 0
			"weather_fixed":
				available = available and values.weather_mode == 2
			"weather_seconds":
				available = available and values.weather_mode == 1
			"brightmaps":
				available = true
			"night_daytime_enabled":
				available = values.brightmaps
			"brightmap_folder", "night_light_strength":
				available = (values.day_enabled or values.night_daytime_enabled) and values.brightmaps
			"night_glow", "night_ground":
				available = (values.day_enabled or values.night_daytime_enabled) and values.brightmaps and values.night_light_strength > 0.0
			"life_car_amount":
				available = values.life_cars_enabled
			"life_people_amount":
				available = values.life_people_enabled
		var control: Control = controls[key]
		var relevant := true
		match key:
			"day_hour":
				relevant = values.day_mode == 1
			"day_seconds":
				relevant = values.day_mode == 0
			"season_fixed":
				relevant = values.season_mode == 2
			"season_seconds":
				relevant = values.season_mode == 1
			"season_transition":
				relevant = values.season_mode != 2
			"weather_fixed":
				relevant = values.weather_mode == 2
			"weather_seconds":
				relevant = values.weather_mode == 1
		control.get_parent().visible = relevant
		if control is OptionButton:
			var selection := (control as OptionButton).get_item_text((control as OptionButton).selected)
			var hint: String = HINTS.get(key, "")
			control.tooltip_text = selection if hint.is_empty() else selection + "\n" + hint
		if control is BaseButton:
			(control as BaseButton).disabled = not available
		elif control is SpinBox:
			(control as SpinBox).editable = available
		elif control is LineEdit:
			(control as LineEdit).editable = available
		control.get_parent().modulate.a = 1.0 if available else 0.45


func show_values(source: Dictionary) -> void:
	filling = true
	var values := VisualEnhancementOptions.normalize(source)
	profile_folder = str(values.lut_folder)
	for key in controls:
		var control: Control = controls[key]
		if control is CheckBox:
			(control as CheckBox).button_pressed = values[key]
		elif control is OptionButton:
			(control as OptionButton).select(values[key])
		elif control is SpinBox:
			(control as SpinBox).value = float(values[key]) * _display_scale(key)
		elif control is LineEdit:
			(control as LineEdit).text = values[key]
	filling = false
	_update_availability()


func selected_values() -> Dictionary:
	# Retain the hidden profile path when editing unrelated settings.
	var values := {"lut_folder": profile_folder}
	for key in controls:
		var control: Control = controls[key]
		if control is CheckBox:
			values[key] = (control as CheckBox).button_pressed
		elif control is OptionButton:
			values[key] = (control as OptionButton).selected
		elif control is SpinBox:
			values[key] = (control as SpinBox).value / _display_scale(key)
		elif control is LineEdit:
			values[key] = (control as LineEdit).text
	return VisualEnhancementOptions.normalize(values)
