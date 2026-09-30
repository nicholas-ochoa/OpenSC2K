//! The level, raise, and lower tools, as TerrainCommand and TerrainEditSurface.

use std::collections::HashSet;

use crate::gd_edit_result;
use crate::sim::city::City;
use crate::sim::events::EffectEvent;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::underground_tile_ids as under;
use crate::sim::random::SimRandom;
use crate::sim::tools::commands::landscape::heights::{self as heights, LEVEL_COST, Plan};
use crate::sim::tools::commands::{EditBase, ToolArgs};
use crate::sim::tools::demolish::{append_effect_sequence, demolish_point};
use crate::sim::tools::network::replace_building;
use crate::sim::tools::terrain::{land_altitude, retile_region};
use crate::sim::tools::underground::replace_underground;
use crate::sim::value::Ints32;

pub const SUBTOOL_LEVEL: i64 = 1;
pub const SUBTOOL_RAISE: i64 = 2;
pub const SUBTOOL_LOWER: i64 = 3;

/// Free mode may spend without limit.
const FREE_FUNDS: i64 = 0x7fff_ffff;

const SOUND_EXPLODE: i64 = 504;

/// The chunks that TerrainCommand checks: the building chunks and ALTM.
pub const PAYLOAD_IDS: [&str; 10] = ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"];

gd_edit_result! {
    pub struct TerrainResult as "TerrainEditResult" {
        pub target_altitude: i64 = -1,
        pub action_count: i64 = 0,
        pub skipped_conflicts: i64 = 0,
        pub skipped_insufficient: i64 = 0,
        pub random_used: bool = false,
    }
}

/// A terrain path. `target_override` replaces the start height for the level tool.
pub struct TerrainPath<'a> {
    pub start: Vec2i,
    pub points: &'a [Vec2i],
    pub target_override: i64,
}

/// TerrainCommand.apply_path. Without a random generator, a structure in the
/// way skips the tile.
pub fn apply(city: &mut City, args: &ToolArgs, path: &TerrainPath, mut random: Option<&mut SimRandom>) -> TerrainResult {
    let edge = city.map_size;
    let start_index = city.index_of(path.start.x, path.start.y);

    if start_index < 0 || path.points.is_empty() {
        return TerrainResult::rejected("terrain path is outside the city", 0);
    }

    if city.missing_or_resized(&PAYLOAD_IDS[1..]).is_some() {
        return TerrainResult::rejected("required city data is missing or invalid", 0);
    }

    if city.missing_or_resized(&PAYLOAD_IDS[..1]).is_some() {
        return TerrainResult::rejected("required altitude data is missing or invalid", 0);
    }

    let old_funds = city.funds();
    let mut funds = if args.free_mode { FREE_FUNDS } else { old_funds };
    let target = if path.target_override >= 0 {
        path.target_override
    } else {
        land_altitude(&city.altm.data, start_index)
    };

    let sea_level = city.misc_u32(misc_layout::WATER_LEVEL);
    let rotation = city.compass_rotation();
    let random_before = random.as_ref().map_or(0, |random| random.state);

    let mut action_count = 0;
    let mut total_cost = 0;
    let mut listed_cost = 0;
    let mut changed = Changed::default();
    let mut skipped_conflicts = 0;
    let mut skipped_insufficient = 0;
    let mut effect_events = Vec::new();
    let mut sound_events = Vec::new();
    let mut next_effect_frame = 0;
    let mut random_used = false;

    for &point in path.points {
        let index = city.index_of(point.x, point.y);

        if index < 0 {
            continue;
        }

        let operation = height_operation(args.subtool, land_altitude(&city.altm.data, index), target);

        if operation == SUBTOOL_LEVEL {
            continue;
        }

        let decoded = heights::decode_heights(&city.altm.data, edge);
        let trial: Plan = if operation == SUBTOOL_RAISE {
            heights::plan_raise(&decoded, &city.xzon.data, &city.xbld.data, point, funds, edge)
        } else {
            heights::plan_lower(&decoded, point, funds, edge)
        };

        if !trial.valid {
            if trial.insufficient {
                skipped_insufficient += 1;
            }

            continue;
        }

        let retile = expanded_indices(&trial.modified, edge);

        if random.is_none()
            && retile
                .iter()
                .any(|&index| city.xbld.data[index as usize] as i64 >= tiles::SMALL_PARK)
        {
            skipped_conflicts += 1;
            continue;
        }

        let maps = city.maps();
        heights::write_heights(maps.altitude, &trial.heights, &trial.modified);

        for &index in &trial.zone_indices {
            maps.zones[index as usize] &= zone::CORNERS_MASK as u8;
        }

        let cleared = clear_terrain_conflicts(city, &retile, random.as_deref_mut(), rotation);
        random_used |= cleared.random_used;
        funds = trial.funds;
        listed_cost += trial.cost;

        if !args.free_mode {
            total_cost += trial.cost;
        }

        action_count += 1;

        let maps = city.maps();
        retile_region(
            maps.altitude,
            maps.buildings,
            maps.terrain,
            maps.zones,
            maps.flags,
            maps.misc,
            &retile,
            sea_level,
            edge,
        );

        for &index in trial.modified.iter().chain(&retile).chain(&cleared.indices) {
            changed.add(index);
        }

        next_effect_frame = append_effect_sequence(&mut effect_events, &cleared.effect_events, next_effect_frame);
        sound_events.extend(cleared.sound_events);
    }

    if action_count == 0 {
        if let Some(random) = random.as_deref_mut() {
            random.state = random_before;
        }

        if skipped_insufficient > 0 {
            return TerrainResult::rejected("insufficient funds", LEVEL_COST);
        }

        if skipped_conflicts > 0 {
            return TerrainResult::rejected("terrain conflict demolition needs random state", 0);
        }

        return TerrainResult::rejected("no terrain height changed", 0);
    }

    city.set_funds(if args.free_mode { old_funds } else { funds });

    let mut result = TerrainResult {
        base: EditBase::accepted("terrain", args.group, args.subtool),
        target_altitude: target,
        action_count,
        skipped_conflicts,
        skipped_insufficient,
        random_used,
    };

    result.base.tile_indices = Ints32(changed.list);
    result.base.cost = total_cost;
    result.base.listed_cost = listed_cost;
    result.base.free_mode = args.free_mode;
    result.base.effect_events = effect_events;
    result.base.sound_events = sound_events;
    result.base.tracks_random = true;
    result.base.random_state_before = random_before;
    result.base.random_state_after = random.as_ref().map_or(random_before, |random| random.state);

    result
}

/// The level tool raises or lowers each tile toward the target height.
fn height_operation(subtool: i64, current: i64, target: i64) -> i64 {
    if subtool != SUBTOOL_LEVEL {
        return subtool;
    }

    if current < target {
        SUBTOOL_RAISE
    } else if current > target {
        SUBTOOL_LOWER
    } else {
        SUBTOOL_LEVEL
    }
}

/// Changed tile indices in first-change order.
#[derive(Default)]
struct Changed {
    list: Vec<i32>,
    seen: HashSet<i64>,
}

impl Changed {
    fn add(&mut self, index: i64) {
        if self.seen.insert(index) {
            self.list.push(index as i32);
        }
    }
}

/// TerrainEditSurface._expanded_indices: each index with its eight neighbors.
pub fn expanded_indices(indices: &[i64], map_edge: i64) -> Vec<i64> {
    let mut result = Vec::new();
    let mut seen = HashSet::new();

    for &index in indices {
        let point = Vec2i::new(index / map_edge, index % map_edge);

        for x in (point.x - 1).max(0)..(point.x + 2).min(map_edge) {
            for y in (point.y - 1).max(0)..(point.y + 2).min(map_edge) {
                let checked = x * map_edge + y;

                if seen.insert(checked) {
                    result.push(checked);
                }
            }
        }
    }

    result
}

#[derive(Default)]
struct ClearResult {
    indices: Vec<i64>,
    effect_events: Vec<EffectEvent>,
    sound_events: Vec<i64>,
    random_used: bool,
}

/// TerrainEditSurface._clear_terrain_conflicts: demolish the structures on the
/// changed ground and clear the smaller tiles and the pipes under it.
fn clear_terrain_conflicts(city: &mut City, indices: &[i64], mut random: Option<&mut SimRandom>, rotation: i64) -> ClearResult {
    let edge = city.map_size;
    let mut result = ClearResult::default();
    let mut seen = HashSet::new();
    let mut next_effect_frame = 0;
    let mut maps = city.maps();

    for &index in indices {
        let point = Vec2i::new(index / edge, index % edge);
        let old_building = maps.buildings[index as usize] as i64;

        if old_building >= tiles::SMALL_PARK {
            // The caller checks for a random generator before any structure.
            let Some(random) = random.as_deref_mut() else {
                return ClearResult::default();
            };

            let demolished = demolish_point(&mut maps, point, random, rotation, true, false, true, false);
            result.random_used = true;

            for &changed in &demolished.indices {
                if seen.insert(changed) {
                    result.indices.push(changed);
                }
            }

            next_effect_frame = append_effect_sequence(&mut result.effect_events, &demolished.effect_events, next_effect_frame);

            if !demolished.effect_events.is_empty() {
                result.sound_events.push(SOUND_EXPLODE);
            }
        }

        if old_building != tiles::RADIOACTIVE_WASTE {
            replace_building(maps.buildings, maps.zones, maps.misc, index, tiles::EMPTY);

            if seen.insert(index) {
                result.indices.push(index);
            }
        }

        if maps.underground[index as usize] as i64 != under::EMPTY {
            replace_underground(maps.underground, maps.zones, maps.misc, index, under::EMPTY);

            if seen.insert(index) {
                result.indices.push(index);
            }
        }
    }

    result
}
