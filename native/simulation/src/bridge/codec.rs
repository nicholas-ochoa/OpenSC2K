//! City file codec entry points.

use godot::prelude::*;

use crate::formats::{rle, sc2};

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

/// Static city-array entry points for CityState.
#[derive(GodotClass)]
#[class(no_init, base = Object)]
pub struct NativeCityArrays {}

#[godot_api]
impl NativeCityArrays {
    /// A content signature of `flags` with only the bits of `mask` in each
    /// byte. Equal masked content gives an equal signature.
    #[func]
    fn masked_signature(flags: PackedByteArray, mask: i64) -> i64 {
        crate::sim::signature::masked_bytes(flags.as_slice(), mask as u8)
    }

    /// OverlayData.sign_indices: the sign cells of `start..end` of an XTXT
    /// index. A negative `end` scans to the last cell.
    #[func]
    fn sign_indices(overlays: PackedByteArray, start: i64, end: i64) -> PackedInt32Array {
        PackedInt32Array::from(crate::sim::overlay::sign_indices(overlays.as_slice(), start, end).as_slice())
    }

    /// The big-endian 16-bit ALTM words of every tile. A 4096-tile map has
    /// 16.7 million, too many for a GDScript loop.
    #[func]
    fn altitude_words(altitude: PackedByteArray) -> PackedInt32Array {
        let words: Vec<i32> = altitude
            .as_slice()
            .chunks_exact(2)
            .map(|word| i32::from(u16::from_be_bytes([word[0], word[1]])))
            .collect();

        PackedInt32Array::from(words.as_slice())
    }

    /// The land height of every tile: the low five bits of each ALTM word.
    #[func]
    fn land_heights(altitude: PackedByteArray) -> PackedInt32Array {
        let heights: Vec<i32> = altitude.as_slice().chunks_exact(2).map(|word| i32::from(word[1] & 0x1f)).collect();

        PackedInt32Array::from(heights.as_slice())
    }

    /// CityDataGrid.expand: one value per tile from a half or quarter grid, or an
    /// empty array for a grid of another size.
    #[func]
    fn expand_grid(data: PackedByteArray, map_edge: i64) -> PackedByteArray {
        let edge = map_edge.max(0) as usize;
        let bytes = data.as_slice();
        let Some(grid) = [edge, edge / 2, edge / 4]
            .into_iter()
            .find(|grid| *grid > 0 && grid * grid == bytes.len())
        else {
            return PackedByteArray::new();
        };
        let scale = edge / grid;
        let mut result = vec![0u8; edge * edge];

        for x in 0..edge {
            let source = &bytes[(x / scale) * grid..(x / scale + 1) * grid];

            for (y, value) in result[x * edge..(x + 1) * edge].iter_mut().enumerate() {
                *value = source[y / scale];
            }
        }

        PackedByteArray::from(result.as_slice())
    }
}

/// Static SC2, SCN, and SCLG file entry points for Sc2File.
#[derive(GodotClass)]
#[class(no_init, base = Object)]
pub struct NativeSc2Form {}

#[godot_api]
impl NativeSc2Form {
    /// `{ok, error, map_size, large_version, repaired_length, chunks}`. Each chunk is
    /// `{chunk_id, source_offset, stored, decoded, expected_size, compressed}`.
    #[func]
    fn parse(bytes: PackedByteArray) -> VarDictionary {
        let mut result = VarDictionary::new();

        match sc2::parse(bytes.as_slice()) {
            Ok(form) => {
                let mut chunks = VarArray::new();

                for chunk in &form.chunks {
                    let mut fields = VarDictionary::new();
                    fields.set("chunk_id", chunk.id.as_str());
                    fields.set("source_offset", chunk.source_offset as i64);
                    fields.set("stored", &PackedByteArray::from(chunk.stored.as_slice()));
                    fields.set("decoded", &PackedByteArray::from(chunk.decoded.as_slice()));
                    fields.set("expected_size", chunk.expected_size);
                    fields.set("compressed", chunk.compressed);
                    chunks.push(&fields.to_variant());
                }

                result.set("ok", true);
                result.set("error", "");
                result.set("map_size", form.map_size);
                result.set("large_version", form.large_version);
                result.set("repaired_length", form.repaired_length);
                result.set("chunks", &chunks);
            }
            Err(error) => {
                result.set("ok", false);
                result.set("error", error.as_str());
            }
        }

        result
    }

    /// A FORM file of the chunk IDs and their stored payloads.
    #[func]
    fn encode(map_size: i64, large_version: i64, chunk_ids: PackedStringArray, payloads: VarArray) -> PackedByteArray {
        let ids: Vec<String> = chunk_ids.as_slice().iter().map(|id| id.to_string()).collect();
        let stored: Vec<PackedByteArray> = payloads
            .iter_shared()
            .map(|payload| payload.try_to::<PackedByteArray>().unwrap_or_default())
            .collect();
        let chunks = ids.iter().zip(&stored).map(|(id, payload)| (id.as_str(), payload.as_slice()));

        PackedByteArray::from(sc2::encode(map_size, large_version, chunks).as_slice())
    }

    /// The decoded size of a chunk of an SC2, SCN, or SCLG file, or -1.
    #[func]
    fn decoded_size(chunk_id: GString, map_size: i64, large_version: i64) -> i64 {
        sc2::decoded_size(&chunk_id.to_string(), map_size, large_version)
    }
}
