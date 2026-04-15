class_name NewCityPreviewJob
extends RefCounted
# the worker owns its document, random state, images, and rendering cache
var session := NewCityTerrainSession.new()
var thread := Thread.new()
var revision := 0

func start(source: NewCityTerrainSession, template_path: String, options: Dictionary,
	palette: Sc2Palette, sprites: Sc2SpriteArchive, advance_seed: bool) -> Error:
	session.independent_template = source.independent_template
	session.begin(source.preview_process_cursor if advance_seed else source.preview_process_start,
		source.preview_game_cursor if advance_seed else source.preview_game_start)
	return thread.start(_generate.bind(template_path, options.duplicate(true), palette, sprites))


func _generate(template_path: String, options: Dictionary, palette: Sc2Palette,
	sprites: Sc2SpriteArchive) -> Dictionary:
	var result := session.generate_preview(template_path, options, true)
	if not result.ok:
		return result
	var rendered := CityIsometricRenderer.create_image(result.city, palette, sprites,
		CityIsometricRenderer.VIEW_SMALL, 0, false, false, false, false)
	if not rendered.ok:
		return {"ok": false, "stage": "preview", "error": rendered.error}
	result["landscape_image"] = rendered.image
	result["minimap_image"] = CityMinimap.create_image(result.city, palette, "structures")
	return result
