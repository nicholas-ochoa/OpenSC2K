class_name CityMapMovingOcclusion
extends RefCounted
# same scene three times: palette, normal depth, train depth
# gpu occlusion and shadows for moving objects. state belongs to citymapcontrol
#
# three buffers repeat the visible region meshes at one texel per native
# sprite pixel: the static palette indices, the static depth, and the train depth
# see citygpuocclusiondepth for the depth values. the dynamic canvas shader
# samples these buffers at each sprite pixel. it hides a pixel behind a later
# static silhouette and draws aircraft shadows from the static indices. the
# buffers draw again only when the visible rectangle or region meshes change

@warning_ignore_start("integer_division")

const MAX_BUFFER_EDGE := 8192
# item modes in the draw color alpha. 255 is an ordinary indexed sprite
const MODE_SPRITE := 1
const MODE_SHADOW := 2
const MODE_TRAIN := 3
const MODE_PLAIN := 255
# draw order for a sprite that no static sprite may cover
const NO_OCCLUSION := 0xffffff
const SPRITE_SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D animated_palette : source_color, filter_nearest, repeat_disable;
uniform bool palette_cycle_enabled = false;
uniform bool palette_lookup_all = false;
uniform bool gpu_occlusion = false;
uniform sampler2D static_index : filter_nearest, repeat_disable;
uniform sampler2D static_depth : filter_nearest, repeat_disable;
uniform sampler2D train_depth : filter_nearest, repeat_disable;
uniform float buffer_divisor = 1.0;
uniform vec2 buffer_origin = vec2(0.0);
uniform vec2 buffer_size = vec2(1.0);

varying flat vec4 item;
varying vec2 source_position;

float decode_value(vec4 encoded) {
	vec3 bytes = floor(encoded.rgb * 255.0 + 0.5);
	return bytes.r * 65536.0 + bytes.g * 256.0 + bytes.b;
}

vec4 palette_color(int index) {
	return texture(animated_palette, vec2((float(index) + 0.5) / 256.0, 0.5));
}

void vertex() {
	item = COLOR;
	source_position = VERTEX;
}

void fragment() {
	vec4 base_color = texture(TEXTURE, UV);
	int mode = int(round(item.a * 255.0));

	if (mode == 255) {
		// The unchanged indexed-sprite path of the palette cycle shader.
		int palette_index = int(round(base_color.r * 255.0));
		COLOR = palette_cycle_enabled && palette_lookup_all
			? vec4(palette_color(palette_index).rgb, base_color.a)
			: base_color;
	} else {
		if (base_color.a <= 0.0) {
			discard;
		}

		// Decide once per native source pixel, as the CPU path does.
		vec2 native_pixel = floor(source_position / buffer_divisor);
		vec2 buffer_uv = (native_pixel + 0.5 - buffer_origin) / buffer_size;
		int palette_index = int(round(base_color.r * 255.0));

		if (gpu_occlusion) {
			float order = decode_value(item);
			vec4 depth = mode == 3 ? texture(train_depth, buffer_uv) : texture(static_depth, buffer_uv);
			float stored = decode_value(depth);

			if (stored >= order + 2.0) {
				discard;
			}
		}

		if (mode == 2) {
			if (!gpu_occlusion) {
				discard;
			}

			int under = int(round(texture(static_index, buffer_uv).r * 255.0));
			int shadow = under == 95 ? 100 : ((under >= 116 && under <= 126) ? 126 : under);

			if (shadow == under) {
				discard;
			}

			palette_index = shadow;
		}

		COLOR = palette_cycle_enabled
			? vec4(palette_color(palette_index).rgb, 1.0)
			: vec4(vec3(float(palette_index) / 255.0), 1.0);
	}
}
"""
const DEPTH_SHADER := """
shader_type canvas_item;
render_mode unshaded, blend_disabled;

varying flat vec4 depth_color;

void vertex() {
	depth_color = COLOR;
}

void fragment() {
	if (texture(TEXTURE, UV).a <= 0.0) {
		discard;
	}

	COLOR = vec4(depth_color.rgb, 1.0);
}
"""

var map: CityMapControl
var enabled := false
var _viewports: Array[SubViewport] = []
var _worlds: Array[Node2D] = []
var _source: CityMapSource
var _buffer_rect := Rect2i()
var _buffer_divisor := 0
# buffer mesh instances by region mesh, kept while the region is published
var _instances: Dictionary = {}
var _depth_material: ShaderMaterial
var _active := false


func _init(control: CityMapControl) -> void:
	map = control


static func create_sprite_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = SPRITE_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader

	return material


# encode a sprite's draw order and item mode as its draw color
static func item_color(order: int, mode: int) -> Color:
	if mode == MODE_PLAIN:
		return Color.WHITE

	var value := NO_OCCLUSION if order < 0 else mini(order, NO_OCCLUSION)

	return Color8((value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff, mode)


func set_enabled(value: bool) -> void:
	if enabled == value:
		return

	enabled = value
	sync()


func active() -> bool:
	return _active


func buffer_textures() -> Array[Texture2D]:
	var textures: Array[Texture2D] = []

	for viewport in _viewports:
		textures.append(viewport.get_texture())

	return textures


func sync() -> void:
	var source := map.city_source
	var usable := (
		enabled and map.is_inside_tree() and source != null and map.data_view_mode.is_empty()
		and map._dynamic_material != null and source.has_occlusion_depth()
		and map.size.x >= 1.0 and map.size.y >= 1.0
	)

	if not usable:
		_release()

		return

	# one texel per native sprite pixel over the visible source rectangle
	# integer mesh positions then map each source pixel to exactly one texel,
	# whatever the zoom and window scale
	var divisor := source.meshes[0].divisor
	var visible := map.camera.visible_source_rect()
	var first := Vector2i((visible.position / divisor).floor()) - Vector2i.ONE
	var last := Vector2i((visible.end / divisor).ceil()) + Vector2i.ONE
	var native := Rect2i(first, last - first).intersection(
		Rect2i(Vector2i.ZERO, source.size / divisor)
	)

	if not native.has_area() or native.size.x > MAX_BUFFER_EDGE or native.size.y > MAX_BUFFER_EDGE:
		_release()

		return

	_ensure_viewports()
	var changed := _source != source or _buffer_rect != native or _buffer_divisor != divisor

	if changed:
		var world_transform := Transform2D(0.0, Vector2.ONE / divisor, 0.0, -Vector2(native.position))

		for index in _viewports.size():
			if _viewports[index].size != native.size:
				_viewports[index].size = native.size

			_worlds[index].transform = world_transform
			_viewports[index].render_target_update_mode = SubViewport.UPDATE_ONCE

	_buffer_rect = native
	_buffer_divisor = divisor

	if _source != source:
		_rebuild(source)

	var material := map._dynamic_material
	material.set_shader_parameter("static_index", _viewports[0].get_texture())
	material.set_shader_parameter("static_depth", _viewports[1].get_texture())
	material.set_shader_parameter("train_depth", _viewports[2].get_texture())
	material.set_shader_parameter("buffer_divisor", float(divisor))
	material.set_shader_parameter("buffer_origin", Vector2(native.position))
	material.set_shader_parameter("buffer_size", Vector2(native.size))
	material.set_shader_parameter("gpu_occlusion", true)
	_active = true


func _ensure_viewports() -> void:
	if not _viewports.is_empty():
		return

	_depth_material = ShaderMaterial.new()
	_depth_material.shader = Shader.new()
	_depth_material.shader.code = DEPTH_SHADER

	for buffer_name in ["StaticIndexBuffer", "StaticDepthBuffer", "TrainDepthBuffer"]:
		var viewport := SubViewport.new()
		viewport.name = buffer_name
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var world := Node2D.new()
		world.name = "World"
		viewport.add_child(world)
		map.add_child(viewport)
		_viewports.append(viewport)
		_worlds.append(world)


# each simulation refresh publishes a new source with mostly unchanged
# regions. keep their instances; replace only changed regions
func _rebuild(source: CityMapSource) -> void:
	var retained := _instances
	_instances = {}

	for entry in source.meshes:
		var key := entry.mesh.get_instance_id()
		var instances: Array = retained.get(key, [])
		retained.erase(key)

		if instances.is_empty() or instances[0].texture != entry.texture or instances[1].mesh != entry.depth_mesh or instances[2].mesh != entry.train_depth_mesh:
			_free_instances(instances)
			instances = [
				_add_mesh(_worlds[0], entry, entry.mesh, null),
				_add_mesh(_worlds[1], entry, entry.depth_mesh, _depth_material),
				_add_mesh(_worlds[2], entry, entry.train_depth_mesh, _depth_material),
			]

		for instance: MeshInstance2D in instances:
			instance.position = entry.position
			instance.scale = Vector2.ONE * entry.divisor

		_instances[key] = instances

	for instances: Array in retained.values():
		_free_instances(instances)

	_source = source


func _add_mesh(world: Node2D, entry: CityMapSource.MeshEntry, mesh: Mesh, material: Material) -> MeshInstance2D:
	var instance := MeshInstance2D.new()
	instance.mesh = mesh
	instance.texture = entry.texture
	instance.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	instance.material = material
	world.add_child(instance)

	return instance


static func _free_instances(instances: Array) -> void:
	for instance: MeshInstance2D in instances:
		instance.get_parent().remove_child(instance)
		instance.queue_free()


func _release() -> void:
	if map._dynamic_material != null:
		map._dynamic_material.set_shader_parameter("gpu_occlusion", false)

	for viewport in _viewports:
		viewport.queue_free()

	_viewports.clear()
	_worlds.clear()
	_instances.clear()
	_source = null
	_buffer_rect = Rect2i()
	_buffer_divisor = 0
	_active = false


# map-control units to render-target pixels, so one buffer texel is one
# screen pixel. the final transform holds the window stretch
func _screen_transform() -> Transform2D:
	var viewport := map.get_viewport()

	if viewport == null:
		return Transform2D.IDENTITY

	return viewport.get_final_transform() * map.get_global_transform_with_canvas()
