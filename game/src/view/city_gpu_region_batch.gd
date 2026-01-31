class_name CityGpuRegionBatch
extends RefCounted

const MAX_REGIONS := 4

static func build(request: Dictionary, context: CityGpuBuildContext, uploaded_revision: int) -> Dictionary:
	var display: CityState = request.city if request.prepared else CityViewFilter.surface_copy(request.city, request.visibility)
	var regions: Array[Dictionary] = []
	var divisor := int(CityIsometricRenderer.view_configuration(request.view).divisor)
	for key: Vector2i in request.keys:
		var started := Time.get_ticks_usec()
		var bounds := Rect2i(key * int(request.edge), Vector2i.ONE * int(request.edge))
		var result := CityGpuRegionRenderer.render(display, request.palette, request.sprites,
			bounds, request.view, request.mode, request.pipes, request.subways,
			context, request.generation, uploaded_revision, false)
		if not result.ok:
			return result
		if request.mode == "city":
			result.sign_foregrounds = CityGpuSignForegrounds.build(result, request.signs,
				request.palette, request.sprites, context, divisor)
		result.key = key
		result.usec = Time.get_ticks_usec() - started
		regions.append(result)
	return {"ok": true, "regions": regions, "display_city": display,
		"atlas_revision": context.atlas_revision,
		"atlas_image": context.atlas.duplicate() if context.atlas != null and context.atlas_revision != uploaded_revision else null}
