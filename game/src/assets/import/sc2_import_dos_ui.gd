class_name Sc2ImportDosUi
extends RefCounted
## The DOS toolbar. TOOL.RAW is a 72 by 312 indexed image, with its height before
## its width. Its button interiors go to the places of the Windows toolbar strip.
## MINE.PAL supplies its colors.

@warning_ignore_start("integer_division")

const TOOLBAR_SIZE := Vector2i(72, 312)
const HEADER_SIZE := 4
const PALETTE_SIZE := 768
const STRIP_SIZE := Vector2i(531, 23)
const BUTTON_BACKGROUND := 145
# The 15 tool group buttons: a 3 by 5 grid of 24 by 24 cells, with a 19 by 19 icon
# 3 pixels inside each cell
const GROUP_COLUMNS := 3
const GROUP_CELL := 24
const GROUP_ICON := Vector2i(19, 19)
const GROUP_ICON_OFFSET := 3
const GROUP_TARGETS := [
	Rect2i(0, 0, 23, 23), Rect2i(24, 0, 26, 23), Rect2i(50, 0, 20, 23),
	Rect2i(70, 0, 25, 23), Rect2i(95, 0, 21, 23), Rect2i(116, 0, 24, 23),
	Rect2i(140, 0, 23, 23), Rect2i(163, 0, 23, 23), Rect2i(186, 0, 23, 23),
	Rect2i(209, 0, 23, 23), Rect2i(232, 0, 23, 23), Rect2i(255, 0, 23, 23),
	Rect2i(278, 0, 23, 23), Rect2i(302, 0, 23, 23), Rect2i(325, 0, 23, 23),
]
# [source in TOOL.RAW, target in the strip]
const SPECIAL_REGIONS := [
	[Rect2i(8, 127, 25, 18), Rect2i(348, 0, 29, 23)], # Sign
	[Rect2i(38, 127, 25, 18), Rect2i(377, 0, 26, 23)], # Query
	[Rect2i(8, 154, 25, 17), Rect2i(405, 0, 27, 23)], # Rotate left
	[Rect2i(38, 154, 25, 17), Rect2i(433, 0, 27, 23)], # Rotate right
	[Rect2i(4, 176, 19, 19), Rect2i(462, 0, 23, 23)], # Zoom out
	[Rect2i(27, 176, 19, 19), Rect2i(486, 0, 23, 23)], # Zoom in
	[Rect2i(50, 176, 19, 19), Rect2i(510, 0, 21, 23)], # Center
]


# The toolbar strip of TOOL.RAW, with the colors of MINE.PAL.
static func toolbar(raw: PackedByteArray, palette_bytes: PackedByteArray) -> IndexedImageResult:
	if raw.size() != HEADER_SIZE + TOOLBAR_SIZE.x * TOOLBAR_SIZE.y:
		return IndexedImageResult.failure("DOS TOOL.RAW has an invalid pixel length.")

	if raw.decode_u16(0) != TOOLBAR_SIZE.y or raw.decode_u16(2) != TOOLBAR_SIZE.x:
		return IndexedImageResult.failure("DOS TOOL.RAW must contain a 72 by 312 toolbar.")

	if palette_bytes.size() != PALETTE_SIZE:
		return IndexedImageResult.failure("DOS toolbar needs the 256-color MINE.PAL.")

	var result := IndexedImageResult.new()
	result.ok = true
	result.width = STRIP_SIZE.x
	result.height = STRIP_SIZE.y
	result.top_down = true
	result.pixels.resize(result.width * result.height)
	result.pixels.fill(BUTTON_BACKGROUND)
	result.palette = Sc2Palette.new()
	result.palette.colors.assign(Sc2ImportGraphics.rgb_colors(palette_bytes))

	for group in GROUP_TARGETS.size():
		var cell := Vector2i(group % GROUP_COLUMNS, group / GROUP_COLUMNS) * GROUP_CELL
		_copy_icon(raw, Rect2i(cell + Vector2i.ONE * GROUP_ICON_OFFSET, GROUP_ICON), GROUP_TARGETS[group], result)

	for pair in SPECIAL_REGIONS:
		_copy_icon(raw, pair[0], pair[1], result)

	return result


# Copies `source` to the center of `target`.
static func _copy_icon(raw: PackedByteArray, source: Rect2i, target: Rect2i, result: IndexedImageResult) -> void:
	var position := target.position + (target.size - source.size) / 2

	for y in source.size.y:
		for x in source.size.x:
			var from := HEADER_SIZE + (source.position.y + y) * TOOLBAR_SIZE.x + source.position.x + x
			result.pixels[(position.y + y) * result.width + position.x + x] = raw[from]
