# Native scripting

The script runtime is a Rust GDExtension in `native/scripting`. It embeds
QuickJS-ng 0.17.0. The C sources are in `native/scripting/quickjs`, unchanged,
and `build.rs` compiles them with the `cc` crate. The crate dependencies are
`godot` and, at build time only, `cc`. For the scripting API, see
[Scripting](scripting.md).

## Layout

- `quickjs/` holds the vendored QuickJS-ng sources, the license and the
  version of the sources.
- `src/ffi` holds the C API declarations. `shim.c` exports the static inline
  functions of `quickjs.h` that Rust cannot call. Only 64-bit targets are
  supported. There, a `JSValue` is a 16-byte struct, and `shim.c` checks this.
- `src/value.rs` holds `JsData`, a JavaScript value without Godot types, and
  its conversion to and from QuickJS values.
- `src/engine` holds `Engine`, one runtime and its context:
  - `state.rs` keeps the host function, the time limit and the rejected promises.
    The C callbacks read it through the opaque pointers.
  - `callbacks.rs` holds `__host`, the interrupt check of the time limit and the
    promise rejection tracker.
  - `modules.rs` loads ES modules from files.
  - `tests.rs` holds the unit tests.
- `src/prelude.js` is the runtime core: `console`, the timers, the event bus,
  `inspect` and the script commands. It keeps `__host` as `__runtime.host`.
- `src/inspector` holds the DevTools inspector:
  - `mod.rs` and `server.rs`: the HTTP and WebSocket server on 127.0.0.1. The
    accept thread answers the `/json` discovery requests of `chrome://inspect`.
    Each connection has a reader and a writer thread. The threads only move
    message text; the main thread polls them.
  - `websocket.rs`, `sha1.rs` and `base64.rs`: the request head, the frames and
    the handshake key, written for this server.
  - `inspector.js`: the Chrome DevTools Protocol handler. It runs in the runtime
    after `prelude.js`, and keeps the table of remote objects.
  - `tests.rs`: the server tests with a WebSocket client.
- `src/engine/inspector_native.rs` holds `__inspectorNative`, the engine functions
  that `inspector.js` uses: send, evaluate, syntax check, scripts, memory.
  `src/engine/inspector_tests.rs` tests the protocol against a real engine.
- `src/godot_class` holds `ScriptRuntime`, the Godot class, and the Variant
  conversion.

## Calls between Godot and JavaScript

GDScript sets a host Callable: `(name: String, arguments: Array) -> Variant`.
Scripts call it with `__runtime.host(name, ...arguments)`. A host function can
call the runtime again, for example to dispatch an event that its action causes.
Thus each `ScriptRuntime` method takes `&self`, and the engine holds no borrow
while JavaScript runs. A host function calls `throw_error(message)` to throw an
Error in the script.

The first call from the game starts the time limit (5 seconds by default) and
records the stack top. A nested call uses the same deadline. After the
outermost call, the engine runs the promise jobs and reports each rejection
without a handler through the host `console` function.

## Inspector

`ScriptRuntime.inspector_start(port, title)` starts the server, and
`inspector_poll()` gives the arrived messages to `inspector.js`; GDScript calls
it each frame. The engine records the source of each script file and module.
`inspector.js` announces them as `Debugger.scriptParsed`. The prelude gives each
console call and uncaught error to the inspector through `__runtime.taps`.
`inspector_log(level, text)` sends a line of the game console.

DevTools input runs as console input does, with top-level await. An evaluation
that DevTools marks `throwOnSideEffect` (eager evaluation and completion) runs
only when it is a name or a property path. A message that stops with an
uncatchable error, such as the time limit, gets that error as its answer.

QuickJS-ng has no debugger API. Breakpoints, pausing and stepping need a change
to the interpreter loop of `quickjs.c`, thus they are not supported yet.

A debug build of the crate keeps the QuickJS asserts. `JS_FreeRuntime` then
stops on a leaked value, so `cargo test` without `--release` also checks for
leaks. A release build defines `NDEBUG`, as the CMake Release build of QuickJS-ng does.

## Build and checks

`python3 tools/build_native.py` builds and installs every native library. Run
`cargo fmt`, `cargo fmt --check`,
`cargo clippy --all-targets --all-features -- -D warnings` and
`cargo test --release` from `native/scripting`. The Godot checks are in the
`scripting` validation domain: `tools/validate_project.sh --suite scripting`.

After you add the extension to a checkout, run the Godot editor or
`godot --headless --path game --import` once. Godot then adds
`opensc2k_scripting.gdextension` to `.godot/extension_list.cfg`.

To update QuickJS-ng, follow `native/scripting/quickjs/README.md`.
