extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or FileAccess.file_exists(args[0]):
		push_error("Supply a new output path. Existing files are never overwritten.")
		quit(1)
		return
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	city.set_funds(1000000)
	city.set_simulation_speed(GameSpeedController.Speed.PAUSED)
	for variant in 3:
		var scenario := TripQueryFixture.add_scenario(city, variant, Vector2i(16, 12 + variant * 30))
		if scenario.is_empty():
			quit(1)
			return
	if TripQueryFixture.add_subway_scenario(city, Vector2i(16, 102)).is_empty():
		quit(1)
		return
	TripQueryFixture.add_tunnel_scenario(city, Vector2i(80, 6))
	for size in range(1, 5):
		var route := TripQueryFixture.add_route(city, size, size, ["road", "rail", "highway", "rail"][size - 1], Vector2i(82, 12 + size * 16))
		var label := "%d %dx%d to %dx%d %s" % [size + 6, size, size, size, size, route.network]
		assert(SignCommand.set_sign(city, route.source.position + Vector2i(0, -3), label).ok)
		if size == 4:
			TripQueryFixture.stamp(city, route.source, 0xd9, 0)
			TripQueryFixture.stamp(city, route.destination, 0xd7, 0)
	TripQueryFixture.add_bus_scenario(city, Vector2i(110, 24))
	var result := CityFileStore.save_copy(city.document, args[0], "res://../references")
	if not result.ok:
		push_error(result.error)
		quit(1)
		return
	var loaded := Sc2File.load_path(result.path)
	assert(loaded.serialize().data == result.data)
	print("Created paused Trip Query comparison city: ", result.path)
	quit()
