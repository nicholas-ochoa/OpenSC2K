//! City edit rules that the simulation shares with the player tools: demolition,
//! network retiling, underground retiling, terrain retiling, highway sections, view rotation,
//! and the map stages of new-city terrain.
//! These are ports of the GDScript tool helpers that the simulation calls.

pub mod commands;
pub mod demolish;
pub mod highway;
pub mod network;
pub mod new_terrain;
pub mod rotation;
pub mod terrain;
pub mod underground;

use super::city::City;
use super::geom::Vec2i;
use super::ids::sc2zone_layout as zone;
use super::moving::spawner::VehicleCaps;

/// The tile maps that an edit reads and writes, borrowed from one city.
pub struct Maps<'a> {
    pub map_edge: i64,
    pub altitude: &'a mut [u8],
    pub buildings: &'a mut [u8],
    pub terrain: &'a mut [u8],
    pub zones: &'a mut [u8],
    pub underground: &'a mut [u8],
    pub flags: &'a mut [u8],
    pub text_overlays: &'a mut [u8],
    pub labels: &'a mut [u8],
    /// True for the wide label records of an SC2X version 4 working document.
    pub wide_labels: bool,
    /// The vehicle caps and record pool budget of the city.
    pub vehicle_caps: VehicleCaps,
    pub microsims: &'a mut [u8],
    pub misc: &'a mut [u8],
}

impl City {
    /// Borrow the edit maps. This does not mark the chunks written.
    pub fn maps(&mut self) -> Maps<'_> {
        let vehicle_caps = VehicleCaps::for_city(self);

        Maps {
            map_edge: self.map_size,
            altitude: &mut self.altm.data,
            buildings: &mut self.xbld.data,
            terrain: &mut self.xter.data,
            zones: &mut self.xzon.data,
            underground: &mut self.xund.data,
            flags: &mut self.xbit.data,
            text_overlays: &mut self.xtxt.data,
            wide_labels: self.large_version >= 4,
            vehicle_caps,
            labels: &mut self.xlab.data,
            microsims: &mut self.xmic.data,
            misc: &mut self.misc.data,
        }
    }
}

/// The edit maps plus the thing records and the coarse maps, borrowed together.
pub struct CityParts<'a> {
    pub maps: Maps<'a>,
    pub things: &'a mut Vec<u8>,
    pub traffic: &'a mut Vec<u8>,
    pub pollution: &'a mut Vec<u8>,
    pub land_value: &'a mut Vec<u8>,
    pub crime: &'a mut Vec<u8>,
}

impl City {
    /// Borrow the edit maps with XTHG, XTRF, XPLT, XVAL, and XCRM.
    pub fn parts(&mut self) -> CityParts<'_> {
        let wide_labels = self.large_version >= 4;
        let vehicle_caps = VehicleCaps::for_city(self);
        let City {
            map_size,
            altm,
            xbld,
            xter,
            xzon,
            xund,
            xbit,
            xtxt,
            xlab,
            xmic,
            misc,
            xthg,
            xtrf,
            xplt,
            xval,
            xcrm,
            ..
        } = self;

        CityParts {
            maps: Maps {
                map_edge: *map_size,
                altitude: &mut altm.data,
                buildings: &mut xbld.data,
                terrain: &mut xter.data,
                zones: &mut xzon.data,
                underground: &mut xund.data,
                flags: &mut xbit.data,
                text_overlays: &mut xtxt.data,
                labels: &mut xlab.data,
                wide_labels,
                vehicle_caps,
                microsims: &mut xmic.data,
                misc: &mut misc.data,
            },
            things: &mut xthg.data,
            traffic: &mut xtrf.data,
            pollution: &mut xplt.data,
            land_value: &mut xval.data,
            crime: &mut xcrm.data,
        }
    }
}

impl Maps<'_> {
    #[inline]
    pub fn index(&self, point: Vec2i) -> i64 {
        point.x * self.map_edge + point.y
    }

    #[inline]
    pub fn in_bounds(&self, point: Vec2i) -> bool {
        point.x >= 0 && point.x < self.map_edge && point.y >= 0 && point.y < self.map_edge
    }
}

pub const CORNER_BOTTOM_LEFT: [i64; 4] = [0x10, 0x20, 0x40, 0x80];
pub const CORNER_BOTTOM_RIGHT: [i64; 4] = [0x20, 0x40, 0x80, 0x10];
pub const CORNER_TOP_LEFT: [i64; 4] = [0x40, 0x80, 0x10, 0x20];
pub const CORNER_TOP_RIGHT: [i64; 4] = [0x80, 0x10, 0x20, 0x40];

/// BuildingSites.set_corners and GrowthSiteRules.set_corners. The zone and
/// building corner flags share one byte.
pub fn set_corners(zones: &mut [u8], position: Vec2i, area: i64, rotation: i64, map_edge: i64) {
    if area == 1 {
        let index = (position.x * map_edge + position.y) as usize;
        zones[index] = ((zones[index] as i64 & zone::TYPE_MASK) | zone::CORNERS_MASK) as u8;

        return;
    }

    let far = position + Vec2i::new(area - 1, area - 1);
    let view = (rotation & 3) as usize;
    let bottom_left = (position.x * map_edge + position.y) as usize;
    let bottom_right = (far.x * map_edge + position.y) as usize;
    let top_left = (far.x * map_edge + far.y) as usize;
    let top_right = (position.x * map_edge + far.y) as usize;
    zones[bottom_left] = ((zones[bottom_left] as i64 & zone::TYPE_MASK) | CORNER_BOTTOM_LEFT[view]) as u8;
    zones[bottom_right] = ((zones[bottom_right] as i64 & zone::TYPE_MASK) | CORNER_BOTTOM_RIGHT[view]) as u8;
    zones[top_left] = ((zones[top_left] as i64 & zone::TYPE_MASK) | CORNER_TOP_LEFT[view]) as u8;
    zones[top_right] = ((zones[top_right] as i64 & zone::TYPE_MASK) | CORNER_TOP_RIGHT[view]) as u8;
}

/// GrowthSiteRules.set_corners. Unlike BuildingSites.set_corners, an area of
/// one uses the four corner formulas too.
pub fn set_growth_corners(zones: &mut [u8], position: Vec2i, area: i64, rotation: i64, map_edge: i64) {
    let far = position + Vec2i::new(area - 1, area - 1);
    let view = (rotation & 3) as usize;
    let bottom_left = (position.x * map_edge + position.y) as usize;
    let bottom_right = (far.x * map_edge + position.y) as usize;
    let top_left = (far.x * map_edge + far.y) as usize;
    let top_right = (position.x * map_edge + far.y) as usize;
    zones[bottom_left] = ((zones[bottom_left] as i64 & zone::TYPE_MASK) | CORNER_BOTTOM_LEFT[view]) as u8;
    zones[bottom_right] = ((zones[bottom_right] as i64 & zone::TYPE_MASK) | CORNER_BOTTOM_RIGHT[view]) as u8;
    zones[top_left] = ((zones[top_left] as i64 & zone::TYPE_MASK) | CORNER_TOP_LEFT[view]) as u8;
    zones[top_right] = ((zones[top_right] as i64 & zone::TYPE_MASK) | CORNER_TOP_RIGHT[view]) as u8;
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::bytes::{read_u32_be, write_u32_be};
    use crate::sim::growth::special::replace_special_building;
    use crate::sim::ids::sc2misc_layout as misc_layout;

    /// Growth corners rotate with the view and keep each zone type.
    #[test]
    fn growth_corners_follow_the_rotation() {
        for edge in [16i64, 128, 256] {
            for area in 1..5 {
                for point in [Vec2i::ZERO, Vec2i::new(1, 2), Vec2i::new(edge - area, edge - area)] {
                    for rotation in 0..4 {
                        let mut zones = vec![0xa7u8; (edge * edge) as usize];
                        let mut expected = zones.clone();

                        if area == 1 {
                            // The last corner write selects the anchor for a one-tile building.
                            expected[(point.x * edge + point.y) as usize] = [0x87, 0x17, 0x27, 0x47][rotation as usize];
                        } else {
                            let corners = [
                                point,
                                point + Vec2i::new(area - 1, 0),
                                point + Vec2i::new(area - 1, area - 1),
                                point + Vec2i::new(0, area - 1),
                            ];

                            for (corner, at) in corners.iter().enumerate() {
                                expected[(at.x * edge + at.y) as usize] = (7 | (1 << (4 + (corner as i64 + rotation) % 4))) as u8;
                            }
                        }

                        set_growth_corners(&mut zones, point, area, rotation, edge);
                        assert_eq!(zones, expected);
                    }
                }
            }
        }
    }

    /// Military tiles move their own count slots. Other tiles use the civilian counts.
    #[test]
    fn military_counts_use_the_original_slots() {
        let counted = [
            0xdd, 0xde, 0xef, 0xf2, 0xea, 0xe3, 0xe4, 0xe5, 0xf1, 0xe0, 0xe2, 0xe7, 0xe8, 0xf6, 0xf9,
        ];
        let mut base = vec![90u8; 4800];

        for byte in &mut base[0xfa8..0xfe8] {
            *byte = 0;
        }

        base[0xfab] = 10;

        for tile in 0..256i64 {
            let slot = counted.iter().position(|value| *value == tile).map_or(0, |position| position + 1);
            let mut expected = base.clone();

            if slot != 0 {
                expected[0xfab] = 9;
                expected[0xfab + slot * 4] = 1;
            }

            for edge in [128i64, 16] {
                let buildings = vec![0u8; (edge * edge) as usize];
                let mut zones = buildings.clone();
                zones[0] = 0xf7;
                let misc = base.clone();

                for replace in [
                    replace_special_building as fn(&mut [u8], &[u8], &mut [u8], i64, i64),
                    network::replace_building,
                ] {
                    let mut buildings = buildings.clone();
                    let mut misc = misc.clone();
                    replace(&mut buildings, &zones, &mut misc, 0, tile);
                    assert_eq!(buildings[0] as i64, tile);
                    assert_eq!(misc, expected, "only the original military count slots change");
                }
            }
        }
    }

    /// Classic cities keep 16-bit counts. Larger maps keep full counts.
    #[test]
    fn tile_count_changes_keep_the_map_width() {
        for edge in [128i64, 256, 1024] {
            for change in [
                crate::sim::growth::replace_building as fn(&mut [u8], &[u8], &mut [u8], i64, i64),
                network::replace_building,
                replace_special_building,
            ] {
                let mut buildings = vec![0u8; (edge * edge) as usize];
                let zones = buildings.clone();
                let mut misc = vec![0u8; 4800];
                let road = misc_layout::TILE_COUNTS + 0x1d * 4;
                write_u32_be(&mut misc, road, 65535);
                change(&mut buildings, &zones, &mut misc, edge * edge - 1, 0x1d);
                assert_eq!(read_u32_be(&misc, road), if edge == 128 { 0 } else { 65536 });
            }
        }
    }
}
