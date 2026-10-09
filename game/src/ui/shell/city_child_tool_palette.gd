class_name CityChildToolPalette
extends VBoxContainer

signal subtool_requested(index: int)

const Tools = preload("res://src/tools/shared/tool_catalog.gd")
const DisplayNumbers = preload("res://src/ui/shared/display_number_format.gd")

var free_landscape := false
var heading: Label
var scroll: ScrollContainer
var grid: GridContainer
var buttons: Dictionary = {}
# the group whose tools the buttons show, or -1
var shown_group := -1


func _ready() -> void:
	build()


# the buttons put the tool names in their text, so they change with the language
func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED or shown_group < 0:
		return

	for subtool_index: int in buttons:
		var button := buttons[subtool_index] as Button
		var tool := Tools.tool(shown_group, subtool_index)
		button.text = tr(tool.name) if free_landscape else "%s\n%s" % [tr(tool.name), _tool_price(tool)]
		button.tooltip_text = tool_button_tooltip(shown_group, subtool_index, not button.disabled)


func build() -> void:
	if heading != null:
		return

	add_theme_constant_override("separation", 4)
	heading = Label.new()
	heading.text = "Selected Group"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.clip_text = true
	heading.add_theme_font_size_override("font_size", 13)
	add_child(heading)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 96)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 1
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)


func show_tool_group(
	group_index: int,
	city: CityState,
	icon_provider: Callable = Callable(),
	preferred_subtool := -1,
) -> int:
	if group_index < 0 or group_index >= Tools.GROUPS.size():
		return 0

	_clear_buttons()
	shown_group = group_index
	scroll.scroll_vertical = 0
	scroll.set_deferred("scroll_vertical", 0)
	var visible_group := group_index < CityToolIds.Group.SIGNS or group_index == CityToolIds.Group.QUERY
	heading.visible = visible_group
	scroll.visible = visible_group

	if not visible_group:
		return 0

	var group := Tools.group(group_index)
	heading.text = str(group.name)
	var button_group := ButtonGroup.new()
	var first_available_subtool := -1

	for subtool_index in group.tools.size():
		if not free_landscape and LandscapeEditorCommand.supports_tool(
			group_index,
			subtool_index,
		) and not (group_index == CityToolIds.Group.LANDSCAPE and subtool_index == CityToolIds.Landscape.FOREST):
			continue

		if (free_landscape
				and ((group_index == CityToolIds.Group.BULLDOZER and subtool_index == CityToolIds.Bulldozer.DEZONE)
				or (group_index == CityToolIds.Group.QUERY and subtool_index != CityToolIds.Query.QUERY))):
			continue

		# debug query tools appear only in debug mode
		if not DebugMode.allows_tool(group_index, subtool_index):
			continue

		if ((group_index == CityToolIds.Group.POWER and subtool_index == CityToolIds.Power.PLANTS)
				or (group_index == CityToolIds.Group.REWARDS and subtool_index == CityToolIds.Rewards.ARCOLOGIES)):
			continue

		var available := free_landscape or city == null or ToolAvailability.is_available(
			city, group_index, subtool_index
		)
		var button := _create_button(
			group_index,
			subtool_index,
			button_group,
			available,
			icon_provider,
		)
		grid.add_child(button)
		buttons[subtool_index] = button

		if available and first_available_subtool < 0:
			first_available_subtool = subtool_index

	# keep the last subtool chosen in this group while it is still offered
	if buttons.has(preferred_subtool) and not (buttons[preferred_subtool] as Button).disabled:
		return preferred_subtool

	return maxi(0, first_available_subtool)


func sync_selection(subtool_index: int) -> void:
	var displayed_subtool := subtool_index

	for button_subtool in buttons:
		var button: Button = buttons[button_subtool]
		button.button_pressed = int(button_subtool) == displayed_subtool


# the buttons keep the icons of the group they show. a scurk edit tool can
# select another group without a new palette
func refresh_icons(icon_provider: Callable) -> void:
	if not icon_provider.is_valid() or shown_group < 0:
		return

	for subtool_index in buttons:
		var button: Button = buttons[subtool_index]
		button.theme_type_variation = "ArtworkButton"
		button.icon = icon_provider.call(shown_group, int(subtool_index))


func refresh_availability(
	city: CityState,
	group_index: int,
	selected_subtool: int,
	selected_was_available: bool,
) -> bool:
	if city == null:
		return false

	var changed := false

	for subtool_index in buttons:
		var available := free_landscape or ToolAvailability.is_available(
			city, shown_group, int(subtool_index)
		)
		var button: Button = buttons[subtool_index]

		if button.disabled == available:
			button.disabled = not available
			changed = true

		button.tooltip_text = tool_button_tooltip(
			shown_group, int(subtool_index), available
		)

	var selected_available := free_landscape or ToolAvailability.is_available(
		city, group_index, selected_subtool
	)

	return changed or selected_available != selected_was_available


func tool_button_tooltip(
	group_index: int, subtool_index: int, available: bool
) -> String:
	var tool := Tools.tool(group_index, subtool_index)

	if tool == null:
		return ""

	if group_index == CityToolIds.Group.QUERY and subtool_index == CityToolIds.Query.TRIP_REACH:
		return ("Trip Query\nClick a zone or transport tile. Colors show trip cost. A blue pin marks the origin. Green " +
			"checkmarks mark possible destinations. Inspection does not change the city.")

	if group_index == CityToolIds.Group.QUERY and subtool_index == CityToolIds.Query.TILE_INSPECTOR:
		return ("Tile Inspector\nPoint at a tile to show its stored bytes, flags, data map values and debug layer value. " +
			"Click to keep the panel on a tile. Inspection does not change the city.")

	var price := _tool_price(tool)
	var lines := PackedStringArray([tr(str(tool.name))])

	if not free_landscape:
		lines.append(tr("Cost: %s") % price)

	if int(tool.area) > 0:
		lines.append(tr("Footprint: %d x %d tiles") % [tool.area, tool.area])

	if group_index == CityToolIds.Group.POWER and subtool_index >= CityToolIds.Power.COAL:
		var details := Tools.power_plant_details(subtool_index)

		if details != null:
			lines.append(tr("Nominal output: %d MW") % details.output_mw)
			lines.append(tr("Grid capacity: %s") % tr(details.grid_capacity))
			lines.append(tr("Pollution factor: %d") % details.pollution)
			lines.append(tr("Service life: %s") % tr(details.service_life))
			lines.append(tr(str(details.note)))

	const FACILITY_DETAILS := {
		"220": "Requires power and pipes. Output depends on weather and nearby water; each adjacent fresh-water tile adds 10 supply units.",
		"235": ("Stores 100 water units per tower tile. Stores surplus supply and releases stored water "
			+ "when needed. Requires a pipe connection."),
		"211": "Fire coverage scales with funding. Unpowered stations have half strength. Supports emergency fire dispatch.",
		"210": ("Police coverage scales with funding and the prison bonus. Unpowered stations have half "
			+ "strength. Coverage reduces local crime."),
		"209": ("At full funding, each hospital supplies 25 units of capacity to the health phase. Funding "
			+ "cuts reduce capacity proportionally."),
		"217": ("At full funding, each college supplies 50 units of capacity to the education phase. "
			+ "Serves the college-age population group."),
		"215": "Recreation facility. Choose the team name after placement. Query shows annual attendance and financial statistics.",
		"216": "Prison facilities contribute to the police-strength bonus. Query shows annual prison statistics.",
		"244": ("Treats 2,000 watered consumers per plant. Sufficient treatment improves the pollution "
			+ "calculation. It does not generate water."),
		"250": "Requires power and pipes. Each adjacent salt-water tile adds 20 supply units. Coastal placement improves output.",
		"245": "Supports education. Query shows its annual education statistic. Ruminate opens the library reports.",
		"214": "At full funding, each school supplies 15 units of capacity to the education phase. Serves younger population groups.",
		"212": "Supports education and city services. Query shows the annual museum statistic.",
	}
	var tile_id := BuildingSites.tile_for_tool(group_index, subtool_index)

	if FACILITY_DETAILS.has(str(tile_id)):
		lines.append(tr(FACILITY_DETAILS[str(tile_id)]))

	if not available:
		lines.append(tr("Status: Not available in this city."))

	return "\n".join(lines)


func _clear_buttons() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	buttons.clear()


func _create_button(
	group_index: int,
	subtool_index: int,
	button_group: ButtonGroup,
	available: bool,
	icon_provider: Callable,
) -> Button:
	var tool := Tools.tool(group_index, subtool_index)
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.button_group = button_group
	button.text = tr(str(tool.name)) if free_landscape else "%s\n%s" % [tr(tool.name), _tool_price(tool)]
	button.clip_text = false
	button.theme_type_variation = "ArtworkButton"
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.icon = (
		icon_provider.call(group_index, subtool_index)
		if icon_provider.is_valid()
		else null
	)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.disabled = not available
	button.tooltip_text = tool_button_tooltip(
		group_index, subtool_index, available
	)
	button.pressed.connect(subtool_requested.emit.bind(subtool_index))

	return button


func _tool_price(tool: ToolCatalog.Tool) -> String:
	if free_landscape:
		return tr("Free")

	return (
		"Free"
		if int(tool.cost) == 0
		else "$%s" % DisplayNumbers.format(int(tool.cost))
	)
