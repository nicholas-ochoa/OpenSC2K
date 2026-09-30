//! Trees, forests, and water, as LandscapeCommand.

use super::{EditBase, ToolArgs, in_bounds};
use crate::gd_edit_result;
use crate::sim::city::City;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2altitude_layout as altitude_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::overlay;
use crate::sim::random::SimRandom;
use crate::sim::tools::terrain::{update_building_count, water_shape, water_transition};
use crate::sim::value::Ints32;

pub const SUBTOOL_TREES: i64 = 0;
pub const SUBTOOL_WATER: i64 = 1;
pub const SUBTOOL_FOREST: i64 = 3;

/// The chunks that LandscapeCommand._city_payloads checks.
pub const PAYLOAD_IDS: [&str; 6] = ["XBLD", "XTER", "XZON", "XBIT", "ALTM", "MISC"];

/// A forest click plants in a disc of this squared radius around the point.
const FOREST_RADIUS_SQUARED: i64 = 10;

/// The forest disc starts at the pointer and extends this far in each axis.
const FOREST_REACH: i64 = 3;

/// Water may not replace a tile with a sign or a neighbor connection above this marker.
const LAST_WATER_MARKER: i64 = 0xf9;

gd_edit_result! {
    pub struct LandscapeResult as "LandscapeEditResult" {
        pub skipped_insufficient: i64 = 0,
    }
}

/// LandscapeCommand.apply_path. A brush forest plants at a share of the brush points.
pub fn apply(city: &mut City, args: &ToolArgs, points: &[Vec2i], random: &mut SimRandom, use_brush_points: bool) -> LandscapeResult {
    let edge = city.map_size;

    if points.is_empty() {
        return LandscapeResult::rejected("landscape path is empty", 0);
    }

    if city.missing_or_resized(&PAYLOAD_IDS).is_some() {
        return LandscapeResult::rejected("required city data is missing or invalid", 0);
    }

    let listed_per_tile = args.cost;
    let per_tile = if args.free_mode { 0 } else { listed_per_tile };
    let old_funds = city.funds();
    let random_before = random.state;
    let placement = if args.subtool == SUBTOOL_FOREST {
        forest_points(points, random, use_brush_points)
    } else {
        points.to_vec()
    };

    let mut total_cost = 0;
    let mut applied = Vec::new();
    let mut skipped_insufficient = 0;

    for point in placement {
        let index = city.index_of(point.x, point.y);

        if index < 0 {
            continue;
        }

        if old_funds - total_cost < per_tile {
            skipped_insufficient += 1;
            continue;
        }

        let placed = if args.subtool == SUBTOOL_TREES || args.subtool == SUBTOOL_FOREST {
            place_tree(city, index, random)
        } else {
            place_water(city, point)
        };

        if placed {
            total_cost += per_tile;
            applied.push(index as i32);
        }
    }

    if applied.is_empty() {
        random.state = random_before;

        if skipped_insufficient > 0 {
            return LandscapeResult::rejected("insufficient funds", per_tile);
        }

        return LandscapeResult::rejected("no eligible tiles changed", 0);
    }

    let _ = edge;
    city.set_funds(old_funds - total_cost);

    let mut result = LandscapeResult {
        base: EditBase::accepted("landscape", args.group, args.subtool),
        skipped_insufficient,
    };
    result.base.listed_cost = applied.len() as i64 * listed_per_tile;
    result.base.tile_indices = Ints32(applied);
    result.base.cost = total_cost;
    result.base.free_mode = args.free_mode;
    result.base.tracks_random = true;
    result.base.random_state_before = random_before;
    result.base.random_state_after = random.state;

    result
}

/// The points that a forest plants: a random share of the brush points, or
/// of the disc around the first point.
fn forest_points(points: &[Vec2i], random: &mut SimRandom, use_brush_points: bool) -> Vec<Vec2i> {
    let mut candidates = Vec::new();

    if use_brush_points {
        candidates.extend_from_slice(points);
    } else {
        for x in -FOREST_REACH..=FOREST_REACH {
            for y in -FOREST_REACH..=FOREST_REACH {
                if x * x + y * y <= FOREST_RADIUS_SQUARED {
                    candidates.push(points[0] + Vec2i::new(x + FOREST_REACH, y + FOREST_REACH));
                }
            }
        }
    }

    let mut attempts = 8 + random.next_u15() % 13;

    if use_brush_points {
        attempts = 1.max((candidates.len() as i64 * (25 + random.next_u15() % 36)) / 100);
    }

    let mut result = Vec::new();

    for _ in 0..attempts.min(candidates.len() as i64) {
        let choice = (random.next_u15() % candidates.len() as i64) as usize;
        result.push(candidates.remove(choice));
    }

    result
}

/// LandscapeCommand._place_tree: plant a tree, or grow a tree thicker.
fn place_tree(city: &mut City, index: i64, random: &mut SimRandom) -> bool {
    let i = index as usize;
    let edge = city.map_size;
    let old = city.xbld.data[i] as i64;
    let terrain = city.xter.data[i] as i64;

    if city.xbit.data[i] as i64 & flag_bits::WATER != 0 || old == tiles::RADIOACTIVE_WASTE {
        return false;
    }

    if terrain == terrain_ids::FORBIDDEN_COAST || terrain == terrain_ids::WATERFALL {
        return false;
    }

    let new = if old < tiles::TREE_FIRST {
        tiles::TREE_FIRST + (random.next_u15() & 1)
    } else if old < tiles::TREES_6 {
        old + 1
    } else if old <= tiles::TREE_LAST {
        tiles::TREES_6 + (random.next_u15() & 1)
    } else {
        return false;
    };

    // The count mask follows the map width, as sqrt(XBLD size) gives it.
    let maps = city.maps();
    update_building_count(maps.misc, maps.zones[i] as i64 & zone::TYPE_MASK, old, new, edge);
    maps.buildings[i] = new as u8;

    true
}

/// LandscapeCommand._place_water: flood one land tile and reshape the water around it.
fn place_water(city: &mut City, point: Vec2i) -> bool {
    let edge = city.map_size;
    let index = point.x * edge + point.y;
    let i = index as usize;
    let marker = overlay::marker_at(&city.xtxt.data, index);

    if city.xbit.data[i] as i64 & flag_bits::WATER != 0 || (marker > LAST_WATER_MARKER && marker <= 0xff) {
        return false;
    }

    let old = city.xbld.data[i] as i64;

    if old >= tiles::POWER_LINE_FIRST || old == tiles::RADIOACTIVE_WASTE {
        return false;
    }

    let terrain = city.xter.data[i] as i64;

    if terrain == terrain_ids::FORBIDDEN_COAST || terrain == terrain_ids::WATERFALL {
        return false;
    }

    let maps = city.maps();
    let shape = water_shape(maps.flags, point.x, point.y, edge);
    let (value, keep) = water_transition(terrain, shape);

    if !keep {
        maps.terrain[i] = value as u8;
        update_building_count(maps.misc, maps.zones[i] as i64 & zone::TYPE_MASK, old, tiles::EMPTY, edge);
        maps.buildings[i] = tiles::EMPTY as u8;

        // The water surface starts at the land height.
        let offset = i * 2;
        let mut word = ((maps.altitude[offset] as i64) << 8) | maps.altitude[offset + 1] as i64;
        word = (word & (!altitude_layout::WATER_MASK & 0xffff)) | ((word & altitude_layout::LEVEL_MASK) << altitude_layout::WATER_SHIFT);
        maps.altitude[offset] = (word >> 8) as u8;
        maps.altitude[offset + 1] = word as u8;
        maps.flags[i] |= flag_bits::WATER as u8;

        for near_x in (point.x - 1).max(0)..(point.x + 2).min(edge) {
            for near_y in (point.y - 1).max(0)..(point.y + 2).min(edge) {
                let near = Vec2i::new(near_x, near_y);

                if near == point || !in_bounds(near, edge) {
                    continue;
                }

                let near_index = (near_x * edge + near_y) as usize;

                if maps.flags[near_index] as i64 & flag_bits::WATER == 0 {
                    continue;
                }

                let near_shape = water_shape(maps.flags, near_x, near_y, edge);
                let (near_value, near_keep) = water_transition(maps.terrain[near_index] as i64, near_shape);

                if !near_keep {
                    maps.terrain[near_index] = near_value as u8;
                }
            }
        }
    }

    maps.zones[i] &= zone::CORNERS_MASK as u8;

    true
}
