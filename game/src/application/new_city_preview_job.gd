class_name NewCityPreviewJob
extends RefCounted
# the worker owns its document, random state, images, and rendering cache
var session := NewCityTerrainSession.new()
var thread := Thread.new()
var revision := 0
var view_size := CityIsometricRenderer.VIEW_SMALL

func start(source: NewCityTerrainSession, template_path: String, options: NewCityTerrain.Options, palette: Sc2Palette, sprites: Sc2SpriteArchive, advance_seed: bool) -> Error:
	session.independent_template = source.independent_template
	session.begin(source.preview_process_cursor if advance_seed else source.preview_process_start, source.preview_game_cursor if advance_seed else source.preview_game_start)

	return thread.start(_generate.bind(template_path, options.copy(), palette, sprites))


func _generate(template_path: String, options: NewCityTerrain.Options, palette: Sc2Palette, sprites: Sc2SpriteArchive) -> NewCityTerrainSession.PreviewResult:
	var result := session.generate_preview(template_path, options, true)

	if not result.ok:
		return result

	var rendered := CityIsometricRenderer.create_image(result.city, palette, sprites, view_size, 0, false, false, false, false)

	if not rendered.ok:
		return NewCityTerrainSession.PreviewResult.failure(rendered.error, "preview")

	result.landscape_image = rendered.image
	result.minimap_image = CityMinimap.create_image(result.city, palette, "structures")

	return result


static func preview_view_size(edge: int, target: Vector2) -> int:
	# never enlarge the small sprite set when a more detailed native set fits
	for view in [CityIsometricRenderer.VIEW_SMALL, CityIsometricRenderer.VIEW_MEDIUM]:
		var extent := Vector2(CityIsometricRenderer.output_size_for_view(view, edge))

		if extent.x >= target.x * 2.0 and extent.y >= target.y * 2.0:
			return view

	return CityIsometricRenderer.VIEW_LARGE
