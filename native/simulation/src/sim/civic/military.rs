//! The military base proposal, as MilitaryProposalPhase, ArmyBaseLayout, and NavalBaseSite.

use crate::gd_phase_result;
use crate::sim::bytes::{read_u32_be, write_u32_be};
use crate::sim::city::City;
use crate::sim::geom::{Rect2i, Vec2i};
use crate::sim::growth::special::replace_special_building;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::ids::underground_tile_ids as under;
use crate::sim::phase::TimingSpan;
use crate::sim::random::GameLcgRandom;
use crate::sim::tools::network::{grade_surface_terrain, retile_surface_neighborhood};
use crate::sim::value::Ints32;

const ZONE_MILITARY: i64 = 7;
pub const BASE_DECLINED: i64 = 1;
pub const BASE_ARMY: i64 = 2;
pub const BASE_AIR_FORCE: i64 = 3;
pub const BASE_NAVY: i64 = 4;
pub const BASE_MISSILE_SILOS: i64 = 5;
const NOTICE_ARMY: i64 = 0xf1;
const NOTICE_AIR_FORCE: i64 = 0xf2;
const NOTICE_NAVY: i64 = 0xf3;
const NOTICE_MISSILE_SILOS: i64 = 0xf4;
const NOTICE_NO_SITE: i64 = 0x19b;
const MODE_ROAD: i64 = 0;
const ALL_BUILDING_CORNERS: i64 = 0xf0;
const NAVAL_LENGTH: i64 = 10;
const NAVAL_DEPTH: i64 = 4;
const INLAND_STEPS: [Vec2i; 4] = [Vec2i::new(1, 0), Vec2i::new(0, 1), Vec2i::new(-1, 0), Vec2i::new(0, -1)];
/// NetworkTerrainRules.ENTRY_BLOCKS_DIRECTION: one row per terrain shape, one
/// column per direction (N, E, S, W).
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

gd_phase_result! {
    pub struct MilitaryProposalResult as "MilitaryProposalPhase.Result" {
        pub accepted: bool = false,
        pub base_type: i64 = 0,
        pub site: Rect2i = Rect2i::default(),
        pub changed_indices: Ints32 = Ints32::default(),
        pub notice_id: i64 = -1,
        pub sites: Vec<Rect2i> = Vec::new(),
    }
}

const PROPOSAL_CHUNKS: [&str; 6] = ["XBLD", "XTER", "XZON", "XUND", "XBIT", "MISC"];

fn result(accepted: bool, base_type: i64, site: Rect2i, changed: Vec<i64>, notice_id: i64) -> MilitaryProposalResult {
    let mut result = MilitaryProposalResult {
        accepted,
        base_type,
        site,
        changed_indices: Ints32(changed.iter().map(|value| *value as i32).collect()),
        notice_id,
        ..Default::default()
    };
    result.base.ok = true;

    if notice_id >= 0 {
        result.base.notice_ids.0.push(notice_id as i32);
    }

    if accepted {
        let center = if base_type == BASE_ARMY || base_type == BASE_AIR_FORCE {
            site.position + Vec2i::new(4, 4)
        } else {
            site.position
        };
        result.base.view_center_requests.push(center);
    }

    result
}

fn count_mask(map_edge: i64) -> i64 {
    if map_edge == 128 { 0xffff } else { 0xffff_ffff }
}

fn decrement_tile_count(misc: &mut [u8], tile: i64, map_edge: i64) {
    let offset = misc_layout::TILE_COUNTS + tile * 4;
    write_u32_be(misc, offset, (read_u32_be(misc, offset) - 1) & count_mask(map_edge));
}

fn increment_military_other(misc: &mut [u8], map_edge: i64) {
    let offset = misc_layout::MILITARY_TILE_COUNTS;
    write_u32_be(misc, offset, (read_u32_be(misc, offset) + 1) & count_mask(map_edge));
}

fn is_clear_land(buildings: &[u8], terrain: &[u8], flags: &[u8], index: usize) -> bool {
    (buildings[index] as i64) < tiles::SMALL_PARK
        && terrain[index] as i64 == terrain_ids::FLAT
        && flags[index] as i64 & flag_bits::WATER == 0
}

/// The maps that a base plot writes.
struct PlotMaps<'a> {
    buildings: &'a mut [u8],
    terrain: &'a mut [u8],
    zones: &'a mut [u8],
    underground: &'a [u8],
    flags: &'a mut [u8],
    misc: &'a mut [u8],
    map_edge: i64,
}

fn plot_maps(city: &mut City) -> PlotMaps<'_> {
    let map_edge = city.map_size;
    let City { xbld, xter, xzon, xund, xbit, misc, .. } = city;

    PlotMaps {
        buildings: &mut xbld.data,
        terrain: &mut xter.data,
        zones: &mut xzon.data,
        underground: &xund.data,
        flags: &mut xbit.data,
        misc: &mut misc.data,
        map_edge,
    }
}

/// MilitaryProposalPhase._zone_plot.
fn zone_plot(maps: &mut PlotMaps, site: Rect2i) -> Vec<i64> {
    let edge = maps.map_edge;
    let mut changed = Vec::new();

    for x in site.position.x..site.end().x {
        for y in site.position.y..site.end().y {
            let index = x * edge + y;
            let i = index as usize;

            if is_clear_land(maps.buildings, maps.terrain, maps.flags, i)
                && maps.zones[i] as i64 & zone::TYPE_MASK == 0
                && maps.underground[i] as i64 == under::EMPTY
            {
                decrement_tile_count(maps.misc, maps.buildings[i] as i64, edge);
                maps.zones[i] = ((maps.zones[i] as i64 & 0xf7) | ZONE_MILITARY) as u8;
                increment_military_other(maps.misc, edge);
                changed.push(index);
            }
        }
    }

    changed
}

/// Mark chunks stored, as BuildingState._apply_payloads stores each listed chunk.
fn store(city: &mut City, ids: &[&str]) {
    for id in ids {
        if let Some(chunk) = city.chunk_mut(id) {
            chunk.written = true;
        }
    }
}

/// MilitaryProposalPhase.resolve. A stored proposal has step timing.
pub fn resolve(
    city: &mut City,
    accepted: bool,
    game: Option<&mut GameLcgRandom>,
    defer_land_plot: bool,
) -> MilitaryProposalResult {
    let mut span = TimingSpan::new();
    span.mark("prepare data");
    let mut result = resolve_steps(city, accepted, game, defer_land_plot, &mut span);

    if result.base.ok {
        result.base.timing = span.finish();
    }

    result
}

fn resolve_steps(
    city: &mut City,
    accepted: bool,
    game: Option<&mut GameLcgRandom>,
    defer_land_plot: bool,
    span: &mut TimingSpan,
) -> MilitaryProposalResult {
    let edge = city.map_size;

    if accepted && game.is_none() {
        return MilitaryProposalResult::failed("a compatible game random generator is required");
    }

    if city.missing_or_resized(&PROPOSAL_CHUNKS).is_some() {
        return MilitaryProposalResult::failed("military proposal data is missing or invalid");
    }

    if !accepted {
        span.mark("store declined proposal");
        city.set_misc_u32(misc_layout::MILITARY_BASE_TYPE, BASE_DECLINED);

        return result(false, BASE_DECLINED, Rect2i::default(), Vec::new(), -1);
    }

    let game = game.expect("checked above");
    span.mark("naval site search");
    let navy_site = find_naval_site(city);

    if navy_site.has_area() && game.next_mod(2) == 1 {
        span.mark("build and store naval base");
        let mut maps = plot_maps(city);
        let changed = zone_plot(&mut maps, navy_site);

        for index in &changed {
            // Ownership moved to the military-other counter above.
            maps.buildings[*index as usize] = tiles::EMPTY as u8;
        }

        write_u32_be(maps.misc, misc_layout::MILITARY_BASE_TYPE, BASE_NAVY);
        store(city, &["XZON", "MISC", "XBLD"]);
        let mut navy = result(true, BASE_NAVY, navy_site, changed, NOTICE_NAVY);
        navy.base.view_center_requests = vec![navy_site.position + Vec2i::new(navy_site.size.x / 2, navy_site.size.y / 2)];

        return navy;
    }

    span.mark("land base site search");
    let mut last_altitude = 0;

    for _ in 0..24 {
        let x = game.next_mod(edge - 9);
        let y = game.next_mod(edge - 9);
        let origin = Vec2i::new(x, y);
        last_altitude = city.land_altitude(origin.x, origin.y);
        let mut valid = 0;
        let mut level = 0;

        for x in origin.x..origin.x + 8 {
            for y in origin.y..origin.y + 8 {
                let i = (x * edge + y) as usize;

                if is_clear_land(&city.xbld.data, &city.xter.data, &city.xbit.data, i)
                    && city.xzon.data[i] & 15 == 0
                    && city.xund.data[i] as i64 == under::EMPTY
                {
                    valid += 1;

                    if city.land_altitude(x, y) == last_altitude {
                        level += 1;
                    }
                }
            }
        }

        if valid < 40 {
            continue;
        }

        span.mark("build and store land base");
        let base_type = if valid == level { BASE_AIR_FORCE } else { BASE_ARMY };
        let notice = if base_type == BASE_AIR_FORCE { NOTICE_AIR_FORCE } else { NOTICE_ARMY };
        let site = Rect2i::from(origin, Vec2i::new(8, 8));

        if defer_land_plot {
            city.set_misc_u32(misc_layout::MILITARY_BASE_TYPE, base_type);
            let mut deferred = result(true, base_type, site, Vec::new(), notice);
            deferred.base.complete = false;
            deferred.base.view_center_requests.clear();

            return deferred;
        }

        return reserve_land_site(city, base_type, site, notice);
    }

    span.mark("missile site search");
    let mut sites = Vec::new();

    for _ in 0..40 {
        let x = game.next_mod(edge - 4);
        let y = game.next_mod(edge - 4);
        let origin = Vec2i::new(x, y);
        let mut valid = 0;

        for x in origin.x..origin.x + 3 {
            for y in origin.y..origin.y + 3 {
                let i = (x * edge + y) as usize;

                if is_clear_land(&city.xbld.data, &city.xter.data, &city.xbit.data, i)
                    && city.land_altitude(x, y) == last_altitude
                    && city.xzon.data[i] as i64 & zone::TYPE_MASK != ZONE_MILITARY
                    && city.xund.data[i] as i64 == under::EMPTY
                {
                    valid += 1;
                }
            }
        }

        if valid == 9 {
            sites.push(Rect2i::from(origin, Vec2i::new(3, 3)));

            if sites.len() == 6 {
                break;
            }
        }
    }

    span.mark("store missile sites or failed proposal");

    if sites.len() != 6 {
        city.set_misc_u32(misc_layout::MILITARY_BASE_TYPE, BASE_DECLINED);

        return result(false, BASE_DECLINED, Rect2i::default(), Vec::new(), NOTICE_NO_SITE);
    }

    let maps = plot_maps(city);
    let mut changed = Vec::new();

    for site in &sites {
        for x in site.position.x..site.end().x {
            for y in site.position.y..site.end().y {
                let index = x * edge + y;
                let i = index as usize;
                decrement_tile_count(maps.misc, maps.buildings[i] as i64, edge);
                maps.zones[i] = ((maps.zones[i] as i64 & 0xf7) | ZONE_MILITARY) as u8;
                increment_military_other(maps.misc, edge);
                changed.push(index);
            }
        }
    }

    write_u32_be(maps.misc, misc_layout::MILITARY_BASE_TYPE, BASE_MISSILE_SILOS);
    store(city, &["XZON", "MISC"]);
    let last = *sites.last().expect("six sites");
    let mut missiles = result(true, BASE_MISSILE_SILOS, last, changed, NOTICE_MISSILE_SILOS);
    missiles.sites = sites;
    missiles
}

/// MilitaryProposalPhase.reserve_land_site. The original shows the Army or Air
/// Force notice before it changes the plot.
pub fn reserve_land_site(city: &mut City, base_type: i64, site: Rect2i, notice_id: i64) -> MilitaryProposalResult {
    if city.missing_or_resized(&PROPOSAL_CHUNKS).is_some() || (base_type != BASE_ARMY && base_type != BASE_AIR_FORCE) {
        return MilitaryProposalResult::failed("military base reservation is invalid");
    }

    let mut maps = plot_maps(city);
    let changed = zone_plot(&mut maps, site);
    write_u32_be(maps.misc, misc_layout::MILITARY_BASE_TYPE, base_type);

    if base_type == BASE_ARMY {
        build_army_base(&mut maps, site.position);
    }

    store(city, &["XZON", "MISC", "XBLD", "XTER", "XBIT"]);

    result(true, base_type, site, changed, notice_id)
}

/// ArmyBaseLayout.build.
fn build_army_base(maps: &mut PlotMaps, origin: Vec2i) {
    for offset in [2, 5] {
        army_strip(maps, origin + Vec2i::new(offset, 0), Vec2i::new(0, 1));
    }

    for offset in [2, 5] {
        army_strip(maps, origin + Vec2i::new(0, offset), Vec2i::new(1, 0));
    }
}

fn army_strip(maps: &mut PlotMaps, start: Vec2i, step: Vec2i) {
    let edge = maps.map_edge;
    let mut placed = 0;
    let direction = if step.y != 0 { 2 } else { 1 };

    for distance in 0..8 {
        let point = start + Vec2i::new(step.x * distance, step.y * distance);
        let i = (point.x * edge + point.y) as usize;

        if maps.zones[i] as i64 & zone::TYPE_MASK != zone::MILITARY
            || maps.underground[i] as i64 != under::EMPTY
            || maps.flags[i] as i64 & flag_bits::WATER != 0
        {
            continue;
        }

        let tile = maps.buildings[i] as i64;
        let terrain = maps.terrain[i] as i64;

        if tile >= tiles::SMALL_PARK || tile == tiles::RADIOACTIVE_WASTE || terrain >= terrain_ids::DEEP_WATER_FIRST {
            continue;
        }

        if ENTRY_BLOCKS_DIRECTION[((terrain & terrain_ids::SHAPE_MASK) * 4 + direction) as usize] {
            continue;
        }

        grade_surface_terrain(maps.terrain, maps.flags, point, direction, edge);
        replace_special_building(maps.buildings, maps.zones, maps.misc, i as i64, tiles::ROAD_STRAIGHT_1);
        retile_surface_neighborhood(maps.buildings, maps.terrain, maps.zones, maps.flags, maps.misc, point, MODE_ROAD, &[], edge);
        placed += 1;
    }

    if placed == 0 {
        return;
    }

    for distance in [0, 7] {
        let point = start + Vec2i::new(step.x * distance, step.y * distance);
        let i = (point.x * edge + point.y) as usize;

        if distance == 7 && placed < 2 {
            continue;
        }

        let tile = maps.buildings[i] as i64;

        if maps.terrain[i] as i64 == terrain_ids::FLAT
            && maps.zones[i] as i64 & zone::TYPE_MASK == zone::MILITARY
            && (tile == tiles::ROAD_STRAIGHT_1 || tile == tiles::ROAD_STRAIGHT_2)
        {
            replace_special_building(maps.buildings, maps.zones, maps.misc, i as i64, tiles::RUNWAY_CROSSING);
            maps.zones[i] = (maps.zones[i] as i64 | ALL_BUILDING_CORNERS) as u8;
            maps.flags[i] = (maps.flags[i] as i64 & !flag_bits::UTILITY_MASK & 0xff) as u8;
        }
    }
}

/// NavalBaseSite.find. An empty rectangle means no site.
pub fn find_naval_site(city: &City) -> Rect2i {
    if city.misc_u32(misc_layout::HAS_OCEAN) == 0 {
        return Rect2i::default();
    }

    let edge = city.map_size;
    let rotation = city.compass_rotation();

    for turn in 0..4 {
        let inland = INLAND_STEPS[((rotation + turn) & 3) as usize];
        let along = Vec2i::new(-inland.y, inland.x);

        for x in 1..edge - 1 {
            crate::sim::budget::checkpoint();

            for y in 1..edge - 1 {
                let shore = Vec2i::new(x, y);

                if !naval_clear_land(city, shore) || !salt_water(city, shore - inland) {
                    continue;
                }

                let site = naval_candidate(city, shore, inland, along);

                if site.has_area() {
                    return site;
                }
            }
        }
    }

    Rect2i::default()
}

fn scaled(point: Vec2i, factor: i64) -> Vec2i {
    Vec2i::new(point.x * factor, point.y * factor)
}

fn naval_candidate(city: &City, shore: Vec2i, inland: Vec2i, along: Vec2i) -> Rect2i {
    let altitude = city.land_altitude(shore.x, shore.y);

    // A land tile at each end keeps the ten developed columns off the shore ends.
    for column in -1..NAVAL_LENGTH + 1 {
        let point = shore + scaled(along, column);

        if !naval_clear_land(city, point) || city.land_altitude(point.x, point.y) != altitude {
            return Rect2i::default();
        }

        if !salt_water(city, point - inland) {
            return Rect2i::default();
        }
    }

    for column in 0..NAVAL_LENGTH {
        for row in 0..NAVAL_DEPTH {
            let point = shore + scaled(along, column) + scaled(inland, row);

            if !naval_clear_land(city, point) || city.land_altitude(point.x, point.y) != altitude {
                return Rect2i::default();
            }
        }
    }

    let last = shore + scaled(along, NAVAL_LENGTH - 1) + scaled(inland, NAVAL_DEPTH - 1);
    let position = Vec2i::new(shore.x.min(last.x), shore.y.min(last.y));
    let size = Vec2i::new((shore.x - last.x).abs() + 1, (shore.y - last.y).abs() + 1);

    Rect2i::from(position, size)
}

fn naval_clear_land(city: &City, point: Vec2i) -> bool {
    let index = city.index_of(point.x, point.y);

    if index < 0 {
        return false;
    }

    let i = index as usize;
    let building = city.xbld.data[i] as i64;

    building < tiles::SMALL_PARK
        && building != tiles::RADIOACTIVE_WASTE
        && city.xter.data[i] as i64 == terrain_ids::FLAT
        && city.xbit.data[i] as i64 & flag_bits::WATER == 0
        && city.xzon.data[i] as i64 & zone::TYPE_MASK == 0
        && city.xund.data[i] as i64 == under::EMPTY
}

fn salt_water(city: &City, point: Vec2i) -> bool {
    let index = city.index_of(point.x, point.y);
    let salt = flag_bits::WATER | flag_bits::SALT_WATER;

    index >= 0 && city.xbit.data[index as usize] as i64 & salt == salt
}
