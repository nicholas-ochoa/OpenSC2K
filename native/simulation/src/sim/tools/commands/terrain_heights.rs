//! Height plans for the raise and lower tools, as TerrainEditHeights.
//!
//! A plan works on a copy of the land heights. It lists the tiles it changed in
//! the order the original visits them, and the price of the change.

use std::collections::HashSet;

use super::in_bounds;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::tools::terrain::{NEIGHBOR_MASKS, NEIGHBOR_OFFSETS, land_altitude, set_land_altitude};

/// Each level that a tile moves costs this much.
pub const LEVEL_COST: i64 = 25;

/// A tile above this level cannot rise.
const MAX_RAISE_SOURCE: i64 = 29;

/// The lower tool keeps its work in a ring of this many points.
const LOWER_QUEUE: usize = 512;

const CARDINAL_OFFSETS: [Vec2i; 4] = [Vec2i::new(0, -1), Vec2i::new(1, 0), Vec2i::new(0, 1), Vec2i::new(-1, 0)];

/// A raised tile first raises its lower neighbors in this order.
const RAISE_DEPENDENCY_OFFSETS: [Vec2i; 4] = [Vec2i::new(-1, 0), Vec2i::new(0, -1), Vec2i::new(1, 0), Vec2i::new(0, 1)];

/// Every surrounding tile, with the corner mask that a higher neighbor raises.
const HIGHER_NEIGHBORS: usize = 8;

/// All corners of a tile are raised.
const ALL_CORNERS: i64 = 15;

#[derive(Clone, Debug, Default)]
pub struct Plan {
    pub valid: bool,
    pub insufficient: bool,
    pub heights: Vec<i64>,
    pub modified: Vec<i64>,
    pub zone_indices: Vec<i64>,
    pub funds: i64,
    pub cost: i64,
}

impl Plan {
    fn invalid(insufficient: bool) -> Self {
        Self {
            insufficient,
            ..Default::default()
        }
    }
}

/// Indices in first-visit order, as PackedInt32Array.has and append.
#[derive(Default)]
struct OrderedIndices {
    list: Vec<i64>,
    seen: HashSet<i64>,
}

impl OrderedIndices {
    fn add(&mut self, index: i64) {
        if self.seen.insert(index) {
            self.list.push(index);
        }
    }
}

/// Every land height of the map.
pub fn decode_heights(altitude: &[u8], map_edge: i64) -> Vec<i64> {
    (0..map_edge * map_edge).map(|index| land_altitude(altitude, index)).collect()
}

pub fn write_heights(altitude: &mut [u8], heights: &[i64], indices: &[i64]) {
    for &index in indices {
        set_land_altitude(altitude, index, heights[index as usize]);
    }
}

fn is_military(zones: &[u8], index: i64) -> bool {
    zones[index as usize] as i64 & zone::TYPE_MASK == zone::MILITARY
}

/// TerrainEditHeights.plan_raise: raise `start` and each lower tile that holds
/// it up, while the funds last.
pub fn plan_raise(heights: &[i64], zones: &[u8], buildings: &[u8], start: Vec2i, funds: i64, map_edge: i64) -> Plan {
    let mut search = RaiseSearch {
        heights,
        zones,
        map_edge,
        visiting: HashSet::new(),
        visited: HashSet::new(),
        postorder: Vec::new(),
    };

    if !search.collect(start) {
        return Plan::invalid(false);
    }

    let mut trial = heights.to_vec();
    let mut modified = OrderedIndices::default();
    let mut zone_indices = Vec::new();
    let mut remaining = funds;
    let mut cost = 0;

    for point in search.postorder {
        if remaining < LEVEL_COST {
            continue;
        }

        let index = point.x * map_edge + point.y;
        trial[index as usize] += 1;
        remaining -= LEVEL_COST;
        cost += LEVEL_COST;
        zone_indices.push(index);
        modified.add(index);
        normalize_cardinal_slopes(&mut trial, buildings, point, &mut modified, map_edge);
    }

    if cost == 0 {
        return Plan::invalid(true);
    }

    Plan {
        valid: true,
        insufficient: false,
        heights: trial,
        modified: modified.list,
        zone_indices,
        funds: remaining,
        cost,
    }
}

/// The depth-first order in which a raise lifts the lower tiles first.
struct RaiseSearch<'a> {
    heights: &'a [i64],
    zones: &'a [u8],
    map_edge: i64,
    visiting: HashSet<i64>,
    visited: HashSet<i64>,
    postorder: Vec<Vec2i>,
}

impl RaiseSearch<'_> {
    /// False when a military base or the height limit blocks the raise. Each
    /// step goes to a lower tile, so the depth is at most the level count.
    fn collect(&mut self, point: Vec2i) -> bool {
        let edge = self.map_edge;
        let index = point.x * edge + point.y;

        if self.visited.contains(&index) || self.visiting.contains(&index) {
            return true;
        }

        if is_military(self.zones, index) || self.heights[index as usize] > MAX_RAISE_SOURCE {
            return false;
        }

        for offset in NEIGHBOR_OFFSETS {
            let neighbor = point + offset;

            if in_bounds(neighbor, edge) && is_military(self.zones, neighbor.x * edge + neighbor.y) {
                return false;
            }
        }

        self.visiting.insert(index);

        for offset in RAISE_DEPENDENCY_OFFSETS {
            let neighbor = point + offset;

            if !in_bounds(neighbor, edge) {
                continue;
            }

            let neighbor_index = neighbor.x * edge + neighbor.y;

            if self.heights[neighbor_index as usize] < self.heights[index as usize] && !self.collect(neighbor) {
                return false;
            }
        }

        self.visiting.remove(&index);
        self.visited.insert(index);
        self.postorder.push(point);

        true
    }
}

/// Keep cardinal neighbors within one level. Parks and larger buildings stay.
fn normalize_cardinal_slopes(heights: &mut [i64], buildings: &[u8], point: Vec2i, modified: &mut OrderedIndices, map_edge: i64) {
    let index = (point.x * map_edge + point.y) as usize;

    for offset in CARDINAL_OFFSETS {
        let neighbor = point + offset;

        if !in_bounds(neighbor, map_edge) {
            continue;
        }

        let neighbor_index = neighbor.x * map_edge + neighbor.y;
        let n = neighbor_index as usize;

        if buildings[n] as i64 >= tiles::SMALL_PARK {
            continue;
        }

        let difference = heights[index] - heights[n];

        if difference >= 2 {
            heights[n] = heights[index] - 1;
        } else if difference <= -2 {
            heights[n] = heights[index] + 1;
        } else {
            continue;
        }

        modified.add(neighbor_index);
        normalize_cardinal_slopes(heights, buildings, neighbor, modified, map_edge);
    }
}

/// TerrainEditHeights._plan_lower: lower `start` and let the higher tiles
/// around it settle, as the original breadth-first ring does.
pub fn plan_lower(heights: &[i64], start: Vec2i, funds: i64, map_edge: i64) -> Plan {
    if funds < LEVEL_COST {
        return Plan::invalid(true);
    }

    let start_index = start.x * map_edge + start.y;

    if heights[start_index as usize] == 0 {
        return Plan::invalid(false);
    }

    let mut trial = heights.to_vec();
    let mut queue = [Vec2i::ZERO; LOWER_QUEUE];
    let mask = LOWER_QUEUE - 1;
    let mut head = 0;
    let mut tail = 1;
    queue[0] = start;

    let mut modified = OrderedIndices::default();
    modified.add(start_index);
    let mut zone_indices = OrderedIndices::default();
    trial[start_index as usize] -= 1;
    let mut decrements = 1;

    while head != tail {
        let point = queue[head];
        head = (head + 1) & mask;
        let index = point.x * map_edge + point.y;
        zone_indices.add(index);

        let current = trial[index as usize];
        let mut higher_mask = 0;

        for neighbor in 0..HIGHER_NEIGHBORS {
            let checked = point + NEIGHBOR_OFFSETS[neighbor];

            if in_bounds(checked, map_edge) && trial[(checked.x * map_edge + checked.y) as usize] > current {
                higher_mask |= NEIGHBOR_MASKS[neighbor];
            }
        }

        for offset in NEIGHBOR_OFFSETS {
            let checked = point + offset;

            if !in_bounds(checked, map_edge) {
                continue;
            }

            let checked_index = checked.x * map_edge + checked.y;
            let value = trial[checked_index as usize];

            if value > trial[index as usize] + 1 || (value > trial[index as usize] && higher_mask == ALL_CORNERS) {
                trial[checked_index as usize] -= 1;
                decrements += 1;
                queue[tail] = checked;
                tail = (tail + 1) & mask;

                // A full ring drops its oldest entry.
                if head == tail {
                    head = (tail + 1) & mask;
                }

                modified.add(checked_index);
            }
        }
    }

    Plan {
        valid: true,
        insufficient: false,
        heights: trial,
        modified: modified.list,
        zone_indices: zone_indices.list,
        funds: (funds - decrements * LEVEL_COST).max(0),
        cost: funds.min(decrements * LEVEL_COST),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Partial funds raise the lower neighbors in the executable order: west,
    /// north, east, south. The tile itself comes last.
    #[test]
    fn partial_raises_follow_the_executable_order() {
        let edge = 128i64;
        let cells = (edge * edge) as usize;
        let mut heights = vec![0i64; cells];
        let (zones, buildings) = (vec![0u8; cells], vec![0u8; cells]);
        let start = Vec2i::new(20, 20);
        let index = |point: Vec2i| (point.x * edge + point.y) as usize;
        heights[index(start)] = 1;

        let plan = plan_raise(&heights, &zones, &buildings, start, LEVEL_COST, edge);

        assert!(plan.valid);
        assert_eq!(plan.heights[index(Vec2i::new(19, 20))], 1);
        assert_eq!(plan.heights[index(Vec2i::new(20, 19))], 0);
        assert_eq!(plan.heights[index(start)], 1);
    }
}
