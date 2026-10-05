//! The C callbacks that QuickJS calls: the host function `__host`, the
//! interrupt check of the time limit, and the tracker of rejected promises.

use std::ffi::{CString, c_int, c_void};

use super::state::EngineState;
use crate::ffi::*;
use crate::value::{JsData, from_js, new_string, to_js, to_text};

/// # Safety
/// The context opaque pointer must be the EngineState of the engine.
unsafe fn state_of<'a>(context: *mut JSContext) -> &'a EngineState {
    unsafe { &*(JS_GetContextOpaque(context) as *const EngineState) }
}

/// Throws `new Error(message)` and returns the exception value.
///
/// # Safety
/// `context` must be a live context.
pub unsafe fn throw_error(context: *mut JSContext, message: &str) -> JSValue {
    unsafe {
        let error = JS_NewError(context);
        let text = new_string(context, message);
        let key = CString::new("message").unwrap_or_default();
        JS_DefinePropertyValueStr(context, error, key.as_ptr(), text, JS_PROP_WRITABLE | JS_PROP_CONFIGURABLE);

        JS_Throw(context, error)
    }
}

/// `__host(name, ...arguments)`: runs the host function of the game.
pub unsafe extern "C" fn host_call(
    context: *mut JSContext,
    _this: JSValue,
    count: c_int,
    arguments: *mut JSValue,
    _magic: c_int,
    _data: *mut JSValue,
) -> JSValue {
    unsafe {
        let state = state_of(context);
        let values = if count > 0 {
            std::slice::from_raw_parts(arguments, count as usize)
        } else {
            &[]
        };

        let Some(name) = values.first().and_then(|value| to_text(context, *value)) else {
            return throw_error(context, "__host needs a function name");
        };

        let Some(host) = state.host() else {
            return throw_error(context, &format!("No host function runs '{name}'"));
        };

        let data: Vec<JsData> = values[1..].iter().map(|value| from_js(context, *value)).collect();

        // a getter of an argument can throw
        if JS_HasException(context) {
            return JS_EXCEPTION;
        }

        match host(&name, data) {
            Ok(result) => to_js(context, &result),
            Err(message) => throw_error(context, &message),
        }
    }
}

/// Stops the script when a call from the game passes its deadline. QuickJS
/// then throws an uncatchable "interrupted" error.
pub unsafe extern "C" fn interrupt(_runtime: *mut JSRuntime, opaque: *mut c_void) -> c_int {
    let state = unsafe { &*(opaque as *const EngineState) };

    state.deadline_passed() as c_int
}

/// Keeps each rejected promise that has no handler, with its reason. A
/// handler that a later job adds removes it again. The engine reports the
/// rest after the jobs. This runs inside a promise operation, thus it calls
/// no JavaScript.
pub unsafe extern "C" fn track_rejection(
    context: *mut JSContext,
    promise: JSValue,
    reason: JSValue,
    is_handled: bool,
    opaque: *mut c_void,
) {
    unsafe {
        let state = &*(opaque as *const EngineState);
        let mut rejections = state.rejections.borrow_mut();

        if is_handled {
            if let Some(index) = rejections.iter().position(|(kept, _)| kept.u.ptr == promise.u.ptr) {
                let (kept, kept_reason) = rejections.remove(index);
                JS_FreeValue(context, kept);
                JS_FreeValue(context, kept_reason);
            }

            return;
        }

        rejections.push((JS_DupValue(context, promise), JS_DupValue(context, reason)));
    }
}
