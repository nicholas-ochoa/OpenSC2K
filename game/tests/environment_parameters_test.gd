extends SceneTree
## Rendering cache regressions: skipped frames, late materials and restored defaults.


func _initialize() -> void:
	var cache := CityEnvironmentParameters.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float amount = 0.25; uniform vec2 drift; uniform sampler2D artwork;"
	var material := ShaderMaterial.new()
	material.shader = shader
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	var values := {"amount": 0.5, "drift": Vector2.ZERO, "artwork": texture}
	cache.update(values)
	assert(cache.apply(material) == 3)
	assert(cache.apply(material) == 0, "An unchanged frame must not upload uniforms")
	cache.update(values.duplicate())
	assert(cache.apply(material) == 0)
	values.drift = Vector2.ONE
	cache.update(values)
	assert(cache.apply(material) == 1)
	assert(material.get_shader_parameter("drift") == Vector2.ONE)
	# A hidden material misses several updates, including a texture replacement.
	values.amount = 0.75
	cache.update(values)
	values.artwork = ImageTexture.create_from_image(image)
	cache.update(values)
	assert(cache.apply(material) == 2)
	assert(material.get_shader_parameter("amount") == 0.75)
	assert(material.get_shader_parameter("artwork") == values.artwork)
	var late := ShaderMaterial.new()
	late.shader = shader
	assert(cache.apply(late) == 3)
	assert(late.get_shader_parameter("amount") == 0.75)
	values.erase("artwork")
	cache.update(values)
	assert(cache.apply(material) == 1)
	assert(material.get_shader_parameter("artwork") == null)
	# Replacing a shader invalidates the marker even when values are unchanged.
	material.shader = shader.duplicate()
	assert(cache.apply(material) == 3)
	assert(material.get_shader_parameter("amount") == 0.75)
	var other := CityEnvironmentParameters.new()
	other.update(values)
	assert(other.apply(material) == 2)
	_check_water_clock()
	print("PASS: unchanged uniforms, partial updates, hidden/late materials, texture replacement and frozen water")
	quit()


func _check_water_clock() -> void:
	var water := CityWaterLayer.new()
	var region := WaterReflectionRegion.new()
	region.bounds = Rect2i(0, 0, 8, 8)
	for key in ["surface", "reflected", "emission", "seasons"]:
		region.set(key, Image.create(8, 8, false, Image.FORMAT_RGBA8))
	var source := CityMapSource.new(Vector2i(8, 8))
	var entry := CityMapSource.TileEntry.new(Vector2.ZERO, Vector2(8, 8), null)
	entry.water = region
	source.tiles.append(entry)
	water.clock = 17.0
	water.set_environment({"water_enabled": true, "water_frozen": true})
	water.sync(source, 1.0, Vector2.ZERO, null)
	var material := (water.nodes[Vector2.ZERO] as Sprite2D).material as ShaderMaterial
	assert(material.get_shader_parameter("water_clock") == 17.0, "A new region must join the current frozen clock")
	water._process(1.0)
	assert(water.clock == 17.0)
	water.set_environment({"water_enabled": false, "water_frozen": false})
	water._process(1.0)
	assert(water.clock == 17.0)
	water.set_environment({"water_enabled": true, "water_frozen": false})
	water._process(1.0)
	assert(water.clock == 18.0 and material.get_shader_parameter("water_clock") == 18.0)
	water.free()
