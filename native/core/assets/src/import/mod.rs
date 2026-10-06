//! Converters of the supplied game files to portable formats.

pub mod container;
pub mod newspaper;
pub mod sprites;
pub mod voc;
pub mod wave;
pub mod xmi;

/// True when `length` bytes from `offset` lie inside `data`.
pub fn has_range(data: &[u8], offset: usize, length: usize) -> bool {
    offset <= data.len() && length <= data.len() - offset
}
