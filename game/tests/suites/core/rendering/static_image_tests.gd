extends "res://tests/support/core_test_suite.gd"

## Rendering: static image checks.

@warning_ignore_start("integer_division")

const Palette = preload("res://src/assets/sc2_palette.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")


func run(small_medium: Sc2SpriteArchive) -> void:
	# Pixel formats and local patches need only a small, populated drawing fixture.
	# Large-map patch extents are owned by large_render_patch_test.
	var render_fixture := CityModel.from_document(EmptyCityTemplate.create(16))
	for point in [Vector2i(4, 4), Vector2i(12, 12), Vector2i(10, 6)]:
		render_fixture.set_building_id(point.x, point.y, Tiles.SMALL_PARK)
	var indexed_city := IsometricRenderer.create_image(
		render_fixture, Palette.index_encoding(), small_medium,
		IsometricRenderer.VIEW_SMALL, 0, false, true
	)
	_check(
		indexed_city.ok and indexed_city.image.get_pixel(0, 0).a == 0.0,
		"Indexed city rendering keeps its outer canvas transparent",
	)
	_check(
		indexed_city.ok and indexed_city.image.get_format() == Image.FORMAT_LA8,
		"Transparent indexed city rendering uses two bytes per pixel",
	)
	var opaque_indexed_city := IsometricRenderer.create_image(
		render_fixture, Palette.index_encoding(), small_medium,
		IsometricRenderer.VIEW_SMALL, 0, false, false, false, false
	)
	_check(
		opaque_indexed_city.ok
		and opaque_indexed_city.image.get_format() == Image.FORMAT_L8,
		"Opaque indexed city rendering uses one byte per pixel",
	)
	_check(
		indexed_city.ok and indexed_city.image.get_used_rect().has_area(),
		"Indexed city rendering draws nontransparent map pixels",
	)
	var patch_document := render_fixture.document.duplicate_document()
	var patch_city := CityModel.from_document(patch_document)
	var patch_point := Vector2i(8, 8)
	var patch_index := patch_city.index_of(patch_point.x, patch_point.y)
	_check(
		patch_city.set_building_id(patch_point.x, patch_point.y, Tiles.SMALL_PARK),
		"Static region fixture places a small park",
	)
	var patch_result := IsometricRenderer.patch_static_image(
		indexed_city.image,
		patch_city,
		Palette.index_encoding(),
		small_medium,
		PackedInt32Array([patch_index]),
		IsometricRenderer.VIEW_SMALL,
		0
	)
	var patch_full := IsometricRenderer.create_image(
		patch_city, Palette.index_encoding(), small_medium,
		IsometricRenderer.VIEW_SMALL, 0, false, true, false, false
	)
	_check(
		patch_result.ok
		and patch_full.ok
		and patch_result.image.get_data() == patch_full.image.get_data(),
		"A regional static edit is byte-identical to a complete small-view render",
	)
	var scaled_before: Image = indexed_city.image.duplicate()
	scaled_before.resize(
		IsometricRenderer.output_size_for_view(IsometricRenderer.VIEW_LARGE, 16).x,
		IsometricRenderer.output_size_for_view(IsometricRenderer.VIEW_LARGE, 16).y,
		Image.INTERPOLATE_NEAREST
	)
	var scaled_patch := IsometricRenderer.patch_static_image(
		scaled_before,
		patch_city,
		Palette.index_encoding(),
		small_medium,
		PackedInt32Array([patch_index]),
		IsometricRenderer.VIEW_SMALL,
		0
	)
	var scaled_full: Image = patch_full.image.duplicate()
	scaled_full.resize(
		IsometricRenderer.output_size_for_view(IsometricRenderer.VIEW_LARGE, 16).x,
		IsometricRenderer.output_size_for_view(IsometricRenderer.VIEW_LARGE, 16).y,
		Image.INTERPOLATE_NEAREST
	)
	_check(
		scaled_patch.ok
		and scaled_patch.image.get_data() == scaled_full.get_data(),
		"A scaled regional edit is byte-identical to the complete display image",
	)
	var base_patch_occlusion := IsometricRenderer.static_occlusion_commands(
		render_fixture, small_medium, IsometricRenderer.VIEW_SMALL
	)
	var regional_patch_occlusion := (
		IsometricRenderer.patch_static_occlusion_commands(
			base_patch_occlusion,
			patch_city,
			small_medium,
			PackedInt32Array([patch_index]),
			IsometricRenderer.VIEW_SMALL
		)
	)
	var full_patch_occlusion := IsometricRenderer.static_occlusion_commands(
		patch_city, small_medium, IsometricRenderer.VIEW_SMALL
	)
	_check(
		_static_command_values(regional_patch_occlusion) == _static_command_values(full_patch_occlusion),
		"A regional edit keeps the complete static occlusion command order",
	)
	_check(IsometricRenderer.terrain_sprite_id(0x00, false) == 1256, "Flat land uses sprite 1256")
	_check(IsometricRenderer.terrain_sprite_id(0x10, true) == 1270, "Submerged land uses sprite 1270")
	_check(IsometricRenderer.terrain_sprite_id(0x45, true) == 1290, "Last water tile uses sprite 1290")
	_check(
		IsometricRenderer.terrain_sprite_id(0x00, false, 0) == 256,
		"Small flat land uses sprite 256",
	)
	_check(
		IsometricRenderer.terrain_sprite_id(0x00, false, 500) == 756,
		"Medium flat land uses sprite 756",
	)
	_check(
		IsometricRenderer.output_size_for_view(IsometricRenderer.VIEW_SMALL)
		== Vector2i(1040, 736),
		"Small city view has the recovered quarter-scale canvas",
	)
	_check(
		IsometricRenderer.output_size_for_view(IsometricRenderer.VIEW_MEDIUM)
		== Vector2i(2080, 1472),
		"Medium city view has the recovered half-scale canvas",
	)
	var small_terrain := small_medium.find_sprite(256)
	var medium_terrain := small_medium.find_sprite(756)
	_check(
		small_terrain != null and small_terrain.width == 8 and small_terrain.height == 5,
		"Small terrain sprite is 8 by 5",
	)
	_check(
		medium_terrain != null and medium_terrain.width == 16 and medium_terrain.height == 9,
		"Medium terrain sprite is 16 by 9",
	)


func _static_command_values(commands: Array[CityStaticCommand], include_region := true) -> Array:
	var values: Array = []

	for command in commands:
		var fields := [command.sprite_id, command.flip, command.position, command.size,
			command.depth_order, command.train_ignore, command.train_foreground_reference_sprite_id,
			command.train_deck_thickness, command.train_deck_reference_sprite_id,
			command.train_foreground_requires_depth]

		if include_region:
			fields.append(command.region_order)

		values.append(fields)

	return values
