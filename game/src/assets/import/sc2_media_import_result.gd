class_name Sc2MediaImportResult
extends RefCounted
## Each category can succeed independently. No path denotes a failed category.

var ok := false
var partial := false
var platform := ""
var root := ""
var graphics := ""
var sound := ""
var music := ""
var data := ""
var error := ""
var warnings := PackedStringArray()
var counts: Dictionary[String, int] = {}
var failures: Dictionary[String, String] = {}


func summary() -> String:
	var lines := PackedStringArray()

	for kind in Sc2MediaImporter.CATEGORIES:
		if counts.has(kind):
			lines.append("%s: imported %d assets." % [kind.capitalize(), counts[kind]])
		if failures.has(kind):
			lines.append("%s: %s" % [kind.capitalize(), failures[kind]])

	lines.append_array(warnings)

	if not error.is_empty():
		lines.append(error)

	return "\n".join(lines)
