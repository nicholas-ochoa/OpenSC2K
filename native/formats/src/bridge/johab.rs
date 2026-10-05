//! The Johab codec of the Korean text resources and newspaper grammar.

use godot::prelude::*;
use sc2k_assets::text::johab;

/// The Johab codec of the Korean text resources and newspaper grammar.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeJohab {}

#[godot_api]
impl NativeJohab {
    /// The Unicode code point of the pair at `at`, or 0 for an invalid pair.
    #[func]
    fn code_point(bytes: PackedByteArray, at: i64) -> i64 {
        usize::try_from(at).map_or(0, |at| i64::from(johab::code_point(bytes.as_slice(), at)))
    }

    /// True when the whole resource file is Johab text. A pair cannot cross
    /// one of `record_boundaries`.
    #[func]
    fn is_text(bytes: PackedByteArray, record_boundaries: PackedInt32Array) -> bool {
        let boundaries: Option<Vec<usize>> = record_boundaries.as_slice().iter().map(|&end| usize::try_from(end).ok()).collect();

        boundaries.is_some_and(|boundaries| johab::is_text(bytes.as_slice(), &boundaries))
    }

    #[func]
    fn decode_text(bytes: PackedByteArray) -> GString {
        GString::from(johab::decode_text(bytes.as_slice()).as_str())
    }

    /// True when newspaper grammar is Johab text.
    #[func]
    fn is_grammar(grammar: PackedByteArray, offsets: PackedByteArray) -> bool {
        johab::is_grammar(grammar.as_slice(), offsets.as_slice())
    }
}
