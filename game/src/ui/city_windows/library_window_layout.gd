class_name LibraryWindowLayout
extends RefCounted

@warning_ignore_start("integer_division")

const WINDOW_WIDTH := 480
const VIEWPORT_MARGIN := 16


static func window_width(viewport_size: Vector2i) -> int:
	return mini(WINDOW_WIDTH, maxi(1, viewport_size.x - VIEWPORT_MARGIN * 2))


static func max_window_height(viewport_size: Vector2i) -> int:
	return maxi(1, viewport_size.y - VIEWPORT_MARGIN * 2)


# the original centers each text window over the game window
static func rect(viewport_size: Vector2i, window_size: Vector2i) -> Rect2i:
	var size := Vector2i(
		clampi(window_size.x, 1, window_width(viewport_size)),
		clampi(window_size.y, 1, max_window_height(viewport_size)),
	)
	var position := Vector2i(
		maxi(0, (viewport_size.x - size.x) / 2),
		maxi(0, (viewport_size.y - size.y) / 2),
	)

	return Rect2i(position, size)
