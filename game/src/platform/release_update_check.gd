class_name ReleaseUpdateCheck
extends RefCounted
## Rules for the optional check for a newer stable OpenSC2K release on GitHub.
## The check only reports a release. The player downloads and installs it.

enum Status {
	UPDATE_AVAILABLE,
	UP_TO_DATE,
	FAILED,
}

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


static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


# accept the release tag form: an optional "v", then three numbers from 0 to 65535.
# The native library holds the rules; see native/core/platform/src/release.rs
static func parse_version(value: String) -> Array[int]:
	var result: Array[int] = []
	result.assign(Array(NativePlatform.parse_version(value)))

	return result


static func normalized_version(value: String) -> String:
	return NativePlatform.normalized_version(value)


static func is_newer(candidate: String, current: String) -> bool:
	return NativePlatform.is_newer(candidate, current)


# a clock that moved back must not stop the daily check
static func is_due(last_check: int, now: int) -> bool:
	return NativePlatform.is_due(last_check, now)


static func failed(message: String) -> Outcome:
	var outcome := Outcome.new()
	outcome.message = message

	return outcome


static func read_response(
	result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, current: String, now: int
) -> Outcome:
	var transport := "other"

	match result:
		HTTPRequest.RESULT_SUCCESS:
			transport = "success"
		HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CANT_CONNECT, \
				HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_NO_RESPONSE:
			transport = "connect"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			transport = "tls"
		HTTPRequest.RESULT_TIMEOUT:
			transport = "timeout"

	var fields := NativePlatform.read_response(transport, result, response_code, headers, body, current, now)
	var outcome := Outcome.new()
	outcome.status = fields.status as Status
	outcome.version = fields.version
	outcome.url = fields.url
	outcome.message = fields.message

	return outcome


# seconds until GitHub accepts requests again, or -1 when the response is not a rate limit
static func retry_seconds(headers: PackedStringArray, now: int) -> int:
	return NativePlatform.retry_seconds(headers, now)


static func wait_text(seconds: int) -> String:
	return NativePlatform.wait_text(seconds)


# summary of the last check in local time, for example "Last checked 2026-09-25 14:05."
static func status_text(checked_at: int, error: String, bias_minutes := int(Time.get_time_zone_from_system().bias)) -> String:
	return NativePlatform.status_text(checked_at, error, bias_minutes)


static func header_value(headers: PackedStringArray, header_name: String) -> String:
	return NativePlatform.header_value(headers, header_name)


class Outcome extends RefCounted:
	var status := Status.FAILED
	var version := ""
	var url := LATEST_RELEASE_PAGE
	var message := ""
