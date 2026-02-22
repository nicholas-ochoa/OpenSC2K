extends SceneTree
## Inclusive build costs. Timers add overhead; use the pan benchmark for latency.
class ProfiledContext extends CityGpuBuildContext:
	var intersection_usec := 0
	var intersection_calls := 0
	var tile_usec := 0
	var tile_calls := 0
	var slot_usec := 0
	func intersects(city: CityState, sprites: Sc2SpriteArchive, config: Dictionary, x: int, y: int, region: Rect2i, mode: String) -> bool:
		var began := Time.get_ticks_usec()
		var value := super.intersects(city, sprites, config, x, y, region, mode)
		intersection_usec += Time.get_ticks_usec() - began
		intersection_calls += 1
		return value
	func tile(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive, configuration: Dictionary, x: int, y: int, mode: String, pipes: bool, subways: bool) -> Dictionary:
		var began := Time.get_ticks_usec()
		var value := super.tile(city, palette, sprites, configuration, x, y, mode, pipes, subways)
		tile_usec += Time.get_ticks_usec() - began
		tile_calls += 1
		return value
	func slot(image: Image) -> Rect2i:
		var began := Time.get_ticks_usec()
		var value := super.slot(image)
		slot_usec += Time.get_ticks_usec() - began
		return value

func _initialize() -> void:
	var city := CityState.from_document(Sc2File.load_path("res://../local/large-cities/stitched-512.sc2x"))
	var sprites := Sc2SpriteArchive.load_path("res://../references/DATA/LARGE.DAT")
	var palette := Sc2Palette.index_encoding()
	var context := ProfiledContext.new()
	var center := CityIsometricRenderer.output_size_for_view(2, 512) / 2 / 256
	var began := Time.get_ticks_usec()
	var quads := 0
	for y in range(-4, 4):
		for x in range(-4, 4):
			var result := CityGpuRegionRenderer.render(city, palette, sprites, Rect2i((center + Vector2i(x, y)) * 256, Vector2i(256, 256)), 2, "city", true, true, context, 1, -1, false)
			assert(result.ok)
			quads += result.gpu_arrays[Mesh.ARRAY_VERTEX].size() / 4
	print("BUILD total_us=%d intersection_us=%d calls=%d tile_us=%d calls=%d slot_us=%d quads=%d cached_tiles=%d" % [Time.get_ticks_usec() - began, context.intersection_usec, context.intersection_calls, context.tile_usec, context.tile_calls, context.slot_usec, quads, context.tiles.size()])
	quit()
