//! The optional check for a newer stable OpenSC2K release on GitHub. The
//! check only reports a release; the player downloads and installs it.

use crate::text::{is_valid_int, strip_edges};
use sc2k_formats::json::{self, Value};

pub const REPOSITORY: &str = "nicholas-ochoa/OpenSC2K";
pub const LATEST_RELEASE_PAGE: &str = "https://github.com/nicholas-ochoa/OpenSC2K/releases/latest";
const RELEASE_PAGE_PREFIX: &str = "https://github.com/nicholas-ochoa/OpenSC2K/releases/tag/";
pub const CHECK_INTERVAL_SECONDS: i64 = 24 * 60 * 60;
const VERSION_PART_LIMIT: i64 = 65535;
const VERSION_PART_DIGITS: usize = 5;
const SECONDS_PER_MINUTE: i64 = 60;
const SECONDS_PER_DAY: i64 = 86_400;

/// How the request ended before any HTTP status.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Transport {
    Success,
    /// The name did not resolve, the connection failed, or nothing answered.
    Connect,
    Tls,
    Timeout,
    /// Another request error, with its engine code.
    Other(i64),
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Status {
    UpdateAvailable,
    UpToDate,
    Failed,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Outcome {
    pub status: Status,
    pub version: String,
    pub url: String,
    pub message: String,
}

impl Outcome {
    pub fn failed(message: impl Into<String>) -> Self {
        Self {
            status: Status::Failed,
            version: String::new(),
            url: LATEST_RELEASE_PAGE.into(),
            message: message.into(),
        }
    }
}

/// The three numbers of a release tag: an optional "v", then three numbers
/// from 0 to 65535 without leading zeros.
pub fn parse_version(value: &str) -> Option<[i64; 3]> {
    let text = strip_edges(value);
    let text = text.strip_prefix('v').unwrap_or(text);
    let parts: Vec<&str> = text.split('.').collect();

    if parts.len() != 3 {
        return None;
    }

    let mut numbers = [0; 3];

    for (number, part) in numbers.iter_mut().zip(&parts) {
        let valid = !part.is_empty()
            && part.len() <= VERSION_PART_DIGITS
            && part.bytes().all(|byte| byte.is_ascii_digit())
            && (*part == "0" || !part.starts_with('0'));

        if !valid {
            return None;
        }

        *number = part.parse().ok().filter(|&value| value <= VERSION_PART_LIMIT)?;
    }

    Some(numbers)
}

pub fn normalized_version(value: &str) -> String {
    parse_version(value).map_or(String::new(), |[major, minor, patch]| format!("{major}.{minor}.{patch}"))
}

pub fn is_newer(candidate: &str, current: &str) -> bool {
    match (parse_version(candidate), parse_version(current)) {
        (Some(candidate), Some(current)) => candidate > current,
        _ => false,
    }
}

/// A clock that moved back must not stop the daily check.
pub fn is_due(last_check: i64, now: i64) -> bool {
    last_check <= 0 || now < last_check || now - last_check >= CHECK_INTERVAL_SECONDS
}

/// The value of a response header, or an empty string.
pub fn header_value<'a>(headers: &'a [String], name: &str) -> &'a str {
    let prefix = format!("{}:", name.to_lowercase());

    headers
        .iter()
        .find(|header| header.to_lowercase().starts_with(&prefix))
        .map_or("", |header| strip_edges(&header[prefix.len()..]))
}

/// Seconds until GitHub accepts requests again, or `None` when the response is
/// not a rate limit.
pub fn retry_seconds(headers: &[String], now: i64) -> Option<i64> {
    let retry_after = header_value(headers, "retry-after");

    if is_valid_int(retry_after) {
        return Some(retry_after.parse::<i64>().unwrap_or(0).max(0));
    }

    let reset = header_value(headers, "x-ratelimit-reset");

    if header_value(headers, "x-ratelimit-remaining") == "0" && is_valid_int(reset) {
        return Some((reset.parse::<i64>().unwrap_or(0) - now).max(0));
    }

    None
}

pub fn wait_text(seconds: i64) -> String {
    let minutes = ((seconds + SECONDS_PER_MINUTE - 1) / SECONDS_PER_MINUTE).max(1);

    if minutes == 1 {
        "1 minute".into()
    } else {
        format!("{minutes} minutes")
    }
}

/// The outcome of a finished request for the latest release.
pub fn read_response(transport: Transport, response_code: i64, headers: &[String], body: &[u8], current: &str, now: i64) -> Outcome {
    match transport {
        Transport::Success => {}
        Transport::Connect => {
            return Outcome::failed("Cannot connect to GitHub. Check the internet connection, then try again.");
        }
        Transport::Tls => return Outcome::failed("Cannot make a secure connection to GitHub."),
        Transport::Timeout => {
            return Outcome::failed("GitHub did not respond in time. Try again later.");
        }
        Transport::Other(code) => {
            return Outcome::failed(format!("Cannot check for updates (request error {code})."));
        }
    }

    if response_code == 403 || response_code == 429 {
        if let Some(wait) = retry_seconds(headers, now) {
            return Outcome::failed(format!(
                "GitHub has limited update checks from this network. Try again in {}.",
                wait_text(wait)
            ));
        }

        if response_code == 429 {
            return Outcome::failed("GitHub has limited update checks from this network. Try again later.");
        }
    }

    if response_code == 404 {
        return Outcome::failed("GitHub has no published OpenSC2K release.");
    }

    if response_code >= 500 {
        return Outcome::failed(format!(
            "GitHub is not available at this time (HTTP {response_code}). Try again later."
        ));
    }

    if response_code != 200 {
        return Outcome::failed(format!("GitHub returned an unexpected response (HTTP {response_code})."));
    }

    let data = json::parse(&String::from_utf8_lossy(body)).ok();
    let release = data.as_ref().and_then(Value::as_object);
    let Some(tag) = release.and_then(|release| release.get("tag_name")).and_then(Value::as_str) else {
        return Outcome::failed("GitHub returned release information that OpenSC2K cannot read.");
    };
    let version = normalized_version(tag);

    if version.is_empty() {
        return Outcome::failed(format!("The latest release has a version that OpenSC2K cannot read: {tag}."));
    }

    // open only a release page of this project
    let page = release
        .and_then(|release| release.get("html_url"))
        .map(crate::text::display)
        .unwrap_or_default();
    let url = if page.starts_with(RELEASE_PAGE_PREFIX) {
        page
    } else {
        LATEST_RELEASE_PAGE.to_string()
    };
    let status = if is_newer(&version, current) {
        Status::UpdateAvailable
    } else {
        Status::UpToDate
    };

    Outcome {
        status,
        version,
        url,
        message: String::new(),
    }
}

/// The civil date of a day count from 1970-01-01.
fn civil_from_days(days: i64) -> (i64, i64, i64) {
    let shifted = days + 719_468;
    let era = shifted.div_euclid(146_097);
    let day_of_era = shifted.rem_euclid(146_097);
    let year_of_era = (day_of_era - day_of_era / 1460 + day_of_era / 36_524 - day_of_era / 146_096) / 365;
    let day_of_year = day_of_era - (365 * year_of_era + year_of_era / 4 - year_of_era / 100);
    let month_index = (5 * day_of_year + 2) / 153;
    let day = day_of_year - (153 * month_index + 2) / 5 + 1;
    let month = if month_index < 10 { month_index + 3 } else { month_index - 9 };
    let year = year_of_era + era * 400 + i64::from(month <= 2);

    (year, month, day)
}

/// A summary of the last check in local time, such as "Last checked 2026-09-25 14:05."
pub fn status_text(checked_at: i64, error: &str, bias_minutes: i64) -> String {
    let local = checked_at + bias_minutes * SECONDS_PER_MINUTE;
    let (year, month, day) = civil_from_days(local.div_euclid(SECONDS_PER_DAY));
    let seconds = local.rem_euclid(SECONDS_PER_DAY);
    let stamp = format!("{year:04}-{month:02}-{day:02} {:02}:{:02}", seconds / 3600, seconds / 60 % 60);

    if error.is_empty() {
        format!("Last checked {stamp}.")
    } else {
        format!("Last check failed {stamp}. {error}")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tags_parse_as_three_small_numbers() {
        assert_eq!(parse_version(" v1.2.3 "), Some([1, 2, 3]));
        assert_eq!(parse_version("1.02.3"), None);
        assert_eq!(parse_version("1.2"), None);
        assert_eq!(parse_version("65536.0.0"), None);
        assert!(is_newer("0.10.0", "0.9.9") && !is_newer("0.9.9", "0.9.9") && !is_newer("x", "0.1.0"));
    }

    #[test]
    fn responses_report_releases_and_limits() {
        let body = br#"{"tag_name": "v1.4.0", "html_url": "https://evil.example/"}"#;
        let found = read_response(Transport::Success, 200, &[], body, "1.3.9", 0);
        assert_eq!(
            (found.status, found.version.as_str(), found.url.as_str()),
            (Status::UpdateAvailable, "1.4.0", LATEST_RELEASE_PAGE)
        );

        let limited = read_response(Transport::Success, 403, &["Retry-After: 61".into()], b"", "1.0.0", 0);
        assert_eq!(
            limited.message,
            "GitHub has limited update checks from this network. Try again in 2 minutes."
        );
        assert_eq!(
            read_response(Transport::Other(9), 0, &[], b"", "1.0.0", 0).message,
            "Cannot check for updates (request error 9)."
        );
        assert_eq!(
            read_response(Transport::Success, 200, &[], b"[]", "1.0.0", 0).status,
            Status::Failed
        );
    }

    #[test]
    fn the_status_uses_local_time() {
        assert_eq!(status_text(1_790_000_000, "", 0), "Last checked 2026-09-21 14:13.");
        assert_eq!(status_text(0, "Offline.", -60), "Last check failed 1969-12-31 23:00. Offline.");
        assert!(is_due(0, 5) && is_due(100, 50) && !is_due(100, 200));
    }
}
