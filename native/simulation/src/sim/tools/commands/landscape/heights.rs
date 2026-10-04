//! Height plans for the raise and lower tools, as TerrainEditHeights.
//!
//! A plan reads the land heights and keeps its own changes apart from them, so
//! a plan costs only the tiles it visits. It lists the tiles it changed in the
//! order the original visits them, their new heights, and the price.

use std::collections::{HashMap, HashSet};

use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::tools::commands::in_bounds;
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
    /// The new height of each `modified` tile.
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

/// The heights of a plan: the map heights with the plan's changes over them.
struct TrialHeights<'a> {
    base: &'a [i64],
    changes: HashMap<i64, i64>,
}

impl<'a> TrialHeights<'a> {
    fn new(base: &'a [i64]) -> Self {
        Self {
            base,
            changes: HashMap::new(),
        }
    }

    fn get(&self, index: i64) -> i64 {
        self.changes.get(&index).copied().unwrap_or(self.base[index as usize])
    }

    fn set(&mut self, index: i64, value: i64) {
        self.changes.insert(index, value);
    }

    /// The new height of each index.
    fn values(&self, indices: &[i64]) -> Vec<i64> {
        indices.iter().map(|&index| self.get(index)).collect()
    }
}

/// Every land height of the map.
pub fn decode_heights(altitude: &[u8], map_edge: i64) -> Vec<i64> {
    (0..map_edge * map_edge).map(|index| land_altitude(altitude, index)).collect()
}

/// Store the new heights of a plan in the altitude map and in `decoded`.
pub fn write_heights(altitude: &mut [u8], decoded: &mut [i64], heights: &[i64], indices: &[i64]) {
    for (&index, &height) in indices.iter().zip(heights) {
        set_land_altitude(altitude, index, height);
        decoded[index as usize] = height;
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

    let mut trial = TrialHeights::new(heights);
    let mut modified = OrderedIndices::default();
    let mut zone_indices = Vec::new();
    let mut remaining = funds;
    let mut cost = 0;

    for point in search.postorder {
        if remaining < LEVEL_COST {
            continue;
        }

        let index = point.x * map_edge + point.y;
        trial.set(index, trial.get(index) + 1);
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
        heights: trial.values(&modified.list),
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
fn normalize_cardinal_slopes(heights: &mut TrialHeights, buildings: &[u8], point: Vec2i, modified: &mut OrderedIndices, map_edge: i64) {
    let index = point.x * map_edge + point.y;

    for offset in CARDINAL_OFFSETS {
        let neighbor = point + offset;

        if !in_bounds(neighbor, map_edge) {
            continue;
        }

        let neighbor_index = neighbor.x * map_edge + neighbor.y;

        if buildings[neighbor_index as usize] as i64 >= tiles::SMALL_PARK {
            continue;
        }

        let difference = heights.get(index) - heights.get(neighbor_index);

        if difference >= 2 {
            heights.set(neighbor_index, heights.get(index) - 1);
        } else if difference <= -2 {
            heights.set(neighbor_index, heights.get(index) + 1);
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

    let mut trial = TrialHeights::new(heights);
    let mut queue = [Vec2i::ZERO; LOWER_QUEUE];
    let mask = LOWER_QUEUE - 1;
    let mut head = 0;
    let mut tail = 1;
    queue[0] = start;

    let mut modified = OrderedIndices::default();
    modified.add(start_index);
    let mut zone_indices = OrderedIndices::default();
    trial.set(start_index, trial.get(start_index) - 1);
    let mut decrements = 1;

    while head != tail {
        let point = queue[head];
        head = (head + 1) & mask;
        let index = point.x * map_edge + point.y;
        zone_indices.add(index);

        let current = trial.get(index);
        let mut higher_mask = 0;

        for neighbor in 0..HIGHER_NEIGHBORS {
            let checked = point + NEIGHBOR_OFFSETS[neighbor];

            if in_bounds(checked, map_edge) && trial.get(checked.x * map_edge + checked.y) > current {
                higher_mask |= NEIGHBOR_MASKS[neighbor];
            }
        }

        for offset in NEIGHBOR_OFFSETS {
            let checked = point + offset;

            if !in_bounds(checked, map_edge) {
                continue;
            }

            let checked_index = checked.x * map_edge + checked.y;
            let value = trial.get(checked_index);
            let here = trial.get(index);

            if value > here + 1 || (value > here && higher_mask == ALL_CORNERS) {
                trial.set(checked_index, value - 1);
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
        heights: trial.values(&modified.list),
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

        let height = |point: Vec2i| {
            let at = plan.modified.iter().position(|&modified| modified == index(point) as i64);
            at.map_or(heights[index(point)], |at| plan.heights[at])
        };

        assert!(plan.valid);
        assert_eq!(height(Vec2i::new(19, 20)), 1);
        assert_eq!(height(Vec2i::new(20, 19)), 0);
        assert_eq!(height(start), 1);
    }
}
