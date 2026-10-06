class_name CityEnvironmentParameters
extends RefCounted
## One change list per frame, shared by all materials in a display layer.
## Materials keep only a revision marker; this cache never retains materials.

const STATE := &"_city_environment_parameters"

var _values: Dictionary = {}
var _versions: Dictionary = {}
var _changed: Dictionary = {}
var _revision := 0


func update(parameters: Dictionary) -> void:
	var changed := {}
	for key in parameters:
		if not _values.has(key) or _values[key] != parameters[key]:
			changed[key] = parameters[key]
	for key in _values:
		if not parameters.has(key):
			changed[key] = null
	if changed.is_empty():
		return
	_revision += 1
	_changed = changed
	_values = parameters.duplicate()
	for key in changed:
		_versions[key] = _revision


func apply(material: ShaderMaterial) -> int:
	if material == null:
		return 0
	var state: Array = material.get_meta(STATE, [])
	var previous := -1
	if state.size() == 3 and state[0] == get_instance_id() and state[2] == material.shader:
		previous = state[1]
	if previous == _revision:
		return 0
	var writes := 0
	if previous == _revision - 1:
		for key in _changed:
			material.set_shader_parameter(key, _changed[key])
			writes += 1
	else:
		# Newly created materials and layers hidden for several frames catch up.
		for key in _versions:
			if _versions[key] > previous:
				material.set_shader_parameter(key, _values.get(key))
				writes += 1
	material.set_meta(STATE, [get_instance_id(), _revision, material.shader])
	return writes
