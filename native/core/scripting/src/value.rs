//! `JsData` is a copy of a JavaScript value without Godot types, thus the
//! engine runs under `cargo test`. It converts to and from QuickJS values.
//! Functions, symbols and values deeper than `MAX_DEPTH` copy as `Undefined`.

use std::ffi::{CString, c_char};
use std::ptr;

use crate::ffi::*;

// a deeper value copies as Undefined. This also stops a reference cycle
pub const MAX_DEPTH: usize = 32;
// 2^53: a larger integer is not exact in a JavaScript number
const MAX_SAFE_INTEGER: f64 = 9_007_199_254_740_992.0;

#[derive(Clone, Debug, PartialEq)]
pub enum JsData {
    Undefined,
    Null,
    Bool(bool),
    Int(i64),
    Float(f64),
    String(String),
    Array(Vec<JsData>),
    // keys in the order of the object
    Object(Vec<(String, JsData)>),
}

impl JsData {
    pub fn object(entries: Vec<(&str, JsData)>) -> JsData {
        JsData::Object(entries.into_iter().map(|(key, value)| (key.to_string(), value)).collect())
    }

    #[cfg(test)]
    pub fn get(&self, key: &str) -> Option<&JsData> {
        match self {
            JsData::Object(entries) => entries.iter().find(|(name, _)| name == key).map(|(_, value)| value),
            _ => None,
        }
    }
}

/// A value that this code owns. Drop frees it.
pub struct Owned {
    context: *mut JSContext,
    value: JSValue,
}

impl Owned {
    /// # Safety
    /// `value` must be a value of `context` that the caller owns.
    pub unsafe fn new(context: *mut JSContext, value: JSValue) -> Owned {
        Owned { context, value }
    }

    pub fn value(&self) -> JSValue {
        self.value
    }
}

impl Drop for Owned {
    fn drop(&mut self) {
        unsafe { JS_FreeValue(self.context, self.value) };
    }
}

/// A new string value. A NUL in `text` stays in the string.
///
/// # Safety
/// `context` must be a live context.
pub unsafe fn new_string(context: *mut JSContext, text: &str) -> JSValue {
    unsafe { JS_NewStringLen(context, text.as_ptr() as *const c_char, text.len()) }
}

/// The text of a value, as `String(value)` gives it. None after an exception.
///
/// # Safety
/// `context` must be a live context and `value` a value of it.
pub unsafe fn to_text(context: *mut JSContext, value: JSValue) -> Option<String> {
    let mut length = 0usize;
    let pointer = unsafe { JS_ToCStringLen2(context, &mut length, value, false) };

    if pointer.is_null() {
        return None;
    }

    let bytes = unsafe { std::slice::from_raw_parts(pointer as *const u8, length) };
    let text = String::from_utf8_lossy(bytes).into_owned();
    unsafe { JS_FreeCString(context, pointer) };

    Some(text)
}

/// A new value with the contents of `data`.
///
/// # Safety
/// `context` must be a live context.
pub unsafe fn to_js(context: *mut JSContext, data: &JsData) -> JSValue {
    unsafe {
        match data {
            JsData::Undefined => JS_UNDEFINED,
            JsData::Null => JS_NULL,
            JsData::Bool(value) => osc_new_bool(context, *value as i32),
            JsData::Int(value) => osc_new_int64(context, *value),
            JsData::Float(value) => osc_new_float64(context, *value),
            JsData::String(text) => new_string(context, text),
            JsData::Array(items) => {
                let array = JS_NewArray(context);

                for (index, item) in items.iter().enumerate() {
                    JS_SetPropertyUint32(context, array, index as u32, to_js(context, item));
                }

                array
            }
            JsData::Object(entries) => {
                let object = JS_NewObject(context);

                for (key, item) in entries {
                    set_property(context, object, key, to_js(context, item));
                }

                object
            }
        }
    }
}

/// Sets `object[key]` and takes `value`. A key with a NUL is not set.
///
/// # Safety
/// `context` must be a live context, `object` and `value` values of it.
pub unsafe fn set_property(context: *mut JSContext, object: JSValue, key: &str, value: JSValue) {
    match CString::new(key) {
        Ok(name) => unsafe {
            JS_SetPropertyStr(context, object, name.as_ptr(), value);
        },
        Err(_) => unsafe { JS_FreeValue(context, value) },
    }
}

/// `object[key]`, owned by the caller.
///
/// # Safety
/// `context` must be a live context and `object` a value of it.
pub unsafe fn get_property(context: *mut JSContext, object: JSValue, key: &str) -> Owned {
    let name = CString::new(key).unwrap_or_default();

    unsafe { Owned::new(context, JS_GetPropertyStr(context, object, name.as_ptr())) }
}

/// A copy of `value`. A getter that throws leaves its exception pending; the
/// copy holds Undefined in that place.
///
/// # Safety
/// `context` must be a live context and `value` a value of it.
pub unsafe fn from_js(context: *mut JSContext, value: JSValue) -> JsData {
    unsafe { copy_value(context, value, 0) }
}

unsafe fn copy_value(context: *mut JSContext, value: JSValue, depth: usize) -> JsData {
    match value.tag() {
        JS_TAG_UNDEFINED => JsData::Undefined,
        JS_TAG_NULL => JsData::Null,
        JS_TAG_BOOL => JsData::Bool(unsafe { value.u.int32 } != 0),
        JS_TAG_INT => JsData::Int(unsafe { value.u.int32 } as i64),
        JS_TAG_FLOAT64 => number(unsafe { value.u.float64 }),
        JS_TAG_STRING | JS_TAG_STRING_ROPE => JsData::String(unsafe { to_text(context, value) }.unwrap_or_default()),
        JS_TAG_BIG_INT | JS_TAG_SHORT_BIG_INT => big_int(unsafe { to_text(context, value) }.unwrap_or_default()),
        JS_TAG_OBJECT if depth < MAX_DEPTH => unsafe { copy_object(context, value, depth) },
        _ => JsData::Undefined,
    }
}

/// An integral number in the exact range copies as an integer.
fn number(value: f64) -> JsData {
    if value.fract() == 0.0 && value.abs() < MAX_SAFE_INTEGER && !(value == 0.0 && value.is_sign_negative()) {
        JsData::Int(value as i64)
    } else {
        JsData::Float(value)
    }
}

fn big_int(text: String) -> JsData {
    match text.parse::<i64>() {
        Ok(value) => JsData::Int(value),
        Err(_) => JsData::String(text),
    }
}

unsafe fn copy_object(context: *mut JSContext, value: JSValue, depth: usize) -> JsData {
    unsafe {
        if JS_IsFunction(context, value) {
            return JsData::Undefined;
        }

        // an error copies as its text, "TypeError: message"
        if JS_IsError(value) {
            return JsData::String(to_text(context, value).unwrap_or_default());
        }

        if JS_IsArray(value) {
            return copy_array(context, value, depth);
        }

        copy_entries(context, value, depth)
    }
}

unsafe fn copy_array(context: *mut JSContext, value: JSValue, depth: usize) -> JsData {
    unsafe {
        let length_value = get_property(context, value, "length");
        let mut length = 0.0;
        JS_ToFloat64(context, &mut length, length_value.value());
        let mut items = Vec::with_capacity(length as usize);

        for index in 0..length as u32 {
            let item = Owned::new(context, JS_GetPropertyUint32(context, value, index));
            items.push(copy_value(context, item.value(), depth + 1));
        }

        JsData::Array(items)
    }
}

unsafe fn copy_entries(context: *mut JSContext, value: JSValue, depth: usize) -> JsData {
    unsafe {
        let mut table: *mut JSPropertyEnum = ptr::null_mut();
        let mut count = 0u32;

        if JS_GetOwnPropertyNames(context, &mut table, &mut count, value, JS_GPN_STRING_MASK | JS_GPN_ENUM_ONLY) < 0 {
            return JsData::Undefined;
        }

        let mut entries = Vec::with_capacity(count as usize);

        for index in 0..count as usize {
            let atom = (*table.add(index)).atom;
            let mut length = 0usize;
            let pointer = JS_AtomToCStringLen(context, &mut length, atom);

            if pointer.is_null() {
                continue;
            }

            let key = String::from_utf8_lossy(std::slice::from_raw_parts(pointer as *const u8, length)).into_owned();
            JS_FreeCString(context, pointer);
            let item = get_property(context, value, &key);
            let data = copy_value(context, item.value(), depth + 1);

            // a method of the object is not data
            if data != JsData::Undefined || item.value().is_undefined() {
                entries.push((key, data));
            }
        }

        JS_FreePropertyEnum(context, table, count);

        JsData::Object(entries)
    }
}
