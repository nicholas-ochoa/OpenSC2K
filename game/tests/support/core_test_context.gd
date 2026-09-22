extends RefCounted

## Share result counts and read-only fixture inputs across core suites.

const Sc2Document = preload("res://src/formats/sc2_file.gd")

var fixture_documents: Dictionary = {}
var fixture_root: String
var failures := 0
var checks := 0


func _init(reference_root: String) -> void:
	fixture_root = reference_root


func check(condition: bool, message: String) -> void:
	checks += 1

	if not condition:
		failures += 1
		printerr("FAIL: %s" % message)


func load_fixture(path: String) -> Sc2File:
	# Cache only read-only inputs. Every caller gets private state; saved outputs
	# still use the actual loader, so reload and round-trip checks are not bypassed.
	if not path.begins_with(fixture_root + "/"):
		return Sc2Document.load_path(path)
	if not fixture_documents.has(path):
		fixture_documents[path] = Sc2Document.load_path(path)
	return fixture_documents[path].duplicate_document()
