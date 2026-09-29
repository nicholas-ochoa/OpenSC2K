//! The scans after a city load, as SimulationEngine.initialize_loaded_city.

use crate::sim::city::City;
use crate::sim::civic::mayor;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::infrastructure::{power, water};
use crate::sim::random::SimRandom;

/// Utility use and developed tiles after the load scans.
pub struct LoadScan {
    pub power_usage_percent: i64,
    pub water_usage_percent: i64,
    pub developed_tiles: i64,
}

/// The original loads a city file, then scans power and water and counts the
/// developed tiles. The power scan uses the process random state. None is a failed scan.
pub fn initialize_loaded_city(city: &mut City, random: &mut SimRandom) -> Option<LoadScan> {
    if city.is_extended() && mayor::recount_tiles(city) < 0 {
        return None;
    }

    let power = power::run(city, random);

    if !power.base.ok {
        return None;
    }

    let water = water::run(city);

    if !water.base.ok {
        return None;
    }

    let edge = city.map_size;

    if city.xbit.data.len() as i64 != edge * edge {
        return None;
    }

    let mut developed = 0;
    let City { xbld, xzon, xbit, .. } = city;
    let flags = xbit.mutate();

    for x in 0..edge {
        for y in 0..edge {
            let index = (x * edge + y) as usize;

            // The day-three scan has the same count and half-coordinate mark.
            if xbld.data[index] as i64 >= tiles::FIRST_ROAD || xzon.data[index] as i64 & zone::TYPE_MASK != 0 {
                let marked = ((x >> 1) * edge + (y >> 1)) as usize;
                flags[marked] |= flag_bits::MARK as u8;
                developed += 1;
            }
        }
    }

    Some(LoadScan {
        power_usage_percent: power.usage_percent,
        water_usage_percent: water.usage_percent,
        developed_tiles: developed,
    })
}
