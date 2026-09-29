//! Airport, seaport, and military zone growth, as SpecialZoneGrowth,
//! SpecialZoneSelection, SpecialZonePlacement, and SpecialZoneState.

use super::{Counters, has_power};
use crate::sim::bytes::{read_u32_be, write_u32_be};
use crate::sim::events::SoundEvent;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2altitude_layout as altitude_layout;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::ids::underground_tile_ids as under;
use crate::sim::moving::spawner;
use crate::sim::random::SimRandom;
use crate::sim::tools::network::{count_mask, military_count_index};
use crate::sim::tools::set_growth_corners;
use crate::sim::tools::underground::is_subway_tile;

pub const SOUND_SHIP: i64 = 517;
const SPECIAL_SIMPLE_TILES: [i64; 9] = [
    tiles::CONTROL_TOWER_1,
    tiles::CONTROL_TOWER_2,
    tiles::SEAPORT_WAREHOUSE,
    tiles::AIRPORT_BUILDING_1,
    tiles::AIRPORT_BUILDING_2,
    tiles::TARMAC,
    tiles::FIGHTER_JET,
    tiles::HANGAR_1,
    tiles::RADAR,
];
const SPECIAL_TWO_BY_TWO_TILES: [i64; 6] =
    [tiles::PARKING_LOT_1, tiles::PARKING_LOT_2, tiles::LOADING_BAY, tiles::TOP_SECRET, tiles::CARGO_YARD, tiles::HANGAR_2];
const CARDINAL_DIRECTIONS: [Vec2i; 4] = [Vec2i::new(0, 1), Vec2i::new(1, 0), Vec2i::new(0, -1), Vec2i::new(-1, 0)];

/// The maps that special zone growth reads and writes.
pub struct SpecialMaps<'a> {
    pub buildings: &'a mut [u8],
    pub zones: &'a mut [u8],
    pub underground: &'a mut [u8],
    pub flags: &'a mut [u8],
    pub terrain: &'a [u8],
    pub altitude: &'a [u8],
    pub text_overlays: &'a mut [u8],
    pub things: &'a mut [u8],
    pub misc: &'a mut [u8],
    pub rotation: i64,
    pub map_edge: i64,
    pub allow_edge_buildings: bool,
}

#[derive(Clone, Copy, Default)]
pub struct Placement {
    pub ok: bool,
    pub changed_tiles: i64,
}

impl Placement {
    fn failed() -> Self {
        Self::default()
    }

    fn done(changed_tiles: i64) -> Self {
        Self { ok: true, changed_tiles }
    }
}

#[inline]
fn index_of(point: Vec2i, map_edge: i64) -> i64 {
    if point.x < 0 || point.x >= map_edge || point.y < 0 || point.y >= map_edge {
        return -1;
    }

    point.x * map_edge + point.y
}

fn count_offset(tile: i64, military: bool) -> i64 {
    if !military {
        return misc_layout::TILE_COUNTS + tile * 4;
    }

    misc_layout::MILITARY_TILE_COUNTS + military_count_index(tile) * 4
}

/// SpecialZoneState.tile_count.
pub fn tile_count(misc: &[u8], tile: i64, military: bool, map_edge: i64) -> i64 {
    read_u32_be(misc, count_offset(tile, military)) & if map_edge == 128 { 0xffff } else { 0xffff_ffff }
}

/// SpecialZoneState._replace_special_building. Military zones use their own counts.
pub fn replace_special_building(buildings: &mut [u8], zones: &[u8], misc: &mut [u8], index: i64, new_tile: i64) {
    let old_tile = buildings[index as usize] as i64;

    if old_tile == new_tile {
        return;
    }

    let military = zones[index as usize] as i64 & zone::TYPE_MASK == zone::MILITARY;
    let old_offset = count_offset(old_tile, military);
    let new_offset = count_offset(new_tile, military);
    let mask = count_mask(buildings.len());
    let old_count = read_u32_be(misc, old_offset);
    write_u32_be(misc, old_offset, (old_count - 1) & mask);
    let new_count = read_u32_be(misc, new_offset);
    write_u32_be(misc, new_offset, (new_count + 1) & mask);
    buildings[index as usize] = new_tile as u8;
}

fn replace_special_underground(underground: &mut [u8], zones: &[u8], misc: &mut [u8], index: i64, new_tile: i64) {
    let old_tile = underground[index as usize] as i64;

    if old_tile == new_tile {
        return;
    }

    if zones[index as usize] as i64 & zone::TYPE_MASK != zone::MILITARY {
        let mask = count_mask(underground.len());
        let mut count = read_u32_be(misc, misc_layout::SUBWAY_COUNT);

        if is_subway_tile(old_tile) {
            count = (count - 1) & mask;
        }

        if is_subway_tile(new_tile) {
            count = (count + 1) & mask;
        }

        write_u32_be(misc, misc_layout::SUBWAY_COUNT, count);
    }

    underground[index as usize] = new_tile as u8;
}

fn axis_is_flipped(x_delta: i64, rotation: i64) -> bool {
    if x_delta == 0 { rotation & 1 != 0 } else { rotation & 1 == 0 }
}

/// SpecialZoneGrowth.process.
pub fn process(maps: &mut SpecialMaps, point: Vec2i, random: &mut SimRandom, counters: &mut Counters) {
    let edge = maps.map_edge;
    let index = index_of(point, edge);
    let zone_type = crate::sim::bytes::at(maps.zones, index) & 0x0f;
    let current_tile = crate::sim::bytes::at(maps.buildings, index);
    let mut fallback_tile = -1;

    let selected_tile = if zone_type == 7 {
        match read_u32_be(maps.misc, misc_layout::MILITARY_BASE_TYPE) & 0xff {
            2 => {
                if random.next_u15() & 3 != 0 {
                    return;
                }

                let parking_count = tile_count(maps.misc, tiles::PARKING_LOT_2, true, edge) / 4;
                fallback_tile = tiles::HANGAR_1;

                if tile_count(maps.misc, tiles::HANGAR_1, true, edge) / 12 < parking_count {
                    tiles::HANGAR_1
                } else {
                    tiles::PARKING_LOT_2
                }
            }
            3 => airport_selection(maps, point, current_tile, true, random, counters),
            4 => {
                fallback_tile = tiles::SEAPORT_WAREHOUSE;
                seaport_selection(maps, point, current_tile, true, random, counters)
            }
            5 => {
                if current_tile != tiles::MISSILE_SILO {
                    tiles::MISSILE_SILO
                } else {
                    -1
                }
            }
            _ => return,
        }
    } else if zone_type == 8 {
        airport_selection(maps, point, current_tile, false, random, counters)
    } else if zone_type == 9 {
        fallback_tile = tiles::SEAPORT_WAREHOUSE;
        seaport_selection(maps, point, current_tile, false, random, counters)
    } else {
        return;
    };

    if selected_tile < 0 {
        return;
    }

    counters.special_growth_attempts += 1;
    let mut placed = grow_special_zone(maps, point, selected_tile, zone_type);

    if !placed.ok && fallback_tile >= 0 {
        placed = grow_special_zone(maps, point, fallback_tile, zone_type);
    }

    counters.special_tiles_placed += placed.changed_tiles;
}

fn airport_selection(
    maps: &mut SpecialMaps,
    point: Vec2i,
    current_tile: i64,
    military: bool,
    random: &mut SimRandom,
    counters: &mut Counters,
) -> i64 {
    let edge = maps.map_edge;

    if random.next_u15() & 3 != 0 {
        if military || current_tile != tiles::RUNWAY || random.next_u15() % 30 != 0 {
            return -1;
        }

        let index = index_of(point, edge);

        if crate::sim::bytes::at(maps.flags, index) & flag_bits::POWERED == 0 {
            return -1;
        }

        if random.next_u15() % 10 < 4 {
            let helicopter = spawner::spawn_helicopter(maps.things, maps.text_overlays, point, random, edge);

            if helicopter.spawned {
                counters.spawned_helicopters += 1;
            }
        } else {
            let flipped = crate::sim::bytes::at(maps.flags, index) & flag_bits::FLIPPED != 0;
            let runway_axis = if flipped != (maps.rotation & 1 != 0) { 2 } else { 0 };
            let airplane = spawner::spawn_airplane(maps.things, maps.text_overlays, point, runway_axis, random, edge);

            if airplane.spawned {
                counters.spawned_airplanes += 1;
            }
        }

        return -1;
    }

    let misc = &*maps.misc;
    let count = |tile: i64| tile_count(misc, tile, military, edge);
    let runway_groups = (count(tiles::RUNWAY) + count(tiles::RUNWAY_CROSSING)) / 5;
    let parking_tile = if military { tiles::PARKING_LOT_2 } else { tiles::PARKING_LOT_1 };

    if count(parking_tile) / 4 >= runway_groups {
        return tiles::RUNWAY;
    }

    let tower = if military { tiles::CONTROL_TOWER_2 } else { tiles::CONTROL_TOWER_1 };

    if count(tower) * 2 < runway_groups {
        return tower;
    }

    if count(tiles::RADAR) * 2 < runway_groups {
        return tiles::RADAR;
    }

    let apron = if military { tiles::FIGHTER_JET } else { tiles::TARMAC };

    if count(apron) < runway_groups {
        return apron;
    }

    if count(tiles::AIRPORT_BUILDING_1) / 2 < runway_groups {
        return tiles::AIRPORT_BUILDING_1;
    }

    if count(tiles::AIRPORT_BUILDING_2) / 2 < runway_groups {
        return tiles::AIRPORT_BUILDING_2;
    }

    if count(tiles::HANGAR_2) / 4 < runway_groups {
        return tiles::HANGAR_2;
    }

    parking_tile
}

fn seaport_selection(
    maps: &mut SpecialMaps,
    point: Vec2i,
    current_tile: i64,
    military: bool,
    random: &mut SimRandom,
    counters: &mut Counters,
) -> i64 {
    let edge = maps.map_edge;

    if random.next_u15() & 3 != 0 {
        if !military && current_tile == tiles::CRANE && random.next_u15() & 3 == 0 {
            let ship = spawner::spawn_ship(maps.terrain, maps.things, maps.text_overlays, point, random, edge);

            if ship.spawned {
                counters.spawned_ships += 1;
                counters.ship_home_found = true;
                counters.ship_home = ship.point;
                counters.sound_events.push(SoundEvent::for_thing(SOUND_SHIP, 3, ship.record, ship.point));
            }
        }

        return -1;
    }

    let misc = &*maps.misc;
    let count = |tile: i64| tile_count(misc, tile, military, edge);
    let crane_count = count(tiles::CRANE);

    if count(tiles::CARGO_YARD) / 4 >= crane_count {
        return tiles::CRANE;
    }

    let second_tile = if military { tiles::TOP_SECRET } else { tiles::LOADING_BAY };

    if count(second_tile) / 4 < crane_count {
        return second_tile;
    }

    if count(tiles::SEAPORT_WAREHOUSE) / 3 < crane_count {
        return tiles::SEAPORT_WAREHOUSE;
    }

    tiles::CARGO_YARD
}

pub fn grow_special_zone(maps: &mut SpecialMaps, point: Vec2i, tile: i64, zone_type: i64) -> Placement {
    let edge = maps.map_edge;

    if zone_type != 7 && !has_power(maps.flags, point.x, point.y, edge) {
        return Placement::failed();
    }

    if tile == tiles::RUNWAY {
        return place_runway(maps, point, zone_type);
    }

    if tile == tiles::CRANE {
        return place_crane_and_pier(maps, point, zone_type);
    }

    if SPECIAL_SIMPLE_TILES.contains(&tile) {
        let index = index_of(point, edge);
        let before = crate::sim::bytes::at(maps.buildings, index);

        if before < 0x0d {
            place_special_item(maps, point, tile, 1, zone_type, false);
            let i = crate::sim::bytes::slot(maps.zones.len(), index);
            maps.zones[i] = ((maps.zones[i] as i64 & zone::CORNERS_MASK) | zone_type) as u8;

            if zone_type == 7 {
                maps.flags[i] = (maps.flags[i] as i64 & !flag_bits::UTILITY_MASK & 0xff) as u8;
            }
        }

        let after = crate::sim::bytes::at(maps.buildings, index);

        return Placement::done((after != before) as i64);
    }

    if SPECIAL_TWO_BY_TWO_TILES.contains(&tile) {
        return place_special_two_by_two(maps, point, tile, zone_type);
    }

    if tile == tiles::MISSILE_SILO {
        return place_missile_silo(maps, point, zone_type);
    }

    Placement::done(0)
}

fn place_runway(maps: &mut SpecialMaps, point: Vec2i, zone_type: i64) -> Placement {
    let edge = maps.map_edge;
    // Military runway orientation uses its own count, as in sc2kfix.
    let count = tile_count(maps.misc, tiles::RUNWAY, zone_type == 7, edge);

    let direction = if count & 1 == 0 {
        if point.x & 1 != 0 {
            Vec2i::new(0, 1)
        } else if point.y & 1 != 0 {
            Vec2i::new(1, 0)
        } else {
            return Placement::failed();
        }
    } else if point.y & 1 != 0 {
        Vec2i::new(1, 0)
    } else if point.x & 1 != 0 {
        Vec2i::new(0, 1)
    } else {
        return Placement::failed();
    };

    let mut new_tiles = 0;
    let mut checked = point;

    while index_of(checked, edge) >= 0 {
        let checked_index = index_of(checked, edge) as usize;

        if maps.zones[checked_index] as i64 & zone::TYPE_MASK != zone_type {
            return Placement::failed();
        }

        if zone_type == 7 {
            let tile = maps.buildings[checked_index] as i64;

            if (tiles::FIRST_ROAD..=tiles::LAST_ROAD).contains(&tile) || tile == tiles::CRANE || tile == tiles::MISSILE_SILO {
                return Placement::failed();
            }

            if (!maps.terrain.is_empty() && maps.terrain[checked_index] as i64 != terrain_ids::FLAT)
                || (!maps.underground.is_empty() && maps.underground[checked_index] as i64 != under::EMPTY)
            {
                return Placement::failed();
            }
        }

        let tile = maps.buildings[checked_index] as i64;

        if tile == tiles::RUNWAY || tile == tiles::RUNWAY_CROSSING {
            new_tiles -= 1;
        }

        new_tiles += 1;
        checked = checked + direction;

        if new_tiles >= 5 {
            break;
        }
    }

    if new_tiles < 5 {
        return Placement::failed();
    }

    let flip = axis_is_flipped(direction.x, maps.rotation);
    let mut changed_tiles = 0;
    let mut placed_tiles = 0;
    let mut current = point;

    while placed_tiles < 5 {
        let index = index_of(current, edge);
        let i = crate::sim::bytes::slot(maps.buildings.len(), index);
        let current_tile = maps.buildings[i] as i64;

        if current_tile == tiles::RUNWAY || current_tile == tiles::RUNWAY_CROSSING {
            placed_tiles -= 1;

            if current_tile == tiles::RUNWAY && (maps.flags[i] as i64 & flag_bits::FLIPPED != 0) != flip {
                replace_special_building(maps.buildings, maps.zones, maps.misc, i as i64, tiles::RUNWAY_CROSSING);
                maps.zones[i] = (maps.zones[i] as i64 | zone::CORNERS_MASK) as u8;

                if zone_type != 7 {
                    maps.flags[i] = (maps.flags[i] as i64 | flag_bits::POWER_MASK) as u8;
                }

                maps.flags[i] = (maps.flags[i] as i64 & !flag_bits::FLIPPED & 0xff) as u8;
                changed_tiles += 1;
            }
        } else {
            clear_special_building(maps, current);
            replace_special_building(maps.buildings, maps.zones, maps.misc, i as i64, tiles::RUNWAY);
            maps.zones[i] = (maps.zones[i] as i64 | zone::CORNERS_MASK) as u8;

            if zone_type != 7 {
                maps.flags[i] = (maps.flags[i] as i64 | flag_bits::POWER_MASK) as u8;
            }

            if flip {
                maps.flags[i] = (maps.flags[i] as i64 | flag_bits::FLIPPED) as u8;
            }

            changed_tiles += 1;
        }

        placed_tiles += 1;
        current = current + direction;
    }

    Placement::done(changed_tiles)
}

fn place_crane_and_pier(maps: &mut SpecialMaps, point: Vec2i, zone_type: i64) -> Placement {
    let edge = maps.map_edge;
    let mut direction = Vec2i::ZERO;

    for candidate in CARDINAL_DIRECTIONS {
        let neighbor_index = index_of(point + candidate, edge);

        if neighbor_index >= 0 && maps.flags[neighbor_index as usize] as i64 & flag_bits::WATER != 0 {
            direction = candidate;
            break;
        }
    }

    if direction == Vec2i::ZERO {
        return Placement::failed();
    }

    if (direction.y != 0 && point.x & 1 != 0) || (direction.x != 0 && point.y & 1 != 0) {
        return Placement::failed();
    }

    let mut checked = point;

    for _ in 0..5 {
        checked = checked + direction;
        let index = index_of(checked, edge);

        if index < 0
            || maps.flags[index as usize] as i64 & flag_bits::WATER == 0
            || maps.buildings[index as usize] as i64 != tiles::EMPTY
        {
            return Placement::failed();
        }
    }

    let last = index_of(checked, edge);
    let last_word =
        ((maps.altitude[(last * 2) as usize] as i64) << 8) | maps.altitude[(last * 2 + 1) as usize] as i64;

    if ((last_word & altitude_layout::WATER_MASK) >> altitude_layout::WATER_SHIFT)
        < (last_word & altitude_layout::LEVEL_MASK) + 2
    {
        return Placement::failed();
    }

    clear_special_building(maps, point);
    let index = index_of(point, edge);
    let i = crate::sim::bytes::slot(maps.buildings.len(), index);
    let before = maps.buildings[i] as i64;
    place_special_item(maps, point, tiles::CRANE, 1, zone_type, false);
    maps.zones[i] = ((maps.zones[i] as i64 & zone::CORNERS_MASK) | zone_type) as u8;

    if zone_type == 7 {
        maps.flags[i] = (maps.flags[i] as i64 & !flag_bits::UTILITY_MASK & 0xff) as u8;
    }

    let mut changed_tiles = (maps.buildings[i] as i64 != before) as i64;
    let flip = axis_is_flipped(direction.x, maps.rotation);
    let mut pier = point;

    for _ in 0..4 {
        pier = pier + direction;
        let pier_index = index_of(pier, edge);
        replace_special_building(maps.buildings, maps.zones, maps.misc, pier_index, tiles::PIER);
        let p = pier_index as usize;
        maps.zones[p] = (maps.zones[p] as i64 | zone::CORNERS_MASK) as u8;

        if flip {
            maps.flags[p] = (maps.flags[p] as i64 | flag_bits::FLIPPED) as u8;
        }

        changed_tiles += 1;
    }

    Placement::done(changed_tiles)
}

fn place_special_two_by_two(maps: &mut SpecialMaps, point: Vec2i, tile: i64, zone_type: i64) -> Placement {
    let edge = maps.map_edge;
    let anchor = Vec2i::new(point.x & !1, point.y & !1);

    if anchor.x < 0 || anchor.y < 0 || anchor.x >= edge - 1 || anchor.y >= edge - 1 {
        return Placement::failed();
    }

    let points = [anchor, anchor + Vec2i::new(1, 0), anchor + Vec2i::new(0, 1), anchor + Vec2i::new(1, 1)];

    for (point_index, checked) in points.iter().enumerate() {
        let index = index_of(*checked, edge) as usize;
        let checked_tile = maps.buildings[index] as i64;

        if checked_tile == tiles::RUNWAY || checked_tile == tiles::RUNWAY_CROSSING || checked_tile == tiles::CRANE {
            return Placement::failed();
        }

        // The original checks 0xeb..0xff only at the anchor.
        if point_index == 0 && checked_tile > tiles::RADAR {
            return Placement::failed();
        }

        if maps.zones[index] as i64 & zone::TYPE_MASK != zone_type {
            return Placement::failed();
        }
    }

    // Clear structures before the common placement checks. A failed placement
    // keeps these changes and still reports success, as in the original.
    for checked in points {
        clear_special_building(maps, checked);
    }

    let before: Vec<i64> = points.iter().map(|checked| maps.buildings[index_of(*checked, edge) as usize] as i64).collect();
    let allow_edge = maps.allow_edge_buildings;
    place_special_item(maps, anchor, tile, 2, zone_type, allow_edge);

    for checked in points {
        let i = index_of(checked, edge) as usize;
        maps.zones[i] = ((maps.zones[i] as i64 & zone::CORNERS_MASK) | zone_type) as u8;

        if zone_type == 7 {
            maps.flags[i] = (maps.flags[i] as i64 & !flag_bits::UTILITY_MASK & 0xff) as u8;
        }
    }

    let mut changed_tiles = 0;

    for (position, checked) in points.iter().enumerate() {
        let i = index_of(*checked, edge) as usize;
        changed_tiles += (maps.buildings[i] as i64 != before[position]) as i64;
    }

    Placement::done(changed_tiles)
}

/// SpecialZonePlacement.place_special_item.
fn place_special_item(maps: &mut SpecialMaps, anchor: Vec2i, tile: i64, area: i64, zone_type: i64, allow_edge_buildings: bool) -> bool {
    let edge = maps.map_edge;
    let origin = if area > 2 { anchor - Vec2i::new(1, 1) } else { anchor };
    let mut points = Vec::new();

    for x in origin.x..origin.x + area {
        for y in origin.y..origin.y + area {
            let point = Vec2i::new(x, y);
            let index = index_of(point, edge);

            if index < 0 || (!allow_edge_buildings && area > 1 && (x < 1 || y < 1 || x > edge - 2 || y > edge - 2)) {
                return false;
            }

            let i = index as usize;
            let building = maps.buildings[i] as i64;

            if building >= tiles::FIRST_ROAD || building == tiles::RADIOACTIVE_WASTE || building == tiles::SMALL_PARK {
                return false;
            }

            if maps.zones[i] as i64 & zone::TYPE_MASK == 7 && zone_type != 7 {
                return false;
            }

            if maps.terrain[i] as i64 != terrain_ids::FLAT || maps.flags[i] as i64 & flag_bits::WATER != 0 {
                return false;
            }

            points.push(point);
        }
    }

    for &point in &points {
        let index = index_of(point, edge);
        let i = index as usize;
        maps.flags[i] = ((maps.flags[i] as i64 & !flag_bits::STRUCTURE_MASK & 0xff) | flag_bits::STRUCTURE_MASK) as u8;
        replace_special_building(maps.buildings, maps.zones, maps.misc, index, tile);
        maps.zones[i] = 0;
    }

    if area == 1 {
        let i = crate::sim::bytes::slot(maps.zones.len(), index_of(origin, edge));
        maps.zones[i] = (maps.zones[i] as i64 | zone::CORNERS_MASK) as u8;
    } else {
        set_growth_corners(maps.zones, origin, area, maps.rotation, edge);
    }

    for &point in &points {
        let i = index_of(point, edge) as usize;
        maps.zones[i] = ((maps.zones[i] as i64 & zone::CORNERS_MASK) | zone_type) as u8;
    }

    true
}

fn place_missile_silo(maps: &mut SpecialMaps, point: Vec2i, zone_type: i64) -> Placement {
    let edge = maps.map_edge;
    let mut origin = point;

    for _ in 0..2 {
        let left = origin + Vec2i::new(-1, 0);
        let index = index_of(left, edge);

        if index >= 0 && maps.zones[index as usize] as i64 & zone::TYPE_MASK == zone_type {
            origin = left;
        }
    }

    for _ in 0..2 {
        let upper = origin + Vec2i::new(0, -1);
        let index = index_of(upper, edge);

        if index >= 0 && maps.zones[index as usize] as i64 & zone::TYPE_MASK == zone_type {
            origin = upper;
        }
    }

    if origin.x < 0 || origin.y < 0 || origin.x > edge - 3 || origin.y > edge - 3 {
        return Placement::failed();
    }

    let mut changed_tiles = 0;

    for x in origin.x..origin.x + 3 {
        for y in origin.y..origin.y + 3 {
            let index = x * edge + y;

            if maps.buildings[index as usize] as i64 != tiles::MISSILE_SILO {
                changed_tiles += 1;
            }

            replace_special_building(maps.buildings, maps.zones, maps.misc, index, tiles::MISSILE_SILO);
            replace_special_underground(maps.underground, maps.zones, maps.misc, index, under::MISSILE_SILO);
        }
    }

    set_growth_corners(maps.zones, origin, 3, maps.rotation, edge);

    Placement::done(changed_tiles)
}

fn clear_special_building(maps: &mut SpecialMaps, point: Vec2i) {
    let edge = maps.map_edge;
    let selected = index_of(point, edge);

    if selected < 0 || maps.buildings[selected as usize] as i64 <= tiles::DEVELOPED_3X3_LAST {
        return;
    }

    let tile = maps.buildings[selected as usize] as i64;
    let points: Vec<Vec2i> = if !(tiles::STATUE..=tiles::RADAR).contains(&tile) {
        let anchor = Vec2i::new(point.x & !1, point.y & !1);
        vec![anchor, anchor + Vec2i::new(1, 0), anchor + Vec2i::new(0, 1), anchor + Vec2i::new(1, 1)]
    } else {
        vec![point]
    };

    for cleared in points {
        let index = index_of(cleared, edge);

        if index < 0 {
            continue;
        }

        let i = index as usize;
        replace_special_building(maps.buildings, maps.zones, maps.misc, index, tiles::EMPTY);
        maps.flags[i] = (maps.flags[i] as i64 & !flag_bits::POWER_MASK & 0xff) as u8;
        maps.zones[i] = (maps.zones[i] as i64 & zone::TYPE_MASK) as u8;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::city::City;
    use crate::sim::testing::empty_city;

    const MAP_SIZES: [i64; 9] = [16, 32, 64, 128, 256, 384, 512, 640, 1024];

    fn fixture(edge: i64) -> City {
        let mut city = empty_city(edge);
        city.xzon.data.fill(7);
        write_u32_be(&mut city.misc.data, misc_layout::TILE_COUNTS, 0);
        write_u32_be(&mut city.misc.data, misc_layout::MILITARY_TILE_COUNTS, edge * edge);
        city
    }

    fn maps(city: &mut City, rotation: i64) -> SpecialMaps<'_> {
        let map_edge = city.map_size;
        let City { xbld, xzon, xund, xbit, xter, altm, xtxt, xthg, misc, .. } = city;

        SpecialMaps {
            buildings: &mut xbld.data,
            zones: &mut xzon.data,
            underground: &mut xund.data,
            flags: &mut xbit.data,
            terrain: &xter.data,
            altitude: &altm.data,
            text_overlays: &mut xtxt.data,
            things: &mut xthg.data,
            misc: &mut misc.data,
            rotation,
            map_edge,
            allow_edge_buildings: false,
        }
    }

    fn state(city: &City) -> Vec<Vec<u8>> {
        [&city.xbld, &city.xzon, &city.xund, &city.xbit, &city.xter, &city.misc].iter().map(|chunk| chunk.data.clone()).collect()
    }

    #[test]
    fn military_buildings_grow_at_the_far_map_edge() {
        for edge in MAP_SIZES {
            let base = fixture(edge);

            for rotation in 0..4 {
                for tile in
                    [tiles::CONTROL_TOWER_2, tiles::SEAPORT_WAREHOUSE, tiles::HANGAR_1, tiles::PARKING_LOT_2, tiles::TOP_SECRET, tiles::CARGO_YARD]
                {
                    let mut city = base.clone();
                    let point = Vec2i::new(edge - 12, edge - 12);
                    let result = grow_special_zone(&mut maps(&mut city, rotation), point, tile, 7);
                    let expected = if [0xef, 0xf1, 0xf2].contains(&tile) { 4 } else { 1 };
                    assert!(result.ok && result.changed_tiles == expected, "military tile {tile} grows at edge {edge}");
                    let index = (point.x * edge + point.y) as usize;
                    assert_eq!(city.xbld.data[index] as i64, tile);
                    assert_eq!(city.xzon.data[index] & 15, 7, "the military zone survives growth");
                    assert_eq!(tile_count(&city.misc.data, tile, true, edge), result.changed_tiles);
                    assert_eq!(tile_count(&city.misc.data, tile, false, edge), 0, "the civilian count stays separate");
                }

                let mut city = base.clone();
                let point = Vec2i::new(edge - 11, edge - 11);
                write_u32_be(&mut city.misc.data, misc_layout::TILE_COUNTS + tiles::RUNWAY * 4, 1);
                let runway = grow_special_zone(&mut maps(&mut city, rotation), point, tiles::RUNWAY, 7);
                assert!(runway.ok && runway.changed_tiles == 5, "a military runway grows");
                assert_eq!(city.xbld.data[(point.x * edge + point.y + 4) as usize] as i64, tiles::RUNWAY, "military parity ignores the civilian runway count");
            }
        }
    }

    #[test]
    fn two_by_two_military_rules() {
        let base = fixture(128);
        let point = Vec2i::new(2, 2);
        let anchor = 2 * 128 + 2;
        let other = 3 * 128 + 2;
        let aircraft = 3 * 128 + 3;

        // Each original footprint restriction rejects before it clears anything.
        for tile in [tiles::RUNWAY, tiles::RUNWAY_CROSSING, tiles::CRANE] {
            for offset in [0, 1, 128, 129] {
                let mut city = base.clone();
                city.xbld.data[anchor + offset] = tile as u8;
                let before = state(&city);
                assert!(!grow_special_zone(&mut maps(&mut city, 0), point, tiles::PARKING_LOT_2, 7).ok);
                assert_eq!(state(&city), before, "the original obstruction prevents all writes");
            }
        }

        for offset in [0, 1, 128, 129] {
            let mut city = base.clone();
            city.xzon.data[anchor + offset] = 8;
            let before = state(&city);
            assert!(!grow_special_zone(&mut maps(&mut city, 0), point, tiles::PARKING_LOT_2, 7).ok, "every cell has the same zone");
            assert_eq!(state(&city), before);
        }

        let mut blocked = base.clone();
        blocked.xbld.data[anchor] = tiles::MISSILE_SILO as u8;
        assert!(!grow_special_zone(&mut maps(&mut blocked, 0), point, tiles::PARKING_LOT_2, 7).ok, "a high building ID blocks the anchor");

        // Extra military guards do not suppress clearing or change the fallback.
        for obstruction in [tiles::FIRST_ROAD, tiles::RADIOACTIVE_WASTE, tiles::SMALL_PARK, tiles::MISSILE_SILO, -1, -2, -3] {
            let mut city = base.clone();
            replace_special_building(&mut city.xbld.data, &city.xzon.data, &mut city.misc.data, aircraft as i64, tiles::FIGHTER_JET);
            city.xbit.data[aircraft] = 0xf3;
            city.xzon.data[aircraft] = 0xf7;

            match obstruction {
                -1 => city.xund.data[other] = under::PIPE_LR as u8,
                -2 => city.xter.data[other] = 1,
                -3 => city.xbit.data[other] = flag_bits::WATER as u8,
                _ => replace_special_building(&mut city.xbld.data, &city.xzon.data, &mut city.misc.data, other as i64, obstruction),
            }

            let underground = city.xund.data.clone();
            let terrain = city.xter.data.clone();
            write_u32_be(&mut city.misc.data, misc_layout::MILITARY_BASE_TYPE, 2);
            let mut counters = Counters::default();
            process(&mut maps(&mut city, 0), point, &mut SimRandom::new(3), &mut counters);
            let placed = obstruction == -1 || obstruction == tiles::MISSILE_SILO;
            let expected = if placed { tiles::PARKING_LOT_2 } else { tiles::EMPTY };
            assert_eq!(city.xbld.data[anchor] as i64, expected, "army growth keeps its outcome without a hangar fallback");
            assert_eq!(city.xbld.data[aircraft] as i64, expected, "clearing removes the existing aircraft");
            assert_eq!(tile_count(&city.misc.data, tiles::FIGHTER_JET, true, 128), 0);
            assert_eq!(tile_count(&city.misc.data, tiles::PARKING_LOT_2, true, 128), if placed { 4 } else { 0 });
            assert_eq!(city.xbit.data[aircraft], 3, "processing clears utility flags and keeps low flags");
            assert_eq!(city.xzon.data[aircraft] & 15, 7);
            assert!(city.xund.data == underground && city.xter.data == terrain, "growth keeps underground and terrain");

            if [tiles::FIRST_ROAD, tiles::RADIOACTIVE_WASTE, tiles::SMALL_PARK].contains(&obstruction) {
                assert_eq!(city.xbld.data[other] as i64, obstruction, "common placement rejects road, radiation, or park");
            }
        }
    }

    #[test]
    fn simple_military_tiles_keep_their_utility_flag_rules() {
        let base = fixture(128);
        let point = Vec2i::new(2, 2);
        let index = 2 * 128 + 2;

        for tile in [tiles::SMALL_PARK, tiles::FIRST_ROAD, tiles::RUNWAY, tiles::CONTROL_TOWER_2, tiles::MISSILE_SILO] {
            let mut city = base.clone();
            city.xbld.data[index] = tile as u8;
            city.xbit.data[index] = 0xf3;
            city.xzon.data[index] = 0xf7;
            let before = state(&city);
            let result = grow_special_zone(&mut maps(&mut city, 0), point, tiles::CONTROL_TOWER_2, 7);
            assert!(result.ok && result.changed_tiles == 0, "a blocked one-cell attempt reports success");
            assert_eq!(state(&city), before, "a blocked one-cell attempt keeps all state");
        }

        for tile in [tiles::EMPTY, tiles::RADIOACTIVE_WASTE, tiles::TREE_LAST] {
            let mut city = base.clone();
            city.xbld.data[index] = tile as u8;
            city.xbit.data[index] = 0xf3;
            let result = grow_special_zone(&mut maps(&mut city, 0), point, tiles::CONTROL_TOWER_2, 7);
            let placed = tile != tiles::RADIOACTIVE_WASTE;
            assert!(result.ok && result.changed_tiles == placed as i64);
            assert_eq!(city.xbld.data[index] as i64, if placed { tiles::CONTROL_TOWER_2 } else { tile });
            assert_eq!(city.xbit.data[index], 3, "an eligible one-cell attempt clears utility flags");
        }
    }
}

#[cfg(test)]
mod edge_tests {
    use super::*;
    use crate::sim::city::City;
    use crate::sim::testing::empty_city;

    fn maps(city: &mut City, rotation: i64) -> SpecialMaps<'_> {
        let map_edge = city.map_size;
        let City { xbld, xzon, xund, xbit, xter, altm, xtxt, xthg, misc, .. } = city;

        SpecialMaps {
            buildings: &mut xbld.data,
            zones: &mut xzon.data,
            underground: &mut xund.data,
            flags: &mut xbit.data,
            terrain: &xter.data,
            altitude: &altm.data,
            text_overlays: &mut xtxt.data,
            things: &mut xthg.data,
            misc: &mut misc.data,
            rotation,
            map_edge,
            allow_edge_buildings: false,
        }
    }

    #[test]
    fn special_zones_reach_the_far_interior() {
        for edge in [128i64, 256, 384, 512, 640, 1024] {
            let mut city = empty_city(edge);
            write_u32_be(&mut city.misc.data, misc_layout::SUBWAY_COUNT, 65535);
            let last = edge * edge - 1;
            replace_special_underground(&mut city.xund.data, &city.xzon.data, &mut city.misc.data, last, 1);
            let wide = if edge == 128 { 0 } else { 65536 };
            assert_eq!(read_u32_be(&city.misc.data, misc_layout::SUBWAY_COUNT), wide, "special growth keeps a wide subway count");
            replace_special_underground(&mut city.xund.data, &city.xzon.data, &mut city.misc.data, last, 0);
            assert_eq!(read_u32_be(&city.misc.data, misc_layout::SUBWAY_COUNT), 65535, "special growth subway decrement");

            for area in [2, 3] {
                for rotation in 0..4 {
                    let mut city = empty_city(edge);
                    let anchor = Vec2i::new(edge - 3, edge - 3);
                    assert!(place_special_item(&mut maps(&mut city, rotation), anchor, 0xdc, area, 8, false), "a far special footprint");
                    let mut city = empty_city(edge);
                    let outside = Vec2i::new(edge - 2, edge - 2);
                    assert!(!place_special_item(&mut maps(&mut city, rotation), outside, 0xdc, area, 8, false), "the special-zone edge margin");
                }
            }

            for origin in [Vec2i::new(edge - 3, edge - 3), Vec2i::new(edge - 2, edge - 2)] {
                let mut city = empty_city(edge);
                let result = place_missile_silo(&mut maps(&mut city, 0), origin, 7);
                assert_eq!(result.ok, origin.x == edge - 3, "a silo fits exactly at the map edge");
                assert_eq!(result.changed_tiles, if result.ok { 9 } else { 0 });
            }
        }
    }
}
