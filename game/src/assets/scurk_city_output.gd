class_name ScurkCityOutput
extends RefCounted

@warning_ignore_start("integer_division")

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const UndergroundView = preload("res://src/view/city_underground_view.gd")
const ViewFilter = preload("res://src/view/city_view_filter.gd")
const IndexedBitmap = preload("res://src/assets/indexed_bmp.gd")

const PDF_PAGE_WIDTH := 612.0
const PDF_PAGE_HEIGHT := 792.0
const PDF_MARGIN := 36.0
const SIGN_PANEL_INDEX := 160
const SIGN_POST_INDEX := 158
const SIGN_LIGHT_INDEX := 155
const SIGN_DARK_INDEX := 165
const SIGN_TEXT_INDEX := 106
const FONT_5X7 := {
	" ": [0, 0, 0, 0, 0, 0, 0],
	"?": [14, 17, 1, 2, 4, 0, 4],
	"A": [14, 17, 17, 31, 17, 17, 17],
	"B": [30, 17, 17, 30, 17, 17, 30],
	"C": [14, 17, 16, 16, 16, 17, 14],
	"D": [30, 17, 17, 17, 17, 17, 30],
	"E": [31, 16, 16, 30, 16, 16, 31],
	"F": [31, 16, 16, 30, 16, 16, 16],
	"G": [14, 17, 16, 23, 17, 17, 14],
	"H": [17, 17, 17, 31, 17, 17, 17],
	"I": [14, 4, 4, 4, 4, 4, 14],
	"J": [7, 2, 2, 2, 18, 18, 12],
	"K": [17, 18, 20, 24, 20, 18, 17],
	"L": [16, 16, 16, 16, 16, 16, 31],
	"M": [17, 27, 21, 21, 17, 17, 17],
	"N": [17, 25, 21, 19, 17, 17, 17],
	"O": [14, 17, 17, 17, 17, 17, 14],
	"P": [30, 17, 17, 30, 16, 16, 16],
	"Q": [14, 17, 17, 17, 21, 18, 13],
	"R": [30, 17, 17, 30, 20, 18, 17],
	"S": [15, 16, 16, 14, 1, 1, 30],
	"T": [31, 4, 4, 4, 4, 4, 4],
	"U": [17, 17, 17, 17, 17, 17, 14],
	"V": [17, 17, 17, 17, 17, 10, 4],
	"W": [17, 17, 17, 21, 21, 21, 10],
	"X": [17, 17, 10, 4, 10, 17, 17],
	"Y": [17, 17, 10, 4, 4, 4, 4],
	"Z": [31, 1, 2, 4, 8, 16, 31],
	"0": [14, 17, 19, 21, 25, 17, 14],
	"1": [4, 12, 4, 4, 4, 4, 14],
	"2": [14, 17, 1, 2, 4, 8, 31],
	"3": [30, 1, 1, 14, 1, 1, 30],
	"4": [2, 6, 10, 18, 31, 2, 2],
	"5": [31, 16, 16, 30, 1, 1, 30],
	"6": [14, 16, 16, 30, 17, 17, 14],
	"7": [31, 1, 2, 4, 8, 8, 8],
	"8": [14, 17, 17, 14, 17, 17, 14],
	"9": [14, 17, 17, 15, 1, 1, 14],
	"-": [0, 0, 0, 31, 0, 0, 0],
	".": [0, 0, 0, 0, 0, 12, 12],
	",": [0, 0, 0, 0, 0, 4, 8],
	"'": [4, 4, 8, 0, 0, 0, 0],
	"&": [12, 18, 20, 8, 21, 18, 13],
	"/": [1, 1, 2, 4, 8, 16, 16],
}


class Options extends RefCounted:
	var view := "city"
	var color := true
	var magnification := 1
	var entire_city := true
	var selected_pages := PackedByteArray()
	var show_pipes := true
	var show_water_mains := true
	var moving_things := false
	var special_overlays := false
	var transparent_background := false
	var progress := Callable()
	var surface_visibility: Dictionary[String, bool] = {}

	func _init() -> void:
		surface_visibility.assign(ViewFilter.DEFAULT_VISIBILITY)

	func copy() -> Options:
		var result := Options.new()
		result.view = view
		result.color = color
		result.magnification = magnification
		result.entire_city = entire_city
		result.selected_pages = selected_pages.duplicate()
		result.show_pipes = show_pipes
		result.show_water_mains = show_water_mains
		result.moving_things = moving_things
		result.special_overlays = special_overlays
		result.transparent_background = transparent_background
		result.progress = progress
		result.surface_visibility = surface_visibility.duplicate()

		return result


class PageGrid extends RefCounted:
	var columns: int
	var rows: int
	var count: int
	var view_size: int

	func _init(column_count: int, row_count: int, graphics_size: int) -> void:
		columns = column_count
		rows = row_count
		count = columns * rows
		view_size = graphics_size


class PdfResult extends FileWriteResult:
	var page_count := 0
	var available_page_count := 0

	static func rejected(message: String) -> PdfResult:
		var result := PdfResult.new()
		result.error = message

		return result


static func page_grid(magnification: int) -> PageGrid:
	match magnification:
		1:
			return PageGrid.new(2, 1, Renderer.VIEW_SMALL)
		2:
			return PageGrid.new(4, 2, Renderer.VIEW_MEDIUM)
		4:
			return PageGrid.new(7, 4, Renderer.VIEW_LARGE)

	return null


static func render(
	city: CityState,
	render_palette: Sc2Palette,
	sprites: Sc2SpriteArchive,
	view_size: int,
	options: Options
) -> AssetImageResult:
	if city == null or not city.is_valid():
		return AssetImageResult.failure("city is invalid")

	var view := String(options.view)
	var transparent := bool(options.transparent_background)
	var progress: Callable = options.progress
	var result: AssetImageResult

	if view == "underground":
		result = UndergroundView.create_image(
			city,
			render_palette,
			sprites,
			view_size,
			true,
			bool(options.show_pipes), true, bool(options.show_water_mains),
			transparent, progress
		)
	elif view == "city":
		var show_signs := bool(
			options.surface_visibility.get("signs", true)
		)
		var visibility := ViewFilter.normalized(
			options.surface_visibility
		)
		var display_city := ViewFilter.surface_copy(city, visibility)
		result = Renderer.create_image(
			display_city,
			render_palette,
			sprites,
			view_size,
			0,
			bool(options.moving_things),
			transparent,
			true,
			bool(options.special_overlays),
			progress
		)

		if result.ok and show_signs:
			_draw_signs(result.image, display_city, render_palette, view_size)
	else:
		return AssetImageResult.failure("print view must be city or underground")

	if not result.ok:
		return AssetImageResult.failure(result.error)

	var image: Image = result.image

	if image == null or image.is_empty():
		return AssetImageResult.failure("city output is empty")

	if view == "city":
		_draw_artwork_stamps(image, city, render_palette, sprites, view_size)

	if not bool(options.color):
		image = _monochrome_copy(image)

	var outcome := AssetImageResult.new()
	outcome.ok = true
	outcome.error = ""
	outcome.image = image

	return outcome


static func save_small_bmp(
	path: String,
	city: CityState,
	index_palette: Sc2Palette,
	output_palette: Sc2Palette,
	sprites: Sc2SpriteArchive,
	options: Options
) -> FileWriteResult:
	var rendered := render(
		city, index_palette, sprites, Renderer.VIEW_SMALL, options
	)

	if not rendered.ok:
		return FileWriteResult.failure(rendered.error)

	var image: Image = rendered.image

	if image.get_format() != Image.FORMAT_L8:
		return FileWriteResult.failure("indexed city output has the wrong image format")

	var bytes := image.get_data()
	var pixels := PackedInt32Array()
	pixels.resize(bytes.size())

	for index in bytes.size():
		pixels[index] = bytes[index]

	var saved := IndexedBitmap.save_path(
		path, image.get_width(), image.get_height(), pixels, output_palette
	)

	return saved


static func save_pdf(
	path: String,
	city: CityState,
	output_palette: Sc2Palette,
	sprites: Sc2SpriteArchive,
	options: Options
) -> PdfResult:
	var magnification := int(options.magnification)
	var grid := page_grid(magnification)

	if grid == null:
		return PdfResult.rejected("print magnification must be 1x, 2x, or 4x")

	var rendered := render(
		city, output_palette, sprites, int(grid.view_size), options
	)

	if not rendered.ok:
		return PdfResult.rejected(rendered.error)

	var image: Image = rendered.image

	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	var selected := _selected_page_indices(options, int(grid.count))

	if selected.is_empty():
		return PdfResult.rejected("select at least one page to print")

	var pdf := _encode_pdf(image, grid, selected)

	if not pdf.ok:
		return PdfResult.rejected(pdf.error)

	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		return PdfResult.rejected(
			"cannot open PDF output: %s" % error_string(FileAccess.get_open_error())
		)

	file.store_buffer(pdf.bytes)
	var write_error := file.get_error()
	file.close()

	if write_error != OK:
		return PdfResult.rejected("cannot write PDF output: %s" % error_string(write_error))

	var outcome := PdfResult.new()
	outcome.ok = true
	outcome.error = ""
	outcome.path = path
	outcome.page_count = selected.size()
	outcome.available_page_count = int(grid.count)

	return outcome


static func _selected_page_indices(options: Options, page_count: int) -> PackedInt32Array:
	var result := PackedInt32Array()

	if bool(options.entire_city):
		for index in page_count:
			result.append(index)

		return result

	var selected: PackedByteArray = options.selected_pages

	for index in mini(selected.size(), page_count):
		if selected[index] != 0:
			result.append(index)

	return result


static func _encode_pdf(
	image: Image, grid: PageGrid, selected: PackedInt32Array
) -> AssetBytesResult:
	var columns := int(grid.columns)
	var rows := int(grid.rows)
	var object_count := 2 + selected.size() * 3
	var bodies: Array[PackedByteArray] = []
	bodies.resize(object_count + 1)
	bodies[1] = "<< /Type /Catalog /Pages 2 0 R >>\n".to_ascii_buffer()
	var page_ids := PackedInt32Array()

	for output_index in selected.size():
		page_ids.append(3 + output_index * 3)

	var kids := ""

	for page_id in page_ids:
		kids += "%d 0 R " % page_id

	bodies[2] = (
		"<< /Type /Pages /Count %d /Kids [%s] >>\n" % [page_ids.size(), kids]
	).to_ascii_buffer()

	for output_index in selected.size():
		var page_index := int(selected[output_index])
		var column := page_index / rows
		var row := page_index % rows

		if column < 0 or column >= columns:
			return AssetBytesResult.failure("selected print page is outside the page grid")

		var left := floori(float(image.get_width()) * float(column) / float(columns))
		var right := floori(float(image.get_width()) * float(column + 1) / float(columns))
		var top := floori(float(image.get_height()) * float(row) / float(rows))
		var bottom := floori(float(image.get_height()) * float(row + 1) / float(rows))
		var page_image := image.get_region(
			Rect2i(left, top, maxi(1, right - left), maxi(1, bottom - top))
		)
		page_image.convert(Image.FORMAT_RGB8)
		var jpeg := page_image.save_jpg_to_buffer(0.96)

		if jpeg.is_empty():
			return AssetBytesResult.failure("cannot encode a printable city page")

		var page_id := int(page_ids[output_index])
		var image_id := page_id + 1
		var content_id := page_id + 2
		var maximum_width := PDF_PAGE_WIDTH - PDF_MARGIN * 2.0
		var maximum_height := PDF_PAGE_HEIGHT - PDF_MARGIN * 2.0
		var scale := minf(
			maximum_width / float(page_image.get_width()),
			maximum_height / float(page_image.get_height())
		)
		var drawing_width := float(page_image.get_width()) * scale
		var drawing_height := float(page_image.get_height()) * scale
		var drawing_x := (PDF_PAGE_WIDTH - drawing_width) * 0.5
		var drawing_y := (PDF_PAGE_HEIGHT - drawing_height) * 0.5
		var image_name := "Im%d" % output_index
		var content := (
			"q\n%.3f 0 0 %.3f %.3f %.3f cm\n/%s Do\nQ\n"
			% [drawing_width, drawing_height, drawing_x, drawing_y, image_name]
		).to_ascii_buffer()
		bodies[page_id] = (
			"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
			+ "/Resources << /XObject << /%s %d 0 R >> >> " % [image_name, image_id]
			+ "/Contents %d 0 R >>\n" % content_id
		).to_ascii_buffer()
		var image_body := (
			"<< /Type /XObject /Subtype /Image /Width %d /Height %d "
			+ "/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode "
			+ "/Length %d >>\nstream\n"
		) % [page_image.get_width(), page_image.get_height(), jpeg.size()]
		bodies[image_id] = image_body.to_ascii_buffer()
		bodies[image_id].append_array(jpeg)
		bodies[image_id].append_array("\nendstream\n".to_ascii_buffer())
		bodies[content_id] = (
			"<< /Length %d >>\nstream\n" % content.size()
		).to_ascii_buffer()
		bodies[content_id].append_array(content)
		bodies[content_id].append_array("endstream\n".to_ascii_buffer())

	var output := "%PDF-1.4\n% OpenSC2K printable city\n".to_ascii_buffer()
	var offsets := PackedInt32Array()
	offsets.resize(object_count + 1)

	for object_id in range(1, object_count + 1):
		offsets[object_id] = output.size()
		output.append_array(("%d 0 obj\n" % object_id).to_ascii_buffer())
		output.append_array(bodies[object_id])
		output.append_array("endobj\n".to_ascii_buffer())

	var xref_offset := output.size()
	output.append_array(("xref\n0 %d\n" % (object_count + 1)).to_ascii_buffer())
	output.append_array("0000000000 65535 f \n".to_ascii_buffer())

	for object_id in range(1, object_count + 1):
		output.append_array(("%010d 00000 n \n" % offsets[object_id]).to_ascii_buffer())

	output.append_array((
		"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n"
		% [object_count + 1, xref_offset]
	).to_ascii_buffer())

	var outcome := AssetBytesResult.new()
	outcome.ok = true
	outcome.error = ""
	outcome.bytes = output

	return outcome


static func _monochrome_copy(source: Image) -> Image:
	var result: Image = source.duplicate()

	if result.get_format() != Image.FORMAT_RGBA8:
		result.convert(Image.FORMAT_RGBA8)

	var data := result.get_data()

	for offset in range(0, data.size(), 4):
		var luminance := clampi(roundi(
			float(data[offset]) * 0.299
			+ float(data[offset + 1]) * 0.587
			+ float(data[offset + 2]) * 0.114
		), 0, 255)
		data[offset] = luminance
		data[offset + 1] = luminance
		data[offset + 2] = luminance

	return Image.create_from_data(
		result.get_width(), result.get_height(), false, Image.FORMAT_RGBA8, data
	)


static func _draw_signs(
	image: Image,
	city: CityState,
	render_palette: Sc2Palette,
	view_size: int
) -> void:
	var map_edge: int = city.map_size if city != null else 128

	if image == null or image.is_empty():
		return

	var configuration := Renderer.view_configuration(view_size)

	if configuration == null:
		return

	var divisor := float(configuration.divisor)
	var glyph_scale := 2

	for diagonal in map_edge * 2 - 1:
		for y in diagonal + 1:
			var x := diagonal - y

			if x >= map_edge or y >= map_edge:
				continue

			var label_id := city.text_overlay_id(x, y)

			if not OverlayData.is_sign(label_id):
				continue

			var text := city.label(label_id).strip_edges().to_upper()

			if text.is_empty():
				continue

			text = text.left(30)
			var polygon := Renderer.tile_polygon(city, x, y)

			if polygon.size() != 4:
				continue

			var anchor := polygon[0] / divisor + Vector2(0.0, -8.0 / divisor)
			var text_width := text.length() * 6 * glyph_scale - glyph_scale
			var panel_bottom := anchor.y - float(15 * view_size + 20)
			var panel := Rect2i(
				floori(anchor.x - float(text_width) * 0.5 - 8.0),
				floori(panel_bottom - float(7 * glyph_scale + 6)),
				text_width + 16,
				7 * glyph_scale + 6
			)
			_draw_sign_panel(image, panel, render_palette)
			var post := Rect2i(
				floori(anchor.x - 2.0),
				panel.end.y,
				4,
				maxi(1, floori(anchor.y) - panel.end.y)
			)
			_fill_clipped(image, post, render_palette.color(SIGN_POST_INDEX))
			_draw_text_5x7(
				image,
				text,
				panel.position + Vector2i(8, 3),
				glyph_scale,
				render_palette.color(SIGN_TEXT_INDEX)
			)


static func _draw_sign_panel(
	image: Image, panel: Rect2i, render_palette: Sc2Palette
) -> void:
	_fill_clipped(image, panel, render_palette.color(SIGN_PANEL_INDEX))
	_fill_clipped(
		image,
		Rect2i(panel.position, Vector2i(panel.size.x, 2)),
		render_palette.color(SIGN_LIGHT_INDEX)
	)
	_fill_clipped(
		image,
		Rect2i(panel.position, Vector2i(2, panel.size.y)),
		render_palette.color(SIGN_LIGHT_INDEX)
	)
	_fill_clipped(
		image,
		Rect2i(panel.position.x, panel.end.y - 2, panel.size.x, 2),
		render_palette.color(SIGN_DARK_INDEX)
	)
	_fill_clipped(
		image,
		Rect2i(panel.end.x - 2, panel.position.y, 2, panel.size.y),
		render_palette.color(SIGN_DARK_INDEX)
	)


static func _draw_text_5x7(
	image: Image, text: String, origin: Vector2i, scale: int, color: Color
) -> void:
	for character_index in text.length():
		var character := String.chr(text.unicode_at(character_index))
		var rows: Array = FONT_5X7.get(character, FONT_5X7["?"])
		var character_x := origin.x + character_index * 6 * scale

		for row in 7:
			var bits := int(rows[row])

			for column in 5:
				if bits & (1 << (4 - column)) == 0:
					continue

				_fill_clipped(
					image,
					Rect2i(
						character_x + column * scale,
						origin.y + row * scale,
						scale,
						scale
					),
					color
				)


static func _fill_clipped(image: Image, rectangle: Rect2i, color: Color) -> void:
	var clipped := rectangle.intersection(Rect2i(Vector2i.ZERO, image.get_size()))

	if clipped.get_area() > 0:
		image.fill_rect(clipped, color)


static func _draw_artwork_stamps(output: Image, city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive, view_size: int) -> void:
	var configuration := Renderer.view_configuration(view_size)

	for stamp in city.scurk_artwork_stamps:
		var entry = sprites.find_sprite(int(configuration.sprite_base) + int(stamp.tile_id))

		if entry == null:
			continue

		var rendered := entry.create_image(palette)

		if not rendered.ok:
			continue

		var image: Image = rendered.image
		var anchor := Renderer.tile_polygon(city, stamp.point.x, stamp.point.y)[2] / float(configuration.divisor)
		var origin := Vector2i(anchor) - Vector2i(image.get_width() / 2, image.get_height() - 1)

		for y in image.get_height():
			for x in image.get_width():
				var pixel := image.get_pixel(x, y)
				var target := origin + Vector2i(x, y)

				if pixel.a <= 0.0 or target.x < 0 or target.y < 0 or target.x >= output.get_width() or target.y >= output.get_height():
					continue

				if palette.is_index_encoding:
					pixel = Color(pixel.r, pixel.r, pixel.r, 1.0)

				output.set_pixelv(target, pixel)
