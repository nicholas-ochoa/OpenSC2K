//! Route planning for roads, rails, power lines, subways, and pipes, as
//! NetworkRoutes, NetworkRules, and NetworkTerrainRules.

use super::{DIRECTIONS, in_bounds};
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2altitude_layout as altitude_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::ids::underground_tile_ids as under;
use crate::sim::tools::network::{
    MODE_PIPE, MODE_POWER, MODE_RAIL, MODE_ROAD, MODE_SUBWAY, TERRAIN_IS_NETWORK_SLOPE, rail_connects, road_connects,
};
use crate::sim::tools::terrain::land_altitude;
use crate::sim::tools::underground::underground_connects;

/// One row per terrain shape, one column per direction (N, E, S, W): true
/// where a network may not enter the tile.
const ENTRY_BLOCKS_DIRECTION: [bool; 64] = [
    false, false, false, false, // FLAT
    true, false, true, false, // SLOPE_TOP_LEFT
    false, true, false, true, // SLOPE_TOP_RIGHT
    true, false, true, false, // SLOPE_BOTTOM_RIGHT
    false, true, false, true, // SLOPE_BOTTOM_LEFT
    false, false, false, false, // RAISED_EXCEPT_BOTTOM
    false, false, false, false, // RAISED_EXCEPT_LEFT
    false, false, false, false, // RAISED_EXCEPT_TOP
    false, false, false, false, // RAISED_EXCEPT_RIGHT
    false, false, false, false, // CORNER_TOP
    false, false, false, false, // CORNER_RIGHT
    false, false, false, false, // CORNER_BOTTOM
    false, false, false, false, // CORNER_LEFT
    false, false, false, false, // RAISED
    true, false, true, false, // UNUSED_0E
    true, false, true, false, // UNUSED_0F
];

/// The raised part of a shape adds one level to the height of the step.
const HEIGHT_ADJUSTMENTS: [i64; 16] = [0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 0, 0];

/// A tunnel at these levels blocks a subway or pipe.
const TUNNEL_BLOCKS_UNDERGROUND: [i64; 2] = [1, 2];

/// The city maps that a route reads.
pub struct RouteMaps<'a> {
    pub buildings: &'a [u8],
    pub terrain: &'a [u8],
    pub zones: &'a [u8],
    pub underground: &'a [u8],
    pub flags: &'a [u8],
    pub altitude: &'a [u8],
    pub map_edge: i64,
}

/// NetworkTerrainRules.allows_entry.
pub fn allows_entry(terrain_id: i64, direction: i64) -> bool {
    terrain_id >= terrain_ids::CHANNEL_FIRST || !ENTRY_BLOCKS_DIRECTION[((terrain_id & terrain_ids::SHAPE_MASK) * 4 + direction) as usize]
}

/// NetworkTerrainRules.allows_height_step, from the executable at 0x00448f50.
/// Going downhill is not uphill with a minus sign.
pub fn allows_height_step(
    current_terrain: i64,
    current_height: i64,
    next_terrain: i64,
    next_height: i64,
    keep_straight: bool,
    rail: bool,
) -> bool {
    if keep_straight {
        return !rail || next_terrain == terrain_ids::FLAT || next_height == current_height;
    }

    let effective = current_height + HEIGHT_ADJUSTMENTS[(current_terrain & terrain_ids::SHAPE_MASK) as usize];
    let difference = next_height - effective;

    if HEIGHT_ADJUSTMENTS[(next_terrain & terrain_ids::SHAPE_MASK) as usize] != 0 && (difference == 0 || difference == -2) {
        return false;
    }

    next_terrain != terrain_ids::FLAT || difference != -1
}

/// NetworkRules._surface_fixed_axis: existing mixed crossings cannot turn.
/// Returns -1 when the tile has no fixed axis for `mode`.
pub fn surface_fixed_axis(tile: i64, mode: i64) -> i64 {
    use tiles::*;

    match mode {
        MODE_ROAD => match tile {
            ROAD_POWER_CROSSING_1 | ROAD_RAIL_CROSSING_1 | HIGHWAY_ROAD_CROSSING_2 => 0,
            ROAD_POWER_CROSSING_2 | ROAD_RAIL_CROSSING_2 | HIGHWAY_ROAD_CROSSING_1 => 1,
            _ => -1,
        },
        MODE_RAIL => match tile {
            ROAD_RAIL_CROSSING_2 | RAIL_POWER_CROSSING_1 | HIGHWAY_RAIL_CROSSING_2 => 0,
            ROAD_RAIL_CROSSING_1 | RAIL_POWER_CROSSING_2 | HIGHWAY_RAIL_CROSSING_1 => 1,
            _ => -1,
        },
        _ => match tile {
            ROAD_POWER_CROSSING_2 | RAIL_POWER_CROSSING_2 | HIGHWAY_POWER_CROSSING_2 => 0,
            ROAD_POWER_CROSSING_1 | RAIL_POWER_CROSSING_1 | HIGHWAY_POWER_CROSSING_1 => 1,
            _ => -1,
        },
    }
}

/// NetworkRules._reuses_surface: the route passes this tile without building.
pub fn reuses_surface(tile: i64, mode: i64) -> bool {
    match mode {
        MODE_ROAD => road_connects(tile),
        MODE_RAIL => rail_connects(tile),
        MODE_POWER => {
            (tiles::POWER_LINE_FIRST..=tiles::POWER_LINE_LAST).contains(&tile)
                || (tiles::ROAD_POWER_CROSSING_1..=tiles::ROAD_POWER_CROSSING_2).contains(&tile)
                || (tiles::RAIL_POWER_CROSSING_1..=tiles::RAIL_POWER_CROSSING_2).contains(&tile)
                || (tiles::HIGHWAY_POWER_CROSSING_1..=tiles::HIGHWAY_POWER_CROSSING_2).contains(&tile)
        }
        _ => false,
    }
}

/// NetworkRules._reuses_underground.
pub fn reuses_underground(tile: i64, mode: i64) -> bool {
    (mode == MODE_PIPE || mode == MODE_SUBWAY) && underground_connects(tile, mode == MODE_PIPE)
}

/// True for a straight network tile that runs across `direction`.
fn crosses_straight(tile: i64, direction: i64) -> bool {
    let directional = tile + (direction & 1);

    directional == tiles::POWER_LINE_STRAIGHT_2
        || directional == tiles::ROAD_STRAIGHT_2
        || directional == tiles::RAIL_STRAIGHT_2
        || directional == tiles::HIGHWAY_STRAIGHT_2
}

/// NetworkRules._tile_is_eligible: the route may enter `point` going `direction`.
pub fn tile_is_eligible(maps: &RouteMaps, point: Vec2i, mode: i64, direction: i64) -> bool {
    let edge = maps.map_edge;

    if !in_bounds(point, edge) {
        return false;
    }

    let index = (point.x * edge + point.y) as usize;

    if maps.zones[index] as i64 & zone::TYPE_MASK == zone::MILITARY {
        return false;
    }

    let terrain_id = maps.terrain[index] as i64;

    if !allows_entry(terrain_id, direction) {
        return false;
    }

    if mode == MODE_SUBWAY || mode == MODE_PIPE {
        let word = ((maps.altitude[index * 2] as i64) << 8) | maps.altitude[index * 2 + 1] as i64;
        let tunnel = (word & altitude_layout::TUNNEL_MASK) >> altitude_layout::TUNNEL_SHIFT;

        if TUNNEL_BLOCKS_UNDERGROUND.contains(&tunnel) {
            return false;
        }

        let under_tile = maps.underground[index] as i64;

        if reuses_underground(under_tile, mode) {
            // A pipe and subway crossing keeps each network on its own axis.
            if under_tile == under::PIPE_TB_SUBWAY_LR || under_tile == under::PIPE_LR_SUBWAY_TB {
                let mut axis = under_tile - under::PIPE_TB_SUBWAY_LR;

                if mode == MODE_PIPE {
                    axis = 1 - axis;
                }

                return (direction & 1) == axis;
            }

            return true;
        }

        if under_tile == under::EMPTY {
            return true;
        }

        return under_tile + (direction & 1) == under::PIPE_TB;
    }

    if maps.flags[index] as i64 & flag_bits::WATER != 0 && terrain_id < terrain_ids::CHANNEL_FIRST {
        return false;
    }

    if (terrain_ids::DEEP_WATER_FIRST..terrain_ids::SHORE_FIRST).contains(&terrain_id) {
        return false;
    }

    let building = maps.buildings[index] as i64;

    if reuses_surface(building, mode) {
        let axis = surface_fixed_axis(building, mode);

        return axis < 0 || (direction & 1) == axis;
    }

    if building == tiles::RADIOACTIVE_WASTE || building == tiles::SMALL_PARK || building > tiles::HIGHWAY_POWER_CROSSING_2 {
        return false;
    }

    if building <= tiles::TREE_LAST {
        return true;
    }

    crosses_straight(building, direction)
}

/// NetworkRoutes._primary_direction: along the longer axis toward `finish`.
pub fn primary_direction(current: Vec2i, finish: Vec2i) -> i64 {
    let difference = finish - current;

    if difference.y.abs() < difference.x.abs() {
        return if difference.x >= 0 { 1 } else { 3 };
    }

    if difference.y >= 0 { 2 } else { 0 }
}

/// NetworkRoutes._alternate_direction: along the other axis, or -1 when the
/// route is already aligned with `finish` on that axis.
pub fn alternate_direction(current: Vec2i, finish: Vec2i, primary: i64) -> i64 {
    let difference = finish - current;

    if primary == 1 || primary == 3 {
        if difference.y == 0 {
            return -1;
        }

        return if difference.y > 0 { 2 } else { 0 };
    }

    if difference.x == 0 {
        return -1;
    }

    if difference.x > 0 { 1 } else { 3 }
}

pub fn direction_index(offset: Vec2i) -> i64 {
    DIRECTIONS.iter().position(|direction| *direction == offset).unwrap_or(0) as i64
}

/// NetworkRoutes._route_exit_direction.
pub fn route_exit_direction(planned: &[Vec2i], start: Vec2i, finish: Vec2i) -> i64 {
    if planned.len() > 1 {
        return direction_index(planned[planned.len() - 1] - planned[planned.len() - 2]);
    }

    primary_direction(start, finish)
}

fn point_is_edge(point: Vec2i, map_edge: i64) -> bool {
    point.x == 0 || point.x == map_edge - 1 || point.y == 0 || point.y == map_edge - 1
}

/// NetworkRoutes._is_connection_exit: the route ends at the map edge heading out.
pub fn is_connection_exit(planned: &[Vec2i], start: Vec2i, finish: Vec2i, map_edge: i64) -> bool {
    let Some(&endpoint) = planned.last() else {
        return false;
    };

    if !point_is_edge(endpoint, map_edge) {
        return false;
    }

    if start == endpoint {
        return true;
    }

    let direction = route_exit_direction(planned, start, finish);

    !in_bounds(endpoint + DIRECTIONS[direction as usize], map_edge)
}

/// NetworkRoutes._route_keeps_direction: slopes and straight crossings force
/// the incoming direction before the route can turn toward the pointer.
fn route_keeps_direction(maps: &RouteMaps, point: Vec2i, mode: i64, direction: i64) -> bool {
    let index = (point.x * maps.map_edge + point.y) as usize;

    if TERRAIN_IS_NETWORK_SLOPE[(maps.terrain[index] as i64 & terrain_ids::SHAPE_MASK) as usize] {
        return true;
    }

    if mode < MODE_SUBWAY {
        let surface = maps.buildings[index] as i64;

        return surface_fixed_axis(surface, mode) >= 0 || (surface > tiles::SMALL_PARK && crosses_straight(surface, direction));
    }

    let tile = maps.underground[index] as i64;

    tile == under::PIPE_TB_SUBWAY_LR
        || tile == under::PIPE_LR_SUBWAY_TB
        || (tile != under::EMPTY && (tile + (direction & 1) == under::SUBWAY_TB || tile + (direction & 1) == under::PIPE_TB))
}

/// NetworkRoutes._step_is_eligible.
#[allow(clippy::too_many_arguments)]
fn step_is_eligible(maps: &RouteMaps, current: Vec2i, next: Vec2i, mode: i64, direction: i64, keep_straight: bool) -> bool {
    if !tile_is_eligible(maps, next, mode, direction) {
        return false;
    }

    let edge = maps.map_edge;
    let current_index = current.x * edge + current.y;
    let next_index = next.x * edge + next.y;

    allows_height_step(
        maps.terrain[current_index as usize] as i64,
        land_altitude(maps.altitude, current_index),
        maps.terrain[next_index as usize] as i64,
        land_altitude(maps.altitude, next_index),
        keep_straight,
        mode == MODE_RAIL,
    )
}

/// NetworkRoutes.plan_route: the tiles from `start` toward `finish`, with the
/// direction of each step. The route stops where it cannot continue.
pub fn plan_route(maps: &RouteMaps, start: Vec2i, finish: Vec2i, mode: i64) -> (Vec<Vec2i>, Vec<i64>) {
    let mut points = Vec::new();
    let mut directions = Vec::new();
    let mut current = start;
    let mut direction = primary_direction(current, finish);

    if !tile_is_eligible(maps, current, mode, direction) {
        if start == finish {
            if let Some(candidate) = (0..4).find(|&candidate| tile_is_eligible(maps, current, mode, candidate)) {
                points.push(current);
                directions.push(candidate);
            }

            return (points, directions);
        }

        let alternate = alternate_direction(current, finish, direction);

        if alternate < 0 || !tile_is_eligible(maps, current, mode, alternate) {
            return (points, directions);
        }

        direction = alternate;
    }

    points.push(current);
    directions.push(direction);

    let low = Vec2i::new(start.x.min(finish.x), start.y.min(finish.y));
    let high = Vec2i::new(start.x.max(finish.x), start.y.max(finish.y));

    while current != finish {
        let incoming = direction;
        let keep_straight = route_keeps_direction(maps, current, mode, direction);

        if !keep_straight {
            direction = primary_direction(current, finish);
        }

        let mut next = current + DIRECTIONS[direction as usize];

        if keep_straight && (next.x < low.x || next.x > high.x || next.y < low.y || next.y > high.y) {
            break;
        }

        if !step_is_eligible(maps, current, next, mode, direction, keep_straight) {
            let alternate = alternate_direction(current, finish, direction);

            if keep_straight || alternate < 0 {
                break;
            }

            next = current + DIRECTIONS[alternate as usize];

            if !step_is_eligible(maps, current, next, mode, alternate, keep_straight) {
                break;
            }

            direction = alternate;
        }

        // Check the rail grade after the axis is chosen, as the original does.
        // A failed check ends the route; it does not try the other turn.
        if mode == MODE_RAIL
            && direction != incoming
            && maps.terrain[(next.x * maps.map_edge + next.y) as usize] as i64 != terrain_ids::FLAT
        {
            break;
        }

        current = next;
        points.push(current);
        directions.push(direction);
    }

    (points, directions)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::tools::terrain::set_land_altitude;

    /// Empty maps of one width.
    struct Fixture {
        buildings: Vec<u8>,
        terrain: Vec<u8>,
        zones: Vec<u8>,
        underground: Vec<u8>,
        flags: Vec<u8>,
        altitude: Vec<u8>,
        edge: i64,
    }

    impl Fixture {
        fn new(edge: i64) -> Self {
            let cells = (edge * edge) as usize;

            Self {
                buildings: vec![0; cells],
                terrain: vec![0; cells],
                zones: vec![0; cells],
                underground: vec![0; cells],
                flags: vec![0; cells],
                altitude: vec![0; cells * 2],
                edge,
            }
        }

        fn index(&self, point: Vec2i) -> usize {
            (point.x * self.edge + point.y) as usize
        }

        fn route(&self, start: Vec2i, finish: Vec2i, mode: i64) -> Vec<Vec2i> {
            let maps = RouteMaps {
                buildings: &self.buildings,
                terrain: &self.terrain,
                zones: &self.zones,
                underground: &self.underground,
                flags: &self.flags,
                altitude: &self.altitude,
                map_edge: self.edge,
            };

            plan_route(&maps, start, finish, mode).0
        }
    }

    fn step(direction: usize, count: i64) -> Vec2i {
        Vec2i::new(DIRECTIONS[direction].x * count, DIRECTIONS[direction].y * count)
    }

    /// Each step goes along the axis with more distance left, as the recovered
    /// dominant-axis rule does.
    #[test]
    fn routes_follow_the_dominant_axis() {
        let fixture = Fixture::new(128);
        let route = fixture.route(Vec2i::new(10, 10), Vec2i::new(13, 12), MODE_ROAD);
        let expected = [(10, 10), (11, 10), (11, 11), (12, 11), (12, 12), (13, 12)].map(|(x, y)| Vec2i::new(x, y));

        assert_eq!(route, expected);
    }

    /// A subway crosses only a straight pipe, at right angles.
    #[test]
    fn subways_cross_straight_pipes() {
        let mut fixture = Fixture::new(128);
        let start = Vec2i::new(20, 20);

        for pipe in under::PIPE_LR..under::PIPE_TB_SUBWAY_LR {
            for direction in 0..4 {
                let crossing = fixture.index(start + step(direction, 1));
                fixture.underground[crossing] = pipe as u8;

                let allowed = (pipe == under::PIPE_LR && direction % 2 == 1) || (pipe == under::PIPE_TB && direction % 2 == 0);
                let route = fixture.route(start, start + step(direction, 2), MODE_SUBWAY);
                assert_eq!(route.len(), if allowed { 3 } else { 1 }, "pipe {pipe:x} direction {direction}");

                fixture.underground[crossing] = 0;
            }
        }
    }

    /// Slopes allow only the aligned direction, and a raised tile cannot step
    /// down to a flat one. Rail cannot turn onto a grade or climb unequal slopes.
    #[test]
    fn terrain_limits_each_step() {
        for edge in [128, 256, 384, 512] {
            let mut fixture = Fixture::new(edge);
            let start = Vec2i::new(edge - 12, edge - 12);
            let start_index = fixture.index(start);

            for mode in 0..5 {
                for direction in 0..4 {
                    let next = fixture.index(start + step(direction, 1));
                    let (sideways, aligned) = if direction % 2 == 0 { (1, 2) } else { (2, 1) };

                    fixture.terrain[next] = sideways;
                    assert_eq!(fixture.route(start, start + step(direction, 2), mode), vec![start]);

                    fixture.terrain[next] = aligned;
                    assert_eq!(fixture.route(start, start + step(direction, 2), mode).len(), 3);

                    fixture.terrain[next] = 0;
                    fixture.terrain[start_index] = terrain_ids::RAISED as u8;
                    assert_eq!(fixture.route(start, start + step(direction, 1), mode), vec![start]);
                    fixture.terrain[start_index] = 0;
                }
            }

            let corner = fixture.index(start + Vec2i::new(1, 1));
            fixture.terrain[corner] = 2;
            assert_eq!(
                fixture.route(start, start + Vec2i::new(2, 1), MODE_RAIL),
                vec![start, start + Vec2i::new(1, 0)]
            );
            assert_eq!(fixture.route(start, start + Vec2i::new(2, 1), MODE_ROAD).len(), 3);
            fixture.terrain[corner] = 0;

            // The original compares the raw land heights of a rail on slopes.
            let next = fixture.index(start + Vec2i::new(1, 0));
            fixture.terrain[start_index] = 1;
            fixture.terrain[next] = 1;
            let raised = land_altitude(&fixture.altitude, next as i64) + 1;
            set_land_altitude(&mut fixture.altitude, next as i64, raised);
            assert_eq!(fixture.route(start, start + Vec2i::new(2, 0), MODE_RAIL), vec![start]);
            assert_eq!(fixture.route(start, start + Vec2i::new(2, 0), MODE_ROAD).len(), 3);
        }
    }

    /// Reusing a crossing is free, but each network keeps its fixed axis.
    #[test]
    fn crossings_keep_their_axis() {
        for edge in [128, 512] {
            let mut fixture = Fixture::new(edge);
            let start = Vec2i::new(edge - 12, edge - 12);

            for (mode, tile, axis) in [
                (0, 0x43, 0),
                (0, 0x44, 1),
                (1, 0x45, 1),
                (1, 0x46, 0),
                (2, 0x47, 1),
                (2, 0x48, 0),
                (3, 0x1f, 0),
                (3, 0x20, 1),
                (4, 0x1f, 1),
                (4, 0x20, 0),
            ] {
                let valid = if axis == 1 { Vec2i::new(1, 0) } else { Vec2i::new(0, 1) };
                let cross = Vec2i::new(valid.y, valid.x);
                let set = |fixture: &mut Fixture, point: Vec2i, value: u8| {
                    let index = fixture.index(point);

                    if mode < MODE_SUBWAY {
                        fixture.buildings[index] = value;
                    } else {
                        fixture.underground[index] = value;
                    }
                };

                set(&mut fixture, start + cross, tile);
                assert_eq!(
                    fixture.route(start, start + cross + cross, mode),
                    vec![start],
                    "mode {mode} tile {tile:x}"
                );
                set(&mut fixture, start + cross, 0);

                set(&mut fixture, start + valid, tile);
                let route = fixture.route(start, start + valid + valid + cross, mode);
                assert!(route.contains(&(start + valid + valid)), "mode {mode} tile {tile:x}");
                set(&mut fixture, start + valid, 0);
            }
        }
    }
}
