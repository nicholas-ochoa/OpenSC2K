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

/// New City of earlier versions put the ocean in neighbor slot 0, also when its
/// landform had the ocean on another side. On load, a city with one ocean
/// neighbor whose side is less than half salt water, and a side with more
/// salt water, moves the ocean to the first side with the most salt water. The
/// neighbor of that side takes the old ocean slot. Every supplied city and
/// scenario keeps its neighbors. Returns true when the neighbors changed.
pub fn repair_ocean_side(city: &mut City) -> bool {
    if city.missing_or_resized(&["MISC", "XBIT"]).is_some() || city.misc_u32(misc::HAS_OCEAN) == 0 {
        return false;
    }

    let oceans: Vec<i64> = (0..COUNT).filter(|&slot| is_ocean(city, slot)).collect();

    let [ocean] = oceans[..] else {
        return false;
    };

    let compass = city.compass_rotation();
    let shores = shore_lengths(&city.xbit.data, city.map_size);
    let ocean_shore = shores[side_of_slot(ocean, compass) as usize];
    let widest = widest_shore(&shores);

    if ocean_shore * 2 >= city.map_size || shores[widest as usize] <= ocean_shore {
        return false;
    }

    let ocean_offset = (misc::NEIGHBORS + ocean * STRIDE) as usize;
    let target_offset = (misc::NEIGHBORS + slot_of_side(widest, compass) * STRIDE) as usize;
    let mut data = city.misc.data.clone();

    for byte in 0..STRIDE as usize {
        data.swap(ocean_offset + byte, target_offset + byte);
    }

    city.misc.replace(data);

    true
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::testing::empty_city;

    const EDGE: i64 = 128;

    /// An ocean city whose neighbors 1 to 3 are named, with salt water on the
    /// first `length` tiles of each of `sides`.
    fn coast_city(compass: i64, ocean_slots: &[i64], sides: &[i64], length: i64) -> City {
        let mut city = empty_city(EDGE);
        city.set_misc_u32(misc::HAS_OCEAN, 1);
        city.set_misc_u32(misc::COMPASS, compass);

        for slot in 0..COUNT {
            let name = if ocean_slots.contains(&slot) { 0 } else { slot + 1 };
            city.set_misc_u32(misc::NEIGHBORS + slot * STRIDE, name);
            city.set_misc_u32(misc::NEIGHBORS + slot * STRIDE + 4, (slot + 1) * 1000);
        }

        let last = EDGE - 1;

        for &side in sides {
            for along in 0..length {
                let (x, y) = [(last, along), (along, last), (0, along), (along, 0)][side as usize];
                city.xbit.data[(x * EDGE + y) as usize] |= SALT_WATER as u8;
            }
        }

        city
    }

    fn names(city: &City) -> Vec<i64> {
        (0..COUNT).map(|slot| city.misc_u32(misc::NEIGHBORS + slot * STRIDE)).collect()
    }

    /// The old New City put the ocean in slot 0. The repair swaps it with the
    /// neighbor on the side with the most salt water, once.
    #[test]
    fn a_misplaced_ocean_moves_to_the_salt_water_side() {
        // (compass, side with salt water, slot that becomes the ocean)
        for (compass, side, target) in [(0, 2, 2), (0, 3, 3), (1, 2, 3), (3, 0, 3)] {
            let mut city = coast_city(compass, &[0], &[side], EDGE);
            let before = names(&city);

            assert!(repair_ocean_side(&mut city), "compass {compass} side {side}");
            assert!(city.misc.written);

            let mut expected = before.clone();
            expected.swap(0, target as usize);
            assert_eq!(names(&city), expected, "compass {compass} side {side}");
            assert_eq!(city.misc_u32(misc::NEIGHBORS + 4), (target + 1) * 1000, "the record moves whole");
            assert!(!repair_ocean_side(&mut city), "a repaired city stays unchanged");
        }
    }

    /// Original maps keep the ocean in slot 0. So do maps where the ocean
    /// side is at least half salt water, maps with no other salt water, maps
    /// without an ocean, and maps with more than one ocean neighbor.
    #[test]
    fn other_neighbors_stay_unchanged() {
        let mut cases = [
            coast_city(0, &[0], &[0, 2], EDGE),
            coast_city(0, &[0], &[0, 2], EDGE / 2),
            coast_city(0, &[0], &[], 0),
            coast_city(0, &[0, 1], &[2], EDGE),
            coast_city(0, &[], &[2], EDGE),
        ];
        cases[2].set_misc_u32(misc::HAS_OCEAN, 0);

        for (index, city) in cases.iter_mut().enumerate() {
            let before = names(city);

            assert!(!repair_ocean_side(city), "case {index}");
            assert_eq!(names(city), before, "case {index}");
        }
    }

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
