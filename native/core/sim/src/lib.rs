//! The SimCity 2000 simulation of OpenSC2K.
//!
//! `sim` holds the simulation and `formats` holds the city file codecs. The
//! crate has no engine types, so `cargo test` runs it and any front end can
//! use it.

pub mod formats;
pub mod sim;
