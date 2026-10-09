class_name CityWaterLayer
extends Node2D
## Separate water pass, between static artwork and moving objects.

const WATER_SHADER := preload("res://src/view/water/water_surface.gdshader")

var nodes: Dictionary = {}
var environment: Dictionary = {}
var clock := 0.0
var moving: Array[WaterReflectionSprite] = []
var whole_context: CityGpuBuildContext
var whole_sprites: Sc2SpriteArchive
var whole_divisor := 1
var whole_source_id := 0
var whole_regions: Dictionary = {}
var _environment := CityEnvironmentParameters.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	if not visible or environment.get("water_frozen", false) or delta <= 0.0:
		return
	clock = fposmod(clock + delta, 3600.0)
	for node: Sprite2D in nodes.values():
		(node.material as ShaderMaterial).set_shader_parameter("water_clock", clock)


func set_environment(parameters: Dictionary) -> void:
	environment = parameters
	_environment.update(parameters)
	visible = environment.get("water_enabled", false) and not nodes.is_empty()
	if not visible:
		return
	for node: Sprite2D in nodes.values():
		_apply(node.material as ShaderMaterial)


func _apply(material: ShaderMaterial) -> void:
	_environment.apply(material)


func configure_whole(context: CityGpuBuildContext, sprites: Sc2SpriteArchive, divisor: int, source_id: int) -> void:
	whole_context = context
	whole_sprites = sprites
	whole_divisor = divisor
	whole_source_id = source_id
	whole_regions.clear()


func _whole_entries(source: CityMapSource, visible_area: Rect2) -> Array[CityMapSource.TileEntry]:
	var entries: Array[CityMapSource.TileEntry] = []
	if whole_context == null or source.get_instance_id() != whole_source_id or not whole_sprites.water_reflections:
		return entries
	var first := Vector2i((visible_area.position / whole_divisor).floor())
	var last := Vector2i((visible_area.end / whole_divisor).ceil())
	var native_area := Rect2i(first, last - first)
	var areas: Array[Rect2i] = [native_area]
	var retained := {}
	for key in NativeRegionPlan.keys_for(areas, 256):
		retained[key] = true
		if not whole_regions.has(key):
			whole_regions[key] = whole_context.build_water(Rect2i(key * 256, Vector2i(256, 256)), whole_divisor,
				whole_sprites, CityViewMode.Mode.CITY)
		var region: WaterReflectionRegion = whole_regions[key]
		if region != null:
			var entry := CityMapSource.TileEntry.new(Vector2(key * 256 * whole_divisor), Vector2(256, 256) * whole_divisor, null)
			entry.water = region
			entries.append(entry)
	for key in whole_regions.keys():
		if not retained.has(key):
			whole_regions.erase(key)
	return entries


func sync(source: CityMapSource, view_scale: float, offset: Vector2, palette: Texture2D, visible_area := Rect2()) -> void:
	position = offset
	scale = Vector2.ONE * view_scale
	var retained := {}
	if source != null:
		for entry in source.tiles + source.meshes + _whole_entries(source, visible_area):
			var region: WaterReflectionRegion = entry.water
			if region == null:
				continue
			var key: Vector2 = entry.position
			retained[key] = true
			var node: Sprite2D = nodes.get(key)
			if node == null:
				node = Sprite2D.new()
				node.centered = false
				var material := ShaderMaterial.new()
				material.shader = WATER_SHADER
				node.material = material
				material.set_shader_parameter("water_clock", clock)
				add_child(node)
				nodes[key] = node
			if not node.has_meta("region") or node.get_meta("region") != region:
				region.prepare(node.material as ShaderMaterial)
				node.texture = region.textures.reflected
				node.position = region.bounds.position * region.divisor
				node.scale = Vector2.ONE * region.divisor
				node.set_meta("region", region)
			(node.material as ShaderMaterial).set_shader_parameter("animated_palette", palette)
			_apply_moving(node, region)
			_apply(node.material as ShaderMaterial)
	for key in nodes.keys():
		if not retained.has(key):
			var region: WaterReflectionRegion = (nodes[key] as Sprite2D).get_meta("region")
			region.textures.clear()
			region.moving_signature.clear()
			region.moving_textures.clear()
			(nodes[key] as Sprite2D).queue_free()
			nodes.erase(key)
	visible = environment.get("water_enabled", false) and not nodes.is_empty()


func set_moving(visuals: Array[CityDynamicVisual]) -> void:
	moving.clear()
	for visual in visuals:
		if visual.water_reflection != null:
			moving.append(visual.water_reflection)
	for node: Sprite2D in nodes.values():
		_apply_moving(node, node.get_meta("region") as WaterReflectionRegion)


func _apply_moving(node: Sprite2D, region: WaterReflectionRegion) -> void:
	var composed := region.compose_moving(moving)
	var material := node.material as ShaderMaterial
	node.texture = composed.get("reflected", region.textures.reflected)
	material.set_shader_parameter("environment_emission", composed.get("emission", region.textures.emission))
	material.set_shader_parameter("environment_season_mask", composed.get("seasons", region.textures.seasons))


static func blue_indices(palette: Sc2Palette) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(256)
	if palette == null or not palette.is_valid() or palette.is_index_encoding:
		return result
	for index in 256:
		var color := palette.color(index)
		result[index] = int(color.b > 0.15 and color.b > color.r * 1.2 and color.b > color.g * 1.08)
	return result
