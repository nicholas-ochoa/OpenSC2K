//! SCURK MIF tile sets for GDScript. The script keeps the tile set objects.

use godot::prelude::*;
use sc2k_assets::scurk::mif::{self, Mif};

fn bytes(data: &[u8]) -> PackedByteArray {
    PackedByteArray::from(data)
}

/// SCURK MIF tile sets.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeScurkMif {}

#[godot_api]
impl NativeScurkMif {
    /// `{error, info, piece_count, pieces}`. Each piece has `tag`, `sprite_id`,
    /// `raw`, `name`, and for artwork `width`, `height`, `offset`, `encoded`,
    /// `duplicate_index`, and `opaque`. A failed parse keeps the pieces it read.
    #[func]
    fn parse(data: PackedByteArray) -> VarDictionary {
        let parsed = Mif::parse(data.as_slice());
        let mut pieces = VarArray::new();

        for piece in &parsed.pieces {
            let mut fields = VarDictionary::new();
            fields.set("tag", piece.tag.as_str());
            fields.set("sprite_id", piece.sprite_id);
            fields.set("raw", &bytes(&piece.raw));
            fields.set("name", piece.name.as_deref().unwrap_or_default());
            fields.set("has_shape", piece.shape.is_some());

            if let Some(shape) = &piece.shape {
                fields.set("width", shape.width);
                fields.set("height", shape.height);
                fields.set("offset", shape.offset as i64);
                fields.set("encoded", &bytes(&shape.encoded));
                fields.set("duplicate_index", shape.duplicate_index);
                fields.set("opaque", shape.opaque);
            }

            pieces.push(&fields.to_variant());
        }

        let mut result = VarDictionary::new();
        result.set("error", parsed.error.as_str());
        result.set("info", &bytes(&parsed.info));
        result.set("piece_count", parsed.piece_count as i64);
        result.set("pieces", &pieces);
        result
    }

    /// `{ok, error, payload, encoded}`: the SHAP payload of new artwork and its
    /// pixels with the game's sprite end.
    #[func]
    fn shape_payload(sprite_id: i64, width: i64, height: i64, pixels: PackedInt32Array) -> VarDictionary {
        match mif::shape_payload(sprite_id, width, height, pixels.as_slice()) {
            Ok(payload) => {
                let mut result = super::success();
                result.set("encoded", &bytes(&mif::normalize_pixel_end(&payload[10..])));
                result.set("payload", &bytes(&payload));
                result
            }
            Err(error) => super::failure(&error),
        }
    }

    /// `{ok, error, payload}`: the NAME payload of an object name.
    #[func]
    fn name_payload(sprite_id: i64, text: GString) -> VarDictionary {
        match mif::name_payload(sprite_id, &text.to_string()) {
            Ok(payload) => {
                let mut result = super::success();
                result.set("payload", &bytes(&payload));
                result
            }
            Err(error) => super::failure(&error),
        }
    }

    /// The pixels with the game's sprite end in place of the SCURK end.
    #[func]
    fn normalize_pixel_end(data: PackedByteArray) -> PackedByteArray {
        bytes(&mif::normalize_pixel_end(data.as_slice()))
    }

    /// 1 for artwork with an opaque pixel, 0 for blank artwork, -1 when it does not decode.
    #[func]
    fn shape_state(width: i64, height: i64, encoded: PackedByteArray, allow_unpadded_odd_runs: bool) -> i64 {
        match mif::shape_state(width, height, encoded.as_slice(), allow_unpadded_odd_runs) {
            Ok(opaque) => i64::from(opaque),
            Err(_) => -1,
        }
    }

    /// `{ok, error, bytes}`: the file of a tile set.
    #[func]
    fn to_bytes(info: PackedByteArray, tags: PackedStringArray, payloads: VarArray) -> VarDictionary {
        let pieces: Vec<(String, Vec<u8>)> = tags
            .as_slice()
            .iter()
            .zip(payloads.iter_shared())
            .map(|(tag, payload)| {
                (
                    tag.to_string(),
                    payload.try_to::<PackedByteArray>().map(|data| data.to_vec()).unwrap_or_default(),
                )
            })
            .collect();

        match mif::to_bytes(info.as_slice(), &pieces) {
            Ok(data) => {
                let mut result = super::success();
                result.set("bytes", &bytes(&data));
                result
            }
            Err(error) => super::failure(&error),
        }
    }
}
