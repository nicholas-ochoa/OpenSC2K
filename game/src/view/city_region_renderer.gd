class_name CityRegionRenderer
extends RefCounted

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const Underground = preload("res://src/view/city_underground_view.gd")


static func render(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive,
		bounds: Rect2i, view_size := Renderer.VIEW_LARGE, mode := CityViewMode.Mode.CITY,
		show_pipes := true, show_subways := true, show_water_mains := true) -> CityRegionResult:
	if city == null or not city.is_valid() or palette == null or not palette.is_valid() or sprites == null or not sprites.is_valid():
		return CityRegionResult.rejected("invalid region assets")

	var configuration := Renderer.view_configuration(view_size)

	if configuration == null or not CityViewMode.is_map(mode):
		return CityRegionResult.rejected("invalid region view")

	bounds = bounds.intersection(Rect2i(Vector2i.ZERO, Renderer.output_size_for_view(view_size, city.map_size)))

	if not bounds.has_area():
		return CityRegionResult.rejected("empty region")

	var image := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE if mode == CityViewMode.Mode.UNDERGROUND else Color.TRANSPARENT)
	var local := configuration.copy()
	local.top_margin = int(local.top_margin) - bounds.position.y
	var origin := int(configuration.side_margin) + city.map_size * int(configuration.half_width)
	var sprite_limit := Renderer.maximum_sprite_size(sprites)
	var cache := {}
	var foreground: Array[CityStaticCommand] = []
	var count := 0
	var span := Renderer.region_tile_span(configuration, sprite_limit, bounds, city.map_size, mode == CityViewMode.Mode.UNDERGROUND)

	for diagonal in range(span.first_diagonal, int(span.last_diagonal) + 1):
		var rows := Renderer.diagonal_rows(span, diagonal, city.map_size)

		for y in range(rows.x, rows.y + 1):
			var x := diagonal - y
			var potential := Renderer.potential_tile_bounds(configuration, sprite_limit, x, y, city.map_size)

			if mode == CityViewMode.Mode.UNDERGROUND:
				potential.size.y += 31 * int(configuration.altitude_step)

			if not potential.intersects(bounds):
				continue

			if mode == CityViewMode.Mode.UNDERGROUND:
				Underground.draw_tile(image, city, palette, sprites, cache, local, origin - bounds.position.x, x, y, show_pipes, show_subways, show_water_mains)
			else:
				Renderer.draw_tile(image, city, palette, sprites, cache, local, origin - bounds.position.x, x, y, 0, false, false)
				var order := diagonal * city.map_size + y
				var commands := Renderer.tile_occlusion_commands(city, sprites, configuration, origin, x, y, order)

				for index in commands.size():
					var command: CityStaticCommand = commands[index]

					if Rect2i(command.position, command.size).intersects(bounds):
						command.region_order = (order << 16) | index
						foreground.append(command)

			count += 1

	if palette.is_index_encoding:
		image.convert(Image.FORMAT_L8 if mode == CityViewMode.Mode.UNDERGROUND else Image.FORMAT_LA8)

	var grid := Renderer.build_occlusion_grid(foreground, int(configuration.divisor))

	var result := CityRegionResult.new()
	result.ok = true
	result.error = ""
	result.occlusion_commands = foreground
	result.occlusion_grid = grid
	result.image = image
	result.bounds = bounds
	result.tiles_drawn = count

	return result
