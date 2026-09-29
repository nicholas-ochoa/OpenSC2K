//! City edit rules that the simulation shares with the player tools: demolition,
//! network retiling, underground retiling, terrain retiling, and highway sections.
//! These are ports of the GDScript tool helpers that the simulation calls.

pub mod demolish;
pub mod highway;
pub mod network;
pub mod terrain;
pub mod underground;

use super::city::City;
use super::geom::Vec2i;
use super::ids::sc2zone_layout as zone;

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
    pub microsims: &'a mut [u8],
    pub misc: &'a mut [u8],
}

impl City {
    /// Borrow the edit maps. This does not mark the chunks written.
    pub fn maps(&mut self) -> Maps<'_> {
        Maps {
            map_edge: self.map_size,
            altitude: &mut self.altm.data,
            buildings: &mut self.xbld.data,
            terrain: &mut self.xter.data,
            zones: &mut self.xzon.data,
            underground: &mut self.xund.data,
            flags: &mut self.xbit.data,
            text_overlays: &mut self.xtxt.data,
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
        let City { map_size, altm, xbld, xter, xzon, xund, xbit, xtxt, xlab, xmic, misc, xthg, xtrf, xplt, xval, xcrm, .. } =
            self;

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
