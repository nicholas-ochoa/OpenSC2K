//! Tile values of the debug layers that the raw tile bytes do not hold
//! directly. Each function returns one byte for each map cell.

use crate::changes::overlay;
use crate::ids::{sc2tile_flags, sc2zone_layout, terrain_tile_ids, underground_tile_ids};

/// The largest zone type: 1 to 6 are the residential, commercial and
/// industrial densities, 7 military, 8 airport and 9 seaport.
pub const LAST_ZONE_TYPE: u8 = 9;

/// Bits of the unusual values layer.
pub const UNUSUAL_ZONE: u8 = 0x01;
pub const UNUSUAL_TERRAIN: u8 = 0x02;
pub const UNUSUAL_UNDERGROUND: u8 = 0x04;
pub const UNUSUAL_MARK: u8 = 0x08;

/// Kinds of the overlay kind layer.
pub const OVERLAY_NONE: u8 = 0;
pub const OVERLAY_SIGN: u8 = 1;
pub const OVERLAY_FACILITY: u8 = 2;
pub const OVERLAY_OBJECT: u8 = 3;
pub const OVERLAY_CONNECTION: u8 = 4;
pub const OVERLAY_MARKER: u8 = 5;

// Sc2OverlayLayout ranges.
const ORIGINAL_SIGN_LAST: i32 = 50;
const ORIGINAL_FACILITY_LAST: i32 = ORIGINAL_SIGN_LAST + 150;
const ORIGINAL_THING_LAST: i32 = ORIGINAL_FACILITY_LAST + 40;
const ORIGINAL_MAX_ID: i32 = 0xff;
const CONNECTION_MARKER: i32 = 0xfa;
const EXTRA_SIGN: i32 = 4096;
const EXTRA_THING: i32 = 8192;
const EXTRA_FACILITY_HIGH: i32 = 16384;

/// One field of the ALTM words: `(word >> shift) & mask`.
pub fn altitude_field(altitude: &[i32], shift: u32, mask: i32) -> Vec<u8> {
    altitude.iter().map(|word| ((word >> shift) & mask) as u8).collect()
}

fn unusual_terrain(id: u8) -> bool {
    use terrain_tile_ids::*;

    matches!(
        id,
        UNUSED_0E | UNUSED_0F | UNUSED_1E | UNUSED_1F | UNUSED_2F | UNUSED_3F | UNUSED_46 | UNUSED_47
    ) || id > UNUSED_47
}

/// Bits for values that no known table names: a zone type above 9, an unused
/// terrain or underground ID, and a MARK flag that a scan left set.
pub fn unusual_values(zones: &[u8], terrain: &[u8], underground: &[u8], flags: &[u8]) -> Vec<u8> {
    let cells = zones.len().min(terrain.len()).min(underground.len()).min(flags.len());
    let mut result = vec![0_u8; cells];

    for (i, value) in result.iter_mut().enumerate() {
        if zones[i] & sc2zone_layout::TYPE_MASK > LAST_ZONE_TYPE {
            *value |= UNUSUAL_ZONE;
        }

        if unusual_terrain(terrain[i]) {
            *value |= UNUSUAL_TERRAIN;
        }

        if underground[i] >= underground_tile_ids::UNUSED_24 {
            *value |= UNUSUAL_UNDERGROUND;
        }

        if flags[i] & sc2tile_flags::MARK != 0 {
            *value |= UNUSUAL_MARK;
        }
    }

    result
}

/// The kind of the top overlay value of a tile, as OverlayData.read shows it.
pub fn overlay_kind(id: i32) -> u8 {
    match id {
        0 => OVERLAY_NONE,
        1..=ORIGINAL_SIGN_LAST => OVERLAY_SIGN,
        CONNECTION_MARKER => OVERLAY_CONNECTION,
        id if id <= ORIGINAL_FACILITY_LAST => OVERLAY_FACILITY,
        id if id <= ORIGINAL_THING_LAST => OVERLAY_OBJECT,
        id if id <= ORIGINAL_MAX_ID => OVERLAY_MARKER,
        id if id < EXTRA_SIGN => OVERLAY_FACILITY,
        id if id < EXTRA_THING => OVERLAY_SIGN,
        id if id < EXTRA_FACILITY_HIGH => OVERLAY_OBJECT,
        _ => OVERLAY_FACILITY,
    }
}

/// The overlay kind of each of `cells` tiles. `overlays` is any XTXT layout.
pub fn overlay_kinds(overlays: &[u8], cells: usize) -> Vec<u8> {
    if overlays.len() < cells {
        return vec![OVERLAY_NONE; cells];
    }

    (0..cells).map(|i| overlay_kind(overlay(overlays, i))).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn altitude_fields_split_the_words() {
        let words = [5 | 7 << 5 | 3 << 10, 31];

        assert_eq!(altitude_field(&words, 0, 0x1f), vec![5, 31]);
        assert_eq!(altitude_field(&words, 5, 0x1f), vec![7, 0]);
        assert_eq!(altitude_field(&words, 10, 0x3f), vec![3, 0]);
    }

    #[test]
    fn unusual_values_mark_each_rule() {
        let zones = [0x10 | 9, 10, 0, 0, 0];
        let terrain = [0, 0, terrain_tile_ids::UNUSED_0F, 0x50, 0];
        let underground = [0, 0, 0, underground_tile_ids::UNUSED_24, 0];
        let flags = [0, 0, 0, 0, sc2tile_flags::MARK | sc2tile_flags::POWERED];

        assert_eq!(
            unusual_values(&zones, &terrain, &underground, &flags),
            vec![
                0,
                UNUSUAL_ZONE,
                UNUSUAL_TERRAIN,
                UNUSUAL_TERRAIN | UNUSUAL_UNDERGROUND,
                UNUSUAL_MARK
            ]
        );
    }

    #[test]
    fn overlay_kinds_follow_the_id_ranges() {
        assert_eq!(overlay_kind(0), OVERLAY_NONE);
        assert_eq!(overlay_kind(12), OVERLAY_SIGN);
        assert_eq!(overlay_kind(51), OVERLAY_FACILITY);
        assert_eq!(overlay_kind(201), OVERLAY_OBJECT);
        assert_eq!(overlay_kind(0xfa), OVERLAY_CONNECTION);
        assert_eq!(overlay_kind(0xf1), OVERLAY_MARKER);
        assert_eq!(overlay_kind(300), OVERLAY_FACILITY);
        assert_eq!(overlay_kind(5000), OVERLAY_SIGN);
        assert_eq!(overlay_kind(9000), OVERLAY_OBJECT);
        assert_eq!(overlay_kind(20000), OVERLAY_FACILITY);
    }

    #[test]
    fn narrow_overlays_read_one_byte_for_each_tile() {
        assert_eq!(overlay_kinds(&[0, 3, 60, 0xfa], 4), vec![0, 1, 2, 4]);
        assert_eq!(overlay_kinds(&[], 2), vec![0, 0]);
    }
}
