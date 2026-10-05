//! `__files`, the file functions of a mod in its own folder. The engine
//! adds this global only after `Engine::set_sandbox`. One C function serves
//! all of them; the magic number selects the function. The game API takes
//! the object as `mod.files` and removes the global. Each path is relative
//! to the mod folder; `Sandbox` refuses the others.

use std::ffi::c_int;

use super::callbacks::throw_error;
use super::state::EngineState;
use crate::ffi::*;
use crate::sandbox::{FileEntry, Sandbox};
use crate::value::{JsData, new_string, to_js, to_text};

pub const GLOBAL_NAME: &str = "__files";

// (name, magic, argument count)
pub const FUNCTIONS: [(&str, c_int, c_int); 9] = [
    ("readText", READ_TEXT, 1),
    ("readBytes", READ_BYTES, 1),
    ("write", WRITE, 3),
    ("exists", EXISTS, 1),
    ("stat", STAT, 1),
    ("list", LIST, 1),
    ("makeFolder", MAKE_FOLDER, 1),
    ("remove", REMOVE, 2),
    ("rename", RENAME, 2),
];

const READ_TEXT: c_int = 0;
const READ_BYTES: c_int = 1;
const WRITE: c_int = 2;
const EXISTS: c_int = 3;
const STAT: c_int = 4;
const LIST: c_int = 5;
const MAKE_FOLDER: c_int = 6;
const REMOVE: c_int = 7;
const RENAME: c_int = 8;

/// # Safety
/// QuickJS calls this with the context of the engine.
pub unsafe extern "C" fn call(
    context: *mut JSContext,
    _this: JSValue,
    count: c_int,
    arguments: *mut JSValue,
    magic: c_int,
    _data: *mut JSValue,
) -> JSValue {
    unsafe {
        let state = &*(JS_GetContextOpaque(context) as *const EngineState);

        let Some(sandbox) = state.sandbox.get() else {
            return throw_error(context, "Only a mod has a folder for files");
        };

        let values = if count > 0 {
            std::slice::from_raw_parts(arguments, count as usize)
        } else {
            &[]
        };

        let Some(path) = values.first().and_then(|value| to_text(context, *value)) else {
            return JS_EXCEPTION;
        };

        let result = run(context, sandbox, magic, &path, &values[1..]);

        match result {
            Ok(value) => value,
            Err(message) => throw_error(context, &message),
        }
    }
}

unsafe fn run(context: *mut JSContext, sandbox: &Sandbox, magic: c_int, path: &str, rest: &[JSValue]) -> Result<JSValue, String> {
    unsafe {
        match magic {
            READ_TEXT => {
                let bytes = sandbox.read(path)?;

                Ok(new_string(context, &String::from_utf8_lossy(&bytes)))
            }
            READ_BYTES => {
                let bytes = sandbox.read(path)?;

                Ok(JS_NewUint8ArrayCopy(context, bytes.as_ptr(), bytes.len()))
            }
            WRITE => {
                let data = rest.first().copied().unwrap_or(JS_UNDEFINED);
                let append = rest.get(1).is_some_and(|value| JS_ToBool(context, *value) == 1);
                write(context, sandbox, path, data, append)?;

                Ok(JS_UNDEFINED)
            }
            EXISTS => Ok(to_js(context, &JsData::Bool(sandbox.exists(path)?))),
            STAT => {
                let entry = sandbox.stat(path)?;

                Ok(to_js(context, &entry.map_or(JsData::Null, |entry| entry_data(&entry))))
            }
            LIST => {
                let entries = sandbox.list(path)?;

                Ok(to_js(context, &JsData::Array(entries.iter().map(entry_data).collect())))
            }
            MAKE_FOLDER => {
                sandbox.make_folder(path)?;

                Ok(JS_UNDEFINED)
            }
            REMOVE => {
                let recursive = rest.first().is_some_and(|value| JS_ToBool(context, *value) == 1);

                Ok(to_js(context, &JsData::Bool(sandbox.remove(path, recursive)?)))
            }
            RENAME => {
                let target = rest
                    .first()
                    .and_then(|value| to_text(context, *value))
                    .ok_or_else(|| "rename needs the new path".to_string())?;
                sandbox.rename(path, &target)?;

                Ok(JS_UNDEFINED)
            }
            _ => Err("Unknown file function".to_string()),
        }
    }
}

/// Writes a string as UTF-8, or the bytes of a Uint8Array.
unsafe fn write(context: *mut JSContext, sandbox: &Sandbox, path: &str, data: JSValue, append: bool) -> Result<(), String> {
    unsafe {
        if data.tag() == JS_TAG_STRING || data.tag() == JS_TAG_STRING_ROPE {
            let text = to_text(context, data).unwrap_or_default();

            return sandbox.write(path, text.as_bytes(), append);
        }

        let mut size = 0usize;
        let pointer = JS_GetUint8Array(context, &mut size, data);

        if pointer.is_null() {
            // the TypeError of QuickJS; the message below replaces it
            JS_FreeValue(context, JS_GetException(context));

            return Err("The file data must be a string or a Uint8Array".to_string());
        }

        // a copy: the write cannot run JavaScript, but the slice must not
        // outlive a buffer that a later call could detach
        let bytes = std::slice::from_raw_parts(pointer, size).to_vec();

        sandbox.write(path, &bytes, append)
    }
}

fn entry_data(entry: &FileEntry) -> JsData {
    JsData::object(vec![
        ("name", JsData::String(entry.name.clone())),
        ("type", JsData::String(entry.kind.name().to_string())),
        ("size", JsData::Int(entry.size as i64)),
        ("modified", JsData::Int(entry.modified)),
    ])
}
