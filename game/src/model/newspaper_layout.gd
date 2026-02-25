class_name NewspaperLayout
extends RefCounted
# Newspaper layout tables from the executable. The reader displays HTML.

const PAGE_SIZE := Vector2i(640, 400)
const SECTION_COUNT := 11
const STORY_RECT_INDICES := [4, 7, 8, 9, 10]

# each row contains the 11 rect values initialized by executable function
# 0x00476ff0. the order is title, date, price, picture, main story,
# opinion, weather, and four secondary stories
const LAYOUT_RECTS := [
	[
		Rect2i(0, 6, 640, 30),
		Rect2i(5, 16, 213, 15),
		Rect2i(315, 16, 320, 15),
		Rect2i(243, 76, 213, 100),
		Rect2i(0, 36, 640, 40),
		Rect2i(0, 300, 213, 100),
		Rect2i(426, 300, 214, 100),
		Rect2i(0, 76, 213, 224),
		Rect2i(426, 76, 214, 224),
		Rect2i(213, 176, 107, 224),
		Rect2i(320, 176, 106, 224),
	],
	[
		Rect2i(0, 37, 640, 36),
		Rect2i(421, 53, 214, 15),
		Rect2i(5, 53, 213, 15),
		Rect2i(178, 186, 256, 100),
		Rect2i(0, 0, 640, 37),
		Rect2i(0, 300, 128, 100),
		Rect2i(0, 73, 128, 227),
		Rect2i(128, 73, 512, 113),
		Rect2i(128, 287, 256, 113),
		Rect2i(384, 186, 128, 214),
		Rect2i(512, 186, 128, 214),
	],
	[
		Rect2i(0, 0, 384, 30),
		Rect2i(0, 0, 635, 12),
		Rect2i(0, 12, 635, 12),
		Rect2i(128, 30, 128, 210),
		Rect2i(0, 30, 128, 370),
		Rect2i(256, 30, 128, 105),
		Rect2i(512, 24, 128, 315),
		Rect2i(384, 24, 128, 376),
		Rect2i(128, 240, 128, 160),
		Rect2i(256, 135, 128, 265),
		Rect2i(512, 339, 128, 61),
	],
]

# these are the executable's point sizes for the same 11 sections
const FONT_SIZES := [
	[24, 12, 12, 0, 32, 12, 12, 10, 10, 10, 10],
	[24, 12, 12, 0, 30, 12, 12, 10, 10, 10, 10],
	[24, 10, 10, 1, 10, 0, 0, 10, 10, 10, 10],
]

# 0 is left, 1 is center, and 2 is right in the original text helper
const ALIGNMENTS := [
	[1, 0, 2, 1, 1, 0, 0, 1, 1, 1, 1],
	[1, 2, 0, 1, 1, 1, 1, 0, 1, 1, 1],
	[1, 1, 2, 2, 0, 0, 0, 0, 0, 0, 0],
]


static func section_rect(layout: int, section: int) -> Rect2i:
	if layout < 0 or layout >= LAYOUT_RECTS.size():
		return Rect2i()

	if section < 0 or section >= SECTION_COUNT:
		return Rect2i()

	return LAYOUT_RECTS[layout][section]


static func story_rect(layout: int, slot: int) -> Rect2i:
	if slot < 0 or slot >= STORY_RECT_INDICES.size():
		return Rect2i()

	return section_rect(layout, STORY_RECT_INDICES[slot])

