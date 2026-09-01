class_name CheckControlGraphics
extends RefCounted


const RESOURCE_ID := "CTL3D_3DCHECK"
const CELL_SIZE := Vector2i(14, 13)
const SHEET_SIZE := Vector2i(70, 39)
const ICONS: Dictionary[String, Vector2i] = {
	"unchecked": Vector2i(0, 0), "checked": Vector2i(1, 0),
	"unchecked_disabled": Vector2i(2, 0), "checked_disabled": Vector2i(4, 0),
	"radio_unchecked": Vector2i(0, 1), "radio_checked": Vector2i(1, 1),
	"radio_unchecked_disabled": Vector2i(2, 1), "radio_checked_disabled": Vector2i(4, 1),
}
const CELL_NAMES := [
	"Check: empty", "Check: marked", "Check: empty / gray", "Check: marked / gray", "Check: disabled mark",
	"Radio: empty", "Radio: selected", "Radio: empty / gray", "Radio: selected / gray", "Radio: disabled mark",
	"Unassigned design A", "Mixed", "Unassigned design B", "Mixed / gray", "Mixed / disabled",
]


static func region(cell: Vector2i) -> Rect2i:
	assert(cell.x >= 0 and cell.x < 5 and cell.y >= 0 and cell.y < 3)

	return Rect2i(cell * CELL_SIZE, CELL_SIZE)


static func cell_image(sheet: Image, cell: Vector2i, map_system_colors := false, clear_margin := false) -> Image:
	if sheet == null or sheet.get_size() != SHEET_SIZE:
		return null

	var result := sheet.get_region(region(cell))
	result.convert(Image.FORMAT_RGBA8)

	if map_system_colors:
		for y in result.get_height():
			for x in result.get_width():
				var color := result.get_pixel(x, y)

				if color == Color.YELLOW:
					result.set_pixel(x, y, Color.WHITE)
				elif color == Color.GREEN:
					result.set_pixel(x, y, Color.BLACK)

	if clear_margin:
		_clear_outer_face(result)

	return result


static func apply_theme(theme: Theme, graphics: CityUiGraphics) -> void:
	for icon in ICONS:
		if graphics == null or graphics.check_sheet == null:
			if theme.has_icon(icon, "CheckBox"):
				theme.clear_icon(icon, "CheckBox")

			continue

		var image := cell_image(graphics.check_sheet, ICONS[icon], graphics.check_system_colors, true)
		theme.set_icon(icon, "CheckBox", ImageTexture.create_from_image(image))


static func _clear_outer_face(image: Image) -> void:
	# Clear gray pixels connected to the panel edge. Gray inside the control belongs to the art.
	var pending: Array[Vector2i] = []

	for x in CELL_SIZE.x:
		pending.append(Vector2i(x, 0))
		pending.append(Vector2i(x, CELL_SIZE.y - 1))

	for y in CELL_SIZE.y:
		pending.append(Vector2i(0, y))
		pending.append(Vector2i(CELL_SIZE.x - 1, y))

	while not pending.is_empty():
		var point: Vector2i = pending.pop_back()

		if point.x < 0 or point.y < 0 or point.x >= CELL_SIZE.x or point.y >= CELL_SIZE.y:
			continue

		if image.get_pixelv(point) != Color8(192, 192, 192):
			continue

		image.set_pixelv(point, Color.TRANSPARENT)

		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			pending.append(point + step)
