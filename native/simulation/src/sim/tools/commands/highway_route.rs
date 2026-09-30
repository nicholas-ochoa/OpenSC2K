//! Highway routes of 2 by 2 sections, as HighwayRoutes and HighwayGeometry.

use std::collections::HashSet;

use super::network_route::{alternate_direction, primary_direction};
use super::{DIRECTIONS, scaled};
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::tools::highway::{
    FLAT_TERRAIN_SHAPE, INVALID_TERRAIN_SHAPE, SECTION_OFFSETS, anchor_is_in_bounds, building_is_allowed, is_highway_tile,
    section_altitude, terrain_section_shape,
};

/// The city maps that a highway route reads.
pub struct HighwayMaps<'a> {
    pub buildings: &'a [u8],
    pub terrain: &'a [u8],
    pub flags: &'a [u8],
    pub altitude: &'a [u8],
    pub map_edge: i64,
}

/// HighwayGeometry._network_can_cross: a straight network that runs across `direction`.
pub fn network_can_cross(tile: i64, direction: i64) -> bool {
    let directional = tile + (direction & 1);

    directional == tiles::POWER_LINE_STRAIGHT_2
        || directional == tiles::ROAD_STRAIGHT_2
        || directional == tiles::RAIL_STRAIGHT_2
        || directional == tiles::TUNNEL_ENTRANCE_2
}

/// HighwayGeometry._direction_between.
fn direction_between(start: Vec2i, finish: Vec2i) -> i64 {
    let difference = finish - start;

    if difference.x > 0 {
        1
    } else if difference.x < 0 {
        3
    } else if difference.y >= 0 {
        2
    } else {
        0
    }
}

/// HighwayGeometry._section_direction: the direction of travel at one section.
pub fn section_direction(sections: &[Vec2i], index: usize, finish: Vec2i) -> i64 {
    if index + 1 < sections.len() {
        return direction_between(sections[index], sections[index + 1]);
    }

    if index > 0 {
        return direction_between(sections[index - 1], sections[index]);
    }

    primary_direction(sections[index], finish)
}

fn anchor_is_on_border(anchor: Vec2i, map_edge: i64) -> bool {
    anchor.x == 0 || anchor.x == map_edge - 2 || anchor.y == 0 || anchor.y == map_edge - 2
}

/// HighwayGeometry._is_connection_exit: the route ends heading off the map.
pub fn is_connection_exit(sections: &[Vec2i], finish: Vec2i, map_edge: i64) -> bool {
    if sections.is_empty() {
        return false;
    }

    let last = sections.len() - 1;
    let direction = section_direction(sections, last, finish);
    let after_exit = sections[last] + scaled(DIRECTIONS[direction as usize], 2);

    if !anchor_is_in_bounds(after_exit, map_edge) {
        return true;
    }

    sections.len() == 1 && anchor_is_on_border(sections[0], map_edge)
}

pub fn section_has_water(flags: &[u8], anchor: Vec2i, map_edge: i64) -> bool {
    anchor_is_in_bounds(anchor, map_edge)
        && SECTION_OFFSETS.iter().any(|offset| {
            let point = anchor + *offset;

            flags[(point.x * map_edge + point.y) as usize] as i64 & flag_bits::WATER != 0
        })
}

pub fn section_is_existing_highway(buildings: &[u8], anchor: Vec2i, map_edge: i64) -> bool {
    if !anchor_is_in_bounds(anchor, map_edge) {
        return false;
    }

    (anchor.x..anchor.x + 2).all(|x| (anchor.y..anchor.y + 2).all(|y| is_highway_tile(buildings[(x * map_edge + y) as usize] as i64)))
}

/// HighwayRoutes._section_has_straight_crossing. The executable at
/// 0x00461bfa checks all four tiles before it changes axis.
fn section_has_straight_crossing(buildings: &[u8], anchor: Vec2i, direction: i64, map_edge: i64) -> bool {
    SECTION_OFFSETS.iter().any(|offset| {
        let point = anchor + *offset;
        let tile = buildings[(point.x * map_edge + point.y) as usize] as i64;

        tile >= tiles::POWER_LINE_FIRST && !is_highway_tile(tile) && network_can_cross(tile, direction)
    })
}

/// HighwayRoutes._section_is_flat_eligible.
fn section_is_flat_eligible(maps: &HighwayMaps, anchor: Vec2i, direction: i64) -> bool {
    let edge = maps.map_edge;

    if !anchor_is_in_bounds(anchor, edge) {
        return false;
    }

    for offset in SECTION_OFFSETS {
        let point = anchor + offset;
        let index = (point.x * edge + point.y) as usize;

        if maps.flags[index] as i64 & flag_bits::WATER != 0 {
            return false;
        }

        let tile = maps.buildings[index] as i64;

        if !building_is_allowed(tile) {
            return false;
        }

        if tile > tiles::POWER_LINE_FIRST && !is_highway_tile(tile) && !network_can_cross(tile, direction) {
            return false;
        }
    }

    terrain_section_shape(maps.buildings, maps.terrain, maps.altitude, anchor, edge) != INVALID_TERRAIN_SHAPE
}

/// HighwayRoutes._section_follows: eligible, and at most one level from the current section.
fn section_follows(maps: &HighwayMaps, current: Vec2i, candidate: Vec2i, direction: i64) -> bool {
    section_is_flat_eligible(maps, candidate, direction)
        && (section_altitude(maps.terrain, maps.altitude, candidate, maps.map_edge)
            - section_altitude(maps.terrain, maps.altitude, current, maps.map_edge))
        .abs()
            <= 1
}

/// HighwayRoutes._plan_flat_route: the sections from `start` toward `finish`.
pub fn plan_flat_route(maps: &HighwayMaps, start: Vec2i, finish: Vec2i) -> Vec<Vec2i> {
    let edge = maps.map_edge;
    let mut result = Vec::new();
    let mut current = start;
    let mut direction = primary_direction(current, finish);

    if !section_is_flat_eligible(maps, current, direction) {
        return result;
    }

    result.push(current);
    let mut visited = HashSet::from([current]);
    let low = Vec2i::new(start.x.min(finish.x), start.y.min(finish.y));
    let high = Vec2i::new(start.x.max(finish.x), start.y.max(finish.y));
    let in_drag = |point: Vec2i| point.x >= low.x && point.x <= high.x && point.y >= low.y && point.y <= high.y;

    while current != finish {
        let shape = terrain_section_shape(maps.buildings, maps.terrain, maps.altitude, current, edge);
        let keep_straight = shape != FLAT_TERRAIN_SHAPE || section_has_straight_crossing(maps.buildings, current, direction, edge);

        if !keep_straight {
            direction = primary_direction(current, finish);
        }

        let mut next = current + scaled(DIRECTIONS[direction as usize], 2);

        // Reject overshoots and revisited sections on a forced grade. Otherwise
        // the route could loop back along itself.
        if !in_drag(next) || visited.contains(&next) {
            break;
        }

        if !section_follows(maps, current, next, direction) {
            if keep_straight {
                break;
            }

            let alternate = alternate_direction(current, finish, direction);

            if alternate < 0 {
                break;
            }

            next = current + scaled(DIRECTIONS[alternate as usize], 2);

            if !in_drag(next) || visited.contains(&next) || !section_follows(maps, current, next, alternate) {
                break;
            }

            direction = alternate;
        }

        current = next;
        visited.insert(current);
        result.push(current);
    }

    result
}

/// HighwayEdit.preview_error for a section that cannot start a route. The
/// caller checks the route, the bridge, and the funds first.
pub fn blocked_section_error(buildings: &[u8], anchor: Vec2i, map_edge: i64) -> &'static str {
    let direction = primary_direction(anchor, anchor);

    for offset in SECTION_OFFSETS {
        let point = anchor + offset;
        let tile = buildings[(point.x * map_edge + point.y) as usize] as i64;

        if !building_is_allowed(tile) {
            return "Clear the structure in the highway footprint first.";
        }

        if tile > tiles::POWER_LINE_STRAIGHT_1 && !is_highway_tile(tile) && !network_can_cross(tile, direction) {
            return "The existing network cannot cross a highway in this direction.";
        }
    }

    "The 2 by 2 highway section has incompatible elevations or slopes."
}
