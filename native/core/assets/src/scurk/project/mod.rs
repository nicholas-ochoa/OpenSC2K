//! SCURK project records and archives. A record is the value tree of the
//! script project: JSON values, with byte and pixel arrays as leaves.

pub mod archive;
mod record;
mod text;

#[cfg(test)]
mod tests;

pub use record::Node;

pub const MAX_FILE_BYTES: i64 = 128 * 1024 * 1024;
pub const MAX_DATA_BYTES: i64 = 64 * 1024 * 1024;
pub const MAX_MIF_BYTES: usize = 16 * 1024 * 1024;
pub const MAX_DOCUMENTS: usize = 1500;
pub const MAX_LAYERS: usize = 32;
pub const MAX_STAMPS: usize = 256;
pub const MAX_CHECKPOINTS: usize = 24;
pub const MAX_RESOURCES: usize = 1024;
pub const MAX_WIDTH: i64 = 128;
pub const MAX_HEIGHT: i64 = 256;

/// True for an integer, or a finite float with a whole value, in the range.
pub fn integer_in(value: Option<&Node>, minimum: i64, maximum: i64) -> bool {
    match value {
        Some(Node::Int(value)) => (minimum..=maximum).contains(value),
        Some(Node::Float(value)) => {
            value.is_finite()
                && value.fract() == 0.0
                && *value >= minimum as f64
                && *value <= maximum as f64
        }
        _ => false,
    }
}

pub fn valid_dimensions(width: Option<&Node>, height: Option<&Node>) -> bool {
    integer_in(width, 1, MAX_WIDTH) && integer_in(height, 1, MAX_HEIGHT)
}

/// The 256 RGB colors of the index palette: entry i is gray level i.
pub fn index_palette() -> Vec<u8> {
    (0..=255_u8).flat_map(|level| [level; 3]).collect()
}
