class_name Sc2ImportContainer
extends RefCounted
## Bounded readers for original asset containers. Never execute source programs.

var resources: Array[Sc2ImportResource] = []
var error := ""


static func has_range(data: PackedByteArray, offset: int, length: int) -> bool:
	return offset >= 0 and length >= 0 and offset <= data.size() and length <= data.size() - offset


# The native formats library reads the containers; see
# native/core/assets/src/import/container.rs
static func named_archive(data: PackedByteArray, origin: String) -> Sc2ImportContainer:
	return _from_native(NativeAssetContainer.named_archive(data), origin)


static func macintosh(data: PackedByteArray, origin: String) -> Sc2ImportContainer:
	return _from_native(NativeAssetContainer.macintosh(data), origin)


static func windows(data: PackedByteArray, origin: String) -> Sc2ImportContainer:
	return _from_native(NativeAssetContainer.windows(data), origin)


static func _from_native(fields: Dictionary, origin: String) -> Sc2ImportContainer:
	var result := Sc2ImportContainer.new()
	result.error = fields.error
	var names: PackedStringArray = fields.names
	var kinds: PackedStringArray = fields.kinds
	var ids: PackedInt64Array = fields.ids
	var payloads: Array = fields.payloads

	for index in names.size():
		result.resources.append(Sc2ImportResource.make(names[index], payloads[index], origin, kinds[index], ids[index]))

	return result
