//! File and image codecs. This crate has no engine types, so `cargo test` runs
//! it and any front end can use it.

pub mod bmp;
pub mod crc32;
pub mod gif;
pub mod pe;
pub mod png;
pub mod sprite;
