extends Control

# the opacity of the area around the selected building in HD art
const FADED_ALPHA := 0.25

var zoom := 3.5
var palette: Sc2Palette
var palette_texture: ImageTexture
var ticks := 0
var elapsed := 0.0
var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
# HD art: the selected building over a faded `texture`, or null
var selection_texture: Texture2D:
	set(value):
		selection_texture = value
		queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or palette == null:
		return

	elapsed += delta
	var steps := int(elapsed / 0.2)

	if steps == 0:
		return

	elapsed -= steps * 0.2
	ticks += steps
	palette_texture.update(palette.animation_image(ticks))


func _ready() -> void:
	# a UI scale change on the main window moves the screen pixel grid
	get_tree().root.size_changed.connect(queue_redraw)


func _draw() -> void:
	if texture != null:
		# the zoom on whole screen pixels for each artwork pixel
		var target := Vector2(ScreenPixels.art_length(texture.get_width(), zoom), ScreenPixels.art_length(texture.get_height(), zoom))
		var rect := Rect2((size - target) * 0.5, target)

		if selection_texture == null:
			draw_texture_rect(texture, rect, false)

			return

		draw_texture_rect(texture, rect, false, Color(1, 1, 1, FADED_ALPHA))
		draw_texture_rect(selection_texture, rect, false)


func configure_animation(source: Sc2Palette, start_ticks: int) -> void:
	palette = source
	ticks = start_ticks
	elapsed = 0.0
	material = null
	palette_texture = null
	set_process(source != null)

	if source == null:
		return

	palette_texture = ImageTexture.create_from_image(source.animation_image(ticks))
	var lookup := ShaderMaterial.new()
	lookup.shader = CityMapControl.PALETTE_CYCLE_SHADER
	lookup.set_shader_parameter("animated_palette", palette_texture)
	lookup.set_shader_parameter("palette_cycle_enabled", true)
	lookup.set_shader_parameter("palette_lookup_all", true)
	material = lookup
