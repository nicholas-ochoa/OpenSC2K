//! `__inspectorNative`, the functions that `inspector.js` needs from the
//! engine. One C function serves all of them; the magic number selects the
//! function. `inspector.js` takes the object and removes the global.

use std::ffi::{CString, c_char, c_int};

use super::callbacks::throw_error;
use super::state::EngineState;
use crate::ffi::*;
use crate::inspector::Outgoing;
use crate::value::{JsData, to_js, to_text};

pub const GLOBAL_NAME: &str = "__inspectorNative";
// the file name of DevTools console input in error stacks
const DEVTOOLS_FILE_NAME: &str = "<devtools>";

// (name, magic, argument count)
pub const FUNCTIONS: [(&str, c_int, c_int); 6] = [
    ("send", SEND, 1),
    ("evaluate", EVALUATE, 1),
    ("check", CHECK, 1),
    ("scripts", SCRIPTS, 1),
    ("memory", MEMORY, 0),
    ("collectGarbage", COLLECT_GARBAGE, 0),
];

const SEND: c_int = 0;
const EVALUATE: c_int = 1;
const CHECK: c_int = 2;
const SCRIPTS: c_int = 3;
const MEMORY: c_int = 4;
const COLLECT_GARBAGE: c_int = 5;

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
        let values = if count > 0 {
            std::slice::from_raw_parts(arguments, count as usize)
        } else {
            &[]
        };
        let first_text = || values.first().and_then(|value| to_text(context, *value)).unwrap_or_default();

        match magic {
            SEND => send(state, first_text()),
            EVALUATE => eval(context, &first_text(), JS_EVAL_TYPE_GLOBAL | JS_EVAL_FLAG_ASYNC),
            CHECK => {
                let compiled = eval(
                    context,
                    &first_text(),
                    JS_EVAL_TYPE_GLOBAL | JS_EVAL_FLAG_ASYNC | JS_EVAL_FLAG_COMPILE_ONLY,
                );

                if compiled.is_exception() {
                    return compiled;
                }

                JS_FreeValue(context, compiled);

                JS_UNDEFINED
            }
            SCRIPTS => {
                let mut from = 0.0;

                if let Some(value) = values.first() {
                    JS_ToFloat64(context, &mut from, *value);
                }

                to_js(context, &scripts(state, from.max(0.0) as usize))
            }
            MEMORY => memory(context),
            COLLECT_GARBAGE => {
                JS_RunGC(JS_GetRuntime(context));

                JS_UNDEFINED
            }
            _ => throw_error(context, "Unknown inspector function"),
        }
    }
}

fn send(state: &EngineState, text: String) -> JSValue {
    if let Some(sender) = state.inspector_out.borrow().as_ref() {
        let _ = sender.send(Outgoing::Text(text));
    }

    JS_UNDEFINED
}

/// Runs DevTools input. Top-level await is allowed, thus the result is the
/// promise of `{ value }`.
unsafe fn eval(context: *mut JSContext, source: &str, flags: i32) -> JSValue {
    let mut bytes = source.as_bytes().to_vec();
    bytes.push(0);
    let name = CString::new(DEVTOOLS_FILE_NAME).unwrap_or_default();

    unsafe { JS_Eval(context, bytes.as_ptr() as *const c_char, source.len(), name.as_ptr(), flags) }
}

/// The scripts from index `from`: `[{ id, name, source, module }]`.
fn scripts(state: &EngineState, from: usize) -> JsData {
    let scripts = state.scripts.borrow();

    JsData::Array(
        scripts
            .iter()
            .enumerate()
            .skip(from)
            .map(|(index, script)| {
                JsData::object(vec![
                    ("id", JsData::String((index + 1).to_string())),
                    ("name", JsData::String(script.name.clone())),
                    ("source", JsData::String(script.source.clone())),
                    ("module", JsData::Bool(script.module)),
                ])
            })
            .collect(),
    )
}

unsafe fn memory(context: *mut JSContext) -> JSValue {
    let mut usage = JSMemoryUsage::default();

    unsafe {
        JS_ComputeMemoryUsage(JS_GetRuntime(context), &mut usage);

        to_js(
            context,
            &JsData::object(vec![
                ("used", JsData::Int(usage.memory_used_size)),
                ("total", JsData::Int(usage.malloc_limit)),
            ]),
        )
    }
}
