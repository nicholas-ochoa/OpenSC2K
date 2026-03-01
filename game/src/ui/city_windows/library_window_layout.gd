class_name LibraryWindowLayout
extends RefCounted

const WINDOW_SIZE := Vector2i(480, 300)
const CASCADE_STEP := Vector2i(28, 28)
const VIEWPORT_MARGIN := 16


static func rects(viewport_size: Vector2i, count := 4) -> Array[Rect2i]:
	var result: Array[Rect2i] = []

	if count <= 0 or viewport_size.x <= 0 or viewport_size.y <= 0:
		return result

	var cascade_size := CASCADE_STEP * (count - 1)
	var available_size := Vector2i(
		maxi(1, viewport_size.x - VIEWPORT_MARGIN * 2 - cascade_size.x),
		maxi(1, viewport_size.y - VIEWPORT_MARGIN * 2 - cascade_size.y),
	)
	var window_size := Vector2i(
		mini(WINDOW_SIZE.x, available_size.x),
		mini(WINDOW_SIZE.y, available_size.y),
	)
	var group_size := window_size + cascade_size
	var start := Vector2i(
		maxi(VIEWPORT_MARGIN, (viewport_size.x - group_size.x) / 2),
		maxi(VIEWPORT_MARGIN, (viewport_size.y - group_size.y) / 2),
	)

	for index in count:
		result.append(Rect2i(start + CASCADE_STEP * index, window_size))

	return result
