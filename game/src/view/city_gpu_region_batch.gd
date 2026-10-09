class_name CityGpuRegionBatch
extends RefCounted

const MAX_REGIONS := 4
const BUILD_BUDGET_USEC := 32000
# A streaming worker keeps this many keys queued, so that it has work between
# main-thread polls. A short queue keeps up with viewport priority changes.
const STREAM_QUEUE := 6


static func build(request: Request, context: CityGpuBuildContext, uploaded_revision: int) -> Result:
	var batch_started := Time.get_ticks_usec()
	var display: CityState = request.city if request.prepared else CityViewFilter.surface_copy(request.city, request.visibility)
	var regions: Array[CityGpuRegionResult] = []
	for key: Vector2i in request.keys:
		var result := _region(request, display, key, context, uploaded_revision)

		if not result.ok:
			return Result.failure(result.error)

		regions.append(result)

		# Publish completed geometry before starting another expensive region.
		# The scheduler will request the remaining keys on its next poll.
		if request.budget_usec > 0 and Time.get_ticks_usec() - batch_started >= request.budget_usec:
			break

	# a later region can grow the shared atlas after earlier uvs were built
	for region in regions:
		if int(region.atlas_edge) != context.atlas_edge:
			var uvs: PackedVector2Array = region.gpu_arrays[Mesh.ARRAY_TEX_UV]

			for index in uvs.size():
				uvs[index] *= float(region.atlas_edge) / context.atlas_edge

			region.gpu_arrays[Mesh.ARRAY_TEX_UV] = uvs

			region.atlas_edge = context.atlas_edge

	var batch := Result.new()
	batch.ok = true
	batch.regions = regions
	batch.display_city = display
	batch.atlas_revision = context.atlas_revision
	batch.atlas_image = context.atlas.duplicate() if context.atlas != null and context.atlas_revision != uploaded_revision else null

	return batch


# Build regions from the worker inbox until it is empty or cancelled. Each
# complete region goes to the outbox at once, with a copy of the atlas when the
# region added sprites. The main thread changes the inbox while the stream runs.
static func stream(request: Request, worker: CityRegionCache.RegionWorker, uploaded_revision: int) -> Result:
	var context := worker.context
	var display: CityState = request.city if request.prepared else CityViewFilter.surface_copy(request.city, request.visibility)
	var published := uploaded_revision
	worker.mutex.lock()
	worker.display_city = display
	worker.mutex.unlock()

	while true:
		worker.mutex.lock()

		if worker.cancelled or worker.inbox.is_empty():
			worker.streaming = false
			worker.mutex.unlock()

			break

		var key: Vector2i = worker.inbox.pop_front()
		worker.mutex.unlock()
		var result := _region(request, display, key, context, published)

		if not result.ok:
			worker.mutex.lock()
			worker.streaming = false
			worker.mutex.unlock()

			return Result.failure(result.error)

		# Copies share the image data until the context writes a new sprite.
		if context.atlas != null and context.atlas_revision != published:
			result.atlas_image = context.atlas.duplicate()
			result.emission_image = context.emission_atlas
			result.season_image = context.season_atlas
			published = context.atlas_revision

		result.atlas_revision = published
		worker.mutex.lock()
		worker.outbox.append(result)
		worker.mutex.unlock()

	var batch := Result.new()
	batch.ok = true
	batch.display_city = display
	batch.atlas_revision = published

	return batch


static func _region(request: Request, display: CityState, key: Vector2i, context: CityGpuBuildContext,
		uploaded_revision: int) -> CityGpuRegionResult:
	var started := Time.get_ticks_usec()
	var bounds := Rect2i(key * int(request.edge), Vector2i.ONE * int(request.edge))
	var result := CityGpuRegionRenderer.render(display, request.palette, request.sprites,
		bounds, request.view, request.mode, request.pipes, request.subways,
		context, request.generation, uploaded_revision, false, request.water_mains, request.tunnels)

	if not result.ok:
		return result

	result.key = key
	result.usec = Time.get_ticks_usec() - started

	return result


class Request extends RefCounted:
	var city: CityState
	var prepared := false
	var visibility: Dictionary = {}
	var palette: Sc2Palette
	var sprites: Sc2SpriteArchive
	var keys: Array[Vector2i] = []
	var edge := 0
	var view := 0
	var mode := CityViewMode.Mode.CITY
	var pipes := true
	var subways := true
	var water_mains := true
	var tunnels := true
	var generation := 0
	var budget_usec := 0


class Result extends RefCounted:
	var ok := false
	var error := ""
	var regions: Array[CityGpuRegionResult] = []
	var display_city: CityState
	var atlas_revision := -1
	var atlas_image: Image

	static func failure(message: String) -> Result:
		var result := Result.new()
		result.error = message

		return result
