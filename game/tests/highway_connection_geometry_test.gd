extends SceneTree

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	for edge in Sc2File.MAP_SIZES:
		for native in [false, true]:
			# Exhaust geometry once; other cases cover each size and storage mode.
			var directions := [0, 1, 2, 3] if edge == 128 and not native else [Sc2File.MAP_SIZES.find(edge)]
			for direction in directions:
				var sides := [0, 20, edge - 2] if edge == 128 and not native else [edge - 2]
				for side in sides:
					var finish := Vector2i(edge - 2 if direction == 1 else 0, side)
					if direction in [0, 2]:
						finish = Vector2i(side, edge - 2 if direction == 2 else 0)
					var start: Vector2i = finish - HighwayCommand.DIRECTIONS[direction] * 6
					var doc := EmptyCityTemplate.create(edge)
					if native:
						doc.enable_full_resolution_maps()
					doc.set_misc_u32(0x08, direction)
					var city := CityState.from_document(doc)
					var initial: PackedByteArray = doc.serialize().data
					var canceled := HighwayCommand.apply(city, 6, 1, start, finish, HighwayCommand.CONNECTION_CANCELLED)
					check(canceled.ok, "Highway route reaches side or corner")
					var shape := city.buildings.duplicate()
					var terrain := city.terrain.duplicate()
					var zones := city.zones.duplicate()
					var flags := city.tile_flags.duplicate()
					var route_bytes: PackedByteArray = doc.serialize().data
					var existing := HighwayCommand.apply(city, 6, 1, start, finish, HighwayCommand.CONNECTION_CONFIRMED)
					check(existing.ok and city.buildings == shape and city.terrain == terrain, "Connecting a pre-existing route preserves its shape")
					check(HighwayCommand.undo(city, existing).ok and doc.serialize().data == route_bytes, "Connection-only Undo preserves existing route")
					check(HighwayCommand.undo(city, canceled).ok and doc.serialize().data == initial, "Canceled route has exact Undo")
					var connected := HighwayCommand.apply(city, 6, 1, start, finish, HighwayCommand.CONNECTION_CONFIRMED)
					check(connected.ok and connected.connection_built, "Confirm highway neighbor connection")
					check(city.buildings == shape and city.terrain == terrain and city.zones == zones and city.tile_flags == flags,
						"Confirmation preserves road shape, terrain, zones and flags")
					check(city.text_overlay_id(finish.x, finish.y) == 250 and connected.cost == canceled.cost + 1500,
						"Connection still stores marker and charges once")
					var saved: PackedByteArray = doc.serialize().data
					var loaded := Sc2File.new()
					check(loaded.parse(saved), "Reload connected highway")
					check(SimulationEngine.new(CityState.from_document(loaded)).industry_connections == 1,
						"Straight highway marker survives industrial recount")
					check(HighwayCommand.undo(city, connected).ok and doc.serialize().data == initial, "Connection has exact Undo")
					# Also test connecting a pre-existing isolated edge section by click.
					var placed := HighwayCommand.apply(city, 6, 1, finish, finish, HighwayCommand.CONNECTION_CANCELLED)
					check(placed.ok, "Place isolated border highway")
					shape = city.buildings.duplicate()
					connected = HighwayCommand.apply(city, 6, 1, finish, finish, HighwayCommand.CONNECTION_CONFIRMED)
					check(connected.ok and city.buildings == shape, "Connecting existing edge %s direction %d: ok=%s error=%s shape=%s" % [finish, direction, connected.ok, connected.get("error", ""), city.buildings == shape])
	print("Highway connection geometry: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
