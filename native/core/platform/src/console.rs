//! The console log: the recent output of the game for the Console window and
//! its file, as ConsoleLog. Any thread can log; the log is a global.

use std::sync::{Mutex, OnceLock};
use std::time::Instant;

/// The oldest entries go when the log holds more than this many.
pub const MAX_ENTRIES: usize = 5000;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Level {
    Message,
    ErrorOutput,
    Warning,
    Error,
    Input,
    Result,
}

#[derive(Clone, Debug)]
pub struct Entry {
    pub serial: u64,
    pub level: Level,
    pub text: String,
    /// Milliseconds since the start of the game.
    pub msec: u64,
}

#[derive(Default)]
struct Log {
    entries: Vec<Entry>,
    serial: u64,
    /// It grows with each clear, so a view knows to show the log again.
    generation: u64,
    warnings: usize,
    errors: usize,
}

fn log() -> &'static Mutex<Log> {
    static LOG: OnceLock<Mutex<Log>> = OnceLock::new();

    LOG.get_or_init(|| Mutex::new(Log::default()))
}

fn started() -> Instant {
    static START: OnceLock<Instant> = OnceLock::new();

    *START.get_or_init(Instant::now)
}

fn with_log<T>(call: impl FnOnce(&mut Log) -> T) -> T {
    let mut guard = log().lock().unwrap_or_else(std::sync::PoisonError::into_inner);

    call(&mut guard)
}

fn count(log: &mut Log, level: Level, add: bool) {
    let counter = match level {
        Level::Warning => &mut log.warnings,
        Level::Error => &mut log.errors,
        _ => return,
    };

    if add {
        *counter += 1;
    } else {
        *counter = counter.saturating_sub(1);
    }
}

/// Add a line. Errors and warnings also go to the standard error stream.
pub fn append(level: Level, text: &str) {
    if matches!(level, Level::Error | Level::Warning | Level::ErrorOutput) {
        eprintln!("{text}");
    }

    let msec = started().elapsed().as_millis() as u64;

    with_log(|log| {
        log.serial += 1;
        let entry = Entry {
            serial: log.serial,
            level,
            text: text.to_string(),
            msec,
        };
        log.entries.push(entry);
        count(log, level, true);

        if log.entries.len() > MAX_ENTRIES {
            let removed: Vec<Entry> = log.entries.drain(..log.entries.len() - MAX_ENTRIES).collect();

            for entry in removed {
                count(log, entry.level, false);
            }
        }
    });
}

pub fn message(text: &str) {
    append(Level::Message, text);
}

pub fn warning(text: &str) {
    append(Level::Warning, text);
}

pub fn error(text: &str) {
    append(Level::Error, text);
}

/// The entries after `serial`, oldest first.
pub fn entries_since(serial: u64) -> Vec<Entry> {
    with_log(|log| log.entries.iter().filter(|entry| entry.serial > serial).cloned().collect())
}

pub fn clear() {
    with_log(|log| {
        log.entries.clear();
        log.generation += 1;
        log.warnings = 0;
        log.errors = 0;
    });
}

/// The clear count, the number of warnings, and the number of errors.
pub fn counts() -> (u64, usize, usize) {
    with_log(|log| (log.generation, log.warnings, log.errors))
}

/// The log as text, one line for each entry, with the time and the level.
pub fn text() -> String {
    with_log(|log| {
        log.entries
            .iter()
            .map(|entry| {
                let level = match entry.level {
                    Level::Warning => "WARNING: ",
                    Level::Error => "ERROR: ",
                    _ => "",
                };

                format!("[{:>8.3}] {level}{}\n", entry.msec as f64 / 1000.0, entry.text)
            })
            .collect()
    })
}

/// Write the log to a file.
pub fn save(path: &std::path::Path) -> std::io::Result<()> {
    if let Some(folder) = path.parent() {
        std::fs::create_dir_all(folder)?;
    }

    std::fs::write(path, text())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_log_counts_and_trims() {
        clear();
        message("hello");
        warning("careful");
        let (_, warnings, errors) = counts();
        assert_eq!((warnings, errors), (1, 0));
        assert!(text().contains("WARNING: careful"));
        let last = entries_since(0).last().unwrap().serial;
        assert!(entries_since(last).is_empty());
    }
}
