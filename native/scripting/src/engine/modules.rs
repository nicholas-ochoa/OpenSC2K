//! Loads ES modules from files. A module name is a file path: QuickJS
//! resolves `./` and `../` names from the path of the importing module. In
//! the runtime of a mod, the sandbox refuses a module outside the mod folder.

use std::ffi::{CStr, c_char, c_void};
use std::path::PathBuf;

use super::callbacks::throw_error;
use super::state::EngineState;
use crate::ffi::*;

/// The opaque pointer is the EngineState, which keeps the module source.
pub unsafe extern "C" fn load_module(context: *mut JSContext, name: *const c_char, opaque: *mut c_void) -> *mut JSModuleDef {
    unsafe {
        let path = CStr::from_ptr(name).to_string_lossy().into_owned();
        let state = &*(opaque as *const EngineState);

        // a mod imports only the files in its own folder
        let file = match state.sandbox.get().map(|sandbox| sandbox.module_path(&path)) {
            Some(Ok(file)) => file,
            Some(Err(message)) => {
                throw_error(context, &message);

                return std::ptr::null_mut();
            }
            None => PathBuf::from(&path),
        };

        let mut source = match std::fs::read(&file) {
            Ok(bytes) => bytes,
            Err(error) => {
                throw_error(context, &format!("Cannot load the module {path}: {error}"));

                return std::ptr::null_mut();
            }
        };

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
