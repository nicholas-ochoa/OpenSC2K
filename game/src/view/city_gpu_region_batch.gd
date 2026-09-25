class_name CityGpuRegionBatch
extends RefCounted

const MAX_REGIONS := 4
const BUILD_BUDGET_USEC := 32000


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
	var generation := 0
	var budget_usec := 0
	var signs: Array[CitySignRequest] = []


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


static func build(request: Request, context: CityGpuBuildContext, uploaded_revision: int) -> Result:
	var batch_started := Time.get_ticks_usec()
	var display: CityState = request.city if request.prepared else CityViewFilter.surface_copy(request.city, request.visibility)
	var regions: Array[CityGpuRegionResult] = []
	var divisor := CityIsometricRenderer.view_configuration(request.view).divisor
	for key: Vector2i in request.keys:
		var started := Time.get_ticks_usec()
		var bounds := Rect2i(key * int(request.edge), Vector2i.ONE * int(request.edge))
		var result := CityGpuRegionRenderer.render(display, request.palette, request.sprites,
			bounds, request.view, request.mode, request.pipes, request.subways,
			context, request.generation, uploaded_revision, false, request.water_mains)

		if not result.ok:
			return Result.failure(result.error)

		if request.mode == CityViewMode.Mode.CITY:
			result.sign_foregrounds = CityGpuSignForegrounds.build(result, request.signs,
				request.palette, request.sprites, context, divisor)

		result.key = key
		result.usec = Time.get_ticks_usec() - started
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
