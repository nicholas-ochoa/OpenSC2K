class_name ScurkDrawingWorkspace
extends RefCounted

@warning_ignore_start("integer_division")

const WIDTH := 128
const HEIGHT := 256
const VIEW_DIVISORS := [1, 2, 4]
const STANDARD_BASE_WIDTHS := [32, 64, 96, 128]


static func view_divisor(view: int) -> int:
	return VIEW_DIVISORS[view] if view >= 0 and view < VIEW_DIVISORS.size() else 1


static func is_standard_base_width(width: int) -> bool:
	return width in STANDARD_BASE_WIDTHS


static func base_size(base_width: int) -> int:
	return int(base_width / 32) if is_standard_base_width(base_width) else -1


static func clip_mask(base_width: int, view := ScurkSpriteIds.View.LARGE) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(WIDTH * HEIGHT)

	if not is_standard_base_width(base_width):
		mask.fill(1)

		return mask

	mask.fill(1)
	var divisor := view_divisor(view)
	var outside_limit := (WIDTH - base_width) / 2

	for row_from_bottom in HEIGHT:
		var y := HEIGHT - 1 - row_from_bottom
		var native_row := row_from_bottom / divisor
		var outside_half_width := maxi(outside_limit, WIDTH / 2 - (native_row * 2 + 1) * divisor)

		for x in outside_half_width:
			mask[y * WIDTH + x] = 0
			mask[y * WIDTH + WIDTH - 1 - x] = 0

	return mask


static func apply_clip_mask(
	workspace_pixels: PackedInt32Array, base_width: int, view := ScurkSpriteIds.View.LARGE
) -> PackedInt32Array:
	var result := workspace_pixels.duplicate()

	if result.size() != WIDTH * HEIGHT:
		return result

	var mask := clip_mask(base_width, view)

	for index in result.size():
		if mask[index] == 0:
			result[index] = -1

	return result


static func from_shape(
	shape_width: int,
	shape_height: int,
	shape_pixels: PackedInt32Array,
	view: int,
	base_width: int,
	clipping_enabled := true
) -> PackedInt32Array:
	var workspace := PackedInt32Array()
	workspace.resize(WIDTH * HEIGHT)
	workspace.fill(-1)

	if (
		shape_width <= 0
		or shape_height <= 0
		or shape_pixels.size() != shape_width * shape_height
	):
		return workspace

	var divisor := view_divisor(view)
	var expanded_width := shape_width * divisor
	var expanded_height := shape_height * divisor
	var origin := Vector2i(
		int((WIDTH - expanded_width) / 2),
		HEIGHT - expanded_height
	)

	for source_y in shape_height:
		for source_x in shape_width:
			var value := shape_pixels[source_y * shape_width + source_x]

			for offset_y in divisor:
				var target_y := origin.y + source_y * divisor + offset_y

				if target_y < 0 or target_y >= HEIGHT:
					continue

				for offset_x in divisor:
					var target_x := origin.x + source_x * divisor + offset_x

					if target_x < 0 or target_x >= WIDTH:
						continue

					workspace[target_y * WIDTH + target_x] = value

	return apply_clip_mask(workspace, base_width, view) if clipping_enabled else workspace


static func shape_from_workspace(
	workspace_pixels: PackedInt32Array, base_width: int, view: int, clipping_enabled := true
) -> IndexedImageResult:
	if (
		workspace_pixels.size() != WIDTH * HEIGHT
		or not is_standard_base_width(base_width)
	):
		return IndexedImageResult.failure("SCURK drawing workspace or base width is invalid.")

	var divisor := view_divisor(view)
	var output_base_width := base_width if clipping_enabled else WIDTH
	var output_width := int(output_base_width / divisor)
	var output_max_height := int(HEIGHT / divisor)
	var source_left := int((WIDTH - output_base_width) / 2)
	var clipped := apply_clip_mask(workspace_pixels, base_width, view) if clipping_enabled else workspace_pixels
	var sampled := PackedInt32Array()
	sampled.resize(output_width * output_max_height)
	sampled.fill(-1)

	for y in output_max_height:
		var source_y := divisor - 1 + y * divisor

		for x in output_width:
			var source_x := source_left + x * divisor
			sampled[y * output_width + x] = clipped[source_y * WIDTH + source_x]

	var first_visible_row := output_max_height

	for y in output_max_height:
		for x in output_width:
			if sampled[y * output_width + x] >= 0:
				first_visible_row = y
				break

		if first_visible_row != output_max_height:
			break

	if first_visible_row == output_max_height:
		var blank := PackedInt32Array()
		blank.resize(output_width)
		blank.fill(-1)

		var result := IndexedImageResult.new()
		result.ok = true
		result.width = output_width
		result.height = 1
		result.pixels = blank
		result.error = ""

		return result

	var output_height := output_max_height - first_visible_row
	var output := PackedInt32Array()
	output.resize(output_width * output_height)

	for y in output_height:
		for x in output_width:
			output[y * output_width + x] = sampled[
				(first_visible_row + y) * output_width + x
			]

	var result := IndexedImageResult.new()
	result.ok = true
	result.width = output_width
	result.height = output_height
	result.pixels = output
	result.error = ""

	return result
