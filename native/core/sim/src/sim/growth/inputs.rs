//! The growth inputs of one tile, for the Tile Inspector. It reads the city
//! with the rules of the growth scan and does not change it. The trip itself
//! is a separate query, `trip_reach`.

use super::{ANCHOR_MASKS, development, has_power};
use crate::sim::bytes::read_i32_be;
use crate::sim::city::City;
use crate::sim::geom::Vec2i;
use crate::sim::grid;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::trip;
use crate::sim::value::{ToValue, Value};

/// The first month day of the growth scan. The scan visits one tile of each
/// 4 x 4 block on each of the next 16 days.
const FIRST_SCAN_DAY: i64 = 3;
/// A completed trip adds this to the class demand.
const TRIP_PRESSURE: i64 = 2000;
/// The growth roll draws a number below this.
const ROLL_RANGE: i64 = 32768;
/// The land value that a residential or commercial building needs to grow
/// past each density.
const DENSITY_LAND_VALUES: [i64; 4] = [-1, 0x1f, 0x5f, 0xbf];
const LAST_RCI_ZONE: i64 = 6;
const LAST_LIGHT_DENSITY: i64 = 1;
const LAST_DENSITY: i64 = 4;

#[derive(Default)]
pub struct GrowthInputs {
    pub zone_type: i64,
    pub rci: bool,
    pub building: i64,
    pub density: i64,
    pub status: i64,
    /// False for a building tile that is not the anchor of its building.
    pub visited: bool,
    /// The month day, from 0, of the growth visit of this tile.
    pub visit_day: i64,
    pub powered: bool,
    /// True when a road or rail is near enough for an empty zone tile.
    pub transport: bool,
    pub land_value: i64,
    /// The land value above which the next density can start. -1 when land
    /// value does not limit growth.
    pub needed_land_value: i64,
    pub can_advance: bool,
    pub class_demand: i64,
    /// The growth pressure when the tile's trip reaches a destination.
    pub pressure: i64,
    /// The chance of a density advance in each visit, in 1/10000 parts, when
    /// the trip reaches a destination.
    pub advance_chance: i64,
}

pub fn inspect(city: &City, tile: Vec2i) -> GrowthInputs {
    let edge = city.map_size;
    let mut result = GrowthInputs::default();

    if tile.x < 0 || tile.y < 0 || tile.x >= edge || tile.y >= edge {
        return result;
    }

    let index = (tile.x * edge + tile.y) as usize;
    let zone_byte = i64::from(city.xzon.data[index]);
    result.zone_type = zone_byte & zone::TYPE_MASK;
    result.rci = (1..=LAST_RCI_ZONE).contains(&result.zone_type);
    result.building = i64::from(city.xbld.data[index]);
    result.visit_day = FIRST_SCAN_DAY + 4 * (tile.x % 4) + tile.y % 4;
    result.land_value = crate::sim::bytes::at(&city.xval.data, grid::index(&city.xval.data, edge, tile.x, tile.y));

    if !result.rci {
        return result;
    }

    let anchor_mask = ANCHOR_MASKS[(city.compass_rotation() & 3) as usize];

    if result.building < tiles::DEVELOPED_FIRST {
        result.transport = trip::has_nearby_transport(&city.xbld.data, tile, edge);
        result.visited = result.building < tiles::ROAD_STRAIGHT_1 && result.transport;
    } else {
        result.density = development::density(result.building);
        result.status = development::status(result.building);
        result.visited = result.building <= tiles::DEVELOPED_3X3_LAST && zone_byte & anchor_mask != 0;
    }

    result.powered = has_power(&city.xbit.data, tile.x, tile.y, edge);
    result.can_advance =
        development::can_advance_density(zone_byte, result.zone_type, result.density, &city.xval.data, tile.x, tile.y, edge);
    result.needed_land_value = needed_land_value(result.zone_type, result.density);
    result.class_demand = read_i32_be(&city.misc.data, misc_layout::DEMAND + ((result.zone_type - 1) / 2) * 4);
    result.pressure = result.class_demand + TRIP_PRESSURE;

    if result.can_advance && result.powered {
        let threshold = (result.pressure * 3) / (result.density + 1);
        result.advance_chance = (threshold.clamp(0, ROLL_RANGE) * 10000) / ROLL_RANGE;
    }

    result
}

fn needed_land_value(zone_type: i64, density: i64) -> i64 {
    let light = zone_type & 1 != 0;

    if density >= LAST_DENSITY || (light && density >= LAST_LIGHT_DENSITY) || zone_type > 4 {
        return -1;
    }

    DENSITY_LAND_VALUES[density as usize]
}

impl ToValue for GrowthInputs {
    fn to_value(&self) -> Value {
        let field = |name: &str, value: Value| (Value::Str(name.to_string()), value);

        Value::Dict(vec![
            field("zone_type", Value::Int(self.zone_type)),
            field("rci", Value::Bool(self.rci)),
            field("building", Value::Int(self.building)),
            field("density", Value::Int(self.density)),
            field("status", Value::Int(self.status)),
            field("visited", Value::Bool(self.visited)),
            field("visit_day", Value::Int(self.visit_day)),
            field("powered", Value::Bool(self.powered)),
            field("transport", Value::Bool(self.transport)),
            field("land_value", Value::Int(self.land_value)),
            field("needed_land_value", Value::Int(self.needed_land_value)),
            field("can_advance", Value::Bool(self.can_advance)),
            field("class_demand", Value::Int(self.class_demand)),
            field("pressure", Value::Int(self.pressure)),
            field("advance_chance", Value::Int(self.advance_chance)),
        ])
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn light_zones_and_industry_have_no_land_value_step() {
        assert_eq!(needed_land_value(2, 1), 0x1f);
        assert_eq!(needed_land_value(4, 3), 0xbf);
        assert_eq!(needed_land_value(1, 1), -1);
        assert_eq!(needed_land_value(1, 0), -1);
        assert_eq!(needed_land_value(6, 1), -1);
        assert_eq!(needed_land_value(2, 4), -1);
    }
}
