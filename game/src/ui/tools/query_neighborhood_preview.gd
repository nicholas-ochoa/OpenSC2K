extends Control

var zoom := 3.5
var palette: Sc2Palette
var palette_texture: ImageTexture
var ticks := 0
var elapsed := 0.0


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
	var shader := Shader.new()
	shader.code = CityMapControl.PALETTE_CYCLE_SHADER
	var lookup := ShaderMaterial.new()
	lookup.shader = shader
	lookup.set_shader_parameter("animated_palette", palette_texture)
	lookup.set_shader_parameter("palette_cycle_enabled", true)
	lookup.set_shader_parameter("palette_lookup_all", true)
	material = lookup


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

var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()


func _draw() -> void:
	if texture != null:
		var target := texture.get_size() * zoom
		draw_texture_rect(texture, Rect2((size - target) * 0.5, target), false)
