extends SceneTree
## Check marker size for incomplete buildings.


func _initialize() -> void:
	for edge in [128, 256, 384, 512]:
		for rotation in 4:
			var city := CityState.from_document(EmptyCityTemplate.create(edge))
			city.document.set_misc_i32(0x0008, rotation)
			var points := [Vector2i(20, 20), Vector2i(edge - 1, edge - 1)]
			# First site has all four tiles but no corner flags; second is partial at the edge.
			for x in range(20, 22):
				for y in range(20, 22):
					city.set_building_id(x, y, BuildingTileIds.SHOPPING_CENTER_2X2)
			city.set_building_id(edge - 1, edge - 1, BuildingTileIds.SHOPPING_CENTER_2X2)
			var result := TransportTripReachResult.new()
			result.origin = Vector2i(10, 10)
			result.limit = 100
			result.destinations = {points[0]: 10, points[1]: 20}
			var before: PackedByteArray = city.document.serialize().data
			var overlay := TripReachOverlay.new()
			overlay.rebuild(city, result)
			assert(overlay.destinations.size() == 2, "Unresolved sites lost their separate markers")
			for index in points.size():
				assert(overlay.destinations[index].is_finite(), "Destination center is not finite")
				assert(overlay.destinations[index].is_equal_approx(TripReachOverlay._center(city, points[index])))
			assert(city.document.serialize().data == before)
	print("PASS: incomplete destination markers stay finite and distinct at all map sizes and rotations")
	quit()
