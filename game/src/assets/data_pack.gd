class_name DataPack
extends RefCounted
## Original game data files: text, newspaper data, the city template, cities,
## scenarios, and SCURK tile sets. The files keep their original relative paths.
## A data pack never contains an executable.

const FORMAT := "opensc2k-data"
const REQUIRED_FILES := [
	"DATA/TEXT_USA.DAT", "DATA/TEXT_USA.IDX", "DATA/DATA_USA.DAT", "DATA/DATA_USA.IDX", "DEFAULT.SC2",
]
const FOLDERS := [["CITIES", "sc2"], ["SCENARIO", "scn"], ["SCURKART", "mif"]]

var error := ""
var pack_name := ""
var root := ""
var import_revision := ImportedPackRevision.NOT_IMPORTED
var text := OriginalGameAssets.new()


static func default_folder() -> String:
	return MediaPack.default_folder("data")


static func load_folder(folder: String) -> DataPack:
	var pack := DataPack.new()
	var automatic := folder.strip_edges().is_empty()
	var pack_root := default_folder() if automatic else folder.strip_edges()

	if pack_root.get_file() == "pack.json":
		pack_root = pack_root.get_base_dir()

	var path := pack_root.path_join("pack.json")

	if automatic and not FileAccess.file_exists(path):
		return pack

	var json := JSON.new()

	if not FileAccess.file_exists(path) or json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		pack.error = "Cannot read data pack.json: %s" % pack_root

		return pack

	var manifest: Dictionary = json.data

	if manifest.get("format") != FORMAT or manifest.get("version") != 1 or not manifest.get("name") is String or str(manifest.name).strip_edges().is_empty():
		pack.error = "Invalid data manifest format, version, or name"

		return pack

	pack.import_revision = ImportedPackRevision.read(manifest)

	if pack.import_revision == ImportedPackRevision.INVALID:
		pack.error = "import_revision must be a whole number that is not negative"

		return pack

	for relative in REQUIRED_FILES:
		if not FileAccess.file_exists(pack_root.path_join(relative)):
			pack.error = "The data pack is incomplete. Import it again."

			return pack

	pack.text.load_text_data(pack_root)

	if (
		pack.text.newspaper_data == null or not pack.text.newspaper_data.is_valid()
		or pack.text.library_texts.is_empty() or pack.text.original_credits.is_empty()
	):
		pack.error = "The data pack is incomplete. Import it again."

		return pack

	pack.pack_name = manifest.name
	pack.root = pack_root

	return pack


func is_loaded() -> bool:
	return error.is_empty() and not root.is_empty()


func is_outdated() -> bool:
	return ImportedPackRevision.is_outdated("data", import_revision)


# copy the text data into assets that other windows read
func apply_to(assets: OriginalGameAssets) -> void:
	var library_texts: Dictionary[int, String] = {}

	if is_loaded():
		library_texts = text.library_texts

	assets.newspaper_data = text.newspaper_data if is_loaded() else null
	assets.library_texts = library_texts
	assets.original_credits = text.original_credits if is_loaded() else ""
