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
		TripQueryFixture.add_route(city, size, size, ["road", "rail", "highway", "rail"][size - 1], Vector2i(82, 12 + size * 16))
	TripQueryFixture.add_block(city, Vector2i(90, 96))
	var result := CityFileStore.save_copy(city.document, args[0], "res://../references")
	if not result.ok:
		push_error(result.error)
		quit(1)
		return
	var loaded := Sc2File.load_path(result.path)
	assert(loaded.serialize().data == result.data)
	print("Created paused Trip Query comparison city: ", result.path)
	quit()
