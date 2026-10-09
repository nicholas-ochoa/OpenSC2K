class_name ImportedPackRevision
extends RefCounted
## Importers record the revision of the content that they write in each pack.
## Raise the revision of a pack kind in native/core/assets/src/packs/revision.rs
## when an importer adds or changes its content.
## Packs with an older revision are out of date and need a new import.

# packs that importers wrote before they recorded a revision
const UNRECORDED := 1
# a pack that a person made, not an importer
const NOT_IMPORTED := -1
const INVALID := -2


# The native simulation library holds the rules; see
# native/core/assets/src/packs/revision.rs
static func read(manifest: Dictionary) -> int:
	return NativePacks.read_revision(manifest)


static func current(kind: String, platform := "") -> int:
	return NativePacks.current_revision(kind, platform)


static func is_outdated(kind: String, revision: int, platform := "") -> bool:
	return NativePacks.is_outdated(kind, revision, platform)


static func stamp(kind: String, manifest: Dictionary) -> void:
	manifest.import_revision = current(kind, str(manifest.get("source_platform", "")))
