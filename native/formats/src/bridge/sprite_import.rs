//! The sprite set decoders of the game importer.

use godot::prelude::*;
use sc2k_assets::import::sprites::{self, SpriteSet};

/// `{error, warnings, sprites}`; each sprite has `sprite_id`, `width`,
/// `height`, `encoded`, `allow_unpadded_odd_runs`, and DOS `indices`.
fn set_value(set: &SpriteSet) -> VarDictionary {
    let mut list = VarArray::new();

    for sprite in &set.sprites {
        let mut fields = VarDictionary::new();
        fields.set("sprite_id", sprite.sprite_id);
        fields.set("width", sprite.width as i64);
        fields.set("height", sprite.height as i64);
        fields.set("encoded", &PackedByteArray::from(sprite.encoded.as_slice()));
        fields.set("allow_unpadded_odd_runs", sprite.allow_unpadded_odd_runs);
        fields.set("indices", &PackedInt32Array::from(sprite.indices.as_slice()));
        list.push(&fields.to_variant());
    }

    let mut result = VarDictionary::new();
    result.set("error", set.error.as_str());
    result.set(
        "warnings",
        &set.warnings
            .iter()
            .map(|warning| GString::from(warning.as_str()))
            .collect::<PackedStringArray>(),
    );
    result.set("sprites", &list);
    result
}

/// The sprite set decoders of the game importer.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeSpriteImport {}

#[godot_api]
impl NativeSpriteImport {
    #[func]
    fn mac_tile_set(data: PackedByteArray) -> VarDictionary {
        set_value(&sprites::mac_tile_set(data.as_slice()))
    }

    #[func]
    fn tiles_database(data: PackedByteArray) -> VarDictionary {
        set_value(&sprites::tiles_database(data.as_slice()))
    }

    #[func]
    fn dos(header: PackedByteArray, data: PackedByteArray) -> VarDictionary {
        set_value(&sprites::dos(header.as_slice(), data.as_slice()))
    }
}
