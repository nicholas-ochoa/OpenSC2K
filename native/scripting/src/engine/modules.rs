//! Loads ES modules from files. A module name is a file path: QuickJS
//! resolves `./` and `../` names from the path of the importing module.

use std::ffi::{CStr, c_char, c_void};

use super::callbacks::throw_error;
use super::state::EngineState;
use crate::ffi::*;

/// The opaque pointer is the EngineState, which keeps the module source.
pub unsafe extern "C" fn load_module(context: *mut JSContext, name: *const c_char, opaque: *mut c_void) -> *mut JSModuleDef {
    unsafe {
        let path = CStr::from_ptr(name).to_string_lossy().into_owned();

        let mut source = match std::fs::read(&path) {
            Ok(bytes) => bytes,
            Err(error) => {
                throw_error(context, &format!("Cannot load the module {path}: {error}"));

                return std::ptr::null_mut();
            }
        };

        let state = &*(opaque as *const EngineState);
        state.record_script(&path, &String::from_utf8_lossy(&source), true);

        // JS_Eval needs a NUL after the source
        let length = source.len();
        source.push(0);
        let compiled = JS_Eval(
            context,
            source.as_ptr() as *const c_char,
            length,
            name,
            JS_EVAL_TYPE_MODULE | JS_EVAL_FLAG_COMPILE_ONLY,
        );

        if compiled.is_exception() {
            return std::ptr::null_mut();
        }

        // the runtime keeps the module. The value only refers to it
        let module = osc_module_of(compiled);
        JS_FreeValue(context, compiled);

        module
    }
}
