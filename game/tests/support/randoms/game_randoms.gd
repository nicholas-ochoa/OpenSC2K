extends RefCounted


class SequenceGameModuloRandom:
	extends GameLcgRandom

	var values := PackedInt32Array()
	var position := 0


	func _init(initial_values: Array[int]) -> void:
		values = PackedInt32Array(initial_values)


	func next_mod(divisor: int) -> int:
		var value := int(values[position]) if position < values.size() else 0
		position += 1

		return value % divisor


class ZeroGameRandom:
	extends GameLcgRandom


	func next_mod(_divisor: int) -> int:
		return 0


class NonzeroGameRandom:
	extends GameLcgRandom


	func next_mod(divisor: int) -> int:
		return 1 % divisor


class SequenceGameRandom:
	extends GameLcgRandom

	var values := PackedInt32Array()
	var position := 0


	func _init(initial_values: Array[int]) -> void:
		values = PackedInt32Array(initial_values)


	func next_mod(divisor: int) -> int:
		return _next() % divisor


	func _next() -> int:
		if position >= values.size():
			return 1

		var value := int(values[position])
		position += 1

		return value
