class_name Sc2ImportGraphics
extends RefCounted
## Build indexed graphics packs from available source records, without playback.
## The native assets library reads the records and writes the pack; see
## native/core/assets/src/import/graphics/mod.rs.

var error := ""
var warnings := PackedStringArray()
var count := 0


static func export_pack(source: Sc2ImportSource, folder: String, label: String) -> Sc2ImportGraphics:
	var importer := Sc2ImportGraphics.new()
	var exported := NativeGraphicsImport.export(source.resources, source.platform, label, folder)
	importer.error = exported.error
	importer.warnings = exported.warnings
	importer.count = exported.count

	if importer.error.is_empty():
		importer.error = GraphicsPack.load_root(folder).error

	if not importer.error.is_empty():
		OriginalGameInstaller.remove_tree(folder)

	return importer
