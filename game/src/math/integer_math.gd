class_name IntegerMath
extends RefCounted



# divide integers and discard the remainder. negative results truncate toward
# zero, not toward negative infinity. the denominator must be nonzero
static func div_trunc(numerator: int, denominator: int) -> int:
	@warning_ignore("integer_division")
	return numerator / denominator


# apply the same truncation to each integer vector component
static func div_trunc_vec2i(numerator: Vector2i, denominator: int) -> Vector2i:
	@warning_ignore("integer_division")
	return numerator / denominator
