//! SC2X file version 4 structures. A version 4 file is a ZIP archive with flat
//! entries; GDScript reads and writes the archive and `metadata.json`. These
//! modules encode and validate the binary entries. See docs/sc2x-format.md.

pub mod collection;
pub mod framing;
pub mod labels;
pub mod limits;
pub mod project;
pub mod scenario;
pub mod wire;
pub mod xmic;
pub mod xsgn;
pub mod xthg;
