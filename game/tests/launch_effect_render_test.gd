extends SceneTree
## Rendering: a launching arcology starts where the static painter drew it,
## shakes, and flies off the top of the map.

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const Buildings = preload("res://src/tools/city/building_command.gd")
const LfsrRandom = preload("res://src/simulation/random/sim_lfsr_random.gd")
const Random = preload("res://src/simulation/random/sim_random.gd")


func _initialize() -> void:
	_check_painter_position()
	_check_flight()
	quit()


func _check_painter_position() -> void:
	var document := EmptyCityTemplate.create(128)
	assert(document.set_misc_i32(Sc2MiscLayout.FUNDS, 20000000))
	assert(document.set_misc_u32(ToolAvailability.MISC_PROGRESSION, 6))

	for invention_index in range(12, 16):
		assert(document.set_misc_u32(ToolAvailability.MISC_INVENTION_YEARS + invention_index * 4, 0))

	var city := CityState.from_document(document)
	var launch := Buildings.apply(city, 5, 8, Vector2i(20, 20), LfsrRandom.new(1), Random.new(1))
	assert(launch.ok, "The fixture builds a launch arcology: %s" % launch.error)
	# the painter draws a building from its screen-left corner
	var anchor := Vector2i(launch.site.position.x, launch.site.end.y - 1)
	var small := FixtureGraphics.pack().small_medium_sprites
	var large := FixtureGraphics.pack().large_sprites

	for view in [CityIsometricRenderer.VIEW_SMALL, CityIsometricRenderer.VIEW_MEDIUM, CityIsometricRenderer.VIEW_LARGE]:
		var config := CityIsometricRenderer.view_configuration(view)
		var archive := large if view == CityIsometricRenderer.VIEW_LARGE else small
		var commands := CityIsometricRenderer.tile_occlusion_commands(city, archive, view, anchor.x, anchor.y).filter(
			func(command: CityStaticCommand) -> bool: return command.sprite_id == config.sprite_base + Tiles.LAUNCH_ARCOLOGY)
		assert(commands.size() == 1, "The painter draws the arcology from its screen-left corner in view %d" % view)
		var command: CityStaticCommand = commands[0]
		var position := IsometricGeometry.building_sprite_position(
			city, anchor, city.land_altitude(anchor.x, anchor.y), Vector2i(command.size), view)
		assert(position == Vector2i(command.position),
			"A launching arcology starts on the painted one in view %d: %s, %s" % [view, position, command.position])


func _check_flight() -> void:
	var offsets := CityEffectTiming.launch_offsets(15, 2, 400, 100)
	var liftoff := 15 * CityEffectTiming.LAUNCH_FPS / 10

	for frame in CityEffectTiming.LAUNCH_STILL_FRAMES:
		assert(offsets[frame] == Vector2i.ZERO, "The arcology stands still before it shakes")

	var shake := offsets.slice(CityEffectTiming.LAUNCH_STILL_FRAMES, liftoff)
	assert(shake.any(func(offset: Vector2i) -> bool: return offset != Vector2i.ZERO), "The arcology shakes before liftoff")
	assert(shake.all(func(offset: Vector2i) -> bool: return absi(offset.x) <= 2 and absi(offset.y) <= 2), "The shake is slight")

	for frame in range(liftoff + 2, offsets.size()):
		var step := offsets[frame - 1].y - offsets[frame].y
		var previous := offsets[frame - 2].y - offsets[frame - 1].y
		assert(step >= previous and step >= 0, "The arcology rises faster and faster")

	assert(400 + offsets[-1].y + 100 < 0, "The flight ends above the top of the map")
