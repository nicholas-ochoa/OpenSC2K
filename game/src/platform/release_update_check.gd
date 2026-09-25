class_name ReleaseUpdateCheck
extends RefCounted
## Rules for the optional check for a newer stable OpenSC2K release on GitHub.
## The check only reports a release. The player downloads and installs it.

@warning_ignore_start("integer_division")

const REPOSITORY := "nicholas-ochoa/OpenSC2K"
# the latest release excludes drafts and prereleases, so nightlies never match
const LATEST_RELEASE_API := "https://api.github.com/repos/" + REPOSITORY + "/releases/latest"
const LATEST_RELEASE_PAGE := "https://github.com/" + REPOSITORY + "/releases/latest"
const RELEASE_PAGE_PREFIX := "https://github.com/" + REPOSITORY + "/releases/tag/"
# send only the headers that the GitHub API requires. the explicit user agent
# replaces the engine default, which includes the engine version and system
const REQUEST_HEADERS := [
	"Accept: application/vnd.github+json",
	"X-GitHub-Api-Version: 2022-11-28",
	"User-Agent: OpenSC2K",
]
const CHECK_INTERVAL_SECONDS := 24 * 60 * 60
const TIMEOUT_SECONDS := 20.0
const BODY_SIZE_LIMIT := 1024 * 1024

enum Status { UPDATE_AVAILABLE, UP_TO_DATE, FAILED }


class Outcome extends RefCounted:
	var status := Status.FAILED
	var version := ""
	var url := LATEST_RELEASE_PAGE
	var message := ""


static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


# accept the release tag form: an optional "v", then three numbers from 0 to 65535
static func parse_version(value: String) -> Array[int]:
	var result: Array[int] = []
	var pattern := RegEx.create_from_string("^v?(0|[1-9][0-9]{0,4})\\.(0|[1-9][0-9]{0,4})\\.(0|[1-9][0-9]{0,4})$")
	var found := pattern.search(value.strip_edges())

	if found == null:
		return result

	for group in range(1, 4):
		var number := found.get_string(group).to_int()

		if number > 65535:
			return [] as Array[int]

		result.append(number)

	return result


static func normalized_version(value: String) -> String:
	var parts := parse_version(value)

	return "" if parts.is_empty() else "%d.%d.%d" % parts


static func is_newer(candidate: String, current: String) -> bool:
	var candidate_parts := parse_version(candidate)
	var current_parts := parse_version(current)

	if candidate_parts.is_empty() or current_parts.is_empty():
		return false

	for index in 3:
		if candidate_parts[index] != current_parts[index]:
			return candidate_parts[index] > current_parts[index]

	return false


# a clock that moved back must not stop the daily check
static func is_due(last_check: int, now: int) -> bool:
	return last_check <= 0 or now < last_check or now - last_check >= CHECK_INTERVAL_SECONDS


static func failed(message: String) -> Outcome:
	var outcome := Outcome.new()
	outcome.message = message

	return outcome


static func read_response(
	result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, current: String, now: int
) -> Outcome:
	match result:
		HTTPRequest.RESULT_SUCCESS:
			pass
		HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_NO_RESPONSE:
			return failed("Cannot connect to GitHub. Check the internet connection, then try again.")
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return failed("Cannot make a secure connection to GitHub.")
		HTTPRequest.RESULT_TIMEOUT:
			return failed("GitHub did not respond in time. Try again later.")
		_:
			return failed("Cannot check for updates (request error %d)." % result)

	if response_code == 403 or response_code == 429:
		var wait := retry_seconds(headers, now)

		if wait >= 0:
			return failed("GitHub has limited update checks from this network. Try again in %s." % wait_text(wait))

		if response_code == 429:
			return failed("GitHub has limited update checks from this network. Try again later.")

	if response_code == 404:
		return failed("GitHub has no published OpenSC2K release.")

	if response_code >= 500:
		return failed("GitHub is not available at this time (HTTP %d). Try again later." % response_code)

	if response_code != 200:
		return failed("GitHub returned an unexpected response (HTTP %d)." % response_code)

	var json := JSON.new()
	var data: Variant = json.data if json.parse(body.get_string_from_utf8()) == OK else null

	if not (data is Dictionary) or not (data.get("tag_name") is String):
		return failed("GitHub returned release information that OpenSC2K cannot read.")

	var outcome := Outcome.new()
	outcome.version = normalized_version(data.tag_name)

	if outcome.version.is_empty():
		return failed("The latest release has a version that OpenSC2K cannot read: %s." % data.tag_name)

	# open only a release page of this project
	var page := str(data.get("html_url", ""))
	outcome.url = page if page.begins_with(RELEASE_PAGE_PREFIX) else LATEST_RELEASE_PAGE
	outcome.status = Status.UPDATE_AVAILABLE if is_newer(outcome.version, current) else Status.UP_TO_DATE

	return outcome


# seconds until GitHub accepts requests again, or -1 when the response is not a rate limit
static func retry_seconds(headers: PackedStringArray, now: int) -> int:
	var retry_after := header_value(headers, "retry-after")

	if retry_after.is_valid_int():
		return maxi(0, retry_after.to_int())

	var reset := header_value(headers, "x-ratelimit-reset")

	if header_value(headers, "x-ratelimit-remaining") == "0" and reset.is_valid_int():
		return maxi(0, reset.to_int() - now)

	return -1


static func wait_text(seconds: int) -> String:
	var minutes := maxi(1, (seconds + 59) / 60)

	return "1 minute" if minutes == 1 else "%d minutes" % minutes


# summary of the last check in local time, for example "Last checked 2026-09-25 14:05."
static func status_text(checked_at: int, error: String, bias_minutes := int(Time.get_time_zone_from_system().bias)) -> String:
	var local := Time.get_datetime_dict_from_unix_time(checked_at + bias_minutes * 60)
	var stamp := "%04d-%02d-%02d %02d:%02d" % [local.year, local.month, local.day, local.hour, local.minute]

	return "Last checked %s." % stamp if error.is_empty() else "Last check failed %s. %s" % [stamp, error]


static func header_value(headers: PackedStringArray, header_name: String) -> String:
	var prefix := header_name.to_lower() + ":"

	for header in headers:
		if header.to_lower().begins_with(prefix):
			return header.substr(prefix.length()).strip_edges()

	return ""
