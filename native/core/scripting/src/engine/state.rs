//! The state that the C callbacks of QuickJS read. The engine keeps it in a
//! box, thus its address stays the same; the runtime and the context hold
//! that address as their opaque pointer.

use std::cell::{Cell, OnceCell, RefCell};
use std::rc::Rc;
use std::time::{Duration, Instant};

use std::sync::mpsc::Sender;

use crate::ffi::*;
use crate::inspector::Outgoing;
use crate::sandbox::Sandbox;
use crate::value::JsData;

/// Runs a host function: `(name, arguments)`. An error becomes a JavaScript
/// Error with that message.
pub type HostFunction = Rc<dyn Fn(&str, Vec<JsData>) -> Result<JsData, String>>;

// the file names of the runtime core and the inspector
pub const INTERNAL_PREFIX: &str = "opensc2k:";
pub const DEFAULT_TIME_LIMIT: Duration = Duration::from_secs(5);

pub struct EngineState {
    pub host: RefCell<Option<HostFunction>>,
    // the time that one call from the game may take. Zero turns the limit off
    pub time_limit: Cell<Duration>,
    pub deadline: Cell<Option<Instant>>,
    // the number of calls from the game into JavaScript that run now. A host
    // function can call into JavaScript again
    pub depth: Cell<u32>,
    // rejected promises without a handler: (promise, reason)
    pub rejections: RefCell<Vec<(JSValue, JSValue)>>,
    // the script files and modules that ran, for the inspector
    pub scripts: RefCell<Vec<ScriptRecord>>,
    // the connection of an attached DevTools window
    pub inspector_out: RefCell<Option<Sender<Outgoing>>>,
    // the folder of a mod. Its scripts use files and modules only in it
    pub sandbox: OnceCell<Sandbox>,
}

/// A script file or module that the runtime ran.
pub struct ScriptRecord {
    pub name: String,
    pub source: String,
    pub module: bool,
}

impl EngineState {
    pub fn new() -> EngineState {
        EngineState {
            host: RefCell::new(None),
            time_limit: Cell::new(DEFAULT_TIME_LIMIT),
            deadline: Cell::new(None),
            depth: Cell::new(0),
            rejections: RefCell::new(Vec::new()),
            scripts: RefCell::new(Vec::new()),
            inspector_out: RefCell::new(None),
            sandbox: OnceCell::new(),
        }
    }

    pub fn host(&self) -> Option<HostFunction> {
        self.host.borrow().clone()
    }

    /// Sends a console line to the host. Without a host, the line goes to
    /// standard error.
    pub fn report(&self, level: &str, text: &str) {
        let arguments = vec![JsData::String(level.to_string()), JsData::String(text.to_string())];

        match self.host() {
            Some(host) => {
                let _ = host("console", arguments);
            }
            None => eprintln!("{text}"),
        }
    }

    /// Keeps the source of a script for the inspector. Internal scripts are not kept.
    pub fn record_script(&self, name: &str, source: &str, module: bool) {
        if name.starts_with(INTERNAL_PREFIX) {
            return;
        }

        self.scripts.borrow_mut().push(ScriptRecord {
            name: name.to_string(),
            source: source.to_string(),
            module,
        });
    }

    pub fn deadline_passed(&self) -> bool {
        match self.deadline.get() {
            Some(deadline) => Instant::now() >= deadline,
            None => false,
        }
    }
}

/// Counts one call from the game into JavaScript while it lives. The first
/// call starts the deadline and records the stack top.
pub struct Entry<'a> {
    state: &'a EngineState,
}

impl<'a> Entry<'a> {
    pub fn new(state: &'a EngineState, runtime: *mut JSRuntime) -> Entry<'a> {
        if state.depth.get() == 0 {
            let limit = state.time_limit.get();
            state
                .deadline
                .set(if limit.is_zero() { None } else { Some(Instant::now() + limit) });
            unsafe { JS_UpdateStackTop(runtime) };
        }

        state.depth.set(state.depth.get() + 1);

        Entry { state }
    }
}

impl Drop for Entry<'_> {
    fn drop(&mut self) {
        let depth = self.state.depth.get() - 1;
        self.state.depth.set(depth);

        if depth == 0 {
            self.state.deadline.set(None);
        }
    }
}
