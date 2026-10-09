class_name ScriptingApiBase
extends RefCounted
## The shared parts of the script host functions: the application, the
## failure of the running call, and the conversion of script arguments.
## A function that fails returns `fail(message)`; the script then gets an
## Error with the message.

var app: CityApplication
# { failure: String }. The API objects share it; ApplicationScripting reads
# and clears it around each call
var call_state: Dictionary


func _init(application: CityApplication, shared_state: Dictionary) -> void:
	app = application
	call_state = shared_state


func fail(message: String) -> Variant:
	call_state.failure = message

	return null


## True with a loaded city. Without one, the call fails.
func need_city() -> bool:
	if app.document_state.city == null or app.simulation_state.simulation_engine == null:
		fail("No city is loaded.")

		return false

	return true


## A tile point from a script argument { x, y }, or (-1, -1).
static func point(arguments: Array, index: int) -> Vector2i:
	if index >= arguments.size() or not arguments[index] is Dictionary:
		return Vector2i(-1, -1)

	var value: Dictionary = arguments[index]

	return Vector2i(integer(value.get("x"), -1), integer(value.get("y"), -1))


static func integer(value: Variant, fallback: int) -> int:
	return int(value) if is_number(value) else fallback


static func is_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT]


## The argument at the index, or the fallback when the script left it out.
static func argument(arguments: Array, index: int, fallback: Variant = null) -> Variant:
	return arguments[index] if index < arguments.size() and arguments[index] != null else fallback


func inside_map(point_value: Vector2i) -> bool:
	var city := app.document_state.city

	return city != null and point_value.x >= 0 and point_value.y >= 0 and point_value.x < city.map_size and point_value.y < city.map_size
