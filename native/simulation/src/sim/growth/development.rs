//! Zone buildings: placement, abandonment, density, and construction, as
//! GrowthDevelopment and GrowthConstruction.

use super::replace_building;
use crate::sim::geom::{Rect2i, Vec2i};
use crate::sim::grid;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2altitude_layout as altitude_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::random::SimRandom;
use crate::sim::tools::set_growth_corners;

pub const STATUS_NORMAL: i64 = 0;
pub const STATUS_CONSTRUCTION: i64 = 1;
pub const STATUS_ABANDONED: i64 = 2;
pub const CLASS_RESIDENTIAL: i64 = 0;
pub const CLASS_CONSTRUCTION: i64 = 3;
pub const CLASS_ABANDONED: i64 = 4;

const BUILDING_BASE: [i64; 21] = [
    0,
    tiles::DEVELOPED_FIRST,
    tiles::RESIDENTIAL_2X2_FIRST,
    tiles::RESIDENTIAL_2X2_DENSE_FIRST,
    tiles::RESIDENTIAL_3X3_FIRST,
    tiles::COMMERCIAL_1X1_FIRST,
    tiles::COMMERCIAL_2X2_FIRST,
    tiles::COMMERCIAL_2X2_DENSE_FIRST,
    tiles::COMMERCIAL_3X3_FIRST,
    tiles::INDUSTRIAL_1X1_FIRST,
    tiles::INDUSTRIAL_2X2_FIRST,
    tiles::INDUSTRIAL_2X2_DENSE_FIRST,
    tiles::INDUSTRIAL_3X3_FIRST,
    tiles::CONSTRUCTION_1X1_FIRST,
    tiles::CONSTRUCTION_2X2_FIRST,
    tiles::CONSTRUCTION_2X2_DENSE_FIRST,
    tiles::CONSTRUCTION_3X3_FIRST,
    tiles::ABANDONED_1X1_FIRST,
    tiles::ABANDONED_2X2_FIRST,
    tiles::ABANDONED_2X2_DENSE_FIRST,
    tiles::ABANDONED_3X3_FIRST,
];
const BUILDING_RANGE: [i64; 21] = [196, 12, 4, 4, 4, 8, 5, 5, 10, 4, 4, 4, 6, 2, 2, 2, 2, 2, 2, 2, 2];

/// The zone maps that growth writes.
pub struct ZoneMaps<'a> {
    pub buildings: &'a mut [u8],
    pub zones: &'a mut [u8],
    pub flags: &'a mut [u8],
    pub misc: &'a mut [u8],
    pub land_value: &'a [u8],
    pub altitude: &'a [u8],
    pub rotation: i64,
    pub map_edge: i64,
    pub allow_edge_buildings: bool,
}

#[inline]
fn index_of(point: Vec2i, map_edge: i64) -> i64 {
    if point.x < 0 || point.x >= map_edge || point.y < 0 || point.y >= map_edge {
        return -1;
    }

    point.x * map_edge + point.y
}

pub fn density(tile: i64) -> i64 {
    if tile <= tiles::DEVELOPED_1X1_LAST {
        1
    } else if tile <= tiles::NICE_APARTMENTS_2X2_1 {
        2
    } else if tile <= tiles::RESIDENTIAL_2X2_LAST {
        3
    } else if tile <= tiles::OFFICE_BUILDING_2X2_2 {
        2
    } else if tile <= tiles::COMMERCIAL_2X2_LAST {
        3
    } else if tile <= tiles::FACTORY_2X2_2 {
        2
    } else if tile <= tiles::INDUSTRIAL_2X2_LAST {
        3
    } else if tile <= tiles::CONSTRUCTION_2X2_2 {
        2
    } else if tile <= tiles::CONSTRUCTION_2X2_LAST {
        3
    } else if tile <= tiles::ABANDONED_2X2_2 {
        2
    } else if tile <= tiles::DEVELOPED_2X2_LAST {
        3
    } else {
        4
    }
}

pub fn status(tile: i64) -> i64 {
    if (tiles::CONSTRUCTION_1X1_FIRST..=tiles::CONSTRUCTION_1X1_LAST).contains(&tile)
        || (tiles::CONSTRUCTION_2X2_FIRST..=tiles::CONSTRUCTION_2X2_LAST).contains(&tile)
        || (tiles::CONSTRUCTION_3X3_FIRST..=tiles::CONSTRUCTION_3X3_LAST).contains(&tile)
    {
        return STATUS_CONSTRUCTION;
    }

    if (tiles::ABANDONED_1X1_FIRST..=tiles::DEVELOPED_1X1_LAST).contains(&tile)
        || (tiles::ABANDONED_2X2_FIRST..=tiles::DEVELOPED_2X2_LAST).contains(&tile)
        || (tiles::ABANDONED_3X3_FIRST..=tiles::DEVELOPED_3X3_LAST).contains(&tile)
    {
        return STATUS_ABANDONED;
    }

    STATUS_NORMAL
}

/// GrowthDevelopment.place_zone.
pub fn place_zone(maps: &mut ZoneMaps, anchor: Vec2i, zone_density: i64, building_class: i64, random: &mut SimRandom) -> bool {
    let edge = maps.map_edge;
    let tile;

    if zone_density == 1 && building_class == CLASS_RESIDENTIAL {
        let value_index = grid::index(maps.land_value, edge, anchor.x, anchor.y);
        let value_group = (crate::sim::bytes::at(maps.land_value, value_index) >> 6).min(2);
        tile = BUILDING_BASE[1] + value_group * 4 + (random.next_u15() & 3);
    } else {
        let table_index = (zone_density + building_class * 4) as usize;
        tile = BUILDING_BASE[table_index] + random.next_u15() % BUILDING_RANGE[table_index];
    }

    if zone_density == 1 {
        let index = index_of(anchor, edge);

        if index < 0 {
            return false;
        }

        let i = index as usize;
        replace_building(maps.buildings, maps.zones, maps.misc, index, tile);
        maps.zones[i] = (maps.zones[i] as i64 | zone::CORNERS_MASK) as u8;
        maps.flags[i] = (maps.flags[i] as i64 | flag_bits::STRUCTURE_MASK) as u8;

        return true;
    }

    let radius = zone_density / 2;
    let site_position = Vec2i::new(anchor.x, anchor.y - radius);

    if maps.allow_edge_buildings {
        let site = Rect2i::from(site_position, Vec2i::new(radius + 1, radius + 1));

        if !Rect2i::new(0, 0, edge, edge).encloses(&site) {
            return false;
        }
    } else if anchor.x <= 1 || anchor.y <= 1 || anchor.x > edge - 2 - radius || anchor.y > edge - 2 - radius {
        return false;
    }

    for x in site_position.x..site_position.x + radius + 1 {
        for y in site_position.y..site_position.y + radius + 1 {
            let index = x * edge + y;
            let i = index as usize;
            replace_building(maps.buildings, maps.zones, maps.misc, index, tile);
            maps.zones[i] = (maps.zones[i] as i64 & zone::TYPE_MASK) as u8;
            maps.flags[i] = (maps.flags[i] as i64 | flag_bits::STRUCTURE_MASK) as u8;
        }
    }

    set_growth_corners(maps.zones, site_position, radius + 1, maps.rotation, edge);

    true
}

/// GrowthDevelopment._abandon.
pub fn abandon(maps: &mut ZoneMaps, point: Vec2i, zone_density: i64, pattern: i64, random: &mut SimRandom) {
    match zone_density {
        1 => {
            place_zone(maps, point, 1, CLASS_ABANDONED, random);
        }
        2 => {
            if pattern == 0 {
                place_zone(maps, point, 2, CLASS_ABANDONED, random);
            } else {
                for offset in [Vec2i::new(0, 0), Vec2i::new(1, 0), Vec2i::new(1, -1), Vec2i::new(0, -1)] {
                    place_zone(maps, point + offset, 1, CLASS_ABANDONED, random);
                }
            }
        }
        3 => {
            place_zone(maps, point, if pattern == 0 { 3 } else { 2 }, CLASS_ABANDONED, random);
        }
        4 => {
            if pattern == 0 {
                place_zone(maps, point, 4, CLASS_ABANDONED, random);
            } else {
                for offset in [
                    Vec2i::new(0, 0),
                    Vec2i::new(1, 0),
                    Vec2i::new(2, 0),
                    Vec2i::new(2, -1),
                    Vec2i::new(2, -2),
                    Vec2i::new(1, -2),
                    Vec2i::new(0, -2),
                    Vec2i::new(0, -1),
                ] {
                    place_zone(maps, point + offset, 1, CLASS_ABANDONED, random);
                }

                let selection = random.next_u15() & 3;
                place_zone(
                    maps,
                    point + Vec2i::new(selection & 1, -(selection / 2)),
                    3,
                    CLASS_ABANDONED,
                    random,
                );
            }
        }
        _ => {}
    }
}

/// GrowthDevelopment._place_church.
pub fn place_church(maps: &mut ZoneMaps, anchor: Vec2i) -> bool {
    let edge = maps.map_edge;
    let position = Vec2i::new(anchor.x, anchor.y - 1);

    if maps.allow_edge_buildings {
        if !Rect2i::new(0, 0, edge, edge).encloses(&Rect2i::from(position, Vec2i::new(2, 2))) {
            return false;
        }
    } else if anchor.x <= 0 || anchor.y <= 0 || anchor.x >= edge - 1 || anchor.y >= edge - 1 {
        return false;
    }

    for x in position.x..position.x + 2 {
        for y in position.y..position.y + 2 {
            let index = x * edge + y;
            let i = index as usize;
            replace_building(maps.buildings, maps.zones, maps.misc, index, tiles::CHURCH);
            maps.zones[i] = 0;
            maps.flags[i] = (maps.flags[i] as i64 | flag_bits::STRUCTURE_MASK) as u8;
        }
    }

    set_growth_corners(maps.zones, position, 2, maps.rotation, edge);

    true
}

/// GrowthConstruction.can_advance_density.
pub fn can_advance_density(zone_byte: i64, zone_type: i64, density: i64, land_value: &[u8], x: i64, y: i64, map_edge: i64) -> bool {
    if density == 4 {
        return false;
    }

    if zone_byte & 1 != 0 && density >= 1 {
        return false;
    }

    if zone_type > 4 {
        return true;
    }

    let value = crate::sim::bytes::at(land_value, grid::index(land_value, map_edge, x, y));

    (density != 1 || value > 0x1f) && (density != 2 || value > 0x5f) && (density != 3 || value > 0xbf)
}

#[inline]
fn land_level(altitude: &[u8], index: i64) -> i64 {
    // The low five bits of the ALTM word are in its second byte.
    altitude[(index * 2 + 1) as usize] as i64 & altitude_layout::LEVEL_MASK
}

fn is_surface_network(tile: i64) -> bool {
    (tiles::ROAD_STRAIGHT_1..=tiles::RAIL_SLOPE_8).contains(&tile)
        || (tiles::TUNNEL_ENTRANCE_1..=tiles::RAIL_POWER_CROSSING_2).contains(&tile)
        || (tiles::HIGHWAY_ROAD_CROSSING_1..=tiles::HIGHWAY_RAIL_CROSSING_2).contains(&tile)
        || (tiles::HIGHWAY_ONRAMP_1..=tiles::HIGHWAY_ONRAMP_4).contains(&tile)
        || (tiles::RAIL_SUBWAY_ENTRANCE_1..=tiles::RAIL_SUBWAY_ENTRANCE_4).contains(&tile)
}

fn can_build_site(maps: &ZoneMaps, point: Vec2i, height: i64, zone_type: i64, maximum_building: i64) -> bool {
    let index = index_of(point, maps.map_edge);

    if index < 0 {
        return false;
    }

    if land_level(maps.altitude, index) != height || maps.zones[index as usize] as i64 & zone::TYPE_MASK != zone_type {
        return false;
    }

    let building = maps.buildings[index as usize] as i64;

    building < maximum_building && !is_surface_network(building)
}

/// GrowthConstruction._advance_construction.
pub fn advance_construction(maps: &mut ZoneMaps, point: Vec2i, density: i64, zone_type: i64, random: &mut SimRandom) -> bool {
    match density {
        0 => place_zone(maps, point, 1, CLASS_CONSTRUCTION, random),
        1 => {
            let height = land_level(maps.altitude, index_of(point, maps.map_edge));
            let right = point + Vec2i::new(1, 0);
            let down = point + Vec2i::new(0, 1);
            let down_right = point + Vec2i::new(1, 1);
            let site = |maps: &ZoneMaps, at: Vec2i| can_build_site(maps, at, height, zone_type, 0x8c);

            if site(maps, right) && site(maps, down) && site(maps, down_right) {
                return place_zone(maps, down, 2, CLASS_CONSTRUCTION, random);
            }

            let up = point + Vec2i::new(0, -1);
            let up_right = point + Vec2i::new(1, -1);

            if site(maps, right) && site(maps, up) && site(maps, up_right) {
                return place_zone(maps, point, 2, CLASS_CONSTRUCTION, random);
            }

            let left = point + Vec2i::new(-1, 0);
            let down_left = point + Vec2i::new(-1, 1);

            if site(maps, down) && site(maps, left) && site(maps, down_left) {
                return place_zone(maps, down_left, 2, CLASS_CONSTRUCTION, random);
            }

            let up_left = point + Vec2i::new(-1, -1);

            if site(maps, up) && site(maps, left) && site(maps, up_left) {
                return place_zone(maps, left, 2, CLASS_CONSTRUCTION, random);
            }

            false
        }
        2 => place_zone(maps, point, 3, CLASS_CONSTRUCTION, random),
        3 => advance_to_density_four(maps, point, zone_type, random),
        _ => false,
    }
}

fn advance_to_density_four(maps: &mut ZoneMaps, point: Vec2i, zone_type: i64, random: &mut SimRandom) -> bool {
    let edge = maps.map_edge;
    let height = land_level(maps.altitude, index_of(point, edge));

    for candidate in 0..4 {
        let anchor = point + Vec2i::new(-(candidate & 1), candidate / 2);
        let perimeter = [
            anchor,
            anchor + Vec2i::new(0, -1),
            anchor + Vec2i::new(0, -2),
            anchor + Vec2i::new(1, -2),
            anchor + Vec2i::new(2, -2),
            anchor + Vec2i::new(2, -1),
            anchor + Vec2i::new(2, 0),
            anchor + Vec2i::new(1, 0),
        ];

        if !perimeter
            .iter()
            .all(|&checked| can_build_site(maps, checked, height, zone_type, 0xae))
        {
            continue;
        }

        if !has_density_four_road(maps.buildings, anchor, edge) {
            continue;
        }

        for checked in perimeter {
            let index = index_of(checked, edge);

            if index >= 0 && maps.buildings[index as usize] as i64 > tiles::DEVELOPED_1X1_LAST {
                clear_growth_building(maps, checked, random);
            }
        }

        return place_zone(maps, anchor, 4, CLASS_CONSTRUCTION, random);
    }

    false
}

fn has_density_four_road(buildings: &[u8], anchor: Vec2i, map_edge: i64) -> bool {
    let checks = [
        (
            anchor + Vec2i::new(-1, 1),
            [
                tiles::ROAD_CURVE_1,
                tiles::ROAD_JUNCTION_1,
                tiles::ROAD_JUNCTION_2,
                tiles::ROAD_CROSSROADS,
            ],
        ),
        (
            anchor + Vec2i::new(-1, -3),
            [
                tiles::ROAD_CURVE_2,
                tiles::ROAD_JUNCTION_2,
                tiles::ROAD_JUNCTION_3,
                tiles::ROAD_CROSSROADS,
            ],
        ),
        (
            anchor + Vec2i::new(3, -3),
            [
                tiles::ROAD_CURVE_3,
                tiles::ROAD_JUNCTION_3,
                tiles::ROAD_JUNCTION_4,
                tiles::ROAD_CROSSROADS,
            ],
        ),
        (
            anchor + Vec2i::new(3, 1),
            [
                tiles::ROAD_CURVE_4,
                tiles::ROAD_JUNCTION_4,
                tiles::ROAD_JUNCTION_1,
                tiles::ROAD_CROSSROADS,
            ],
        ),
    ];

    for (point, accepted) in checks {
        let index = index_of(point, map_edge);

        if index >= 0 && accepted.contains(&(buildings[index as usize] as i64)) {
            return true;
        }
    }

    false
}

fn clear_growth_building(maps: &mut ZoneMaps, point: Vec2i, random: &mut SimRandom) {
    let rotation = maps.rotation;
    let direction = match crate::sim::bytes::at(maps.zones, index_of(point, maps.map_edge)) & zone::CORNERS_MASK {
        0x10 => -rotation & 3,
        0x20 => (1 - rotation) & 3,
        0x40 => (-rotation - 2) & 3,
        0x80 => (-rotation - 1) & 3,
        _ => return,
    };
    let mut anchor = point;

    if direction == 0 {
        anchor.y += 1;
    } else if direction == 1 {
        anchor = anchor + Vec2i::new(-1, 1);
    } else if direction == 2 {
        anchor.x -= 1;
    }

    for offset in [Vec2i::new(0, 0), Vec2i::new(1, 0), Vec2i::new(1, -1), Vec2i::new(0, -1)] {
        place_zone(maps, anchor + offset, 1, CLASS_ABANDONED, random);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::city::City;
    use crate::sim::testing::{empty_city, empty_full_resolution_city, sequence_random};

    fn maps(city: &mut City, rotation: i64) -> ZoneMaps<'_> {
        let map_edge = city.map_size;
        let City {
            xbld,
            xzon,
            xbit,
            misc,
            xval,
            altm,
            ..
        } = city;

        ZoneMaps {
            buildings: &mut xbld.data,
            zones: &mut xzon.data,
            flags: &mut xbit.data,
            misc: &mut misc.data,
            land_value: &xval.data,
            altitude: &altm.data,
            rotation,
            map_edge,
            allow_edge_buildings: false,
        }
    }

    fn cities(edge: i64) -> Vec<City> {
        if edge < 128 {
            vec![empty_city(edge), empty_full_resolution_city(edge)]
        } else {
            vec![empty_city(edge)]
        }
    }

    /// Classic growth keeps one free tile at each map edge on every map size.
    #[test]
    fn growth_keeps_the_true_edge_margin() {
        for edge in [16i64, 32, 64, 128, 256, 384, 512, 640, 1024] {
            for base in cities(edge) {
                for density in 2..5 {
                    for rotation in 0..4 {
                        let radius = density / 2;
                        let far = Vec2i::new(edge - 2 - radius, edge - 2 - radius);
                        let anchors = if edge >= 128 { vec![Vec2i::new(20, 20), far] } else { vec![far] };

                        for anchor in anchors {
                            let mut city = base.clone();
                            let placed = place_zone(
                                &mut maps(&mut city, rotation),
                                anchor,
                                density,
                                CLASS_CONSTRUCTION,
                                &mut sequence_random(&[0]),
                            );
                            assert!(placed, "edge {edge} density {density} rotation {rotation} at {anchor:?}");
                            let count = city.xbld.data.iter().filter(|tile| **tile != 0).count() as i64;
                            assert_eq!(count, (radius + 1) * (radius + 1), "the growth footprint size");
                        }

                        let outside = if edge >= 128 {
                            vec![
                                Vec2i::new(edge - 1 - radius, 20),
                                Vec2i::new(20, edge - 1 - radius),
                                Vec2i::new(1, 20),
                            ]
                        } else {
                            vec![far + Vec2i::new(1, 1)]
                        };

                        for anchor in outside {
                            let mut city = base.clone();
                            let before = city.xbld.data.clone();
                            let placed = place_zone(
                                &mut maps(&mut city, rotation),
                                anchor,
                                density,
                                CLASS_CONSTRUCTION,
                                &mut sequence_random(&[0]),
                            );
                            assert!(!placed, "growth keeps the true edge margin");
                            assert_eq!(city.xbld.data, before, "rejected growth does not write buildings");
                        }
                    }
                }
            }
        }
    }

    /// Per-tile land value belongs to its own tile.
    #[test]
    fn density_advance_reads_the_selected_tile_land_value() {
        let edge = 128;
        let mut land = vec![0u8; (edge * edge) as usize];
        let point = Vec2i::new(40, 41);
        land[(point.x * edge + point.y) as usize] = 255;
        assert!(can_advance_density(2, 2, 3, &land, point.x, point.y, edge));
        assert!(!can_advance_density(2, 2, 3, &land, point.x, point.y + 1, edge));
    }
}
