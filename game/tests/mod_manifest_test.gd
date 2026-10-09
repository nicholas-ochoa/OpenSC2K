extends SceneTree
## The info.json file of a mod and the mod catalog: the fields, each problem
## that stops a mod, the version check, duplicate ids, and the load order of
## dependencies and cycles.

const GAME_VERSION := "0.4.2"

var checks := 0
var failures := 0
var folder := ""


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	folder = OS.get_user_data_dir().path_join("mod_manifest_test")
	_remove(folder)
	DirAccess.make_dir_recursive_absolute(folder)
	_check_fields()
	_check_problems()
	_check_versions()
	_check_catalog()
	_remove(folder)
	print("Mod manifests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


# writes a mod folder with info.json (a Dictionary, or raw text) and main.js
func _mod(folder_name: String, info: Variant, main_file := "main.js") -> String:
	var path := folder.path_join(folder_name)
	DirAccess.make_dir_recursive_absolute(path)
	var text: String = info if info is String else JSON.stringify(info)
	FileAccess.open(path.path_join(ModManifest.FILE_NAME), FileAccess.WRITE).store_string(text)

	if not main_file.is_empty():
		FileAccess.open(path.path_join(main_file), FileAccess.WRITE).store_string("// main")

	return path


func _read(folder_name: String, info: Variant, main_file := "main.js") -> ModManifest:
	return ModManifest.read(_mod(folder_name, info, main_file), GAME_VERSION)


func _check_fields() -> void:
	var manifest := _read("Full-Mod", {
		"name": "Full Mod", "version": 2, "main": "main.js", "description": "Does all.", "license": "MIT",
		"author": {"name": "A. Mayor", "email": "mayor@example.com", "url": "https://example.com"},
		"gameVersion": "0.4", "dependencies": ["Other-Mod", "other-mod"], "unknownField": true,
	})
	check(manifest.error.is_empty(), "A full info.json is right: " + manifest.error)
	check(manifest.id == "full-mod", "The id is the lowercase folder name without an id field")
	check(manifest.version == "2", "A number version becomes text")
	check(manifest.author == "A. Mayor" and manifest.email == "mayor@example.com" and manifest.website == "https://example.com",
		"An author object gives the name, email and website")
	check(manifest.dependencies == PackedStringArray(["other-mod"]), "Dependency ids are lowercase and unique")
	var info := manifest.info()
	check(info.name == "Full Mod" and info.gameVersion == "0.4" and info.dependencies == ["other-mod"], str(info))

	var named := _read("folder", {"id": "city.tools_2", "name": "Tools", "version": "1.0", "main": "main.js",
		"author": "Someone", "email": "top@example.com", "website": "https://top.example.com"})
	check(named.error.is_empty() and named.id == "city.tools_2", "An id field sets the id: " + named.error)
	check(named.author == "Someone" and named.email == "top@example.com" and named.website == "https://top.example.com",
		"The top-level email and website stay")


func _check_problems() -> void:
	var valid := {"name": "A", "version": "1", "main": "main.js"}
	var cases := [
		["no-info", null, "has no info.json"],
		["bad-json", "{ name: ", "not valid JSON"],
		["not-object", "[1, 2]", "must hold a JSON object"],
		["no-name", {"version": "1", "main": "main.js"}, "needs a \"name\""],
		["no-version", {"name": "A", "main": "main.js"}, "needs a \"version\""],
		["no-main", {"name": "A", "version": "1"}, "needs a \"main\""],
		["up-main", valid.merged({"main": "../other/main.js"}, true), "must be a path in the mod folder"],
		["absolute-main", valid.merged({"main": "/etc/main.js"}, true), "must be a path in the mod folder"],
		["text-main", valid.merged({"main": "main.txt"}, true), "must be a .js or .mjs file"],
		["missing-main", valid.merged({"main": "gone.js"}, true), "is missing"],
		["bad-id", valid.merged({"id": "Has Space"}, true), "is not valid"],
		["reserved", valid.merged({"id": "console"}, true), "is not valid"],
		["dependency-list", valid.merged({"dependencies": "other"}, true), "must be a list"],
		["self-dependency", valid.merged({"id": "me", "dependencies": ["me"]}, true), "wrong mod id"],
		["new-game", valid.merged({"gameVersion": "0.10"}, true), "needs OpenSC2K 0.10 or newer"],
	]

	for item: Array in cases:
		var manifest: ModManifest

		if item[1] == null:
			DirAccess.make_dir_recursive_absolute(folder.path_join(item[0]))
			manifest = ModManifest.read(folder.path_join(item[0]), GAME_VERSION)
		else:
			manifest = _read(item[0], item[1])

		check(manifest.error.contains(item[2]), "%s: %s" % [item[0], manifest.error])

	check(_read("no-name-2", {"version": "1", "main": "main.js"}).name == "no-name-2", "A mod without a name shows its folder name")


func _check_versions() -> void:
	check(ModManifest.compare_versions("0.10.0", "0.9.9") == 1, "0.10 is newer than 0.9")
	check(ModManifest.compare_versions("1.2", "1.2.0") == 0, "A missing part is 0")
	check(ModManifest.compare_versions("1.2-beta", "1.3") == -1, "A part counts its leading digits")


func _check_catalog() -> void:
	var catalog := folder.path_join("catalog")
	var base := {"version": "1", "main": "main.js"}
	folder = catalog
	_mod("z-first", base.merged({"name": "Z", "id": "zed"}))
	_mod("b-needs-zed", base.merged({"name": "B", "dependencies": ["zed", "not-here"]}))
	_mod("a-plain", base.merged({"name": "A"}))
	_mod("zz-copy", base.merged({"name": "Copy", "id": "zed"}, true))
	_mod("cycle-1", base.merged({"name": "C1", "dependencies": ["cycle-2"]}))
	_mod("cycle-2", base.merged({"name": "C2", "dependencies": ["cycle-1"]}))
	_mod(".hidden", base.merged({"name": "Hidden"}))
	folder = catalog.get_base_dir()

	var order := PackedStringArray()
	var by_folder := {}

	for manifest in ModCatalog.scan(catalog, GAME_VERSION):
		order.append(manifest.folder.get_file())
		by_folder[manifest.folder.get_file()] = manifest

	check(not order.has(".hidden"), "A hidden folder is not a mod")
	check(order.find("z-first") < order.find("b-needs-zed"), "A dependency loads first: %s" % ", ".join(order))
	check(order.find("a-plain") < order.find("z-first"), "Other mods load by id: %s" % ", ".join(order))
	check(by_folder["zz-copy"].error.contains("already has the id zed"), "A second mod with an id fails: " + by_folder["zz-copy"].error)
	check(by_folder["z-first"].error.is_empty(), "The first mod with an id stays")
	check(by_folder["b-needs-zed"].error.is_empty(), "A missing dependency is not an error of the manifest")
	check(by_folder["cycle-1"].error.contains("cycle") and by_folder["cycle-2"].error.contains("cycle"), "A dependency cycle fails")
	check(ModCatalog.scan(folder.path_join("none"), GAME_VERSION).is_empty(), "A missing mods folder has no mods")


func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return

	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))

	for child in DirAccess.get_directories_at(path):
		_remove(path.path_join(child))

	DirAccess.remove_absolute(path)
