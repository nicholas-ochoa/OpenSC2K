class_name NewspaperPicture
extends RefCounted


const STORY_PICTURES := [
	0, 0, 404, 404, 405, 402, 406, 0, 0, 0,
	0, 404, 406, 408, 0, 0, 410, 401, 411, 0,
	0, 0, 408, 0, 408, 409, 400, 406, 408, 408,
	408, 411, 411, 409, 403, 411, 410, 404, 402, 403,
	407, 0, 0, 0, 0, 411, 403, 410, 408, 403,
	403, 403, 411, 411, 403, 403, 403, 403, 411, 410,
	401, 411, 404, 407, 407, 0, 0, 0,
]


static func select(story_type: int, session_seed: int, city_days: int, paper_index: int) -> int:
	# dormant story types beyond the supplied table must not read adjacent data
	if story_type < 0 or story_type >= STORY_PICTURES.size() or paper_index < 0 or paper_index >= 6:
		return 0

	var resource: int = STORY_PICTURES[story_type]

	if resource != 0:
		return resource

	var random := SimRandom.new(session_seed + int(city_days / 25) + paper_index * 500 + 21)

	return 400 + random.next_u15() % 12


static func filler_lines(rect: Rect2i, seed: int) -> Array[Rect2i]:
	# 0x0047aca0 supplies the geometry. the review uses its own stable seed;
	# the original whole-page painter's random side effects remain separate
	var lines: Array[Rect2i] = []

	if rect.size.x < 18 or rect.size.y < 5:
		return lines

	var random := SimRandom.new(seed)
	var row := 0
	var row_count := int(rect.size.y / 5)

	while row < row_count:
		lines.append(Rect2i(rect.position + Vector2i(13, row * 5 + 2), Vector2i(rect.size.x - 16, 3)))
		var full_rows := random.next_u15() % 6

		while full_rows > 0:
			full_rows -= 1
			row += 1

			if row >= row_count:
				break

			lines.append(Rect2i(rect.position + Vector2i(3, row * 5 + 2), Vector2i(rect.size.x - 6, 3)))

		var short_row := row + 1

		if short_row < row_count:
			var cut := random.next_u15() % int(rect.size.x * 2 / 3)
			lines.append(Rect2i(rect.position + Vector2i(3, short_row * 5 + 2), Vector2i(rect.size.x - 6 - cut, 3)))

		row += 2

	return lines
