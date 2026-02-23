extends Control
## Local cursor test surface. It never changes city or editor state.

signal tested(position: Vector2i)
signal tick_changed
var record: Dictionary = {}
var sweep := {"demo": false, "playing": false, "tick": 0, "elapsed": 0.0}
var pointer := Vector2i(-100, -100)
var last_click := Vector2i(-1, -1)
var show_hotspot := false
var _hidden := false
var _background: Image
var _background_texture: ImageTexture
var _pointer_texture: ImageTexture
var _background_click := Vector2i(-2, -2)


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	var local := get_local_mouse_position()
	var inside := is_visible_in_tree() and Rect2(Vector2.ZERO, size).has_point(local) and not record.is_empty()
	var active: bool = inside and get_window().has_focus() and not sweep.demo

	if active != _hidden:
		_hidden = active
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if active else Input.MOUSE_MODE_VISIBLE

	if sweep.playing:
		sweep.elapsed += delta
		var steps := floori(sweep.elapsed / 0.05)

		if steps > 0:
			sweep.tick += steps
			sweep.elapsed -= steps * 0.05
			tick_changed.emit()

	var next := sweep_position(int(sweep.tick), Vector2i(size)) if sweep.demo else (Vector2i(local) if inside else Vector2i(-100, -100))

	if next != pointer:
		pointer = next
		queue_redraw()


func _exit_tree() -> void:
	if _hidden:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		last_click = Vector2i(event.position)
		tested.emit(last_click)
		queue_redraw()


static func background_color(point: Vector2i) -> Color:
	return Color("ffffff") if (int(point.x / 32) + int(point.y / 32)) % 2 == 0 else Color("20364c")


static func sweep_position(tick: int, bounds: Vector2i) -> Vector2i:
	var travel := maxi(1, bounds.x - 64)

	return Vector2i(32 + travel - absi(posmod(tick * 6, travel * 2) - travel), bounds.y / 2)


func _draw() -> void:
	if _background == null or _background.get_size() != Vector2i(size) or _background_click != last_click:
		_background = Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
		_background_click = last_click

		for y in int(size.y):
			for x in int(size.x):
				var color := background_color(Vector2i(x, y))
				var distance := Vector2(x, y).distance_to(Vector2(last_click))

				if last_click.x >= 0 and distance >= 4 and distance <= 6:
					color = Color("d66024")

				_background.set_pixel(x, y, color)

		_background_texture = ImageTexture.create_from_image(_background)

	draw_texture(_background_texture, Vector2.ZERO)

	if pointer.x < 0 or record.is_empty():
		return

	var origin: Vector2i = pointer - record.hotspot
	var backdrop := Image.create(32, 32, false, Image.FORMAT_RGBA8)

	for y in 32:
		for x in 32:
			var point := origin + Vector2i(x, y)
			var color := _background.get_pixelv(point) if Rect2i(Vector2i.ZERO, Vector2i(size)).has_point(point) else background_color(point)
			backdrop.set_pixel(x, y, color)

	var image := DesktopGraphics.render_cursor(record, backdrop)
	_pointer_texture = ImageTexture.create_from_image(image)
	draw_texture(_pointer_texture, Vector2(origin))

	if show_hotspot:
		draw_rect(Rect2(Vector2(pointer), Vector2.ONE), Color.RED)
