//! The JavaScript runtime of OpenSC2K: QuickJS-ng, compiled from the vendored
//! C sources in `quickjs`. `engine` runs one runtime and `prelude.js` defines
//! its core: console, timers, events and script commands. `sandbox` keeps a mod
//! in its own folder. This crate has no engine types; the game functions of
//! scripts are host functions that the front end supplies.

pub mod engine;
mod ffi;
pub mod inspector;
pub mod sandbox;
pub mod value;
