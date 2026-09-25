extends SceneTree
## Covers the optional release check without network access.

const Check = preload("res://src/platform/release_update_check.gd")
const SettingsScene = preload("res://src/ui/settings/app_settings_dialog.tscn")


class FakeUpdates extends ApplicationUpdates:
	var sent := 0
	var send_error := OK
	var opened: Array[String] = []

	func _init(app_preferences: AppPreferences) -> void:
		super(app_preferences)
		current_version = "1.2.3"

	func _open_url(url: String) -> void:
		opened.append(url)

	func _send_request() -> Error:
		sent += 1

		return send_error


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_versions()
	_check_responses()
	var path := "user://update_check_%d.cfg" % OS.get_process_id()
	_check_store(path)
	await _check_dialog()
	await _check_controller(path)
	await _check_settings_dialog()
	await _check_help_menu()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS: release version rules, GitHub responses and rate limits, stored update state, dialog actions, daily and manual checks, settings and Help menu")
	quit()


func _check_versions() -> void:
	assert(Check.parse_version("v1.2.3") == [1, 2, 3])
	assert(Check.parse_version("1.2.3") == [1, 2, 3])

	for invalid in ["", "v1.2", "1.2.3.4", "01.2.3", "1.2.3-beta", "nightly-20260925-1-1", "1.2.65536", "+1.2.3"]:
		assert(Check.parse_version(invalid).is_empty(), invalid)

	assert(Check.normalized_version(" v0.10.0 ") == "0.10.0")
	assert(Check.is_newer("v0.10.0", "0.9.9"))
	assert(Check.is_newer("1.0.0", "0.99.99"))
	assert(not Check.is_newer("v0.1.0", "0.1.0"))
	assert(not Check.is_newer("0.1.0", "0.2.0"))
	assert(not Check.is_newer("invalid", "0.1.0"))
	assert(not Check.is_newer("1.0.0", "invalid"))

	# 2026-09-25 14:05 UTC, shown in local time
	assert(Check.status_text(1790345100, "", 0).contains("2026-09-25 14:05"))
	assert(Check.status_text(1790345100, "", -300).contains("2026-09-25 09:05"))
	assert(Check.status_text(1790345100, "GitHub is down.", 0).contains("GitHub is down."))

	var day := Check.CHECK_INTERVAL_SECONDS
	assert(Check.is_due(0, 1000))
	assert(not Check.is_due(1000, 1000 + day - 1))
	assert(Check.is_due(1000, 1000 + day))
	assert(Check.is_due(1000 + day, 1000), "A clock that moved back must allow a check")


func _release_body(tag: String, page: String) -> PackedByteArray:
	return JSON.stringify({"tag_name": tag, "html_url": page}).to_utf8_buffer()


func _check_responses() -> void:
	var page := Check.RELEASE_PAGE_PREFIX + "v1.3.0"
	var newer := Check.read_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), _release_body("v1.3.0", page), "1.2.3", 0)
	assert(newer.status == Check.Status.UPDATE_AVAILABLE and newer.version == "1.3.0" and newer.url == page)

	var same := Check.read_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), _release_body("v1.2.3", page), "1.2.3", 0)
	assert(same.status == Check.Status.UP_TO_DATE)

	var older := Check.read_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), _release_body("v1.0.0", page), "1.2.3", 0)
	assert(older.status == Check.Status.UP_TO_DATE)

	# open only a release page of this project
	var foreign := Check.read_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), _release_body("v2.0.0", "https://example.com/"), "1.2.3", 0)
	assert(foreign.status == Check.Status.UPDATE_AVAILABLE and foreign.url == Check.LATEST_RELEASE_PAGE)

	for body in ["not json", "[]", "{}", "{\"tag_name\": 5}", "{\"tag_name\": \"latest\"}"]:
		var outcome := Check.read_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), body.to_utf8_buffer(), "1.2.3", 0)
		assert(outcome.status == Check.Status.FAILED and not outcome.message.is_empty(), body)

	var limited := Check.read_response(HTTPRequest.RESULT_SUCCESS, 403,
		PackedStringArray(["X-RateLimit-Remaining: 0", "X-RateLimit-Reset: 1600"]), PackedByteArray(), "1.2.3", 1000)
	assert(limited.status == Check.Status.FAILED)
	assert(Check.retry_seconds(PackedStringArray(["x-ratelimit-remaining: 0", "x-ratelimit-reset: 1600"]), 1000) == 600)
	assert(Check.retry_seconds(PackedStringArray(["Retry-After: 90"]), 1000) == 90)
	assert(Check.retry_seconds(PackedStringArray(["X-RateLimit-Remaining: 12", "X-RateLimit-Reset: 1600"]), 1000) == -1)
	assert(Check.retry_seconds(PackedStringArray(["X-RateLimit-Remaining: 0", "X-RateLimit-Reset: 900"]), 1000) == 0)
	assert(Check.wait_text(0) == Check.wait_text(60))
	assert(Check.wait_text(61) != Check.wait_text(60))

	for code in [403, 404, 429, 500, 502, 503, 301]:
		var outcome := Check.read_response(HTTPRequest.RESULT_SUCCESS, code, PackedStringArray(), PackedByteArray(), "1.2.3", 0)
		assert(outcome.status == Check.Status.FAILED and not outcome.message.is_empty(), str(code))

	for result in [HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR,
			HTTPRequest.RESULT_TIMEOUT, HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED]:
		var outcome := Check.read_response(result, 0, PackedStringArray(), PackedByteArray(), "1.2.3", 0)
		assert(outcome.status == Check.Status.FAILED and not outcome.message.is_empty(), str(result))

	# the request identifies the app and sends no engine or system details
	assert(Check.header_value(PackedStringArray(Check.REQUEST_HEADERS), "user-agent") == "OpenSC2K")


func _check_store(path: String) -> void:
	var defaults := AppSettingsStore.load_values(path)
	assert(not defaults.check_for_updates, "Update checks are off by default")
	assert(defaults.update_last_check == 0 and defaults.update_skipped_version.is_empty())
	assert(defaults.update_checked_at == 0 and defaults.update_error.is_empty())
	assert(AppSettingsStore.save_update_state(1234, "1.3.0", 1240, "Failure", path) == OK)
	assert(AppSettingsStore.save_values(0.5, 0.5, false, path, "", "", null, null, null, null, null, null, null, null, null, null, null, null, null, true) == OK)
	var loaded := AppSettingsStore.load_values(path)
	assert(loaded.check_for_updates)
	assert(loaded.update_last_check == 1234 and loaded.update_skipped_version == "1.3.0", "Saving settings must keep the update state")
	assert(loaded.update_checked_at == 1240 and loaded.update_error == "Failure")
	# a save that omits the preference keeps it
	assert(AppSettingsStore.save_values(0.5, 0.5, false, path) == OK)
	assert(AppSettingsStore.load_values(path).check_for_updates)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check_dialog() -> void:
	var dialog := UpdateCheckDialog.new()
	root.add_child(dialog)
	var downloads: Array = []
	var skips: Array = []
	dialog.download_requested.connect(func(version: String, url: String) -> void:
		downloads.append([version, url]))
	dialog.skip_requested.connect(func(version: String) -> void:
		skips.append(version))

	dialog.show_update("1.3.0", "1.2.3", "https://example.com/release")
	assert(dialog.visible and dialog.skip_button.visible and dialog.exclusive)
	dialog.get_ok_button().pressed.emit()
	assert(downloads == [["1.3.0", "https://example.com/release"]] and not dialog.visible)

	dialog.show_update("1.3.0", "1.2.3", "https://example.com/release")
	dialog.skip_button.pressed.emit()
	assert(skips == ["1.3.0"] and not dialog.visible)

	dialog.show_latest("1.2.3")
	assert(dialog.visible and not dialog.skip_button.visible)
	dialog.get_ok_button().pressed.emit()
	assert(downloads.size() == 1, "Closing a notice must not open a release")

	dialog.show_failure("GitHub is not available.")
	assert(dialog.visible and not dialog.skip_button.visible)
	dialog.hide()
	dialog.free()
	await process_frame


func _check_controller(path: String) -> void:
	var preferences := AppPreferences.new()
	preferences.settings_path = path
	var updates := FakeUpdates.new(preferences)
	var dialog := UpdateCheckDialog.new()
	root.add_child(dialog)
	updates.bind_ui(root, dialog)
	var running_states: Array[bool] = []
	updates.running_changed.connect(func(running: bool) -> void:
		running_states.append(running))
	var statuses: Array = []
	updates.status_changed.connect(func(checked_at: int, error: String) -> void:
		statuses.append([checked_at, error]))
	var now := 10 * Check.CHECK_INTERVAL_SECONDS

	# off by default: the startup check sends nothing
	updates.check_on_startup(now)
	assert(updates.sent == 0 and preferences.update_last_check == 0)

	preferences.check_for_updates = true
	updates.check_on_startup(now)
	assert(updates.sent == 1 and updates.running and running_states == [true])
	assert(AppSettingsStore.load_values(path).update_last_check == now, "The daily check time must persist")
	updates.finish(_outcome(Check.Status.UP_TO_DATE))
	assert(not dialog.visible, "An automatic check with no update shows nothing")
	assert(not updates.running and running_states == [true, false])

	updates.check_on_startup(now + Check.CHECK_INTERVAL_SECONDS - 1)
	assert(updates.sent == 1, "Check not more than one time each day")

	updates.check_on_startup(now + Check.CHECK_INTERVAL_SECONDS)
	updates.finish(_outcome(Check.Status.FAILED), now + 5)
	assert(not dialog.visible, "An automatic check does not show a failure dialog")
	assert(statuses.back() == [now + 5, "Failure"], "An automatic failure is kept for settings")
	var stored := AppSettingsStore.load_values(path)
	assert(stored.update_checked_at == now + 5 and stored.update_error == "Failure")

	updates._start(false)
	updates.finish(_outcome(Check.Status.UP_TO_DATE), now + 6)
	assert(statuses.back() == [now + 6, ""], "A successful check clears the failure")
	assert(AppSettingsStore.load_values(path).update_error.is_empty())

	updates._start(false)
	updates.finish(_outcome(Check.Status.UPDATE_AVAILABLE, "1.3.0"))
	assert(dialog.visible and dialog.skip_button.visible)
	dialog.skip_button.pressed.emit()
	assert(preferences.update_skipped_version == "1.3.0")
	assert(AppSettingsStore.load_values(path).update_skipped_version == "1.3.0")

	updates._start(false)
	updates.finish(_outcome(Check.Status.UPDATE_AVAILABLE, "1.3.0"))
	assert(not dialog.visible, "An automatic check does not show a skipped release")

	updates._start(false)
	updates.finish(_outcome(Check.Status.UPDATE_AVAILABLE, "1.4.0"))
	assert(dialog.visible, "A newer release than the skipped one shows again")
	dialog.get_ok_button().pressed.emit()
	assert(updates.opened == [Check.RELEASE_PAGE_PREFIX + "v1.4.0"])
	assert(AppSettingsStore.load_values(path).update_skipped_version == "1.4.0", "Download also dismisses this release")

	# a manual check shows every result, also with the setting off
	preferences.check_for_updates = false
	updates.check_now()
	updates.finish(_outcome(Check.Status.UP_TO_DATE))
	assert(dialog.visible and not dialog.skip_button.visible)
	dialog.hide()

	updates.check_now()
	updates.finish(_outcome(Check.Status.FAILED))
	assert(dialog.visible and not dialog.skip_button.visible)
	dialog.hide()

	updates.check_now()
	updates.finish(_outcome(Check.Status.UPDATE_AVAILABLE, "1.4.0"))
	assert(dialog.visible and dialog.skip_button.visible, "A manual check shows a skipped release")
	dialog.hide()

	# a manual request during an automatic check reuses that request and shows its result
	var sent := updates.sent
	updates._start(false)
	updates.check_now()
	assert(updates.sent == sent + 1)
	updates.finish(_outcome(Check.Status.UP_TO_DATE))
	assert(dialog.visible)
	dialog.hide()

	updates.send_error = ERR_BUSY
	updates.check_now()
	assert(dialog.visible and not updates.running, "A request that cannot start reports an error")
	dialog.hide()
	dialog.free()
	await process_frame


func _outcome(status: Check.Status, version := "") -> Check.Outcome:
	var outcome := Check.Outcome.new()
	outcome.status = status
	outcome.version = version
	outcome.url = Check.RELEASE_PAGE_PREFIX + "v" + version
	outcome.message = "Failure"

	return outcome


func _check_settings_dialog() -> void:
	var dialog := SettingsScene.instantiate() as AppSettingsDialog
	root.add_child(dialog)
	assert(not dialog.check_for_updates_check.button_pressed, "The setting is off by default")
	assert(not dialog.selected_values().check_for_updates)
	dialog.check_for_updates_check.button_pressed = true
	assert(dialog.selected_values().check_for_updates)
	var requests := [0]
	dialog.update_check_requested.connect(func() -> void:
		requests[0] += 1)
	dialog.check_updates_now_button.pressed.emit()
	assert(requests[0] == 1)
	dialog.set_update_check_running(true)
	assert(dialog.check_updates_now_button.disabled)
	dialog.set_update_check_running(false)
	assert(not dialog.check_updates_now_button.disabled)
	assert(not dialog.update_status_label.visible, "No status before the first check")
	dialog.set_update_status(1790345100, "GitHub is down.")
	assert(dialog.update_status_label.visible and dialog.update_status_label.theme_type_variation == &"ErrorLabel")
	dialog.set_update_status(1790345100, "")
	assert(dialog.update_status_label.visible and dialog.update_status_label.theme_type_variation == &"HelpLabel")
	# the dark underground option is on the Graphics tab
	assert(dialog.tabs.get_child(2).is_ancestor_of(dialog.dark_underground_check))
	dialog.free()
	await process_frame


func _check_help_menu() -> void:
	var menu_bar := CityMenuBar.new()
	root.add_child(menu_bar)
	var help: MenuButton

	for menu in menu_bar.find_children("*", "MenuButton", true, false):
		if (menu as MenuButton).text == "Help":
			help = menu

	var popup := help.get_popup()
	assert(popup.item_count == 3)
	assert(popup.get_item_id(0) == CityMenuBar.MENU_CHECK_FOR_UPDATES)
	assert(popup.is_item_separator(1))
	assert(popup.get_item_id(2) == CityMenuBar.MENU_ABOUT)
	var requested: Array[int] = []
	menu_bar.help_menu_requested.connect(func(id: int) -> void:
		requested.append(id))
	popup.id_pressed.emit(CityMenuBar.MENU_CHECK_FOR_UPDATES)
	assert(requested == [CityMenuBar.MENU_CHECK_FOR_UPDATES])
	menu_bar.free()
	await process_frame
