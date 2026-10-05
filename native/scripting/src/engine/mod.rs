//! `Engine` owns one QuickJS runtime and its context. All calls come from
//! one thread. A host function can call into the engine again, thus each
//! method takes `&self` and holds no borrow while JavaScript runs.

mod callbacks;
mod modules;
mod state;

use std::ffi::{CString, c_char, c_void};
use std::time::Duration;

pub use state::HostFunction;
use state::{EngineState, Entry};

use crate::ffi::*;
use crate::value::{JsData, Owned, from_js, get_property, to_js, to_text};

// the heap of one runtime. A larger script stops with an out-of-memory error
const MEMORY_LIMIT: usize = 256 * 1024 * 1024;
// the C stack that JavaScript calls can use. The Windows main thread has 1 MiB
const STACK_LIMIT: usize = 512 * 1024;
// the file name of console input in error stacks
pub const CONSOLE_FILE_NAME: &str = "<console>";
const RUNTIME_FILE_NAME: &str = "opensc2k:runtime";
// the runtime core defines this global; see prelude.js
const RUNTIME_GLOBAL: &str = "__runtime";
const HOST_GLOBAL: &str = "__host";
const MODULE_EXTENSION: &str = ".mjs";

pub struct Engine {
    runtime: *mut JSRuntime,
    context: *mut JSContext,
    // boxed, thus the opaque pointers of the runtime and the context stay valid
    state: Box<EngineState>,
}

impl Engine {
    /// A new runtime with `__host` and the runtime core of `prelude.js`.
    pub fn new() -> Result<Engine, String> {
        let runtime = unsafe { JS_NewRuntime() };

        if runtime.is_null() {
            return Err("Cannot create the JavaScript runtime.".to_string());
        }

        let context = unsafe { JS_NewContext(runtime) };

        if context.is_null() {
            unsafe { JS_FreeRuntime(runtime) };

            return Err("Cannot create the JavaScript context.".to_string());
        }

        let engine = Engine {
            runtime,
            context,
            state: Box::new(EngineState::new()),
        };

        engine.install_callbacks();
        engine.run_script(include_str!("../prelude.js"), RUNTIME_FILE_NAME)?;

        Ok(engine)
    }

    fn install_callbacks(&self) {
        let opaque = &*self.state as *const EngineState as *mut c_void;

        unsafe {
            JS_SetMemoryLimit(self.runtime, MEMORY_LIMIT);
            JS_SetMaxStackSize(self.runtime, STACK_LIMIT);
            JS_SetContextOpaque(self.context, opaque);
            JS_SetInterruptHandler(self.runtime, Some(callbacks::interrupt), opaque);
            JS_SetHostPromiseRejectionTracker(self.runtime, Some(callbacks::track_rejection), opaque);
            JS_SetModuleLoaderFunc(self.runtime, None, Some(modules::load_module), std::ptr::null_mut());

            let global = Owned::new(self.context, JS_GetGlobalObject(self.context));
            let host = JS_NewCFunctionData(self.context, callbacks::host_call, 1, 0, 0, std::ptr::null_mut());
            crate::value::set_property(self.context, global.value(), HOST_GLOBAL, host);
        }
    }

    pub fn set_host(&self, host: Option<HostFunction>) {
        *self.state.host.borrow_mut() = host;
    }

    /// The time that one call from the game may take. Zero turns the limit off.
    pub fn set_time_limit(&self, limit: Duration) {
        self.state.time_limit.set(limit);
    }

    pub fn time_limit(&self) -> Duration {
        self.state.time_limit.get()
    }

    /// Runs console input. Top-level `await` is allowed. The result is the
    /// inspected value, or None for undefined and for a pending promise, which
    /// prints its value when it settles.
    pub fn eval_console(&self, source: &str) -> Result<Option<String>, String> {
        let _entry = Entry::new(&self.state, self.runtime);
        let promise = self.eval(
            &SourceText::new(source),
            CONSOLE_FILE_NAME,
            JS_EVAL_TYPE_GLOBAL | JS_EVAL_FLAG_ASYNC,
        )?;
        self.run_jobs();
        let state = unsafe { JS_PromiseState(self.context, promise.value()) };

        let result = match state {
            JS_PROMISE_FULFILLED => {
                let completion = unsafe { Owned::new(self.context, JS_PromiseResult(self.context, promise.value())) };
                let value = unsafe { get_property(self.context, completion.value(), "value") };

                if value.value().is_undefined() {
                    Ok(None)
                } else {
                    Ok(Some(self.inspect(value.value())))
                }
            }
            JS_PROMISE_REJECTED => Err(self.promise_error(&promise)),
            _ => {
                self.call_runtime("settle", &[promise.value()]);

                Ok(None)
            }
        };

        self.finish_call();

        result
    }

    /// Runs a script file. An `.mjs` file, or a file with `import` or
    /// `export`, runs as a module, and can import other files by relative path.
    pub fn run_script(&self, source: &str, file_name: &str) -> Result<(), String> {
        let _entry = Entry::new(&self.state, self.runtime);
        let input = SourceText::new(source);
        let module = file_name.ends_with(MODULE_EXTENSION) || unsafe { JS_DetectModule(input.pointer(), input.length()) };
        let flags = if module { JS_EVAL_TYPE_MODULE } else { JS_EVAL_TYPE_GLOBAL };
        let value = self.eval(&input, file_name, flags)?;
        self.run_jobs();

        // a module returns the promise of its evaluation
        let result = if unsafe { JS_PromiseState(self.context, value.value()) } == JS_PROMISE_REJECTED {
            Err(self.promise_error(&value))
        } else {
            Ok(())
        };

        self.finish_call();

        result
    }

    /// Calls the function at a global path such as `__runtime.dispatch`. The
    /// object before the last name is `this`.
    pub fn call(&self, path: &str, arguments: &[JsData]) -> Result<JsData, String> {
        let _entry = Entry::new(&self.state, self.runtime);
        let result = self.call_path(path, arguments);
        self.finish_call();

        result
    }

    /// Runs the queued promise jobs, then reports each rejection without a handler.
    pub fn run_pending_jobs(&self) {
        let _entry = Entry::new(&self.state, self.runtime);
        self.finish_call();
    }

    pub fn has_pending_jobs(&self) -> bool {
        unsafe { JS_IsJobPending(self.runtime) }
    }

    pub fn collect_garbage(&self) {
        unsafe { JS_RunGC(self.runtime) };
    }

    /// The heap counts of the runtime.
    pub fn memory_usage(&self) -> JsData {
        let mut usage = JSMemoryUsage::default();
        unsafe { JS_ComputeMemoryUsage(self.runtime, &mut usage) };

        JsData::object(vec![
            ("memory_used", JsData::Int(usage.memory_used_size)),
            ("memory_limit", JsData::Int(usage.malloc_limit)),
            ("allocations", JsData::Int(usage.malloc_count)),
            ("objects", JsData::Int(usage.obj_count)),
            ("strings", JsData::Int(usage.str_count)),
            ("functions", JsData::Int(usage.js_func_count)),
        ])
    }

    pub fn version() -> String {
        let pointer = unsafe { JS_GetVersion() };

        if pointer.is_null() {
            return String::new();
        }

        unsafe { std::ffi::CStr::from_ptr(pointer) }.to_string_lossy().into_owned()
    }

    fn eval(&self, source: &SourceText, file_name: &str, flags: i32) -> Result<Owned, String> {
        let name = CString::new(file_name.replace('\0', "")).unwrap_or_default();
        let value = unsafe { JS_Eval(self.context, source.pointer(), source.length(), name.as_ptr(), flags) };

        if value.is_exception() {
            let error = self.take_exception();
            self.finish_call();

            return Err(error);
        }

        Ok(unsafe { Owned::new(self.context, value) })
    }

    fn call_path(&self, path: &str, arguments: &[JsData]) -> Result<JsData, String> {
        let mut this = unsafe { Owned::new(self.context, JS_GetGlobalObject(self.context)) };
        let mut function = unsafe { Owned::new(self.context, JS_DupValue(self.context, this.value())) };

        for name in path.split('.') {
            let next = unsafe { get_property(self.context, function.value(), name) };
            this = function;
            function = next;
        }

        if !unsafe { JS_IsFunction(self.context, function.value()) } {
            return Err(format!("TypeError: {path} is not a function"));
        }

        let mut values: Vec<JSValue> = arguments.iter().map(|argument| unsafe { to_js(self.context, argument) }).collect();
        let result = unsafe {
            JS_Call(
                self.context,
                function.value(),
                this.value(),
                values.len() as i32,
                values.as_mut_ptr(),
            )
        };

        for value in values {
            unsafe { JS_FreeValue(self.context, value) };
        }

        if result.is_exception() {
            return Err(self.take_exception());
        }

        let result = unsafe { Owned::new(self.context, result) };
        let data = unsafe { from_js(self.context, result.value()) };

        // a getter of the result can throw
        if unsafe { JS_HasException(self.context) } {
            return Err(self.take_exception());
        }

        Ok(data)
    }

    /// After the outermost call: runs the promise jobs and reports rejections.
    fn finish_call(&self) {
        if self.state.depth.get() > 1 {
            return;
        }

        self.run_jobs();
        self.report_rejections();
    }

    fn run_jobs(&self) {
        loop {
            // a job loop that passes the deadline continues after the next call
            if self.state.deadline_passed() {
                break;
            }

            let mut job_context: *mut JSContext = std::ptr::null_mut();
            let status = unsafe { JS_ExecutePendingJob(self.runtime, &mut job_context) };

            if status == 0 {
                break;
            }

            if status < 0 {
                let error = self.take_exception();
                self.state.report("error", &format!("Uncaught {error}"));
            }
        }
    }

    fn report_rejections(&self) {
        let rejections = std::mem::take(&mut *self.state.rejections.borrow_mut());

        for (promise, reason) in rejections {
            let text = self.format_error(reason);
            self.state.report("error", &format!("Uncaught (in promise) {text}"));

            unsafe {
                JS_FreeValue(self.context, promise);
                JS_FreeValue(self.context, reason);
            }
        }
    }

    /// The error of a rejected promise. The rejection is not reported again.
    fn promise_error(&self, promise: &Owned) -> String {
        let reason = unsafe { Owned::new(self.context, JS_PromiseResult(self.context, promise.value())) };
        self.forget_rejection(promise.value());

        self.format_error(reason.value())
    }

    fn forget_rejection(&self, promise: JSValue) {
        let mut rejections = self.state.rejections.borrow_mut();

        if let Some(index) = rejections.iter().position(|(kept, _)| unsafe { kept.u.ptr == promise.u.ptr }) {
            let (kept, reason) = rejections.remove(index);

            unsafe {
                JS_FreeValue(self.context, kept);
                JS_FreeValue(self.context, reason);
            }
        }
    }

    fn take_exception(&self) -> String {
        let exception = unsafe { Owned::new(self.context, JS_GetException(self.context)) };

        self.format_error(exception.value())
    }

    /// The text of an error with its stack, from `__runtime.formatError`.
    fn format_error(&self, value: JSValue) -> String {
        if let Some(text) = self
            .call_runtime("formatError", &[value])
            .and_then(|result| unsafe { to_text(self.context, result.value()) })
        {
            return text;
        }

        unsafe { to_text(self.context, value) }.unwrap_or_else(|| "Error".to_string())
    }

    /// The text that the console shows for a value, from `__runtime.inspect`.
    fn inspect(&self, value: JSValue) -> String {
        if let Some(text) = self
            .call_runtime("inspect", &[value])
            .and_then(|result| unsafe { to_text(self.context, result.value()) })
        {
            return text;
        }

        unsafe { to_text(self.context, value) }.unwrap_or_default()
    }

    /// Calls a function of the runtime core. None when it is missing or throws.
    fn call_runtime(&self, name: &str, arguments: &[JSValue]) -> Option<Owned> {
        unsafe {
            let global = Owned::new(self.context, JS_GetGlobalObject(self.context));
            let core = get_property(self.context, global.value(), RUNTIME_GLOBAL);
            let function = get_property(self.context, core.value(), name);

            if !JS_IsFunction(self.context, function.value()) {
                return None;
            }

            let mut values: Vec<JSValue> = arguments.to_vec();
            let result = JS_Call(
                self.context,
                function.value(),
                core.value(),
                values.len() as i32,
                values.as_mut_ptr(),
            );

            if result.is_exception() {
                JS_FreeValue(self.context, JS_GetException(self.context));

                return None;
            }

            Some(Owned::new(self.context, result))
        }
    }
}

/// Source text with the NUL after it that the QuickJS parser needs.
struct SourceText {
    bytes: Vec<u8>,
}

impl SourceText {
    fn new(source: &str) -> SourceText {
        let mut bytes = Vec::with_capacity(source.len() + 1);
        bytes.extend_from_slice(source.as_bytes());
        bytes.push(0);

        SourceText { bytes }
    }

    fn pointer(&self) -> *const c_char {
        self.bytes.as_ptr() as *const c_char
    }

    // without the NUL
    fn length(&self) -> usize {
        self.bytes.len() - 1
    }
}

impl Drop for Engine {
    fn drop(&mut self) {
        self.set_host(None);

        for (promise, reason) in std::mem::take(&mut *self.state.rejections.borrow_mut()) {
            unsafe {
                JS_FreeValue(self.context, promise);
                JS_FreeValue(self.context, reason);
            }
        }

        unsafe {
            JS_FreeContext(self.context);
            JS_FreeRuntime(self.runtime);
        }
    }
}

#[cfg(test)]
mod tests;
