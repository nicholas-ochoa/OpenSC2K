//! Structure damage, as DemolishStructures, DemolishBridges, DemolishTransport,
//! and DemolishEffectsSites.

use super::highway;
use super::network::{self, replace_building};
use super::terrain;
use super::underground;
use super::{CORNER_BOTTOM_LEFT, CORNER_BOTTOM_RIGHT, CORNER_TOP_LEFT, CORNER_TOP_RIGHT, Maps};
use crate::sim::bytes::{read_u32_be, write_u32_be};
use crate::sim::events::EffectEvent;
use crate::sim::geom::{Rect2i, Vec2i};
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2label_layout;
use crate::sim::ids::sc2microsim_layout;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2overlay_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::overlay;
use crate::sim::random::SimRandom;

pub const BRIDGE_DEBRIS_SPRITE: i64 = 1392;
pub const PROTECTED_CONNECTION_LABEL: i64 = 0xff;
pub const FLAG_CLEAR_AFTER_STRUCTURE: i64 = !(flag_bits::FLIPPED | flag_bits::POWER_MASK) & 0xff;
pub const MICROSIM_DYNAMIC_FIRST: i64 = 10;
pub const DIRECTIONS: [Vec2i; 4] = [Vec2i::new(0, -1), Vec2i::new(1, 0), Vec2i::new(0, 1), Vec2i::new(-1, 0)];
const SECTION_OFFSETS: [Vec2i; 4] = [Vec2i::new(0, 0), Vec2i::new(1, 0), Vec2i::new(1, 1), Vec2i::new(0, 1)];

#[derive(Clone, Debug, Default, PartialEq)]
pub struct PointResult {
    pub changed: bool,
    pub error: String,
    pub specialized: bool,
    pub easter_event: bool,
    pub indices: Vec<i64>,
    pub effect_events: Vec<EffectEvent>,
}

impl PointResult {
    fn unchanged() -> Self {
        Self::default()
    }

    fn specialized() -> Self {
        Self {
            specialized: true,
            ..Default::default()
        }
    }
}

fn reward_bit(tile: i64) -> Option<i64> {
    match tile {
        tiles::MAYOR_HOUSE => Some(0),
        tiles::CITY_HALL => Some(1),
        tiles::STATUE => Some(2),
        tiles::LLAMA_DOME => Some(3),
        _ => None,
    }
}

/// DemolishEffectsSites.append_effect_sequence. Returns the next free frame.
pub fn append_effect_sequence(destination: &mut Vec<EffectEvent>, source: &[EffectEvent], first_frame: i64) -> i64 {
    if source.is_empty() {
        return first_frame;
    }

    let mut frame_count = 0;

    for source_effect in source {
        let mut effect = source_effect.clone();
        let source_frame = effect.frame;
        effect.frame = first_frame + source_frame;
        destination.push(effect);
        frame_count = frame_count.max(source_frame + 1);
    }

    first_frame + frame_count
}

pub fn effect_altitude(altitude: &[u8], flags: &[u8], index: i64) -> i64 {
    if flags[index as usize] as i64 & flag_bits::WATER != 0 {
        terrain::water_altitude(altitude, index)
    } else {
        terrain::land_altitude(altitude, index)
    }
}

pub fn dust_effect(point: Vec2i, altitude: i64, random: &mut SimRandom, frame: i64, screen_offset: Vec2i) -> EffectEvent {
    let sprite = BRIDGE_DEBRIS_SPRITE + (random.next_u15() & 3);
    let flip = random.next_u15() & 1 != 0;

    EffectEvent::new(point, sprite, screen_offset, flip, frame, altitude)
}

pub fn structure_effects(
    altitude: &[u8],
    flags: &[u8],
    site: Rect2i,
    area: i64,
    random: &mut SimRandom,
    map_edge: i64,
) -> Vec<EffectEvent> {
    let mut effects = Vec::new();
    let anchor = Vec2i::new(site.position.x, site.end().y - 1);
    let anchor_index = anchor.x * map_edge + anchor.y;
    let height = effect_altitude(altitude, flags, anchor_index);

    for frame in 0..area {
        for x_offset in 0..area {
            for y_offset in 0..area {
                let point = Vec2i::new(site.position.x + x_offset, site.end().y - 1 - y_offset);
                effects.push(dust_effect(point, height, random, frame, Vec2i::new(0, -frame * 8)));
            }
        }
    }

    effects
}

/// DemolishEffectsSites._building_area.
pub fn building_area(tile: i64) -> i64 {
    if tile < tiles::DEVELOPED_FIRST || tile <= tiles::DEVELOPED_1X1_LAST {
        return 1;
    }

    if tile <= tiles::DEVELOPED_2X2_LAST {
        return 2;
    }

    if tile <= tiles::DEVELOPED_3X3_LAST {
        return 3;
    }

    if tile <= tiles::SMALL_POWER_LAST {
        return 1;
    }

    if tile <= tiles::LARGE_POWER_LAST {
        return 4;
    }

    if tile <= tiles::CIVIC_3X3_LAST {
        return 3;
    }

    if tile <= tiles::CIVIC_4X4_LAST {
        return 4;
    }

    if tile <= tiles::INFRASTRUCTURE_1X1_LAST {
        return 1;
    }

    if tile <= tiles::INFRASTRUCTURE_2X2_LAST {
        return 2;
    }

    if tile <= tiles::INFRASTRUCTURE_3X3_LAST {
        return 3;
    }

    4
}

/// DemolishEffectsSites._find_building_site. An empty rectangle means none.
pub fn find_building_site(buildings: &[u8], zones: &[u8], selected: Vec2i, tile: i64, area: i64, rotation: i64, map_edge: i64) -> Rect2i {
    if area == 1 {
        return Rect2i::from(selected, Vec2i::new(1, 1));
    }

    for origin_x in (selected.x - area + 1)..(selected.x + 1) {
        for origin_y in (selected.y - area + 1)..(selected.y + 1) {
            let site = Rect2i::new(origin_x, origin_y, area, area);

            if site.position.x < 0 || site.position.y < 0 || site.end().x > map_edge || site.end().y > map_edge {
                continue;
            }

            if site_matches(buildings, zones, site, tile, rotation, map_edge) {
                return site;
            }
        }
    }

    Rect2i::default()
}

fn site_matches(buildings: &[u8], zones: &[u8], site: Rect2i, tile: i64, rotation: i64, map_edge: i64) -> bool {
    for x in site.position.x..site.end().x {
        for y in site.position.y..site.end().y {
            if buildings[(x * map_edge + y) as usize] as i64 != tile {
                return false;
            }
        }
    }

    let far = site.end() - Vec2i::new(1, 1);
    let view = (rotation & 3) as usize;
    let corner = |x: i64, y: i64| zones[(x * map_edge + y) as usize] as i64 & zone::CORNERS_MASK;

    corner(site.position.x, site.position.y) == CORNER_BOTTOM_LEFT[view]
        && corner(far.x, site.position.y) == CORNER_BOTTOM_RIGHT[view]
        && corner(far.x, far.y) == CORNER_TOP_LEFT[view]
        && corner(site.position.x, far.y) == CORNER_TOP_RIGHT[view]
}

/// DemolishEffectsSites._release_overlay.
pub fn release_overlay(text_overlays: &mut [u8], labels: &mut [u8], microsims: &mut [u8], index: i64) {
    let label_id = overlay::read(text_overlays, index);

    if label_id == 0 {
        return;
    }

    if !overlay::blocks_thing(label_id) || label_id == sc2overlay_layout::CONNECTION_MARKER {
        overlay::write(text_overlays, index, 0);
    }

    if overlay::is_sign(label_id) {
        crate::sim::bytes::put(labels, label_id * sc2label_layout::RECORD_SIZE, 0);
    } else if overlay::is_facility(label_id) && overlay::facility_record(label_id) >= MICROSIM_DYNAMIC_FIRST {
        let record = overlay::facility_record(label_id);
        crate::sim::bytes::put(microsims, record * sc2microsim_layout::RECORD_SIZE, 0);
        crate::sim::bytes::put(labels, label_id * sc2label_layout::RECORD_SIZE, 0);
    }
}

/// DemolishStructures.damage_structure_payloads. Trees and smaller tiles are
/// not structures.
pub fn damage_structure(maps: &mut Maps, point: Vec2i, random: &mut SimRandom, rotation: i64, emit_effects: bool) -> PointResult {
    let index = if maps.in_bounds(point) { maps.index(point) } else { -1 };

    if index < 0 || (maps.buildings[index as usize] as i64) < tiles::TREE_FIRST {
        return PointResult::unchanged();
    }

    demolish_point(maps, point, random, rotation, true, false, emit_effects, false)
}

/// DemolishStructures._demolish_point.
#[allow(clippy::too_many_arguments)]
pub fn demolish_point(
    maps: &mut Maps,
    point: Vec2i,
    random: &mut SimRandom,
    rotation: i64,
    force_damage: bool,
    retile_neighbors: bool,
    emit_effects: bool,
    scurk_mode: bool,
) -> PointResult {
    let edge = maps.map_edge;
    let index = point.x * edge + point.y;
    let i = index as usize;
    let tile = maps.buildings[i] as i64;

    if !force_damage && ((maps.zones[i] as i64 & zone::TYPE_MASK) == zone::MILITARY || tile == tiles::RADIOACTIVE_WASTE) {
        return PointResult::unchanged();
    }

    if !force_damage && overlay::read(maps.text_overlays, index) == PROTECTED_CONNECTION_LABEL {
        return PointResult::unchanged();
    }

    if (tiles::TUNNEL_FIRST..=tiles::TUNNEL_LAST).contains(&tile) {
        return demolish_tunnel(maps, point, tile, random, emit_effects);
    }

    if (tiles::SUSPENSION_BRIDGE_1..=tiles::POWER_BRIDGE).contains(&tile) {
        return demolish_bridge(maps, point, random, rotation, emit_effects, scurk_mode);
    }

    if (tiles::HIGHWAY_BRIDGE..=tiles::REINFORCED_HIGHWAY_BRIDGE).contains(&tile) {
        return demolish_reinforced_bridge(maps, point, random, rotation, emit_effects, scurk_mode);
    }

    if (tiles::RUNWAY..=tiles::CRANE).contains(&tile) {
        return demolish_transport_component(maps, point, random, emit_effects, scurk_mode);
    }

    if is_highway_tile(tile) {
        return demolish_highway_section(maps, point, random, rotation, emit_effects, scurk_mode);
    }

    let was_water = maps.flags[i] as i64 & flag_bits::WATER != 0;

    if tile == tiles::EMPTY {
        if scurk_mode || (maps.terrain[i] as i64) < terrain_ids::SURFACE_WATER_FIRST {
            return PointResult::unchanged();
        }

        terrain::remove_surface_water(
            maps.altitude,
            maps.buildings,
            maps.terrain,
            maps.zones,
            maps.flags,
            maps.misc,
            point,
            edge,
        );

        return PointResult {
            changed: true,
            indices: vec![index],
            ..Default::default()
        };
    }

    if tile < tiles::SMALL_PARK {
        if !scurk_mode && tile >= tiles::TREE_FIRST && random.next_u15() % 20 == 0 {
            return PointResult {
                changed: true,
                easter_event: true,
                ..Default::default()
            };
        }

        let mut network_effects = Vec::new();

        if tile >= tiles::TREE_FIRST && emit_effects {
            let height = effect_altitude(maps.altitude, maps.flags, index);
            network_effects.push(dust_effect(point, height, random, 0, Vec2i::ZERO));
        }

        replace_building(maps.buildings, maps.zones, maps.misc, index, tiles::EMPTY);

        if maps.terrain[i] as i64 >= terrain_ids::SURFACE_WATER_FIRST {
            terrain::remove_surface_water(
                maps.altitude,
                maps.buildings,
                maps.terrain,
                maps.zones,
                maps.flags,
                maps.misc,
                point,
                edge,
            );
        }

        terrain::retile_after_demolition(
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

        return PointResult {
            changed: true,
            indices: vec![index],
            effect_events: network_effects,
            ..Default::default()
        };
    }

    let area = building_area(tile);
    let site = find_building_site(maps.buildings, maps.zones, point, tile, area, rotation, edge);

    if site.size == Vec2i::ZERO {
        return PointResult::unchanged();
    }

    let effect_events = if emit_effects {
        structure_effects(maps.altitude, maps.flags, site, area, random, edge)
    } else {
        Vec::new()
    };
    let mut indices = Vec::new();
    let mut changed_points = Vec::new();

    for x in site.position.x..site.end().x {
        for y in site.position.y..site.end().y {
            let changed_index = x * edge + y;
            let c = changed_index as usize;
            let mut rubble = tiles::EMPTY;

            if !scurk_mode && maps.terrain[c] as i64 == terrain_ids::FLAT {
                rubble = tiles::RUBBLE_FIRST + (random.next_u15() & 3);
            }

            replace_building(maps.buildings, maps.zones, maps.misc, changed_index, rubble);
            maps.zones[c] = (maps.zones[c] as i64 & zone::TYPE_MASK) as u8;
            maps.flags[c] = (maps.flags[c] as i64 & FLAG_CLEAR_AFTER_STRUCTURE) as u8;
            release_overlay(maps.text_overlays, maps.labels, maps.microsims, changed_index);
            indices.push(changed_index);
            changed_points.push(Vec2i::new(x, y));
        }
    }

    if tile == tiles::SUBWAY_STATION || (tiles::RAIL_SUBWAY_FIRST..=tiles::DEVELOPED_FIRST).contains(&tile) {
        underground::replace_underground(maps.underground, maps.zones, maps.misc, index, 0);
    }

    if let Some(bit) = reward_bit(tile) {
        let mask = read_u32_be(maps.misc, misc_layout::GRANTED_REWARDS);
        write_u32_be(maps.misc, misc_layout::GRANTED_REWARDS, mask | (1 << bit));
    }

    if retile_neighbors {
        terrain::retile_after_demolition(
            maps.buildings,
            maps.terrain,
            maps.zones,
            maps.underground,
            maps.flags,
            maps.misc,
            &changed_points,
            maps.text_overlays,
            edge,
        );
    }

    if maps.terrain[i] as i64 >= terrain_ids::SURFACE_WATER_FIRST {
        if was_water {
            terrain::retile_surface_water(maps.terrain, maps.flags, point, true, edge);
        } else {
            terrain::remove_surface_water(
                maps.altitude,
                maps.buildings,
                maps.terrain,
                maps.zones,
                maps.flags,
                maps.misc,
                point,
                edge,
            );
        }
    }

    PointResult {
        changed: true,
        indices,
        effect_events,
        ..Default::default()
    }
}

pub fn is_highway_tile(tile: i64) -> bool {
    (tiles::HIGHWAY_STRAIGHT_1..=tiles::HIGHWAY_POWER_CROSSING_2).contains(&tile)
        || (tiles::HIGHWAY_SLOPE_FIRST..=tiles::HIGHWAY_INTERSECTION).contains(&tile)
}

fn in_bounds(point: Vec2i, map_edge: i64) -> bool {
    point.x >= 0 && point.x < map_edge && point.y >= 0 && point.y < map_edge
}

fn demolish_tunnel(maps: &mut Maps, start: Vec2i, tile: i64, random: &mut SimRandom, emit_effects: bool) -> PointResult {
    let edge = maps.map_edge;
    let direction = [Vec2i::new(-1, 0), Vec2i::new(0, -1), Vec2i::new(1, 0), Vec2i::new(0, 1)][(tile - tiles::TUNNEL_FIRST) as usize];
    let mut points = vec![start];
    let mut current = start + direction;

    while in_bounds(current, edge) {
        points.push(current);
        let current_id = maps.buildings[(current.x * edge + current.y) as usize] as i64;

        if (tiles::TUNNEL_FIRST..=tiles::TUNNEL_LAST).contains(&current_id) {
            break;
        }

        current = current + direction;
    }

    if points.len() < 2 || !in_bounds(current, edge) {
        return PointResult::specialized();
    }

    let endpoints = [points[0], points[points.len() - 1]];
    let mut effect_events = Vec::new();

    if emit_effects {
        for entrance in endpoints {
            let entrance_index = entrance.x * edge + entrance.y;
            let height = terrain::land_altitude(maps.altitude, entrance_index);
            effect_events.push(dust_effect(entrance, height, random, 0, Vec2i::ZERO));
        }
    }

    for point in &points {
        terrain::clear_tunnel_level(maps.altitude, point.x * edge + point.y);
    }

    for entrance in endpoints {
        let entrance_index = entrance.x * edge + entrance.y;
        replace_building(maps.buildings, maps.zones, maps.misc, entrance_index, tiles::EMPTY);
        let e = entrance_index as usize;
        maps.zones[e] = (maps.zones[e] as i64 & zone::TYPE_MASK) as u8;
        terrain::retile_adjacent_roads(maps.buildings, maps.terrain, maps.zones, maps.flags, maps.misc, entrance, edge);
    }

    let indices = points.iter().map(|point| point.x * edge + point.y).collect();

    PointResult {
        changed: true,
        indices,
        effect_events,
        ..Default::default()
    }
}

/// Damage a bridge bank. This is the damage_bank callable of the original.
fn damage_bank(maps: &mut Maps, bank: Vec2i, random: &mut SimRandom, rotation: i64, emit_effects: bool, scurk_mode: bool) -> PointResult {
    demolish_point(maps, bank, random, rotation, true, false, emit_effects, scurk_mode)
}

#[allow(clippy::too_many_arguments)]
fn retile_bank(
    maps: &mut Maps,
    point: Vec2i,
    random: &mut SimRandom,
    rotation: i64,
    emit_effects: bool,
    scurk_mode: bool,
    points: &mut Vec<Vec2i>,
    result: &mut PointResult,
) {
    let edge = maps.map_edge;
    let index = point.x * edge + point.y;

    if maps.buildings[index as usize] as i64 >= tiles::SMALL_PARK {
        let damage = damage_bank(maps, point, random, rotation, emit_effects, scurk_mode);
        result.indices.extend(damage.indices);
        result.effect_events.extend(damage.effect_events);
    }

    if maps.underground[index as usize] != 0 {
        underground::replace_underground(maps.underground, maps.zones, maps.misc, index, 0);
    }

    let level = terrain::sea_level(maps.misc);
    terrain::retile_region(
        maps.altitude,
        maps.buildings,
        maps.terrain,
        maps.zones,
        maps.flags,
        maps.misc,
        &[index],
        level,
        edge,
    );
    points.push(point);
    result.indices.push(index);
}

fn demolish_bridge(
    maps: &mut Maps,
    selected: Vec2i,
    random: &mut SimRandom,
    rotation: i64,
    emit_effects: bool,
    scurk_mode: bool,
) -> PointResult {
    let edge = maps.map_edge;
    let selected_index = (selected.x * edge + selected.y) as usize;
    let direction = if maps.flags[selected_index] as i64 & flag_bits::FLIPPED != 0 {
        Vec2i::new(1, 0)
    } else {
        Vec2i::new(0, 1)
    };
    let is_bridge = |tile: i64| (tiles::SUSPENSION_BRIDGE_1..=tiles::POWER_BRIDGE).contains(&tile);
    let mut first = selected;

    while in_bounds(first - direction, edge) {
        let previous = first - direction;

        if !is_bridge(maps.buildings[(previous.x * edge + previous.y) as usize] as i64) {
            break;
        }

        first = previous;
    }

    let mut finish = selected;

    while in_bounds(finish + direction, edge) {
        let next = finish + direction;

        if !is_bridge(maps.buildings[(next.x * edge + next.y) as usize] as i64) {
            break;
        }

        finish = next;
    }

    let mut points = Vec::new();
    let mut result = PointResult::default();
    let mut current = first;

    loop {
        let index = current.x * edge + current.y;
        let i = index as usize;

        if emit_effects {
            let sprite = BRIDGE_DEBRIS_SPRITE + (random.next_u15() & 3);
            let flip = random.next_u15() & 1 != 0;
            let height = terrain::water_altitude(maps.altitude, index);
            result
                .effect_events
                .push(EffectEvent::new(current, sprite, Vec2i::ZERO, flip, 0, height));
        }

        replace_building(maps.buildings, maps.zones, maps.misc, index, tiles::EMPTY);
        maps.zones[i] = (maps.zones[i] as i64 & zone::TYPE_MASK) as u8;
        maps.flags[i] = (maps.flags[i] as i64 & !flag_bits::FLIPPED & 0xff) as u8;
        points.push(current);
        result.indices.push(index);

        if current == finish {
            break;
        }

        current = current + direction;
    }

    for bank in [first - direction, finish + direction] {
        if !in_bounds(bank, edge) {
            continue;
        }

        let bank_index = bank.x * edge + bank.y;
        let b = bank_index as usize;

        if maps.flags[b] as i64 & flag_bits::WATER != 0 {
            continue;
        }

        replace_building(maps.buildings, maps.zones, maps.misc, bank_index, tiles::EMPTY);
        let land = terrain::land_altitude(maps.altitude, bank_index);
        terrain::set_land_altitude(maps.altitude, bank_index, (land - 1).max(0));
        maps.flags[b] = (maps.flags[b] as i64 | flag_bits::WATER) as u8;
        maps.flags[b] = (maps.flags[b] as i64 & !flag_bits::FLIPPED & 0xff) as u8;
        retile_bank(maps, bank, random, rotation, emit_effects, scurk_mode, &mut points, &mut result);
    }

    terrain::retile_surface_water(maps.terrain, maps.flags, selected, true, edge);
    terrain::retile_after_demolition(
        maps.buildings,
        maps.terrain,
        maps.zones,
        maps.underground,
        maps.flags,
        maps.misc,
        &points,
        &[],
        edge,
    );
    result.changed = true;
    result
}

fn reinforced_section_is_valid(buildings: &[u8], anchor: Vec2i, map_edge: i64) -> bool {
    if anchor.x < 0 || anchor.y < 0 || anchor.x > map_edge - 2 || anchor.y > map_edge - 2 {
        return false;
    }

    let tile = buildings[(anchor.x * map_edge + anchor.y) as usize] as i64;

    if !(tiles::HIGHWAY_BRIDGE..=tiles::REINFORCED_HIGHWAY_BRIDGE).contains(&tile) {
        return false;
    }

    [Vec2i::new(1, 0), Vec2i::new(1, 1), Vec2i::new(0, 1)].iter().all(|offset| {
        let point = anchor + *offset;
        buildings[(point.x * map_edge + point.y) as usize] as i64 == tile
    })
}

/// The original terrain update visits all four bank cells. It can remove a
/// structure and its underground layer, but does not lower the bank first.
#[allow(clippy::too_many_arguments)]
fn retile_bank_section(
    maps: &mut Maps,
    anchor: Vec2i,
    random: &mut SimRandom,
    rotation: i64,
    emit_effects: bool,
    scurk_mode: bool,
    points: &mut Vec<Vec2i>,
    result: &mut PointResult,
) {
    for offset in SECTION_OFFSETS {
        let point = anchor + offset;

        if in_bounds(point, maps.map_edge) {
            retile_bank(maps, point, random, rotation, emit_effects, scurk_mode, points, result);
        }
    }
}

fn demolish_reinforced_bridge(
    maps: &mut Maps,
    selected: Vec2i,
    random: &mut SimRandom,
    rotation: i64,
    emit_effects: bool,
    scurk_mode: bool,
) -> PointResult {
    let edge = maps.map_edge;
    let anchor = Vec2i::new(selected.x & !1, selected.y & !1);

    if !reinforced_section_is_valid(maps.buildings, anchor, edge) {
        return PointResult::specialized();
    }

    let kind = highway::section_kind(maps.buildings, maps.zones, maps.flags, anchor, edge);
    let direction = if kind & 1 == 0 { Vec2i::new(2, 0) } else { Vec2i::new(0, 2) };
    let mut first = anchor;

    while highway::section_kind(maps.buildings, maps.zones, maps.flags, first - direction, edge) >= 13 {
        first = first - direction;
    }

    let mut finish = anchor;

    while highway::section_kind(maps.buildings, maps.zones, maps.flags, finish + direction, edge) >= 13 {
        finish = finish + direction;
    }

    let mut points = Vec::new();
    let mut result = PointResult::default();
    let mut current = first;
    retile_bank_section(
        maps,
        first - direction,
        random,
        rotation,
        emit_effects,
        scurk_mode,
        &mut points,
        &mut result,
    );

    loop {
        if emit_effects {
            let sprite = BRIDGE_DEBRIS_SPRITE + (random.next_u15() & 3);
            let current_index = current.x * edge + current.y;

            for screen_offset in [Vec2i::new(0, 0), Vec2i::new(16, -8), Vec2i::new(32, 0), Vec2i::new(16, 8)] {
                let flip = random.next_u15() & 1 != 0;
                let height = terrain::water_altitude(maps.altitude, current_index);
                result
                    .effect_events
                    .push(EffectEvent::new(current, sprite, screen_offset, flip, 0, height));
            }
        }

        for offset in SECTION_OFFSETS {
            let point = current + offset;
            let index = point.x * edge + point.y;
            let i = index as usize;
            replace_building(maps.buildings, maps.zones, maps.misc, index, tiles::EMPTY);
            maps.zones[i] = (maps.zones[i] as i64 & zone::TYPE_MASK) as u8;
            maps.flags[i] = (maps.flags[i] as i64 & !flag_bits::FLIPPED & 0xff) as u8;
            points.push(point);
            result.indices.push(index);
        }

        if current == finish {
            break;
        }

        current = current + direction;
    }

    retile_bank_section(
        maps,
        finish + direction,
        random,
        rotation,
        emit_effects,
        scurk_mode,
        &mut points,
        &mut result,
    );
    terrain::retile_surface_water(maps.terrain, maps.flags, selected, true, edge);
    terrain::retile_after_demolition(
        maps.buildings,
        maps.terrain,
        maps.zones,
        maps.underground,
        maps.flags,
        maps.misc,
        &points,
        &[],
        edge,
    );
    result.changed = true;
    result
}

fn demolish_transport_component(
    maps: &mut Maps,
    start: Vec2i,
    random: &mut SimRandom,
    emit_effects: bool,
    scurk_mode: bool,
) -> PointResult {
    let edge = maps.map_edge;
    let tile = maps.buildings[(start.x * edge + start.y) as usize] as i64;
    let (first, last) = if tile <= tiles::RUNWAY_CROSSING {
        (tiles::RUNWAY, tiles::RUNWAY_CROSSING)
    } else {
        (tiles::PIER, tiles::CRANE)
    };
    let make_rubble = first == tiles::RUNWAY;
    let mut stack = vec![start];
    let mut visited = vec![false; (edge * edge) as usize];
    let mut component = Vec::new();

    while let Some(point) = stack.pop() {
        let index = (point.x * edge + point.y) as usize;

        if visited[index] {
            continue;
        }

        visited[index] = true;
        let current = maps.buildings[index] as i64;

        if current < first || current > last {
            continue;
        }

        component.push(point);

        for offset in DIRECTIONS {
            let neighbor = point + offset;

            if in_bounds(neighbor, edge) {
                stack.push(neighbor);
            }
        }
    }

    let mut indices = Vec::new();
    let mut effect_events = Vec::new();

    for &point in &component {
        let index = point.x * edge + point.y;
        let i = index as usize;
        let mut replacement = tiles::EMPTY;

        if make_rubble && !scurk_mode {
            replacement = tiles::RUBBLE_FIRST + (random.next_u15() & 3);
        }

        if emit_effects {
            let height = if make_rubble {
                terrain::land_altitude(maps.altitude, index)
            } else {
                effect_altitude(maps.altitude, maps.flags, index)
            };
            effect_events.push(dust_effect(point, height, random, 0, Vec2i::ZERO));
        }

        replace_building(maps.buildings, maps.zones, maps.misc, index, replacement);
        maps.zones[i] = (maps.zones[i] as i64 & zone::TYPE_MASK) as u8;
        maps.flags[i] = (maps.flags[i] as i64 & FLAG_CLEAR_AFTER_STRUCTURE) as u8;
        indices.push(index);
    }

    terrain::retile_after_demolition(
        maps.buildings,
        maps.terrain,
        maps.zones,
        maps.underground,
        maps.flags,
        maps.misc,
        &component,
        &[],
        edge,
    );

    PointResult {
        changed: !component.is_empty(),
        indices,
        effect_events,
        ..Default::default()
    }
}

fn demolish_highway_section(
    maps: &mut Maps,
    selected: Vec2i,
    random: &mut SimRandom,
    rotation: i64,
    emit_effects: bool,
    scurk_mode: bool,
) -> PointResult {
    let edge = maps.map_edge;
    let anchor = Vec2i::new(selected.x & !1, selected.y & !1);

    if !highway::anchor_is_in_bounds(anchor, edge) {
        return PointResult::specialized();
    }

    for offset in SECTION_OFFSETS {
        let point = anchor + offset;

        if !is_highway_tile(maps.buildings[(point.x * edge + point.y) as usize] as i64) {
            return PointResult::specialized();
        }
    }

    let mut points = Vec::new();
    let mut indices = Vec::new();
    let effect_events = if emit_effects {
        structure_effects(maps.altitude, maps.flags, Rect2i::from(anchor, Vec2i::new(2, 2)), 2, random, edge)
    } else {
        Vec::new()
    };

    for offset in SECTION_OFFSETS {
        let point = anchor + offset;
        let index = point.x * edge + point.y;
        let i = index as usize;
        let mut replacement = tiles::EMPTY;

        if !scurk_mode && maps.terrain[i] as i64 == terrain_ids::FLAT {
            replacement = tiles::RUBBLE_FIRST + (random.next_u15() & 3);
        }

        replace_building(maps.buildings, maps.zones, maps.misc, index, replacement);
        maps.zones[i] = (maps.zones[i] as i64 & zone::TYPE_MASK) as u8;
        maps.flags[i] = (maps.flags[i] as i64 & FLAG_CLEAR_AFTER_STRUCTURE) as u8;
        release_overlay(maps.text_overlays, maps.labels, maps.microsims, index);
        points.push(point);
        indices.push(index);
    }

    terrain::retile_after_demolition(
        maps.buildings,
        maps.terrain,
        maps.zones,
        maps.underground,
        maps.flags,
        maps.misc,
        &points,
        &[],
        edge,
    );
    let mut adjacent_sections = Vec::new();

    for direction in DIRECTIONS {
        let adjacent = anchor + Vec2i::new(direction.x * 2, direction.y * 2);

        if highway::anchor_is_in_bounds(adjacent, edge) && highway::section_kind(maps.buildings, maps.zones, maps.flags, adjacent, edge) > 1
        {
            adjacent_sections.push(adjacent);
        }
    }

    if !adjacent_sections.is_empty() {
        highway::retile_affected_sections(maps, &adjacent_sections, rotation);
    }

    PointResult {
        changed: true,
        indices,
        effect_events,
        ..Default::default()
    }
}

/// Keep the network mode constants reachable for callers of this module.
pub use network::{MODE_POWER, MODE_RAIL, MODE_ROAD};
