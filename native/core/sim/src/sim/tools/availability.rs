//! The tools that a city allows, as ToolAvailability: the submenu masks of the
//! executable, extended by released inventions, granted rewards, and the
//! military base.

use super::ids::{group, landscape, power, rewards};
use crate::sim::bytes::{read_u32_be, write_u32_be};
use crate::sim::ids::ordinance_ids::NUCLEAR_FREE_ZONE_MASK;
use crate::sim::ids::sc2misc_layout as misc;

pub const INVENTION_COUNT: usize = 17;
const FIRST_ARCOLOGY_INVENTION: usize = 12;
const LAST_ARCOLOGY_INVENTION: usize = 15;

/// The executable table at 0x004e9560. The last three groups use direct
/// actions and no submenu mask.
const BASE_GROUP_MASKS: [i64; group::COUNT] = [
    0x1f, 0x03, 0x03, 0x03, 0x07, 0x00, 0x05, 0x05, 0x01, 0x03, 0x03, 0x03, 0x0f, 0x0f, 0x1f, 0x00, 0x00, 0x00,
];

/// Power plants in chooser order: coal, hydro, oil, gas, nuclear, wind,
/// solar, microwave, and fusion. The first three need no invention.
const BASE_POWER_PLANT_MASK: i64 = 0x07;
const NUCLEAR_INVENTION: usize = 1;
const NUCLEAR_PLANT: i64 = 0x10;

/// The power plant that each other invention releases.
const POWER_INVENTIONS: [(usize, i64); 5] = [(0, 0x08), (2, 0x40), (3, 0x20), (4, 0x80), (5, 0x100)];

/// The submenu items that each later invention releases: invention, group, items.
const GROUP_INVENTIONS: [(usize, i64, i64); 6] = [
    (6, group::PORTS, 0x02),
    (7, group::ROADS, 0x0a),
    (8, group::ROADS, 0x10),
    (9, group::RAIL, 0x1a),
    (10, group::WATER, 0x08),
    (11, group::WATER, 0x10),
];

/// The Arcologies reward item, which needs this progression and an arcology invention.
const ARCOLOGY_REWARD: i64 = 1 << rewards::ARCOLOGIES;
const ARCOLOGY_PROGRESSION: i64 = 6;

/// The military dispatch item, which the army, air force, and navy bases supply.
const MILITARY_DISPATCH: i64 = 0x04;
const DISPATCH_BASES: [i64; 3] = [2, 3, 4];

/// MISC city mode 2. SIMCITY.EXE FUN_0040b250 disables the Emergency button
/// in any other mode.
pub const DISASTER_CITY_MODE: i64 = 2;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Availability {
    pub group_masks: [i64; group::COUNT],
    pub power_plant_mask: i64,
    pub released_inventions: [bool; INVENTION_COUNT],
    pub arcology_count: i64,
    pub progression: i64,
    pub military_base_type: i64,
}

fn released(misc: &[u8], invention: usize) -> bool {
    read_u32_be(misc, misc::INVENTION_YEARS + invention as i64 * 4) & 0xffff == 0
}

fn arcology_count(misc: &[u8]) -> i64 {
    (FIRST_ARCOLOGY_INVENTION..=LAST_ARCOLOGY_INVENTION)
        .filter(|&invention| released(misc, invention))
        .count() as i64
}

/// The masks of a city MISC payload.
pub fn inspect(misc: &[u8]) -> Result<Availability, String> {
    if misc.len() as i64 != misc::SIZE {
        return Err("MISC has the wrong size".into());
    }

    let mut group_masks = BASE_GROUP_MASKS;
    let mut power_plant_mask = BASE_POWER_PLANT_MASK;
    let released_inventions: [bool; INVENTION_COUNT] = std::array::from_fn(|invention| released(misc, invention));

    for (invention, plant) in POWER_INVENTIONS {
        if released_inventions[invention] {
            power_plant_mask |= plant;
        }
    }

    if released_inventions[NUCLEAR_INVENTION] && read_u32_be(misc, misc::ORDINANCES) & NUCLEAR_FREE_ZONE_MASK == 0 {
        power_plant_mask |= NUCLEAR_PLANT;
    }

    for (invention, group_index, items) in GROUP_INVENTIONS {
        if released_inventions[invention] {
            group_masks[group_index as usize] |= items;
        }
    }

    let arcology_count = arcology_count(misc);
    let progression = read_u32_be(misc, misc::PROGRESSION) & 0xffff;
    group_masks[group::REWARDS as usize] = read_u32_be(misc, misc::GRANTED_REWARDS) & 0xffff;

    if progression >= ARCOLOGY_PROGRESSION && arcology_count > 0 {
        group_masks[group::REWARDS as usize] |= ARCOLOGY_REWARD;
    }

    let military_base_type = read_u32_be(misc, misc::MILITARY_BASE_TYPE) & 0xffff;

    if DISPATCH_BASES.contains(&military_base_type) {
        group_masks[group::DISPATCH as usize] |= MILITARY_DISPATCH;
    }

    Ok(Availability {
        group_masks,
        power_plant_mask,
        released_inventions,
        arcology_count,
        progression,
        military_base_type,
    })
}

/// True when a city with `misc` in `city_mode` allows the tool. Signs, the
/// query and centering tools, and the forest brush are always available.
/// The dispatch tools follow the disaster mode; the dispatch command reports
/// the unit counts.
pub fn is_available(misc: &[u8], city_mode: i64, group_index: i64, subtool: i64) -> bool {
    if group_index >= group::SIGNS || (group_index == group::LANDSCAPE && subtool == landscape::FOREST) {
        return true;
    }

    let Ok(masks) = inspect(misc) else {
        return false;
    };

    if !(0..group::COUNT as i64).contains(&group_index) || !(0..63).contains(&subtool) {
        return false;
    }

    if group_index == group::DISPATCH {
        return city_mode == DISASTER_CITY_MODE;
    }

    if group_index == group::POWER && subtool >= power::COAL {
        return masks.power_plant_mask & (1 << (subtool - power::COAL)) != 0;
    }

    if group_index == group::REWARDS && subtool >= rewards::PLYMOUTH {
        return masks.group_masks[group::REWARDS as usize] & ARCOLOGY_REWARD != 0 && subtool - rewards::PLYMOUTH < masks.arcology_count;
    }

    masks.group_masks[group_index as usize] & (1 << subtool) != 0
}

/// Grant the Arcologies reward when the progression and an arcology invention
/// allow it. Returns the granted reward mask.
pub fn rebuild_reward_mask(misc: &mut [u8]) -> i64 {
    if misc.len() as i64 != misc::SIZE {
        return 0;
    }

    let mut mask = read_u32_be(misc, misc::GRANTED_REWARDS);
    let progression = read_u32_be(misc, misc::PROGRESSION) & 0xffff;

    if progression >= ARCOLOGY_PROGRESSION && arcology_count(misc) > 0 {
        mask |= ARCOLOGY_REWARD;
    }

    write_u32_be(misc, misc::GRANTED_REWARDS, mask);

    mask
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A MISC payload with every invention pending.
    fn pending_misc() -> Vec<u8> {
        let mut data = vec![0; misc::SIZE as usize];

        for invention in 0..INVENTION_COUNT {
            write_u32_be(&mut data, misc::INVENTION_YEARS + invention as i64 * 4, 2050);
        }

        data
    }

    fn release(data: &mut [u8], invention: usize) {
        write_u32_be(data, misc::INVENTION_YEARS + invention as i64 * 4, 0);
    }

    #[test]
    fn a_new_city_has_the_base_tools() {
        let data = pending_misc();
        let masks = inspect(&data).unwrap();
        assert_eq!(masks.group_masks[group::ROADS as usize], 0x05);
        assert_eq!(masks.power_plant_mask, BASE_POWER_PLANT_MASK);
        assert!(is_available(&data, 1, group::ROADS, 0) && !is_available(&data, 1, group::ROADS, 1));
        assert!(
            !is_available(&data, 1, group::POWER, power::COAL + 4),
            "nuclear power waits for its invention"
        );
        assert!(is_available(&data, 1, group::SIGNS, 0) && is_available(&data, 1, group::LANDSCAPE, landscape::FOREST));
        assert!(!is_available(&data, 1, group::DISPATCH, 0) && is_available(&data, DISASTER_CITY_MODE, group::DISPATCH, 0));
        assert!(!is_available(&data[1..], 1, group::ROADS, 0), "a short MISC allows nothing");
    }

    #[test]
    fn inventions_release_their_tools() {
        let mut data = pending_misc();
        release(&mut data, 1);
        release(&mut data, 7);
        assert!(is_available(&data, 1, group::POWER, power::COAL + 4));
        assert!(is_available(&data, 1, group::ROADS, 1) && is_available(&data, 1, group::ROADS, 3));

        write_u32_be(&mut data, misc::ORDINANCES, NUCLEAR_FREE_ZONE_MASK);
        assert!(
            !is_available(&data, 1, group::POWER, power::COAL + 4),
            "a nuclear-free zone bans the plant"
        );
    }

    #[test]
    fn arcologies_need_the_progression_and_an_invention() {
        let mut data = pending_misc();
        write_u32_be(&mut data, misc::PROGRESSION, ARCOLOGY_PROGRESSION);
        assert_eq!(rebuild_reward_mask(&mut data), 0);

        release(&mut data, FIRST_ARCOLOGY_INVENTION);
        release(&mut data, FIRST_ARCOLOGY_INVENTION + 1);
        assert_eq!(rebuild_reward_mask(&mut data), ARCOLOGY_REWARD);
        assert!(is_available(&data, 1, group::REWARDS, rewards::PLYMOUTH + 1));
        assert!(
            !is_available(&data, 1, group::REWARDS, rewards::PLYMOUTH + 2),
            "two arcology inventions allow two arcologies"
        );
    }

    #[test]
    fn military_bases_supply_military_dispatch() {
        let mut data = pending_misc();
        write_u32_be(&mut data, misc::MILITARY_BASE_TYPE, 3);
        assert_eq!(inspect(&data).unwrap().group_masks[group::DISPATCH as usize], 0x07);
    }
}
