extends SceneTree
## Retained live integration check. F6 flips desktop art. F7 changes workspace.

var main: Node
var original: DesktopGraphics
var replacement: DesktopGraphics
var use_alternate := false
var label: Label
var icon: TextureRect
var status := ""


func _initialize() -> void:
	root.window_input.connect(_handle_input)
	call_deferred("_run")


func _run() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	original = DesktopGraphics.load_original("res://../references")
	assert(original.error.is_empty(), original.error)
	var folder := OS.get_environment("OPENSC2K_GRAPHICS_PACK")
	if not folder.is_empty():
		var pack := GraphicsPack.load_root(folder)
		assert(pack.error.is_empty(), pack.error)
		replacement = pack.desktop_graphics
	main.desktop_presentation.set_graphics(original)
	main._load_city_unchecked(ProjectSettings.globalize_path("res://../references/CITIES/ISLAND.SC2"))
	main.speed_controller.set_speed(0)
	main._sync_speed_ui()
	var layer := CanvasLayer.new()
	layer.layer = 129
	root.add_child(layer)
	var panel := HBoxContainer.new()
	panel.position = Vector2(100, 42)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	label = Label.new()
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	root.title = "Desktop runtime check — F6 set / F7 workspace"


func _process(_delta: float) -> bool:
	if label != null:
		var desktop: CityDesktopPresentation = main.desktop_presentation
		var presenter := desktop.presenter
		var hovered := root.gui_get_hovered_control()
		var current := "%s | F6 flip desktop set | F7 City/Paint | cursor %s:%d | icon %s | mouse %d" % [
			"Alternate" if use_alternate else "Original", presenter.active_app, presenter.active_group, desktop.icon_key, Input.mouse_mode]
		current += " | focus %s hover %s modal %s" % [root.has_focus(), hovered.name if hovered != null else "none", root.get_last_exclusive_window()]
		if current != status:
			status = current
			label.text = status
			print(status)
			icon.texture = ImageTexture.create_from_image(desktop.icon_image) if desktop.icon_image != null else null
	return false


func _handle_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or main == null:
		return
	if event.keycode == KEY_F6 and replacement != null:
		use_alternate = not use_alternate
		main.desktop_presentation.set_graphics(replacement if use_alternate else original)
		root.set_input_as_handled()
	elif event.keycode == KEY_F7:
		if main.scurk_editor.visible:
			main.scurk_editor.hide()
			main._update_edit_state()
		else:
			main._open_scurk_dialog()
		root.set_input_as_handled()
