class_name CityCameraMotion
extends RefCounted

const SPEED := 650.0
const ACCELERATION := 5200.0
const BRAKING := 6500.0

var velocity := Vector2.ZERO
# the camera action of each held key. mouse buttons use negative ids, so a
# release clears only its own key or button
var held_keys: Dictionary[int, String] = {}


func press(key: int, action: String) -> void:
	if ControlActions.CAMERA_DIRECTIONS.has(action):
		held_keys[key] = action


func release(key: int) -> void:
	held_keys.erase(key)


func held_direction() -> Vector2:
	var direction := Vector2.ZERO

	for key in held_keys:
		direction += ControlActions.CAMERA_DIRECTIONS[held_keys[key]]

	return direction.limit_length()


func step(direction: Vector2, delta: float, enabled := true, speed_scale := 1.0) -> Vector2:
	if not enabled:
		velocity = Vector2.ZERO
		held_keys.clear()

		return Vector2.ZERO

	var duration := clampf(delta, 0.0, 0.05)
	var target := direction.limit_length() * SPEED * speed_scale
	velocity = velocity.move_toward(target, (BRAKING if direction.is_zero_approx() else ACCELERATION) * speed_scale * duration)

	return velocity * duration
