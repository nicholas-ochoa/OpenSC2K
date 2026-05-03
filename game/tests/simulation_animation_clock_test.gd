extends SceneTree
const Main = preload("res://src/main.gd")


func _initialize() -> void:
	var host := Main.new()
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	host.speed_controller = GameSpeedController.new(SimulationEngine.new(city, 1, 2, 3))
	host.speed_controller.set_speed(GameSpeedController.Speed.CHEETAH)
	var before := SimulationSnapshot.stamp(host.speed_controller)

	# No simulation result is delivered during this interval, as with a pending job.
	for frame in 61:
		host.frame._advance_palette_animation(1.0 / 60.0, false)

	assert(host.palette_cycle_ticks == 5, "Display animation continues without published ticks")
	assert(SimulationSnapshot.stamp(host.speed_controller) == before, "Animation cannot advance simulation state")
	host.frame._advance_palette_animation(1.0, true)
	assert(host.palette_cycle_ticks == 5, "Modal pause freezes display clock")
	host.speed_controller.set_speed(GameSpeedController.Speed.PAUSED)
	host.frame._advance_palette_animation(1.0, false)
	assert(host.palette_cycle_ticks == 5, "Paused speed freezes display clock")
	host.free()
	print("PASS: independent palette clock, simulation isolation and pause")
	quit()
