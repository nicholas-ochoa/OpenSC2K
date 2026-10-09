//! Zoning and dezoning rectangles, as ZoneCommand.

use super::{EditBase, ToolArgs, in_bounds};
use crate::gd_edit_result;
use crate::gd_object;
use crate::sim::city::City;
use crate::sim::civic::mayor::recount_tiles;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::value::{Bytes, Ints32};

/// A zone on a slope costs this much more per tile when it is clicked alone.
const TERRAIN_SURCHARGE: i64 = 25;

/// The terrain shapes that charge the surcharge.
const TERRAIN_REQUIRES_SURCHARGE: [bool; 16] = [
    false, false, false, false, false, true, true, true, true, true, true, true, true, false, false, false,
];

gd_object! {
    pub struct Preview as "ZoneCommand.Preview" {
        pub ok: bool = false,
        pub error: String = String::new(),
        pub zone_type: i64 = 0,
        pub dragged: bool = false,
        pub charged_tiles: i64 = 0,
        pub changed_tiles: i64 = 0,
        pub terrain_surcharges: i64 = 0,
        pub cost: i64 = 0,
        pub listed_cost: i64 = 0,
        pub affordable: bool = false,
        pub free_mode: bool = false,
    }
}

impl Preview {
    fn failure(message: &str) -> Self {
        Self {
            error: message.to_string(),
            ..Default::default()
        }
    }
}

gd_edit_result! {
    pub struct ZoneResult as "ZoneEditResult" {
        pub zone_type: i64 = 0,
        pub dragged: bool = false,
        pub charged_tiles: i64 = 0,
        pub terrain_surcharges: i64 = 0,
        pub previous_values: Bytes = Bytes::default(),
        pub new_values: Bytes = Bytes::default(),
        pub previous_buildings: Bytes = Bytes::default(),
        pub new_buildings: Bytes = Bytes::default(),
        pub previous_funds: i64 = 0,
    }
}

/// A zoning request. `zone_type` is the tool zone, or an override in free mode.
pub struct ZoneRequest {
    pub start: Vec2i,
    pub finish: Vec2i,
    pub dragged: bool,
    /// The zone that the tool paints, or -1 when the tool is not a zoning tool.
    pub tool_zone: i64,
    /// False when the tool catalog has no entry for the tool.
    pub has_tool: bool,
    pub zone_type_override: i64,
}

/// ZoneCommand.preview_rectangle.
pub fn preview(city: &City, args: &ToolArgs, request: &ZoneRequest) -> Preview {
    let edge = city.map_size;

    if !in_bounds(request.start, edge) || !in_bounds(request.finish, edge) {
        return Preview::failure("zone rectangle is outside the city");
    }

    let has_override = args.free_mode && (1..=9).contains(&request.zone_type_override);
    let zone_type = if has_override {
        request.zone_type_override
    } else {
        request.tool_zone
    };

    if (!request.has_tool && !has_override) || zone_type < 0 {
        return Preview::failure("tool is not a zoning tool");
    }

    let start_index = city.index_of(request.start.x, request.start.y) as usize;

    // The original refuses a drag that starts on one of these tiles. A drag
    // here zones the eligible tiles in the rectangle and skips the others, so
    // only a click is refused
    if !request.dragged {
        if city.xbit.data[start_index] as i64 & flag_bits::WATER != 0 {
            return Preview::failure("cannot zone water");
        }

        if city.xbld.data[start_index] as i64 == tiles::RADIOACTIVE_WASTE || zone_of(city, start_index) == zone::MILITARY {
            return Preview::failure("cannot zone this tile");
        }
    }

    let mut charged = 0;
    let mut surcharges = 0;
    let mut changed = 0;

    if !request.dragged {
        charged = 1;
        let terrain = city.xter.data[start_index] as i64;

        if terrain < terrain_ids::SURFACE_WATER_FIRST && TERRAIN_REQUIRES_SURCHARGE[(terrain & terrain_ids::SHAPE_MASK) as usize] {
            surcharges = 1;
        }

        if tile_is_eligible(city, start_index) && zone_of(city, start_index) != zone_type {
            changed = 1;
        }
    } else {
        let (minimum, maximum) = corners(request.start, request.finish);

        for x in minimum.x..=maximum.x {
            for y in minimum.y..=maximum.y {
                let index = (x * edge + y) as usize;

                if !tile_is_drag_price_eligible(city, index, zone_type) {
                    continue;
                }

                charged += 1;

                if tile_is_eligible(city, index) {
                    changed += 1;
                }
            }
        }
    }

    let tool_cost = if request.has_tool { args.cost } else { 0 };
    let listed_cost = charged * tool_cost + surcharges * TERRAIN_SURCHARGE;
    let cost = if args.free_mode { 0 } else { listed_cost };

    Preview {
        ok: true,
        zone_type,
        dragged: request.dragged,
        charged_tiles: charged,
        changed_tiles: changed,
        terrain_surcharges: surcharges,
        cost,
        listed_cost,
        affordable: args.free_mode || city.funds() >= cost,
        free_mode: args.free_mode,
        ..Default::default()
    }
}

/// ZoneCommand.apply_rectangle. Dezoning clears the smaller buildings too.
pub fn apply(city: &mut City, args: &ToolArgs, request: &ZoneRequest) -> ZoneResult {
    let preview = preview(city, args, request);

    if !preview.ok {
        return ZoneResult::rejected(&preview.error, 0);
    }

    let edge = city.map_size;
    let zone_type = preview.zone_type;
    let (minimum, maximum) = corners(request.start, request.finish);
    let mut tile_indices = Vec::new();

    for x in minimum.x..=maximum.x {
        for y in minimum.y..=maximum.y {
            let index = (x * edge + y) as usize;

            if tile_is_eligible(city, index) && zone_of(city, index) != zone_type {
                tile_indices.push(index);
            }
        }
    }

    if preview.changed_tiles == 0 && preview.cost == 0 {
        return ZoneResult::rejected("no eligible tiles would change", 0);
    }

    let previous_funds = city.funds();

    if previous_funds < preview.cost {
        return ZoneResult::rejected("insufficient funds", preview.cost);
    }

    let previous_values: Vec<u8> = tile_indices.iter().map(|&index| city.xzon.data[index]).collect();
    let previous_buildings: Vec<u8> = tile_indices.iter().map(|&index| city.xbld.data[index]).collect();

    for &index in &tile_indices {
        city.xzon.data[index] = ((city.xzon.data[index] as i64 & zone::CORNERS_MASK) | zone_type) as u8;
        let building = city.xbld.data[index] as i64;

        if zone_type == zone::NONE && building > tiles::EMPTY && building < tiles::RADIOACTIVE_WASTE {
            city.xbld.data[index] = tiles::EMPTY as u8;
        }
    }

    if preview.cost > 0 {
        city.set_funds(previous_funds - preview.cost);
    }

    // The original clears dezoned buildings without a count change. Extended
    // cities keep exact counts.
    if city.is_extended() {
        recount_tiles(city);
    }

    let mut result = ZoneResult {
        base: EditBase::accepted("zone", args.group, args.subtool),
        zone_type,
        dragged: request.dragged,
        charged_tiles: preview.charged_tiles,
        terrain_surcharges: preview.terrain_surcharges,
        previous_values: Bytes(previous_values),
        new_values: Bytes(tile_indices.iter().map(|&index| city.xzon.data[index]).collect()),
        previous_buildings: Bytes(previous_buildings),
        new_buildings: Bytes(tile_indices.iter().map(|&index| city.xbld.data[index]).collect()),
        previous_funds,
    };

    result.base.tile_indices = Ints32(tile_indices.iter().map(|&index| index as i32).collect());
    result.base.cost = preview.cost;
    result.base.listed_cost = preview.listed_cost;
    result.base.free_mode = args.free_mode;

    result
}

fn corners(start: Vec2i, finish: Vec2i) -> (Vec2i, Vec2i) {
    (
        Vec2i::new(start.x.min(finish.x), start.y.min(finish.y)),
        Vec2i::new(start.x.max(finish.x), start.y.max(finish.y)),
    )
}

fn zone_of(city: &City, index: usize) -> i64 {
    city.xzon.data[index] as i64 & zone::TYPE_MASK
}

/// Dry, flat, undeveloped land outside military bases.
fn tile_is_eligible(city: &City, index: usize) -> bool {
    let building = city.xbld.data[index] as i64;

    city.xbit.data[index] as i64 & flag_bits::WATER == 0
        && city.xter.data[index] as i64 == terrain_ids::FLAT
        && building < tiles::FIRST_ROAD
        && building < tiles::DEVELOPED_FIRST
        && building != tiles::RADIOACTIVE_WASTE
        && building != tiles::SMALL_PARK
        && zone_of(city, index) != zone::MILITARY
}

/// The tiles that a drag charges for, water included.
fn tile_is_drag_price_eligible(city: &City, index: usize, zone_type: i64) -> bool {
    let building = city.xbld.data[index] as i64;
    let current = zone_of(city, index);

    city.xter.data[index] as i64 == terrain_ids::FLAT
        && building < tiles::FIRST_ROAD
        && building != tiles::RADIOACTIVE_WASTE
        && building != tiles::SMALL_PARK
        && current != zone::MILITARY
        && current != zone_type
}
