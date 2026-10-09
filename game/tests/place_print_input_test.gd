extends SceneTree
## Place & Print object rows, flipped placement, sidebar icons, and hover focus.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_object_rows()
	_flipped_placement()
	_palette_icons()
	await _hover_focus()
	print("PASS: Place & Print object rows, flipped placement, sidebar icons and hover focus")
	quit()


func _object_rows() -> void:
	var list := ScurkPlaceObjectList.new()
	root.add_child(list)
	var chosen: Array[int] = []
	list.tile_chosen.connect(func(index: int) -> void: chosen.append(index))
	list.clear_tiles()
	assert(list.add_tile(0x0d, "Small Park", "Landscape tile", null, "") == 0)
	assert(list.add_tile(0xd2, "Police Station", "Building or zone tile", null, "") == 1)
	assert(list.item_count == 2 and list.tile_id_at(1) == 0xd2 and list.tile_id_at(2) == -1)
	list.select_index(1)
	assert(chosen.is_empty(), "A selection from code does not report a choice")
	list.item_selected.emit()
	assert(chosen == [1])
	list.clear_tiles()
	assert(list.item_count == 0)
	list.free()


func _flipped_placement() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	var park := Vector2i(10, 10)
	var placed := ScurkPlaceCommand.apply(city, BuildingTileIds.SMALL_PARK, park, SimRandom.new(1), 0, false, true)
	assert(placed.ok and (city.tile_flags[city.index_of(park.x, park.y)] & Sc2TileFlags.FLIPPED) != 0)
	placed = ScurkPlaceCommand.apply(city, BuildingTileIds.SMALL_PARK, park + Vector2i(2, 0), SimRandom.new(1))
	assert(placed.ok and (city.tile_flags[city.index_of(park.x + 2, park.y)] & Sc2TileFlags.FLIPPED) == 0)
	var stamp := ScurkPlaceCommand.apply(city, BuildingTileIds.MAX_ID + 1, park, SimRandom.new(1), 0, false, true)
	assert(stamp.ok and city.scurk_artwork_stamps[-1].flipped)
	var copies := ScurkArtworkStamp.copy_all(city.scurk_artwork_stamps)
	assert(copies[-1].flipped and ScurkArtworkStamp.same_values(copies, city.scurk_artwork_stamps))
	copies[-1].flipped = false
	assert(not ScurkArtworkStamp.same_values(copies, city.scurk_artwork_stamps))


# a scurk edit tool can select another group. the buttons keep their own icons
func _palette_icons() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	var palette := CityChildToolPalette.new()
	palette.build()
	var groups: Array[int] = []
	var icons := func(group: int, _subtool: int) -> Texture2D:
		groups.append(group)
		return null
	palette.show_tool_group(CityToolIds.Group.ROADS, city, icons)
	groups.clear()
	palette.refresh_icons(icons)
	assert(not groups.is_empty() and groups.all(func(group: int) -> bool: return group == CityToolIds.Group.ROADS))
	palette.free()


func _hover_focus() -> void:
	var main_area := Control.new()
	main_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(main_area)
	var router := HoverFocusRouter.new()
	root.add_child(router)
	router.attach(root)
	var dialog := Window.new()
	dialog.position = Vector2i(400, 100)
	dialog.size = Vector2i(200, 200)
	var field := LineEdit.new()
	dialog.add_child(field)
	root.add_child(dialog)
	dialog.show()
	dialog.grab_focus()
	await process_frame
	assert(router.focused_window() == dialog)

	# hover over the main view releases the dialog, and hover over it takes the focus back
	router.route(_motion(Vector2(100, 400)))
	assert(not dialog.has_focus() and router.focused_window() == null)
	router.route(_wheel(Vector2(500, 200)))
	assert(dialog.has_focus())
	assert(router.window_at(Vector2(500, 90 - dialog.get_theme_constant("title_height") / 2)) == dialog,
		"The title bar belongs to the dialog")

	# a held button, a text field with focus, and an open menu keep the focus
	var held := _motion(Vector2(100, 400))
	held.button_mask = MOUSE_BUTTON_MASK_LEFT
	router.route(held)
	assert(dialog.has_focus())
	field.grab_focus()
	router.route(_motion(Vector2(100, 400)))
	assert(dialog.has_focus())
	field.release_focus()
	var menu := PopupMenu.new()
	menu.add_item("Item")
	root.add_child(menu)
	menu.popup(Rect2i(700, 500, 80, 40))
	await process_frame
	var focus_with_menu := dialog.has_focus()
	router.route(_motion(Vector2(100, 400)))
	assert(menu.visible and dialog.has_focus() == focus_with_menu, "An open menu keeps the focus")
	menu.hide()
	dialog.grab_focus()
	router.route(_motion(Vector2(100, 400)))
	assert(not dialog.has_focus())
	assert(not dialog.unfocusable, "A released dialog can take the focus again")

	# a stretched window gives pixels at twice the viewport scale
	assert(HoverFocusRouter.viewport_point(Vector2(1000, 400), Transform2D.IDENTITY.scaled(Vector2(2, 2)))
		== Vector2(500, 200))

	menu.free()
	dialog.free()
	router.free()
	main_area.free()


# the router reads window pixels, as the root window gives them
func _motion(point: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * point

	return event


func _wheel(point: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	event.factor = 1.0
	event.position = root.get_final_transform() * point

	return event
