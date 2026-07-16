class_name CityRegionRenderer
extends RefCounted

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const Underground = preload("res://src/view/city_underground_view.gd")


static func render(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive,
		bounds: Rect2i, view_size := Renderer.VIEW_LARGE, mode := "city",
		show_pipes := true, show_subways := true, show_water_mains := true) -> Dictionary:
	if city == null or not city.is_valid() or palette == null or not palette.is_valid() or sprites == null or not sprites.is_valid():
		return {"ok": false, "error": "invalid region assets"}

	var configuration := Renderer.view_configuration(view_size)

	if configuration.is_empty() or mode not in ["city", "underground"]:
		return {"ok": false, "error": "invalid region view"}

	bounds = bounds.intersection(Rect2i(Vector2i.ZERO, Renderer.output_size_for_view(view_size, city.map_size)))

	if not bounds.has_area():
		return {"ok": false, "error": "empty region"}

	var image := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE if mode == "underground" else Color.TRANSPARENT)
	var local := configuration.duplicate()
	local.top_margin = int(local.top_margin) - bounds.position.y
	var origin := int(configuration.side_margin) + city.map_size * int(configuration.half_width)
	var sprite_limit := Renderer.maximum_sprite_size(sprites)
	var cache := {}
	var foreground: Array[Dictionary] = []
	var count := 0
	var half_width := int(configuration.half_width)
	var half_height := int(configuration.half_height)
	var bottom_extra := int(configuration.tile_height) + int(IntegerMath.div_trunc(sprite_limit.x, 4)) + 1

	if mode == "underground":
		bottom_extra += 31 * int(configuration.altitude_step)

	var top_extra := 32 * int(configuration.altitude_step) + sprite_limit.y
	var first_diagonal := maxi(0, floori(float(bounds.position.y - int(configuration.top_margin) - bottom_extra) / half_height))
	var last_diagonal := mini(2 * (city.map_size - 1), ceili(float(bounds.end.y - int(configuration.top_margin) + top_extra) / half_height))
	var first_difference := floori(float(bounds.position.x - origin - sprite_limit.x - int(configuration.tile_width) - 1) / half_width)
	var last_difference := ceili(float(bounds.end.x - origin + sprite_limit.x) / half_width)

	for diagonal in range(first_diagonal, last_diagonal + 1):
		var first_y := maxi(maxi(0, diagonal - city.map_size + 1), ceili(float(diagonal - last_difference) / 2.0))
		var last_y := mini(mini(city.map_size - 1, diagonal), floori(float(diagonal - first_difference) / 2.0))

		for y in range(first_y, last_y + 1):
			var x := diagonal - y
			var potential := Renderer.potential_tile_bounds(configuration, sprite_limit, x, y, city.map_size)

			if mode == "underground":
				potential.size.y += 31 * int(configuration.altitude_step)

			if not potential.intersects(bounds):
				continue

			if mode == "underground":
				Underground.draw_tile(image, city, palette, sprites, cache, local, origin - bounds.position.x, x, y, show_pipes, show_subways, show_water_mains)
			else:
				Renderer.draw_tile(image, city, palette, sprites, cache, local, origin - bounds.position.x, x, y, 0, false, false)
				var order := diagonal * city.map_size + y
				var commands := Renderer.tile_occlusion_commands(city, sprites, configuration, origin, x, y, order)

				for index in commands.size():
					var command: Dictionary = commands[index]

					if Rect2i(command.position, command.size).intersects(bounds):
						command.region_order = (order << 16) | index
						foreground.append(command)

			count += 1

	if palette.is_index_encoding:
		image.convert(Image.FORMAT_L8 if mode == "underground" else Image.FORMAT_LA8)

	var grid := Renderer.build_occlusion_grid(foreground, int(configuration.divisor))

	return {"ok": true, "error": "", "occlusion_commands": foreground, "occlusion_grid": grid, "image": image, "bounds": bounds, "tiles_drawn": count}
