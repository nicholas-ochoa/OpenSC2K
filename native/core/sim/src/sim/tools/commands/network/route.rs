//! Route planning for roads, rails, power lines, subways, and pipes, as NetworkRoutes.

use super::rules::{RouteMaps, allows_height_step, crosses_straight, surface_fixed_axis, tile_is_eligible};
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::ids::underground_tile_ids as under;
use crate::sim::tools::commands::{DIRECTIONS, in_bounds};
use crate::sim::tools::network::{MODE_RAIL, MODE_SUBWAY, TERRAIN_IS_NETWORK_SLOPE};
use crate::sim::tools::terrain::land_altitude;

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
    use crate::sim::tools::network::MODE_ROAD;
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
