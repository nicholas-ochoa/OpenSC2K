//! FluidSynth log messages. FluidSynth writes to the console by default; this
//! keeps the last error of each thread so that a failed call can explain itself.
use std::cell::RefCell;
use std::ffi::{CStr, c_char, c_int, c_void};

use super::api::{Api, LOG_DEBUG, LOG_ERROR, LOG_INFO, LOG_PANIC, LOG_WARNING};

thread_local! {
    /// The most severe message since `clear`, and its level.
    static LAST_ERROR: RefCell<(c_int, String)> = const { RefCell::new((LOG_DEBUG, String::new())) };
}

/// Sends errors and warnings to `record`, and drops information and debug text.
pub fn install(api: &Api) {
    // SAFETY: record has the FluidSynth log function signature and lives for the
    // process. A null function turns a level off.
    unsafe {
        for level in [LOG_PANIC, LOG_ERROR, LOG_WARNING] {
            (api.set_log_function)(level, Some(record), std::ptr::null_mut());
        }

        for level in [LOG_INFO, LOG_DEBUG] {
            (api.set_log_function)(level, None, std::ptr::null_mut());
        }
    }
}

/// Forgets the last error of this thread before a call that can fail.
pub fn clear() {
    LAST_ERROR.with_borrow_mut(|last| *last = (LOG_DEBUG, String::new()));
}

/// The last error of this thread, or an empty string.
pub fn take() -> String {
    LAST_ERROR.with_borrow_mut(|last| std::mem::take(&mut last.1))
}

unsafe extern "C" fn record(level: c_int, message: *const c_char, _data: *mut c_void) {
    if message.is_null() {
        return;
    }

    // SAFETY: FluidSynth passes a NUL-terminated message for the time of the call.
    let text = unsafe { CStr::from_ptr(message) }.to_string_lossy();

    // keep the first message of the most severe level: later ones usually repeat its cause
    LAST_ERROR.with_borrow_mut(|last| {
        if last.1.is_empty() || level < last.0 {
            *last = (level, text.into_owned());
        }
    });
}
