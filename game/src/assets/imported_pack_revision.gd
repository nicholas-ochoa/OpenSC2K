class_name ImportedPackRevision
extends RefCounted
## Importers record the revision of the content that they write in each pack.
## Raise the revision of a pack kind when an importer adds or changes its content.
## Packs with an older revision are out of date and need a new import.

const CURRENT: Dictionary[String, int] = { "graphics": 1, "sound": 1, "music": 1, "data": 1 }
# a source platform whose content changed alone. DOS and Macintosh graphics use the Windows palette layout from 2
const CURRENT_BY_PLATFORM: Dictionary[String, Dictionary] = { "graphics": { "DOS": 2, "Macintosh": 2 } }
# packs that importers wrote before they recorded a revision
const UNRECORDED := 1
# a pack that a person made, not an importer
const NOT_IMPORTED := -1
const INVALID := -2
const LEGACY_IMPORTED_NAME := "Original SimCity 2000"


static func read(manifest: Dictionary) -> int:
	if manifest.has("import_revision"):
		var value: Variant = manifest.import_revision

		if (value is int or (value is float and value == floorf(value))) and value >= 0:
			return int(value)

		return INVALID

	if (
		manifest.has("source_platform") or manifest.has("runtime_data")
		or str(manifest.get("name", "")).begins_with(LEGACY_IMPORTED_NAME)
	):
		return UNRECORDED

	return NOT_IMPORTED


static func current(kind: String, platform := "") -> int:
	return int(CURRENT_BY_PLATFORM.get(kind, {}).get(platform, CURRENT[kind]))


static func is_outdated(kind: String, revision: int, platform := "") -> bool:
	return revision >= 0 and revision < current(kind, platform)


static func stamp(kind: String, manifest: Dictionary) -> void:
	manifest.import_revision = current(kind, str(manifest.get("source_platform", "")))
