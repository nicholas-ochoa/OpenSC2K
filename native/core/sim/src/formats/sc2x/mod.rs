//! SC2X file version 4 structures. A version 4 file is a ZIP archive with flat
//! entries. `document` reads and writes the archive, `metadata` reads and writes
//! `metadata.json`, and the other modules encode and validate the binary
//! entries. See docs/sc2x-format.md.

pub mod collection;
pub mod document;
pub mod framing;
pub mod labels;
pub mod limits;
pub mod metadata;
pub mod project;
pub mod scenario;
pub mod wire;
pub mod xmic;
pub mod xsgn;
pub mod xthg;
