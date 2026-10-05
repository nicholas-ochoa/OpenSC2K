//! `ScriptRuntime`, the Godot class of one JavaScript runtime. GDScript sets
//! a host Callable, `(name: String, arguments: Array) -> Variant`, that runs
//! the game functions of `__host`. A host function calls `throw_error` to
//! throw a JavaScript Error.
//!
//! Each method takes `&self`, thus a host function can call the runtime
//! again, for example to dispatch an event that its game action causes.

mod variant;

use std::cell::RefCell;
use std::rc::Rc;
use std::time::Duration;

use godot::prelude::*;

use crate::engine::{Engine, HostFunction};
use crate::value::JsData;
use variant::{from_variant, to_variant};

const DISPATCH_FUNCTION: &str = "__runtime.dispatch";
const TICK_FUNCTION: &str = "__runtime.tick";
const COMMAND_FUNCTION: &str = "__runtime.runCommand";

#[derive(GodotClass)]
#[class(base = RefCounted)]
pub struct ScriptRuntime {
    engine: Option<Engine>,
    // why the engine is missing
    error: String,
    // the message of throw_error during a host call
    host_error: Rc<RefCell<Option<String>>>,
    base: Base<RefCounted>,
}

#[godot_api]
impl IRefCounted for ScriptRuntime {
    fn init(base: Base<RefCounted>) -> Self {
        let (engine, error) = match Engine::new() {
            Ok(engine) => (Some(engine), String::new()),
            Err(error) => (None, error),
        };

        ScriptRuntime {
            engine,
            error,
            host_error: Rc::new(RefCell::new(None)),
            base,
        }
    }
}

#[godot_api]
impl ScriptRuntime {
    /// The QuickJS-ng version, such as "0.17.0".
    #[func]
    fn engine_version() -> GString {
        GString::from(Engine::version().as_str())
    }

    /// False when the engine could not start. `get_error` tells why.
    #[func]
    fn is_ready(&self) -> bool {
        self.engine.is_some()
    }

    #[func]
    fn get_error(&self) -> GString {
        GString::from(self.error.as_str())
    }

    /// Keeps the scripts of this runtime in the folder of a mod: they import
    /// only modules in it, and `mod.files` reads and writes only in it.
    /// Call it before the first script. Returns an empty text, or why the
    /// folder cannot be used.
    #[func]
    fn set_sandbox(&self, folder: GString) -> GString {
        let Some(engine) = &self.engine else {
            return GString::from(self.error.as_str());
        };

        match engine.set_sandbox(std::path::Path::new(&folder.to_string())) {
            Ok(()) => GString::new(),
            Err(error) => GString::from(error.as_str()),
        }
    }

    /// Runs a file of the mod folder, such as the main file of a mod:
    /// `{ok, error}`. The path is relative to the folder.
    #[func]
    fn run_sandbox_file(&self, path: GString) -> VarDictionary {
        let Some(engine) = &self.engine else {
            return self.missing_engine();
        };

        match engine.run_sandbox_file(&path.to_string()) {
            Ok(()) => result(true, "value", Variant::nil(), ""),
            Err(error) => result(false, "value", Variant::nil(), &error),
        }
    }

    #[func]
    fn set_host(&self, host: Callable) {
        let Some(engine) = &self.engine else {
            return;
        };

        let pending = self.host_error.clone();
        let function: HostFunction = Rc::new(move |name: &str, arguments: Vec<JsData>| {
            let mut values = VarArray::new();

            for argument in &arguments {
                values.push(&to_variant(argument));
            }

            let mut call = VarArray::new();
            call.push(&GString::from(name).to_variant());
            call.push(&values.to_variant());
            let result = host.callv(&call);

            match pending.borrow_mut().take() {
                Some(message) => Err(message),
                None => Ok(from_variant(&result)),
            }
        });

        engine.set_host(Some(function));
    }

    /// Stops the inspector and removes the host. The host Callable can refer
    /// to the object that keeps this runtime; close breaks that cycle. Scripts
    /// then cannot call the game.
    #[func]
    fn close(&self) {
        if let Some(engine) = &self.engine {
            engine.stop_inspector();
            engine.set_host(None);
        }
    }

    /// Makes the running host function throw an Error with this message
    /// when it returns.
    #[func]
    fn throw_error(&self, message: GString) {
        *self.host_error.borrow_mut() = Some(message.to_string());
    }

    /// The time in milliseconds that one call from the game may take. A
    /// script that runs longer stops with an error. 0 turns the limit off.
    #[func]
    fn set_time_limit_msec(&self, msec: i64) {
        if let Some(engine) = &self.engine {
            engine.set_time_limit(Duration::from_millis(msec.max(0) as u64));
        }
    }

    #[func]
    fn get_time_limit_msec(&self) -> i64 {
        self.engine.as_ref().map_or(0, |engine| engine.time_limit().as_millis() as i64)
    }

    /// Runs console input: `{ok, text, error}`. `text` is the inspected
    /// result, empty for undefined.
    #[func]
    fn eval_console(&self, source: GString) -> VarDictionary {
        let Some(engine) = &self.engine else {
            return self.missing_engine();
        };

        match engine.eval_console(&source.to_string()) {
            Ok(text) => result(true, "text", GString::from(text.unwrap_or_default().as_str()).to_variant(), ""),
            Err(error) => result(false, "text", GString::new().to_variant(), &error),
        }
    }

    /// Runs a script file: `{ok, error}`. `path` names the file in error
    /// stacks, and a module imports other files relative to it.
    #[func]
    fn run_script(&self, source: GString, path: GString) -> VarDictionary {
        let Some(engine) = &self.engine else {
            return self.missing_engine();
        };

        match engine.run_script(&source.to_string(), &path.to_string()) {
            Ok(()) => result(true, "value", Variant::nil(), ""),
            Err(error) => result(false, "value", Variant::nil(), &error),
        }
    }

    /// Calls the function at a global path, such as "game.on": `{ok, value, error}`.
    #[func]
    fn call_function(&self, path: GString, arguments: VarArray) -> VarDictionary {
        let Some(engine) = &self.engine else {
            return self.missing_engine();
        };

        let values: Vec<JsData> = arguments.iter_shared().map(|argument| from_variant(&argument)).collect();

        match engine.call(&path.to_string(), &values) {
            Ok(value) => result(true, "value", to_variant(&value), ""),
            Err(error) => result(false, "value", Variant::nil(), &error),
        }
    }

    /// Calls the listeners of an event. Returns the event after the
    /// listeners: its fields, with `cancelled` true when a listener cancelled
    /// a cancelable event. Returns an empty Dictionary after an error.
    #[func]
    fn dispatch(&self, event_type: GString, detail: VarDictionary, cancelable: bool) -> VarDictionary {
        let Some(engine) = &self.engine else {
            return VarDictionary::new();
        };

        let arguments = [
            JsData::String(event_type.to_string()),
            from_variant(&detail.to_variant()),
            JsData::Bool(cancelable),
        ];

        match engine.call(DISPATCH_FUNCTION, &arguments) {
            Ok(event) => to_variant(&event).try_to::<VarDictionary>().unwrap_or_default(),
            Err(error) => {
                godot_error!("Script event {event_type}: {error}");

                VarDictionary::new()
            }
        }
    }

    /// Runs a console command that a script registered: the text to show.
    #[func]
    fn run_command(&self, name: GString, words: PackedStringArray) -> VarDictionary {
        let Some(engine) = &self.engine else {
            return self.missing_engine();
        };

        let values = JsData::Array(words.as_slice().iter().map(|word| JsData::String(word.to_string())).collect());

        match engine.call(COMMAND_FUNCTION, &[JsData::String(name.to_string()), values]) {
            Ok(value) => result(true, "text", to_variant(&value), ""),
            Err(error) => result(false, "text", GString::new().to_variant(), &error),
        }
    }

    /// Runs the timers that are due and the promise jobs. Returns the number
    /// of timers that wait.
    #[func]
    fn tick(&self) -> i64 {
        let Some(engine) = &self.engine else {
            return 0;
        };

        match engine.call(TICK_FUNCTION, &[]) {
            Ok(JsData::Int(count)) => count,
            Ok(_) => 0,
            Err(error) => {
                godot_error!("Script timers: {error}");

                0
            }
        }
    }

    #[func]
    fn has_pending_jobs(&self) -> bool {
        self.engine.as_ref().is_some_and(|engine| engine.has_pending_jobs())
    }

    #[func]
    fn run_pending_jobs(&self) {
        if let Some(engine) = &self.engine {
            engine.run_pending_jobs();
        }
    }

    /// The heap of the runtime: memory_used, memory_limit, allocations,
    /// objects, strings and functions.
    #[func]
    fn memory_usage(&self) -> VarDictionary {
        match &self.engine {
            Some(engine) => to_variant(&engine.memory_usage()).try_to::<VarDictionary>().unwrap_or_default(),
            None => VarDictionary::new(),
        }
    }

    #[func]
    fn collect_garbage(&self) {
        if let Some(engine) = &self.engine {
            engine.collect_garbage();
        }
    }

    /// Starts the DevTools server on 127.0.0.1. Port 0 selects a free port.
    /// Returns an empty text, or why it cannot start.
    #[func]
    fn inspector_start(&self, port: i64, title: GString) -> GString {
        let Some(engine) = &self.engine else {
            return GString::from(self.error.as_str());
        };

        match engine.start_inspector(port.clamp(0, u16::MAX as i64) as u16, &title.to_string()) {
            Ok(_) => GString::new(),
            Err(error) => GString::from(error.as_str()),
        }
    }

    #[func]
    fn inspector_stop(&self) {
        if let Some(engine) = &self.engine {
            engine.stop_inspector();
        }
    }

    /// The port of the DevTools server, or 0 when it does not run.
    #[func]
    fn inspector_port(&self) -> i64 {
        self.engine.as_ref().and_then(Engine::inspector_port).map_or(0, |port| port as i64)
    }

    /// True while a DevTools window is connected.
    #[func]
    fn inspector_connected(&self) -> bool {
        self.engine.as_ref().is_some_and(Engine::inspector_connected)
    }

    /// Handles the DevTools messages that arrived. Call it once each frame.
    #[func]
    fn inspector_poll(&self) {
        if let Some(engine) = &self.engine {
            engine.poll_inspector();
        }
    }

    /// Shows a line of the game console in DevTools: level is log, warning or error.
    #[func]
    fn inspector_log(&self, level: GString, text: GString) {
        if let Some(engine) = &self.engine {
            engine.inspector_game_log(&level.to_string(), &text.to_string());
        }
    }

    /// The WebSocket address and the DevTools page of a port.
    #[func]
    fn inspector_urls(port: i64) -> PackedStringArray {
        let port = port.clamp(0, u16::MAX as i64) as u16;
        let mut urls = PackedStringArray::new();
        urls.push(&GString::from(crate::inspector::websocket_url(port).as_str()));
        urls.push(&GString::from(crate::inspector::frontend_url(port).as_str()));

        urls
    }

    fn missing_engine(&self) -> VarDictionary {
        result(false, "value", Variant::nil(), &self.error)
    }
}

fn result(ok: bool, key: &str, value: Variant, error: &str) -> VarDictionary {
    let mut dictionary = VarDictionary::new();
    dictionary.set(&"ok".to_variant(), &ok.to_variant());
    dictionary.set(&GString::from(key).to_variant(), &value);
    dictionary.set(&"error".to_variant(), &GString::from(error).to_variant());

    dictionary
}
