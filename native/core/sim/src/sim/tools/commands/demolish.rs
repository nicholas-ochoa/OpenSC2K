//! The bulldozer, as DemolishEdit and DemolishStructures._demolish_underground_point.

use super::{EditBase, ToolArgs};
use crate::gd_edit_result;
use crate::sim::city::City;
use crate::sim::events::NewsEvent;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2altitude_layout as altitude_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::underground_tile_ids as under;
use crate::sim::overlay;
use crate::sim::random::SimRandom;
use crate::sim::reports::news;
use crate::sim::tools::Maps;
use crate::sim::tools::demolish::{PROTECTED_CONNECTION_LABEL, PointResult, append_effect_sequence, demolish_point};
use crate::sim::tools::terrain::retile_after_demolition;
use crate::sim::tools::underground::replace_underground;
use crate::sim::value::Ints32;

/// The chunks that DemolishEdit checks: the building chunks and ALTM.
pub const PAYLOAD_IDS: [&str; 10] = ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"];

const SOUND_EXPLODE: i64 = 504;
const SOUND_FOREST_PROTEST: i64 = 512;
const NEWS_FOREST_PROTEST: i64 = 0x28;

/// Parallel demolitions start their dust up to this many frames apart.
const MAX_PARALLEL_EFFECT_OFFSET_FRAMES: i64 = 2;

gd_edit_result! {
    pub struct DemolishResult as "DemolishEditResult" {
        pub underground_view: bool = false,
        pub scurk_mode: bool = false,
        pub action_count: i64 = 0,
        pub skipped_specialized: i64 = 0,
        pub skipped_insufficient: i64 = 0,
        pub easter_events: i64 = 0,
        pub news_items: Vec<NewsEvent> = Vec::new(),
        pub news_queue_updated: bool = false,
    }
}

/// DemolishEdit.apply_path. SCURK mode is free and keeps the terrain.
pub fn apply(
    city: &mut City,
    args: &ToolArgs,
    points: &[Vec2i],
    random: &mut SimRandom,
    underground_view: bool,
    scurk_mode: bool,
) -> DemolishResult {
    let edge = city.map_size;

    if points.is_empty() {
        return DemolishResult::rejected("demolish path is empty", 0);
    }

    if city.missing_or_resized(&PAYLOAD_IDS[1..]).is_some() {
        return DemolishResult::rejected("required city data is missing or invalid", 0);
    }

    if city.missing_or_resized(&PAYLOAD_IDS[..1]).is_some() {
        return DemolishResult::rejected("required altitude data is missing or invalid", 0);
    }

    let per_action = if scurk_mode { 0 } else { args.cost };
    let funds = city.funds();
    let rotation = city.compass_rotation();
    let random_before = random.state;
    let original = scurk_mode.then(|| {
        (
            city.xter.data.clone(),
            city.altm.data.clone(),
            city.xzon.data.clone(),
            city.xbit.data.clone(),
        )
    });

    let mut total_cost = 0;
    let mut action_count = 0;
    let mut changed = Vec::new();
    let mut seen = std::collections::HashSet::new();
    let mut skipped_specialized = 0;
    let mut skipped_insufficient = 0;
    let mut easter_events = 0;
    let mut news_items = Vec::new();
    let mut effect_events = Vec::new();
    let mut sound_events = Vec::new();

    for &point in points {
        if city.index_of(point.x, point.y) < 0 {
            continue;
        }

        if funds - total_cost < per_action {
            skipped_insufficient += 1;
            continue;
        }

        let mut maps = city.maps();
        let result = if underground_view {
            demolish_underground_point(&mut maps, point, random, rotation, scurk_mode)
        } else {
            demolish_point(&mut maps, point, random, rotation, scurk_mode, true, !scurk_mode, scurk_mode)
        };

        if result.specialized {
            skipped_specialized += 1;
            continue;
        }

        if !result.changed {
            continue;
        }

        action_count += 1;
        total_cost += per_action;

        if result.easter_event {
            easter_events += 1;

            if news::insert(maps.misc, NEWS_FOREST_PROTEST, 0).is_err() {
                random.state = random_before;

                return DemolishResult::rejected("cannot store forest protest news", 0);
            }

            news_items.push(NewsEvent::new(NEWS_FOREST_PROTEST, 0));
        }

        let offset = parallel_effect_offset(point, action_count - 1, random_before);
        append_effect_sequence(&mut effect_events, &result.effect_events, offset);

        if !result.effect_events.is_empty() && !sound_events.contains(&SOUND_EXPLODE) {
            sound_events.push(SOUND_EXPLODE);
        }

        for &index in &result.indices {
            if seen.insert(index) {
                changed.push(index as i32);
            }
        }
    }

    if action_count == 0 {
        random.state = random_before;

        if skipped_insufficient > 0 {
            return DemolishResult::rejected("insufficient funds", per_action);
        }

        if skipped_specialized > 0 {
            return DemolishResult::rejected("reinforced bridge or network data is malformed", 0);
        }

        return DemolishResult::rejected("no eligible tiles changed", 0);
    }

    city.set_funds(funds - total_cost);

    // One sound plays at a time, so the protest sound goes after the demolition sound.
    if easter_events > 0 {
        sound_events.push(SOUND_FOREST_PROTEST);
    }

    // SCURK keeps the ground: terrain, heights, zone types, and water.
    if let Some((terrain, altitude, zones, flags)) = original {
        city.xter.data = terrain;
        city.altm.data = altitude;

        for index in 0..(edge * edge) as usize {
            city.xzon.data[index] = ((city.xzon.data[index] as i64 & zone::CORNERS_MASK) | (zones[index] as i64 & zone::TYPE_MASK)) as u8;
            city.xbit.data[index] =
                ((city.xbit.data[index] as i64 & !flag_bits::WATER & 0xff) | (flags[index] as i64 & flag_bits::WATER)) as u8;
        }
    }

    let mut result = DemolishResult {
        base: EditBase::accepted("demolish", args.group, args.subtool),
        underground_view,
        scurk_mode,
        action_count,
        skipped_specialized,
        skipped_insufficient,
        easter_events,
        news_queue_updated: easter_events > 0,
        news_items,
    };

    result.base.tile_indices = Ints32(changed);
    result.base.cost = total_cost;
    result.base.listed_cost = action_count * args.cost;
    result.base.effect_events = effect_events;
    result.base.sound_events = sound_events;
    result.base.tracks_random = true;
    result.base.random_state_before = random_before;
    result.base.random_state_after = random.state;

    result
}

/// DemolishEffectsSites.parallel_effect_offset: a small, repeatable delay for
/// each later action of one drag.
fn parallel_effect_offset(point: Vec2i, action_index: i64, random_seed: i64) -> i64 {
    if action_index <= 0 {
        return 0;
    }

    let mut mixed = point.x * 0x45d9f3b + point.y * 0x119de1f3 + action_index * 0x27d4eb2d + random_seed;
    mixed ^= mixed >> 16;

    1 + mixed.abs() % MAX_PARALLEL_EFFECT_OFFSET_FRAMES
}

/// DemolishStructures._demolish_underground_point: clear the pipe or subway,
/// and the tunnel or subway station above it.
fn demolish_underground_point(maps: &mut Maps, point: Vec2i, random: &mut SimRandom, rotation: i64, scurk_mode: bool) -> PointResult {
    let edge = maps.map_edge;
    let index = point.x * edge + point.y;
    let i = index as usize;

    if !scurk_mode && maps.zones[i] as i64 & zone::TYPE_MASK == zone::MILITARY {
        return PointResult::default();
    }

    if !scurk_mode && overlay::marker_at(maps.text_overlays, index) == PROTECTED_CONNECTION_LABEL {
        return PointResult::default();
    }

    let word = ((maps.altitude[i * 2] as i64) << 8) | maps.altitude[i * 2 + 1] as i64;
    let tunnel_level = (word & altitude_layout::TUNNEL_MASK) >> altitude_layout::TUNNEL_SHIFT;
    let underground_tile = maps.underground[i] as i64;

    if underground_tile == under::EMPTY && tunnel_level != 1 && maps.flags[i] as i64 & flag_bits::PIPED == 0 {
        return PointResult::default();
    }

    if (maps.buildings[i] as i64) < tiles::DEVELOPED_FIRST {
        maps.flags[i] &= !(flag_bits::PIPED as u8);
    }

    let mut indices = vec![index];
    let mut effect_events = Vec::new();

    if tunnel_level == 1 || underground_tile == under::SUBWAY_ENTRANCE {
        let surface = demolish_point(maps, point, random, rotation, scurk_mode, true, !scurk_mode, scurk_mode);

        for changed in surface.indices {
            if !indices.contains(&changed) {
                indices.push(changed);
            }
        }

        effect_events = surface.effect_events;
    }

    replace_underground(maps.underground, maps.zones, maps.misc, index, under::EMPTY);
    retile_after_demolition(
        maps.buildings,
        maps.terrain,
        maps.zones,
        maps.underground,
        maps.flags,
        maps.misc,
        &[point],
        maps.text_overlays,
        edge,
    );

    PointResult {
        changed: true,
        indices,
        effect_events,
        ..Default::default()
    }
}
