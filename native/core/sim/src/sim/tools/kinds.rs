//! The command family of each catalog tool, as the `supports_tool` rules of the
//! command classes.

use super::commands::network::segment::tool_mode;
use super::ids::group;
use crate::sim::ids::building_tile_ids as tiles;

/// The zone types of the zoning groups: ports, residential, commercial, industrial.
const ZONE_TYPES: [(i64, [i64; 2]); 4] = [
    (group::PORTS, [9, 8]),
    (group::RESIDENTIAL, [1, 2]),
    (group::COMMERCIAL, [3, 4]),
    (group::INDUSTRIAL, [5, 6]),
];

/// The building of each building tool, by (group, subtool).
const BUILDING_TILES: [((i64, i64), i64); 36] = [
    ((3, 2), tiles::COAL_POWER),
    ((3, 4), tiles::OIL_POWER),
    ((3, 5), tiles::GAS_POWER),
    ((3, 6), tiles::NUCLEAR_POWER),
    ((3, 7), tiles::WIND_POWER),
    ((3, 8), tiles::SOLAR_POWER),
    ((3, 9), tiles::MICROWAVE_POWER),
    ((3, 10), tiles::FUSION_POWER),
    ((4, 1), tiles::WATER_PUMP),
    ((4, 2), tiles::WATER_TOWER),
    ((4, 3), tiles::WATER_TREATMENT),
    ((4, 4), tiles::DESALINIZATION),
    ((5, 0), tiles::MAYOR_HOUSE),
    ((5, 1), tiles::CITY_HALL),
    ((5, 2), tiles::STATUE),
    ((5, 3), tiles::LLAMA_DOME),
    ((5, 5), tiles::PLYMOUTH_ARCOLOGY),
    ((5, 6), tiles::FOREST_ARCOLOGY),
    ((5, 7), tiles::DARCO_ARCOLOGY),
    ((5, 8), tiles::LAUNCH_ARCOLOGY),
    ((6, 4), tiles::BUS_DEPOT),
    ((7, 2), tiles::RAIL_STATION),
    ((7, 3), tiles::SUBWAY_STATION),
    ((12, 0), tiles::SCHOOL),
    ((12, 1), tiles::COLLEGE),
    ((12, 2), tiles::LIBRARY),
    ((12, 3), tiles::MUSEUM),
    ((13, 0), tiles::POLICE_STATION),
    ((13, 1), tiles::FIRE_STATION),
    ((13, 2), tiles::HOSPITAL),
    ((13, 3), tiles::PRISON),
    ((14, 0), tiles::SMALL_PARK),
    ((14, 1), tiles::BIG_PARK),
    ((14, 2), tiles::ZOO),
    ((14, 3), tiles::STADIUM),
    ((14, 4), tiles::MARINA),
];

/// The zone type that a tool paints: 0 for De-zone, or `None` for other tools.
pub fn zone_type(group_index: i64, subtool: i64) -> Option<i64> {
    if group_index == group::BULLDOZER && subtool == 4 {
        return Some(0);
    }

    let (_, types) = ZONE_TYPES.iter().find(|(zone_group, _)| *zone_group == group_index)?;

    usize::try_from(subtool).ok().and_then(|subtool| types.get(subtool)).copied()
}

/// The building that a building tool places.
pub fn building_tile(group_index: i64, subtool: i64) -> Option<i64> {
    BUILDING_TILES
        .iter()
        .find(|(tool, _)| *tool == (group_index, subtool))
        .map(|(_, tile)| *tile)
}

/// The command family of a tool.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Kind {
    Zone,
    Landscape,
    Building,
    Network,
    Hydro,
    SubwayToRail,
    Onramp,
    Tunnel,
    Highway,
    Demolish,
    Terrain,
    Dispatch,
    Sign,
    Query,
    Center,
}

/// The command family of a tool, or `None` for a tool without a command.
pub fn kind(group_index: i64, subtool: i64) -> Option<Kind> {
    if zone_type(group_index, subtool).is_some() {
        return Some(Kind::Zone);
    }

    if group_index == group::LANDSCAPE && [0, 1, 3].contains(&subtool) {
        return Some(Kind::Landscape);
    }

    if building_tile(group_index, subtool).is_some() {
        return Some(Kind::Building);
    }

    if tool_mode(group_index, subtool).is_some() {
        return Some(Kind::Network);
    }

    let kind = match (group_index, subtool) {
        (group::POWER, 3) => Kind::Hydro,
        (group::RAIL, 4) => Kind::SubwayToRail,
        (group::ROADS, 3) => Kind::Onramp,
        (group::ROADS, 2) => Kind::Tunnel,
        (group::ROADS, 1) => Kind::Highway,
        (group::BULLDOZER, 0) => Kind::Demolish,
        (group::BULLDOZER, 1..=3) => Kind::Terrain,
        (group::DISPATCH, 0..=2) => Kind::Dispatch,
        (group::SIGNS, _) => Kind::Sign,
        (group::QUERY, _) => Kind::Query,
        (group::CENTERING, _) => Kind::Center,
        _ => return None,
    };

    Some(kind)
}
