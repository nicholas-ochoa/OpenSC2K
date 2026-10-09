class_name CityDisasterBeamGlow
extends RefCounted
## Small retained light buffers, using the same kernel and additive blend as buildings.

const EMISSION := preload("res://src/view/disasters/beam_emission.gdshader")
const BLUR := preload("res://src/view/environment/night_blur.gdshader")
const GLOW := preload("res://src/view/environment/night_glow.gdshader")
const PADDING := 12
var app: CityApplication
var entries: Array[Entry] = []


func _init(application: CityApplication) -> void:
	app = application


func process() -> void:
	var map := app.map_view
	if map == null:
		return
	var options := app.preferences.visual_enhancements
	var night := float(map.layers.environment_parameters.get("environment_night", 0.0))
	var enabled := app.disaster_effects.active() and night > 0.001 and map.layers.dynamic_canvas != null and map.layers.dynamic_canvas.visible
	var count := 0
	if enabled:
		for visual in map.dynamic_sprites:
			if not visual.beam_glow or visual.emission_texture == null:
				continue
			if count == entries.size():
				entries.append(_create())
			var entry := entries[count]
			var size := Vector2i(visual.size) + Vector2i.ONE * PADDING * 2
			for buffer in entry.buffers:
				buffer.size = size
				buffer.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			for rect in entry.blur_rects:
				rect.size = Vector2(size)
			entry.source.texture = visual.emission_texture
			entry.source.size = visual.size
			var material := entry.source.material as ShaderMaterial
			material.set_shader_parameter("indexed", visual.emission_texture is ImageTexture and (visual.emission_texture as ImageTexture).get_format() == Image.FORMAT_LA8)
			material.set_shader_parameter("animated_palette", map.animated_palette_texture)
			var scale_value := map.camera._view_scale()
			entry.output.position = map.camera._draw_offset(scale_value) + (visual.position - Vector2.ONE * PADDING) * scale_value
			entry.output.size = Vector2(size) * scale_value
			# The building glow defaults to 35%; honor its option when available.
			(entry.output.material as ShaderMaterial).set_shader_parameter("strength", night * float(options.get("night_glow", 35.0)) / 100.0 * 1.6)
			entry.output.show()
			count += 1
	for i in range(count, entries.size()):
		entries[i].output.hide()
		for buffer in entries[i].buffers:
			buffer.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _create() -> Entry:
	var entry := Entry.new()
	for i in 3:
		var buffer := SubViewport.new()
		buffer.disable_3d = true
		buffer.transparent_bg = true
		buffer.use_hdr_2d = app.map_view.get_viewport().use_hdr_2d
		buffer.world_2d = World2D.new()
		app.map_view.add_child(buffer)
		entry.buffers.append(buffer)
		var rect := TextureRect.new()
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var material := ShaderMaterial.new()
		rect.material = material
		buffer.add_child(rect)
		if i == 0:
			rect.position = Vector2.ONE * PADDING
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			material.shader = EMISSION
			entry.source = rect
		else:
			rect.texture = entry.buffers[i - 1].get_texture()
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			material.shader = BLUR
			material.set_shader_parameter("direction", Vector2.RIGHT if i == 1 else Vector2.DOWN)
			material.set_shader_parameter("radius", 1.5)
			entry.blur_rects.append(rect)
	entry.output = TextureRect.new()
	entry.output.show_behind_parent = true
	entry.output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.output.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	entry.output.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	entry.output.texture = entry.buffers.back().get_texture()
	var material := ShaderMaterial.new()
	material.shader = GLOW
	entry.output.material = material
	app.map_view.add_child(entry.output)
	app.map_view.move_child(entry.output, app.map_view.layers.dynamic_canvas.get_index() + 1)
	return entry


class Entry extends RefCounted:
	var buffers: Array[SubViewport] = []
	var blur_rects: Array[TextureRect] = []
	var source: TextureRect
	var output: TextureRect
