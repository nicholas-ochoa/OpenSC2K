//! City file codec entry points.

use godot::prelude::*;

use crate::formats::rle;

/// Static Maxis RLE entry points for `MaxisRle`.
#[derive(GodotClass)]
#[class(no_init, base = Object)]
pub struct NativeMaxisRle {}

#[godot_api]
impl NativeMaxisRle {
    /// `{ok, data, error}`. A negative `expected_size` accepts any output size.
    #[func]
    fn decode(encoded: PackedByteArray, expected_size: i64) -> VarDictionary {
        let expected = usize::try_from(expected_size).ok();
        let mut result = VarDictionary::new();

        match rle::decode(encoded.as_slice(), expected) {
            Ok(decoded) => {
                result.set("ok", true);
                result.set("data", &PackedByteArray::from(decoded.as_slice()));
                result.set("error", "");
            }
            Err(error) => {
                result.set("ok", false);
                result.set("data", &PackedByteArray::new());
                result.set("error", error.as_str());
            }
        }

        result
    }

    #[func]
    fn encode(decoded: PackedByteArray) -> PackedByteArray {
        PackedByteArray::from(rle::encode(decoded.as_slice()).as_slice())
    }
}
