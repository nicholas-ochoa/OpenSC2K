class_name CityCameraMotion
extends RefCounted
const SPEED := 650.0
const ACCELERATION := 5200.0
const BRAKING := 6500.0
const DIRECTIONS := {KEY_W: Vector2.UP, KEY_A: Vector2.LEFT, KEY_S: Vector2.DOWN, KEY_D: Vector2.RIGHT}
var velocity := Vector2.ZERO
var held_keys: Dictionary = {}

func press(key: int) -> void:
	if DIRECTIONS.has(key):
		held_keys[key] = true

func release(key: int) -> void:
	held_keys.erase(key)

func held_direction() -> Vector2:
	var direction := Vector2.ZERO
	for key in held_keys:
		direction += DIRECTIONS[key]
	return direction.limit_length()


func step(direction: Vector2, delta: float, enabled := true) -> Vector2:
	if not enabled:
		velocity = Vector2.ZERO
		held_keys.clear()
		return Vector2.ZERO
	var duration := clampf(delta, 0.0, 0.05)
	var target := direction.limit_length() * SPEED
	velocity = velocity.move_toward(target, (BRAKING if direction.is_zero_approx() else ACCELERATION) * duration)
	return velocity * duration
