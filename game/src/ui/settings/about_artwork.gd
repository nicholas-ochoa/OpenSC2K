class_name AboutArtwork
extends Control
# display-only composition from imported large sprites. no source pixels are saved

const CANVAS_SIZE := Vector2(280, 280)
const MONSTER_POSITION := Vector2i(76, 135)
const ENTRANCE_DELAY := 1.5
const FIRST_BEAM_TIME := 3.0
const BEAM_DURATION := 0.65
const FIRE_SPREAD_INTERVAL := 0.8
const FIRE_POSITIONS := [Vector2(120, 237), Vector2(151, 223), Vector2(169, 253)]
const UPPER_POSES := [0x02, 0x03, 0x0b, 0x0a]
const LOWER_POSES := [0x00, 0x01, 0x09, 0x08]

var textures: Dictionary = {}
var available := false
var animation_time := 0.0
var active := false


func _ready() -> void:
	clip_contents = true
	set_process(false)
	resized.connect(queue_redraw)


func set_assets(assets: OriginalGameAssets) -> void:
	textures.clear()
	available = false

	if assets != null and assets.large_sprites != null and assets.palette != null:
		var ids := [1208, 1385, 1396, 1397, 1398, 1399]
		ids.append_array(range(1478, 1492))
		available = true
		for id in ids:
			var entry := assets.large_sprites.find_sprite(id)
			if entry == null:
				available = false
				continue
			var decoded := entry.create_image(assets.palette)
			if not decoded.ok:
				available = false
				continue
			var image: Image = decoded.image
			textures[Vector2i(id, 0)] = ImageTexture.create_from_image(image)
			var mirrored: Image = image.duplicate()
			mirrored.flip_x()
			textures[Vector2i(id, 1)] = ImageTexture.create_from_image(mirrored)

	set_process(active and available)
	queue_redraw()


func set_active(value: bool) -> void:
	if value and not active:
		animation_time = 0.0
	active = value
	set_process(active and available)
	queue_redraw()


func _process(delta: float) -> void:
	animation_time += delta
	queue_redraw()


func monster_time() -> float:
	return maxf(0.0, animation_time - ENTRANCE_DELAY)


func drop_offset() -> float:
	var progress := clampf(monster_time() / 2.4, 0.0, 1.0)
	return -260.0 * pow(1.0 - progress, 3.0)


func eye_open() -> bool:
	return (int(monster_time() * 0.5) & 1) == 1


func beam_active() -> bool:
	return eye_open() and monster_time() >= FIRST_BEAM_TIME and fmod(monster_time() - FIRST_BEAM_TIME, 8.0) < BEAM_DURATION


func visible_fire_count() -> int:
	var since_impact := monster_time() - FIRST_BEAM_TIME - BEAM_DURATION
	if since_impact < 0.0:
		return 0
	return mini(FIRE_POSITIONS.size(), 1 + int(since_impact / FIRE_SPREAD_INTERVAL))


func fire_frame(index: int) -> int:
	return 1396 + ((int(animation_time * 8.0) + index) & 3)


func _draw() -> void:
	if not available:
		return

	var scale_factor := minf(size.x / CANVAS_SIZE.x, size.y / CANVAS_SIZE.y)
	var origin := (size - CANVAS_SIZE * scale_factor) * 0.5
	draw_set_transform(origin, 0.0, Vector2.ONE * scale_factor)
	var pose_index := int(monster_time() * 0.5) & 3
	var body := MONSTER_POSITION + Vector2i(0, int(drop_offset()))
	var layers := CityIsometricRenderer.monster_pose_layers(
		body, UPPER_POSES[pose_index] | (0x80 if beam_active() else 0),
		LOWER_POSES[pose_index], int(eye_open())
	)
	for layer in layers:
		_draw_sprite(layer.sprite_id, Vector2(layer.screen_x, layer.screen_y), layer.flip)

	_draw_sprite(1208, Vector2(104, 190), false)
	for index in visible_fire_count():
		var id := fire_frame(index)
		var texture: Texture2D = textures[Vector2i(id, index & 1)]
		draw_texture(texture, FIRE_POSITIONS[index] - Vector2(0, texture.get_height()))
	draw_set_transform(Vector2.ZERO)


func _draw_sprite(id: int, position: Vector2, flip: bool) -> void:
	draw_texture(textures[Vector2i(id, int(flip))], position)

