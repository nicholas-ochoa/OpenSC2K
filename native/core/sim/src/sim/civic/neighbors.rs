//! The four neighbor cities of MISC and the map sides they border. At compass
//! rotation 0, slots 0 to 3 border the high-x, high-y, low-x and low-y sides.
//! A turn of the view turns the map and the compass together, so slot `s`
//! borders side `(s - compass) & 3`. CityNeighbors of the scripts places the
//! connection signs by the same rule. A neighbor with name index 0 is the ocean.

use crate::sim::city::City;
use crate::sim::ids::sc2misc_layout as misc;
use crate::sim::ids::sc2tile_flags::SALT_WATER;

pub const COUNT: i64 = 4;
pub const STRIDE: i64 = 0x10;

/// The name index is the low word of the first field.
const NAME_INDEX_MASK: i64 = 0xffff;

/// The neighbor slot that borders map side `side`.
pub fn slot_of_side(side: i64, compass: i64) -> i64 {
    (compass + side) & 3
}

/// The map side that neighbor `slot` borders.
pub fn side_of_slot(slot: i64, compass: i64) -> i64 {
    (slot - compass) & 3
}

/// True when neighbor `slot` is the ocean.
pub fn is_ocean(city: &City, slot: i64) -> bool {
    city.misc_u32(misc::NEIGHBORS + slot * STRIDE) & NAME_INDEX_MASK == 0
}

/// The first ocean neighbor, or slot 0 when no neighbor is the ocean. The
/// ocean of an original map always borders slot 0.
pub fn ocean_slot(city: &City) -> i64 {
    (0..COUNT).find(|&slot| is_ocean(city, slot)).unwrap_or(0)
}

/// The salt-water tiles along each map side, in side order.
pub fn shore_lengths(tile_flags: &[u8], map_size: i64) -> [i64; 4] {
    let edge = map_size as usize;
    let mut lengths = [0; 4];

    if edge == 0 || tile_flags.len() < edge * edge {
        return lengths;
    }

    let last = edge - 1;

    for along in 0..edge {
        let tiles = [(last, along), (along, last), (0, along), (along, 0)];

        for (side, (x, y)) in tiles.into_iter().enumerate() {
            if i64::from(tile_flags[x * edge + y]) & SALT_WATER != 0 {
                lengths[side] += 1;
            }
        }
    }

    lengths
}

/// The first side with the most salt water.
pub fn widest_shore(shores: &[i64; 4]) -> i64 {
    // max_by_key keeps the last maximum. Search from the last side
    (0..COUNT).rev().max_by_key(|&side| shores[side as usize]).unwrap_or(0)
}

/// The ocean sides of a new city: each side that is at least half salt water,
/// or else the first side with the most salt water. An island map has the
/// ocean on all sides.
pub fn ocean_sides(shores: &[i64; 4], map_size: i64, island: bool) -> Vec<i64> {
    let sides: Vec<i64> = (0..COUNT).filter(|&side| island || shores[side as usize] * 2 >= map_size).collect();

    if sides.is_empty() { vec![widest_shore(shores)] } else { sides }
}

#[cfg(test)]
mod tests {
    use super::*;

    const EDGE: i64 = 128;

    #[test]
    fn the_founding_sides_follow_the_salt_water() {
        assert_eq!(ocean_sides(&[128, 0, 0, 20], EDGE, false), [0]);
        assert_eq!(ocean_sides(&[56, 0, 0, 88], EDGE, false), [3]);
        assert_eq!(ocean_sides(&[64, 73, 0, 0], EDGE, false), [0, 1]);
        assert_eq!(ocean_sides(&[40, 0, 0, 58], EDGE, false), [3]);
        assert_eq!(ocean_sides(&[10, 10, 0, 0], EDGE, false), [0]);
        assert_eq!(ocean_sides(&[0, 0, 0, 0], EDGE, true), [0, 1, 2, 3]);
    }
}
