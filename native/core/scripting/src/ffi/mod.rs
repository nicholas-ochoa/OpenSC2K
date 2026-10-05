//! The raw C API of QuickJS-ng that the runtime uses, and the helpers of
//! `shim.c`. Only the 64-bit build is supported: there, a `JSValue` is a
//! 16-byte struct of a value union and a tag. `shim.c` checks this size.
#![allow(non_camel_case_types, non_snake_case, dead_code)]

use std::ffi::{c_char, c_int, c_void};

#[repr(C)]
pub struct JSRuntime {
    _private: [u8; 0],
}

#[repr(C)]
pub struct JSContext {
    _private: [u8; 0],
}

#[repr(C)]
pub struct JSModuleDef {
    _private: [u8; 0],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub union JSValueUnion {
    pub int32: i32,
    pub float64: f64,
    pub ptr: *mut c_void,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct JSValue {
    pub u: JSValueUnion,
    pub tag: i64,
}

pub type JSAtom = u32;

#[repr(C)]
pub struct JSPropertyEnum {
    pub is_enumerable: bool,
    pub atom: JSAtom,
}

#[repr(C)]
#[derive(Default)]
pub struct JSMemoryUsage {
    pub malloc_size: i64,
    pub malloc_limit: i64,
    pub memory_used_size: i64,
    pub malloc_count: i64,
    pub memory_used_count: i64,
    pub atom_count: i64,
    pub atom_size: i64,
    pub str_count: i64,
    pub str_size: i64,
    pub obj_count: i64,
    pub obj_size: i64,
    pub prop_count: i64,
    pub prop_size: i64,
    pub shape_count: i64,
    pub shape_size: i64,
    pub js_func_count: i64,
    pub js_func_size: i64,
    pub js_func_code_size: i64,
    pub js_func_pc2line_count: i64,
    pub js_func_pc2line_size: i64,
    pub c_func_count: i64,
    pub array_count: i64,
    pub fast_array_count: i64,
    pub fast_array_elements: i64,
    pub binary_object_count: i64,
    pub binary_object_size: i64,
}

// value tags
pub const JS_TAG_BIG_INT: i32 = -9;
pub const JS_TAG_SYMBOL: i32 = -8;
pub const JS_TAG_STRING: i32 = -7;
pub const JS_TAG_STRING_ROPE: i32 = -6;
pub const JS_TAG_MODULE: i32 = -3;
pub const JS_TAG_OBJECT: i32 = -1;
pub const JS_TAG_INT: i32 = 0;
pub const JS_TAG_BOOL: i32 = 1;
pub const JS_TAG_NULL: i32 = 2;
pub const JS_TAG_UNDEFINED: i32 = 3;
pub const JS_TAG_EXCEPTION: i32 = 6;
pub const JS_TAG_SHORT_BIG_INT: i32 = 7;
pub const JS_TAG_FLOAT64: i32 = 8;

// JS_Eval flags
pub const JS_EVAL_TYPE_GLOBAL: c_int = 0;
pub const JS_EVAL_TYPE_MODULE: c_int = 1;
pub const JS_EVAL_FLAG_STRICT: c_int = 1 << 3;
pub const JS_EVAL_FLAG_COMPILE_ONLY: c_int = 1 << 5;
pub const JS_EVAL_FLAG_ASYNC: c_int = 1 << 7;

// JS_GetOwnPropertyNames flags
pub const JS_GPN_STRING_MASK: c_int = 1;
pub const JS_GPN_ENUM_ONLY: c_int = 1 << 4;

// property flags
pub const JS_PROP_CONFIGURABLE: c_int = 1;
pub const JS_PROP_WRITABLE: c_int = 1 << 1;

// JSPromiseStateEnum
pub const JS_PROMISE_PENDING: c_int = 0;
pub const JS_PROMISE_FULFILLED: c_int = 1;
pub const JS_PROMISE_REJECTED: c_int = 2;

pub type JSCFunctionData = unsafe extern "C" fn(
    ctx: *mut JSContext,
    this_val: JSValue,
    argc: c_int,
    argv: *mut JSValue,
    magic: c_int,
    data: *mut JSValue,
) -> JSValue;

pub type JSInterruptHandler = unsafe extern "C" fn(rt: *mut JSRuntime, opaque: *mut c_void) -> c_int;

pub type JSHostPromiseRejectionTracker =
    unsafe extern "C" fn(ctx: *mut JSContext, promise: JSValue, reason: JSValue, is_handled: bool, opaque: *mut c_void);

pub type JSModuleNormalizeFunc =
    unsafe extern "C" fn(ctx: *mut JSContext, base: *const c_char, name: *const c_char, opaque: *mut c_void) -> *mut c_char;

pub type JSModuleLoaderFunc = unsafe extern "C" fn(ctx: *mut JSContext, name: *const c_char, opaque: *mut c_void) -> *mut JSModuleDef;

unsafe extern "C" {
    pub fn JS_NewRuntime() -> *mut JSRuntime;
    pub fn JS_FreeRuntime(rt: *mut JSRuntime);
    pub fn JS_SetMemoryLimit(rt: *mut JSRuntime, limit: usize);
    pub fn JS_SetMaxStackSize(rt: *mut JSRuntime, stack_size: usize);
    pub fn JS_UpdateStackTop(rt: *mut JSRuntime);
    pub fn JS_RunGC(rt: *mut JSRuntime);
    pub fn JS_ComputeMemoryUsage(rt: *mut JSRuntime, usage: *mut JSMemoryUsage);
    pub fn JS_SetInterruptHandler(rt: *mut JSRuntime, handler: Option<JSInterruptHandler>, opaque: *mut c_void);
    pub fn JS_SetHostPromiseRejectionTracker(rt: *mut JSRuntime, tracker: Option<JSHostPromiseRejectionTracker>, opaque: *mut c_void);
    pub fn JS_SetModuleLoaderFunc(
        rt: *mut JSRuntime,
        normalize: Option<JSModuleNormalizeFunc>,
        loader: Option<JSModuleLoaderFunc>,
        opaque: *mut c_void,
    );
    pub fn JS_IsJobPending(rt: *mut JSRuntime) -> bool;
    pub fn JS_ExecutePendingJob(rt: *mut JSRuntime, pctx: *mut *mut JSContext) -> c_int;

    pub fn JS_NewContext(rt: *mut JSRuntime) -> *mut JSContext;
    pub fn JS_FreeContext(ctx: *mut JSContext);
    pub fn JS_GetContextOpaque(ctx: *mut JSContext) -> *mut c_void;
    pub fn JS_GetRuntime(ctx: *mut JSContext) -> *mut JSRuntime;
    pub fn JS_SetContextOpaque(ctx: *mut JSContext, opaque: *mut c_void);
    pub fn JS_GetVersion() -> *const c_char;

    pub fn JS_FreeValue(ctx: *mut JSContext, value: JSValue);
    pub fn JS_DupValue(ctx: *mut JSContext, value: JSValue) -> JSValue;

    pub fn JS_Eval(ctx: *mut JSContext, input: *const c_char, input_len: usize, filename: *const c_char, flags: c_int) -> JSValue;
    pub fn JS_EvalFunction(ctx: *mut JSContext, function: JSValue) -> JSValue;
    pub fn JS_DetectModule(input: *const c_char, input_len: usize) -> bool;
    pub fn JS_Call(ctx: *mut JSContext, function: JSValue, this_val: JSValue, argc: c_int, argv: *mut JSValue) -> JSValue;
    pub fn JS_GetGlobalObject(ctx: *mut JSContext) -> JSValue;

    pub fn JS_Throw(ctx: *mut JSContext, value: JSValue) -> JSValue;
    pub fn JS_GetException(ctx: *mut JSContext) -> JSValue;
    pub fn JS_HasException(ctx: *mut JSContext) -> bool;
    pub fn JS_IsError(value: JSValue) -> bool;
    pub fn JS_NewError(ctx: *mut JSContext) -> JSValue;

    pub fn JS_NewObject(ctx: *mut JSContext) -> JSValue;
    pub fn JS_NewArray(ctx: *mut JSContext) -> JSValue;
    pub fn JS_NewStringLen(ctx: *mut JSContext, text: *const c_char, len: usize) -> JSValue;
    pub fn JS_NewCFunctionData(
        ctx: *mut JSContext,
        function: JSCFunctionData,
        length: c_int,
        magic: c_int,
        data_len: c_int,
        data: *mut JSValue,
    ) -> JSValue;

    pub fn JS_NewUint8ArrayCopy(ctx: *mut JSContext, buf: *const u8, len: usize) -> JSValue;
    pub fn JS_GetUint8Array(ctx: *mut JSContext, psize: *mut usize, object: JSValue) -> *mut u8;
    pub fn JS_IsArray(value: JSValue) -> bool;
    pub fn JS_IsFunction(ctx: *mut JSContext, value: JSValue) -> bool;
    pub fn JS_ToBool(ctx: *mut JSContext, value: JSValue) -> c_int;
    pub fn JS_ToFloat64(ctx: *mut JSContext, result: *mut f64, value: JSValue) -> c_int;
    pub fn JS_ToCStringLen2(ctx: *mut JSContext, len: *mut usize, value: JSValue, cesu8: bool) -> *const c_char;
    pub fn JS_FreeCString(ctx: *mut JSContext, text: *const c_char);

    pub fn JS_GetPropertyStr(ctx: *mut JSContext, object: JSValue, name: *const c_char) -> JSValue;
    pub fn JS_SetPropertyStr(ctx: *mut JSContext, object: JSValue, name: *const c_char, value: JSValue) -> c_int;
    pub fn JS_GetPropertyUint32(ctx: *mut JSContext, object: JSValue, index: u32) -> JSValue;
    pub fn JS_SetPropertyUint32(ctx: *mut JSContext, object: JSValue, index: u32, value: JSValue) -> c_int;
    pub fn JS_DefinePropertyValueStr(ctx: *mut JSContext, object: JSValue, name: *const c_char, value: JSValue, flags: c_int) -> c_int;
    pub fn JS_GetOwnPropertyNames(
        ctx: *mut JSContext,
        table: *mut *mut JSPropertyEnum,
        len: *mut u32,
        object: JSValue,
        flags: c_int,
    ) -> c_int;
    pub fn JS_FreePropertyEnum(ctx: *mut JSContext, table: *mut JSPropertyEnum, len: u32);
    pub fn JS_AtomToCStringLen(ctx: *mut JSContext, len: *mut usize, atom: JSAtom) -> *const c_char;

    pub fn JS_PromiseState(ctx: *mut JSContext, promise: JSValue) -> c_int;
    pub fn JS_PromiseResult(ctx: *mut JSContext, promise: JSValue) -> JSValue;

    pub fn osc_new_bool(ctx: *mut JSContext, value: c_int) -> JSValue;
    pub fn osc_new_int64(ctx: *mut JSContext, value: i64) -> JSValue;
    pub fn osc_new_float64(ctx: *mut JSContext, value: f64) -> JSValue;
    pub fn osc_module_of(value: JSValue) -> *mut JSModuleDef;
}

pub const fn make_value(tag: i32, int32: i32) -> JSValue {
    JSValue {
        u: JSValueUnion { int32 },
        tag: tag as i64,
    }
}

pub const JS_UNDEFINED: JSValue = make_value(JS_TAG_UNDEFINED, 0);
pub const JS_NULL: JSValue = make_value(JS_TAG_NULL, 0);
pub const JS_EXCEPTION: JSValue = make_value(JS_TAG_EXCEPTION, 0);

impl JSValue {
    pub fn tag(&self) -> i32 {
        self.tag as i32
    }

    pub fn is_exception(&self) -> bool {
        self.tag() == JS_TAG_EXCEPTION
    }

    pub fn is_undefined(&self) -> bool {
        self.tag() == JS_TAG_UNDEFINED
    }

    pub fn is_object(&self) -> bool {
        self.tag() == JS_TAG_OBJECT
    }
}
