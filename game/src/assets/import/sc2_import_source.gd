class_name Sc2ImportSource
extends RefCounted
## Discover assets by file contents and record names, not a release hash list.

var platform := "Unknown platform"
var resources: Array[Sc2ImportResource] = []
var warnings := PackedStringArray()
# information that does not make the import partial
var notes := PackedStringArray()
var error := ""
var root := ""


# The native formats library scans the files; see
# native/core/assets/src/import/source.rs
static func scan(path: String) -> Sc2ImportSource:
	var scanned := NativeImportSource.scan(ProjectSettings.globalize_path(path).simplify_path())
	var source := Sc2ImportSource.new()
	source.platform = scanned.platform
	source.warnings = scanned.warnings
	source.notes = scanned.notes
	source.error = scanned.error
	source.root = scanned.root
	var names: PackedStringArray = scanned.names
	var kinds: PackedStringArray = scanned.kinds
	var ids: PackedInt64Array = scanned.ids
	var sources: PackedStringArray = scanned.sources
	var payloads: Array = scanned.payloads

	for index in names.size():
		source.resources.append(Sc2ImportResource.make(names[index], payloads[index], sources[index], kinds[index], ids[index]))

	return source
