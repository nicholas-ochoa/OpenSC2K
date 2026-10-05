class_name ApplicationMods
extends RefCounted
## The mods in the mods folder of the user data folder. Each enabled mod runs
## in its own script runtime, in load order, and can use files only in its own
## folder. The player turns mods on and off in the Mods tab of Settings, or
## with the mods console command. The settings file keeps the ids of the
## disabled mods; a new mod is enabled. See docs/mods.md.

signal changed

enum State { RUNNING, DISABLED, FAILED, WAITING }

# ApplicationScripting owns this object; a weak reference does not keep it
var scripting: ApplicationScripting:
	get:
		return _owner.get_ref() as ApplicationScripting
var folder := ModCatalog.default_folder()
var settings_path := AppSettingsStore.default_path()
# the mods of the folder, in load order
var manifests: Array[ModManifest] = []
var disabled: PackedStringArray = []
# id -> the runtime of each mod that runs
var _running: Dictionary[String, ScriptContext] = {}
# id -> why the mod stopped. It stays stopped until a reload, or until the
# player turns it on again
var _failures: Dictionary[String, String] = {}
var _owner: WeakRef


func _init(owner: ApplicationScripting) -> void:
	_owner = weakref(owner)


## Finds the mods in the folder and starts the enabled ones.
func load_all(mods_folder := ModCatalog.default_folder(), settings_file := AppSettingsStore.default_path()) -> void:
	folder = mods_folder
	settings_path = settings_file
	disabled = AppSettingsStore.load_disabled_mods(settings_path)
	reload()


## Stops all mods, finds the mods in the folder again, and starts the enabled ones.
func reload() -> void:
	close_all()
	_failures.clear()
	manifests = ModCatalog.scan(folder, str(ProjectSettings.get_setting("application/config/version", "")))
	sync()


## Stops the mods that must not run, then starts the others in load order.
## A mod runs when it is enabled, its info.json is right, it did not fail,
## and its dependencies run.
func sync() -> void:
	for manifest in manifests:
		if _running.has(manifest.id) and _running[manifest.id].manifest == manifest and not _may_run(manifest):
			_stop(manifest.id)

	for manifest in manifests:
		if not _running.has(manifest.id) and _may_run(manifest):
			_start(manifest)

	changed.emit()


## Stops all mods without events. The game closes, or the mods load again.
func close_all() -> void:
	for context in contexts():
		scripting.close_context(context)

	_running.clear()


## Turns a mod on or off, and keeps the choice in the settings file. Returns
## an empty text, or why it cannot.
func set_enabled(id: String, enabled: bool) -> String:
	if manifest(id) == null:
		return "No mod has the id %s." % id

	var index := disabled.find(id)

	if enabled and index >= 0:
		disabled.remove_at(index)
	elif not enabled and index < 0:
		disabled.append(id)

	# a mod that failed starts again when the player turns it on
	_failures.erase(id)
	var error := AppSettingsStore.save_disabled_mods(disabled, settings_path)
	sync()

	return "" if error == OK else "Cannot save the settings: %s." % error_string(error)


func is_enabled(id: String) -> bool:
	return not disabled.has(id)


func manifest(id: String) -> ModManifest:
	for item in manifests:
		if item.id == id and item.error.is_empty():
			return item

	for item in manifests:
		if item.id == id:
			return item

	return null


## The runtime of a mod that runs, or null.
func context(id: String) -> ScriptContext:
	return _running.get(id)


## The runtimes of the mods that run, in load order.
func contexts() -> Array[ScriptContext]:
	var result: Array[ScriptContext] = []

	for item in manifests:
		if _running.has(item.id) and _running[item.id].manifest == item:
			result.append(_running[item.id])

	return result


## The info of each mod that runs, for game.mods.
func running_info() -> Array:
	var result := []

	for item in contexts():
		result.append(item.manifest.info())

	return result


func state(item: ModManifest) -> State:
	if _running.has(item.id) and _running[item.id].manifest == item:
		return State.RUNNING

	if disabled.has(item.id) and item.error.is_empty():
		return State.DISABLED

	if not item.error.is_empty() or _failures.has(item.id):
		return State.FAILED

	return State.WAITING


## What the Mods window shows about the mod.
func status_text(item: ModManifest) -> String:
	match state(item):
		State.RUNNING:
			return "Running"
		State.DISABLED:
			return "Disabled"
		State.FAILED:
			return item.error if not item.error.is_empty() else _failures[item.id]

	var missing := PackedStringArray()

	for dependency in item.dependencies:
		if not _running.has(dependency):
			missing.append(dependency)

	return "Waits for the mod %s." % ", ".join(missing)


## The rows of the Mods window: the mod info, with enabled, state, failed, status and folder.
func rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for item in manifests:
		var row := item.info()
		row.enabled = is_enabled(item.id)
		row.state = state(item)
		row.failed = row.state == State.FAILED
		row.status = status_text(item)
		row.folder = item.folder
		result.append(row)

	return result


func _may_run(item: ModManifest) -> bool:
	if not item.error.is_empty() or disabled.has(item.id) or _failures.has(item.id):
		return false

	for dependency in item.dependencies:
		if not _running.has(dependency):
			return false

	return true


func _start(item: ModManifest) -> void:
	var storage := ScriptStorage.new(item.folder.path_join(ScriptStorage.FILE_NAME))
	var created := scripting.create_context(item.id, item, storage)

	if not created.error.is_empty():
		_fail(item, created.error)

		return

	# events that the main script causes already reach the mod
	_running[item.id] = created
	var result := created.runtime.run_sandbox_file(item.main)

	if not bool(result.ok):
		_running.erase(item.id)
		scripting.close_context(created)
		_fail(item, "The main script %s stopped with an error:\n%s" % [item.main, result.error])

		return

	ConsoleLog.append(ConsoleLog.Level.RESULT, "Loaded the mod %s %s." % [item.name, item.version])
	scripting.emit("mod.loaded", {"id": item.id, "name": item.name, "version": item.version})


func _stop(id: String) -> void:
	var stopped: ScriptContext = _running[id]
	_running.erase(id)
	scripting.close_context(stopped)
	ConsoleLog.append(ConsoleLog.Level.RESULT, "Stopped the mod %s." % stopped.manifest.name)
	scripting.emit("mod.unloaded", {"id": id})


func _fail(item: ModManifest, message: String) -> void:
	_failures[item.id] = message
	ConsoleLog.append(ConsoleLog.Level.ERROR_OUTPUT, "The mod %s cannot run. %s" % [item.name, message])


## The mods console command: mods, mods enable <id>, mods disable <id>, mods reload.
func command(words: PackedStringArray) -> String:
	var action := words[0].to_lower() if not words.is_empty() else "list"

	match action:
		"list":
			return list_text()
		"reload":
			reload()

			return "The mods loaded again.\n" + list_text()
		"enable", "disable":
			if words.size() < 2:
				ConsoleLog.append(ConsoleLog.Level.ERROR_OUTPUT, "Name a mod: mods %s <id>." % action)

				return ""

			var error := set_enabled(words[1].to_lower(), action == "enable")

			if not error.is_empty():
				ConsoleLog.append(ConsoleLog.Level.ERROR_OUTPUT, error)

				return ""

			return status_text(manifest(words[1].to_lower()))

	ConsoleLog.append(ConsoleLog.Level.ERROR_OUTPUT, "Use mods, mods enable <id>, mods disable <id> or mods reload.")

	return ""


func list_text() -> String:
	if manifests.is_empty():
		return "No mods are in %s." % folder

	var lines := PackedStringArray(["Mods in %s:" % folder])

	for item in manifests:
		lines.append("  [%s] %s %s (%s): %s" % ["x" if is_enabled(item.id) else " ", item.id, item.version, item.name,
			status_text(item)])

	return "\n".join(lines)
