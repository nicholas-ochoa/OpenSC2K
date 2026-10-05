//! `Engine` owns one QuickJS runtime and its context. All calls come from
//! one thread. A host function can call into the engine again, thus each
//! method takes `&self` and holds no borrow while JavaScript runs.

mod callbacks;
mod files_native;
mod inspector_native;
mod modules;
mod state;

use std::cell::{Cell, RefCell};
use std::ffi::{CString, c_char, c_void};
use std::path::Path;
use std::time::Duration;

pub use state::HostFunction;
use state::{EngineState, Entry};

use crate::ffi::*;
use crate::inspector::{Activity, Inspector};
use crate::sandbox::Sandbox;
use crate::value::{JsData, Owned, from_js, get_property, to_js, to_text};

// the heap of one runtime. A larger script stops with an out-of-memory error
const MEMORY_LIMIT: usize = 256 * 1024 * 1024;
// the C stack that JavaScript calls can use. The Windows main thread has 1 MiB
const STACK_LIMIT: usize = 512 * 1024;
// the file name of console input in error stacks
pub const CONSOLE_FILE_NAME: &str = "<console>";
const RUNTIME_FILE_NAME: &str = "opensc2k:runtime";
const INSPECTOR_FILE_NAME: &str = "opensc2k:inspector";
// the protocol handler of the inspector; see inspector.js
const INSPECTOR_HANDLE: &str = "__inspector.handle";
const INSPECTOR_ATTACH: &str = "__inspector.attach";
const INSPECTOR_DETACH: &str = "__inspector.detach";
const INSPECTOR_SYNC: &str = "__inspector.sync";
const INSPECTOR_GAME_LOG: &str = "__inspector.gameLog";
const INSPECTOR_FAIL: &str = "__inspector.fail";
// the runtime core defines this global; see prelude.js
const RUNTIME_GLOBAL: &str = "__runtime";
const HOST_GLOBAL: &str = "__host";
const MODULE_EXTENSION: &str = ".mjs";

pub struct Engine {
    runtime: *mut JSRuntime,
    context: *mut JSContext,
    // boxed, thus the opaque pointers of the runtime and the context stay valid
    state: Box<EngineState>,
    inspector: RefCell<Option<Inspector>>,
    // the number of scripts at the last inspector sync
    synced_scripts: Cell<usize>,
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
            inspector: RefCell::new(None),
            synced_scripts: Cell::new(0),
        };

        engine.install_callbacks();
        engine.run_script(include_str!("../prelude.js"), RUNTIME_FILE_NAME)?;
        engine.run_script(include_str!("../inspector/inspector.js"), INSPECTOR_FILE_NAME)?;

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
            JS_SetModuleLoaderFunc(self.runtime, None, Some(modules::load_module), opaque);

            let global = Owned::new(self.context, JS_GetGlobalObject(self.context));
            let host = JS_NewCFunctionData(self.context, callbacks::host_call, 1, 0, 0, std::ptr::null_mut());
            crate::value::set_property(self.context, global.value(), HOST_GLOBAL, host);

            let native = JS_NewObject(self.context);

            for (name, magic, length) in inspector_native::FUNCTIONS {
                let function = JS_NewCFunctionData(self.context, inspector_native::call, length, magic, 0, std::ptr::null_mut());
                crate::value::set_property(self.context, native, name, function);
            }

            crate::value::set_property(self.context, global.value(), inspector_native::GLOBAL_NAME, native);
        }
    }

    /// Keeps the scripts of this runtime in the folder of a mod: they import
    /// only modules in it, and `__files` reads and writes only in it. The
    /// folder cannot change later.
    pub fn set_sandbox(&self, root: &Path) -> Result<(), String> {
        if self.state.sandbox.get().is_some() {
            return Err("The script runtime already has a mod folder.".to_string());
        }

        let sandbox = Sandbox::new(root)?;
        let _ = self.state.sandbox.set(sandbox);

        unsafe {
            let global = Owned::new(self.context, JS_GetGlobalObject(self.context));
            let files = JS_NewObject(self.context);

            for (name, magic, length) in files_native::FUNCTIONS {
                let function = JS_NewCFunctionData(self.context, files_native::call, length, magic, 0, std::ptr::null_mut());
                crate::value::set_property(self.context, files, name, function);
            }

            crate::value::set_property(self.context, global.value(), files_native::GLOBAL_NAME, files);
        }

        Ok(())
    }

    /// Runs a file of the mod folder, such as the main file of the mod. The
    /// path is relative to the folder.
    pub fn run_sandbox_file(&self, relative: &str) -> Result<(), String> {
        let Some(sandbox) = self.state.sandbox.get() else {
            return Err("The script runtime has no mod folder.".to_string());
        };

        let path = sandbox.resolve(relative)?;
        let bytes = sandbox.read(relative)?;
        let source = String::from_utf8(bytes).map_err(|_| format!("{relative} is not UTF-8 text."))?;

        self.run_script(&source, &crate::sandbox::script_name(&path))
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
        self.state.record_script(file_name, source, module);
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
                let exception = unsafe { Owned::new(self.context, JS_GetException(self.context)) };
                self.report_uncaught(exception.value(), "Uncaught");
            }
        }
    }

    fn report_rejections(&self) {
        let rejections = std::mem::take(&mut *self.state.rejections.borrow_mut());

        for (promise, reason) in rejections {
            self.report_uncaught(reason, "Uncaught (in promise)");

            unsafe {
                JS_FreeValue(self.context, promise);
                JS_FreeValue(self.context, reason);
            }
        }
    }

    /// Reports an error in the game console and in the inspector, through
    /// `__runtime.reportUncaught`.
    fn report_uncaught(&self, error: JSValue, prefix: &str) {
        let prefix_value = unsafe { Owned::new(self.context, crate::value::new_string(self.context, prefix)) };

        if self.call_runtime("reportUncaught", &[error, prefix_value.value()]).is_none() {
            let text = self.format_error(error);
            self.state.report("error", &format!("{prefix} {text}"));
        }
    }

    /// Starts the DevTools server on 127.0.0.1. Port 0 selects a free port.
    /// Returns the port.
    pub fn start_inspector(&self, port: u16, title: &str) -> Result<u16, String> {
        self.stop_inspector();
        let inspector = Inspector::start(port, title).map_err(|error| format!("Cannot listen on port {port}: {error}"))?;
        let port = inspector.port();
        *self.inspector.borrow_mut() = Some(inspector);

        Ok(port)
    }

    pub fn stop_inspector(&self) {
        let inspector = self.inspector.borrow_mut().take();

        if inspector.as_ref().is_some_and(Inspector::connected) {
            *self.state.inspector_out.borrow_mut() = None;
            let _ = self.call(INSPECTOR_DETACH, &[]);
        }
    }

    /// The port of the DevTools server, or None when it is not running.
    pub fn inspector_port(&self) -> Option<u16> {
        self.inspector.borrow().as_ref().map(Inspector::port)
    }

    pub fn inspector_connected(&self) -> bool {
        self.inspector.borrow().as_ref().is_some_and(Inspector::connected)
    }

    /// Handles the DevTools messages that arrived, and announces new scripts.
    pub fn poll_inspector(&self) {
        let activity = match self.inspector.borrow_mut().as_mut() {
            Some(inspector) => inspector.poll(),
            None => return,
        };

        for item in activity {
            let result = match item {
                Activity::Attached => {
                    *self.state.inspector_out.borrow_mut() = self.inspector.borrow().as_ref().and_then(Inspector::sender);
                    self.synced_scripts.set(0);
                    self.call(INSPECTOR_ATTACH, &[])
                }
                Activity::Message(text) => self.call(INSPECTOR_HANDLE, &[JsData::String(text)]),
                Activity::Detached => {
                    *self.state.inspector_out.borrow_mut() = None;
                    self.call(INSPECTOR_DETACH, &[])
                }
            };

            // an uncatchable error, such as the time limit, stops the message
            // without an answer. DevTools gets the error as the answer
            if let Err(error) = result {
                let _ = self.call(INSPECTOR_FAIL, &[JsData::String(error)]);
            }
        }

        let scripts = self.state.scripts.borrow().len();

        if self.inspector_connected() && scripts != self.synced_scripts.get() {
            self.synced_scripts.set(scripts);
            let _ = self.call(INSPECTOR_SYNC, &[]);
        }
    }

    /// Shows a line of the game console in the DevTools console.
    pub fn inspector_game_log(&self, level: &str, text: &str) {
        if self.inspector_connected() {
            let _ = self.call(
                INSPECTOR_GAME_LOG,
                &[JsData::String(level.to_string()), JsData::String(text.to_string())],
            );
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
        self.inspector.borrow_mut().take();
        self.state.inspector_out.borrow_mut().take();

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
mod inspector_tests;
#[cfg(test)]
mod sandbox_tests;
#[cfg(test)]
mod tests;
