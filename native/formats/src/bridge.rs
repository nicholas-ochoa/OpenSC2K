//! Godot classes of the codecs.
use super::crc32;
use godot::prelude::*;

/// CRC-32 of PNG and ZIP records.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeCrc32 {}
#[godot_api]
impl NativeCrc32 {
    #[func]
    fn calculate(bytes: PackedByteArray) -> i64 {
        i64::from(crc32::calculate(bytes.as_slice()))
    }
}
