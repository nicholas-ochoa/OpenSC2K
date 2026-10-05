extends SceneTree
## Mods in the running application: the game loads each enabled mod of the
## mods folder in its own runtime, in dependency order. A mod has its own
## globals, storage and files, cannot use files or modules outside its
## folder, and reaches other mods only through events. The Mods tab of
## Settings and the mods command turn mods off and on.

const AppFixture = preload("res://tests/support/app_fixture.gd")

var checks := 0
var failures := 0
var mods_folder := ""


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	mods_folder = ModCatalog.default_folder()
	_write_mods()
	var main := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	AppFixture.configure(main)
	AppSettingsStore.save_disabled_mods(PackedStringArray(["off-mod"]), main.preferences.settings_path)
	root.add_child(main)
	await process_frame

	_check_loading(main)
	_check_sandbox(main)
	_check_events_and_storage(main)
	_check_enable_and_disable(main)
	main.queue_free()
	await process_frame
	print("Mods: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _write_mods() -> void:
	var base := {"version": "1.0.0", "main": "main.js"}
	_write("alpha/info.json", JSON.stringify(base.merged({"name": "Alpha", "main": "main.mjs", "author": "Tester"}, true)))
	_write("alpha/lib/util.mjs", "export const double = (value) => value * 2;")
	_write("alpha/main.mjs", "\n".join([
		"import { double } from './lib/util.mjs';",
		"globalThis.alphaSecret = 'alpha only';",
		"globalThis.problems = [];",
		"function attempt(name, action) {",
		"  try { action(); problems.push(`${name}: allowed`); } catch (error) { problems.push(`${name}: ${error.message}`); }",
		"}",
		"attempt('read', () => mod.files.readText('../beta/info.json'));",
		"attempt('write', () => mod.files.writeText('../escaped.txt', 'x'));",
		"attempt('emit', () => game.emit('sim.day', {}));",
		"mod.files.writeJSON('data/state.json', { id: mod.id, version: mod.version });",
		"game.storage.set('launches', 1);",
		"globalThis.seenMods = [];",
		"game.on('mod.loaded', (event) => seenMods.push(event.id));",
		"game.on('beta.ping', (event) => game.emit('alpha.pong', { n: double(event.n), from: event.source }));",
		"game.on('tool.beforeApply', (event) => event.cancel());",
		"game.command('alpha-hello', 'Say hello.', () => `hello from ${mod.name}`);",
		"console.log('alpha ready');",
	]))
	_write("beta/info.json", JSON.stringify(base.merged({"name": "Beta", "dependencies": ["alpha"]}, true)))
	_write("beta/main.js", "\n".join([
		"globalThis.betaSaw = typeof alphaSecret;",
		"globalThis.pongs = [];",
		"globalThis.cancelSeen = [];",
		"game.on('alpha.pong', (event) => pongs.push(`${event.source}:${event.n}:${event.from}`));",
		"game.on('tool.beforeApply', (event) => cancelSeen.push(event.cancelled));",
	]))
	_write("broken/info.json", JSON.stringify(base.merged({"name": "Broken"}, true)))
	_write("broken/main.js", "throw new Error('broken on purpose');")
	_write("bad/info.json", JSON.stringify({"version": "1", "main": "main.js"}))
	_write("off-mod/info.json", JSON.stringify(base.merged({"name": "Off"}, true)))
	_write("off-mod/main.js", "globalThis.started = true;")
	_write("waiter/info.json", JSON.stringify(base.merged({"name": "Waiter", "dependencies": ["missing-mod"]}, true)))
	_write("waiter/main.js", "")


func _write(relative: String, text: String) -> void:
	var path := mods_folder.path_join(relative)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	FileAccess.open(path, FileAccess.WRITE).store_string(text)


# runs JavaScript in the runtime of a mod: the console text of the result
func _js(context: ScriptContext, source: String) -> String:
	var result := context.runtime.eval_console(source)

	return str(result.text) if bool(result.ok) else "error: " + str(result.error)


func _state(main: CityApplication, id: String) -> ApplicationMods.State:
	return main.scripting.mods.state(main.scripting.mods.manifest(id))


func _check_loading(main: CityApplication) -> void:
	var mods := main.scripting.mods
	var states := {}

	for id in ["alpha", "beta", "broken", "bad", "off-mod", "waiter"]:
		states[id] = ApplicationMods.State.keys()[_state(main, id)]

	check(states == {"alpha": "RUNNING", "beta": "RUNNING", "broken": "FAILED", "bad": "FAILED", "off-mod": "DISABLED",
		"waiter": "WAITING"}, "Each mod has its state: %s" % states)
	check(mods.status_text(mods.manifest("broken")).contains("broken on purpose"), "A failed main script shows its error")
	check(mods.status_text(mods.manifest("bad")).contains("needs a \"name\""), "A wrong info.json shows its problem")
	check(mods.status_text(mods.manifest("waiter")) == "Waits for the mod missing-mod.", mods.status_text(mods.manifest("waiter")))
	var ids := mods.contexts().map(func(context: ScriptContext) -> String: return context.id)
	check(ids == ["alpha", "beta"], "The mods run in dependency order: %s" % str(ids))
	check(not main.scripting.is_running(), "Mods do not start the console runtime")
	check(main.scripting.evaluate_console("game.mods.map((info) => info.id).join()") == "\"alpha,beta\"", "game.mods lists the mods")
	check(_js(mods.context("alpha"), "mod.info.author + ' ' + mod.version") == "\"Tester 1.0.0\"", "mod has the info.json fields")
	var seen := _js(mods.context("alpha"), "seenMods.join()")
	check(seen == "\"alpha,beta\"", "A mod sees itself and the later mods load: " + seen)

	var lines := ConsoleLog.entries_since(0).map(func(entry: Variant) -> String: return entry.text)
	check(lines.has("[alpha] alpha ready"), "Console output of a mod shows its id")


func _check_sandbox(main: CityApplication) -> void:
	var alpha := main.scripting.mods.context("alpha")
	var beta := main.scripting.mods.context("beta")
	var problems := _js(alpha, "problems.join('|')")
	check(problems.contains("read: A mod can use only the files in its own folder"), problems)
	check(problems.contains("write: A mod can use only the files in its own folder"), problems)
	check(problems.contains("emit: A mod cannot send the game event sim.day"), problems)
	check(not FileAccess.file_exists(mods_folder.path_join("escaped.txt")), "A mod cannot write outside its folder")

	var state: Variant = JSON.parse_string(FileAccess.get_file_as_string(mods_folder.path_join("alpha/data/state.json")))
	check(state is Dictionary and state.id == "alpha", "A mod writes files in its folder")
	check(_js(beta, "betaSaw") == "\"undefined\"", "A mod does not see the globals of another mod")
	check(main.scripting.evaluate_console("typeof alphaSecret") == "\"undefined\"", "The console does not see the globals of a mod")
	check(main.scripting.evaluate_console("typeof mod") == "\"undefined\"", "The console runtime is not a mod")
	_write("alpha/escape.mjs", "import '../beta/main.js';")
	var escape := mods_folder.path_join("alpha/escape.mjs")
	var imported := _js(alpha, "await import('%s').then(() => 'loaded', (error) => error.message)" % escape)
	check(imported.contains("A mod imports only files in its own folder"), "A mod cannot import a module of another mod: " + imported)


func _check_events_and_storage(main: CityApplication) -> void:
	var beta := main.scripting.mods.context("beta")
	main.scripting.evaluate_console("game.emit('beta.ping', { n: 3 })")
	check(_js(beta, "pongs.join()") == "\"alpha:6:console\"", "Events carry data between mods: " + _js(beta, "pongs.join()"))

	check(main.scripting.cancelled("tool.beforeApply", {"tool": "Bulldozer"}), "A mod cancels a game event")
	check(_js(beta, "cancelSeen.join()") == "\"true\"", "A later mod sees that an earlier mod cancelled the event")

	var stored: Variant = JSON.parse_string(FileAccess.get_file_as_string(mods_folder.path_join("alpha/storage.json")))
	check(stored is Dictionary and stored.get("launches") == 1.0, "A mod keeps game.storage in its folder")
	check(main.scripting.evaluate_console("game.storage.get('launches', 'none')") == "\"none\"", "Each runtime has its own storage")

	main.console_window.commands.execute("alpha-hello")
	var entries := ConsoleLog.entries_since(0)
	check(entries[-1].text == "hello from Alpha", "A mod adds a console command: " + entries[-1].text)


func _check_enable_and_disable(main: CityApplication) -> void:
	var mods := main.scripting.mods
	main.settings.open_settings_dialog()
	var panel := main.main_overlays.settings_dialog.mods_panel
	var items := panel.tree.get_root().get_children()
	check(items.size() == mods.manifests.size(), "The Mods tab lists each mod")
	var checked := {}

	for item in items:
		checked[str(item.get_metadata(0))] = item.is_checked(0)

	check(checked.get("alpha") == true and checked.get("off-mod") == false, "The check boxes show the enabled mods: %s" % checked)

	panel.mod_enabled_changed.emit("alpha", false)
	check(_state(main, "alpha") == ApplicationMods.State.DISABLED and _state(main, "beta") == ApplicationMods.State.WAITING,
		"Turning a mod off stops it and the mods that need it")
	check(not main.console_window.commands.has("alpha-hello") and not main.scripting.listens("beta.ping"),
		"A stopped mod has no commands or listeners")
	check(AppSettingsStore.load_disabled_mods(main.preferences.settings_path).has("alpha"), "The settings keep a disabled mod")
	check(DirAccess.dir_exists_absolute(mods_folder.path_join("alpha")), "A disabled mod stays in the folder")

	panel.mod_enabled_changed.emit("alpha", true)
	panel.mod_enabled_changed.emit("off-mod", true)
	var running := mods.contexts().map(func(context: ScriptContext) -> String: return context.id)
	check(running == ["alpha", "beta", "off-mod"], "Turning mods on starts them in order: %s" % str(running))
	check(not AppSettingsStore.load_disabled_mods(main.preferences.settings_path).has("off-mod"), "The settings keep an enabled mod")

	main.console_window.commands.execute("mods disable beta")
	check(_state(main, "beta") == ApplicationMods.State.DISABLED and _state(main, "alpha") == ApplicationMods.State.RUNNING,
		"The mods command turns a mod off")
	main.console_window.commands.execute("mods reload")
	check(_state(main, "broken") == ApplicationMods.State.FAILED and _state(main, "alpha") == ApplicationMods.State.RUNNING,
		"A reload starts the enabled mods again")
	main.console_window.commands.execute("reset")
	check(_state(main, "alpha") == ApplicationMods.State.RUNNING and main.console_window.commands.has("alpha-hello"),
		"A reset loads the mods again")
