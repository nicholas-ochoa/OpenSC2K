extends SceneTree

class TestMap extends CityMapControl:
	func _tile_at(_point: Vector2) -> Vector2i:
		return Vector2i(60, 60)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var map := TestMap.new()
	root.add_child(map)
	map.size = Vector2(640, 480)
	map.set_edit_enabled(true, "point")
	map.placement_error_provider = func(_tile: Vector2i) -> String: return "The site is occupied."
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(300, 200)
	click.pressed = true
	map._handle_mouse_button(click)
	assert(map.placement_error_popup.visible, "Invalid click must show the reason without a timer")
	assert(map.placement_error_label.text == "Cannot build here: The site is occupied.")
	click.pressed = false
	map._handle_mouse_button(click)
	assert(map.placement_error_popup.visible, "Reason must remain after release")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(310, 200)
	map._handle_mouse_motion(motion)
	assert(not map.placement_error_popup.visible)
	map.placement_error_provider = func(_tile: Vector2i) -> String: return ""
	click.pressed = true
	map._handle_mouse_button(click)
	assert(not map.placement_error_popup.visible, "Valid click showed an error")
	map.queue_free()
	await process_frame
	print("PASS: immediate invalid placement tooltip")
	quit()
