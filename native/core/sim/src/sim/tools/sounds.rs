//! The sounds of tool edits, as ToolSoundRules.

use super::ids::{group, landscape, power, rewards};

pub const TRACTOR: i64 = 508;
pub const BUILD: i64 = 500;
pub const ERROR: i64 = 501;
pub const ZONE: i64 = 503;
pub const CENTER: i64 = 505;
pub const SERVICE: i64 = 506;
pub const FIRE_STATION: i64 = 509;
pub const TREE: i64 = 503;
pub const WATER: i64 = 511;
pub const REWARD: i64 = 513;
pub const POWER_LINE: i64 = 514;
pub const BUS_DEPOT: i64 = 521;
pub const PRISON: i64 = 522;
pub const EDUCATION: i64 = 523;
pub const RAIL_DEPOT: i64 = 524;
pub const ZOO: i64 = 527;

/// The last subtool of the groups whose subtools all build.
const LAST_WATER_SUBTOOL: i64 = 4;
const LAST_POWER_PLANT: i64 = 10;
const LAST_REWARD: i64 = 8;
const LAST_ROAD_TOOL: i64 = 3;
const ROADS_BUS_DEPOT: i64 = 4;
const LAST_RAIL_TOOL: i64 = 4;
const RAIL_DEPOT_TOOL: i64 = 2;
const LAST_RECREATION_TOOL: i64 = 4;
const RECREATION_ZOO: i64 = 2;
/// The zone types from residential through seaport.
const ZONED_TYPES: std::ops::RangeInclusive<i64> = 1..=9;

/// The sounds of a successful edit of a tool.
pub fn success_events(group_index: i64, subtool: i64) -> Vec<i64> {
    let sounds: &[i64] = match (group_index, subtool) {
        (group::LANDSCAPE, landscape::TREES | landscape::FOREST) => &[TREE],
        (group::LANDSCAPE, landscape::WATER) => &[WATER],
        (group::DISPATCH, 1) => &[FIRE_STATION],
        (group::DISPATCH, 0 | 2) => &[SERVICE],
        (group::POWER, power::WIRES) => &[POWER_LINE],
        (group::POWER, power::COAL..=LAST_POWER_PLANT) => &[BUILD],
        (group::WATER, 0..=LAST_WATER_SUBTOOL) => &[BUILD],
        (group::REWARDS, rewards::ARCOLOGIES) => &[],
        (group::REWARDS, 0..=LAST_REWARD) => &[REWARD],
        (group::ROADS, ROADS_BUS_DEPOT) => &[BUS_DEPOT],
        (group::ROADS, 0..=LAST_ROAD_TOOL) => &[BUILD],
        (group::RAIL, RAIL_DEPOT_TOOL) => &[RAIL_DEPOT, BUILD],
        (group::RAIL, 0..=LAST_RAIL_TOOL) => &[BUILD],
        (group::PORTS | group::RESIDENTIAL | group::COMMERCIAL | group::INDUSTRIAL, _) => &[ZONE],
        (group::EDUCATION, _) => &[EDUCATION],
        (group::SERVICES, 0 | 2) => &[SERVICE],
        (group::SERVICES, 1) => &[FIRE_STATION],
        (group::SERVICES, 3) => &[PRISON],
        (group::RECREATION, RECREATION_ZOO) => &[ZOO],
        (group::RECREATION, 0..=LAST_RECREATION_TOOL) => &[REWARD],
        (group::CENTERING, _) => &[CENTER],
        _ => &[],
    };

    sounds.to_vec()
}

/// The sounds of a zone edit of `zone_type`.
pub fn zone_success_events(zone_type: i64) -> Vec<i64> {
    if ZONED_TYPES.contains(&zone_type) { vec![ZONE] } else { Vec::new() }
}

/// The sounds of a failed edit. A landscape tool sounds only when funds are short.
pub fn failure_events(group_index: i64, subtool: i64, error: &str) -> Vec<i64> {
    if group_index == group::LANDSCAPE {
        return if error == "insufficient funds" { vec![ERROR] } else { Vec::new() };
    }

    let choosers =
        (group_index == group::POWER && subtool == power::PLANTS) || (group_index == group::REWARDS && subtool == rewards::ARCOLOGIES);

    if !(group::POWER..=group::RECREATION).contains(&group_index) || choosers {
        return Vec::new();
    }

    vec![ERROR]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn each_tool_sounds_its_family() {
        assert_eq!(success_events(group::RAIL, RAIL_DEPOT_TOOL), vec![RAIL_DEPOT, BUILD]);
        assert_eq!(success_events(group::REWARDS, rewards::ARCOLOGIES), Vec::<i64>::new());
        assert_eq!(success_events(group::LANDSCAPE, landscape::STREAM), Vec::<i64>::new());
        assert_eq!(failure_events(group::LANDSCAPE, 0, "insufficient funds"), vec![ERROR]);
        assert_eq!(failure_events(group::POWER, power::PLANTS, ""), Vec::<i64>::new());
        assert_eq!(failure_events(group::QUERY, 0, ""), Vec::<i64>::new());
        assert_eq!(zone_success_events(0), Vec::<i64>::new());
    }
}
