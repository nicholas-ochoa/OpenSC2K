//! Highway on-ramps, as OnrampCommand.

use super::{DIRECTIONS, EditBase, MAX_CLEAR_BUILDING, ToolArgs};
use crate::gd_edit_result;
use crate::sim::city::City;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::tools::network::replace_building;

/// The road directions that can connect to each arrangement of highway
/// neighbors. Both masks use the north, east, south, and west bits.
const ROAD_MASK_BY_HIGHWAY_MASK: [i64; 16] = [0, 10, 5, 12, 10, 0, 9, 0, 5, 6, 0, 0, 3, 0, 0, 0];

gd_edit_result! {
    pub struct OnrampResult as "OnrampEditResult" {
        pub tile_id: i64 = tiles::EMPTY,
        pub road_direction: i64 = 0,
        pub road_point: Vec2i = Vec2i::NONE,
    }
}

pub fn apply(city: &mut City, args: &ToolArgs, point: Vec2i, preview_only: bool) -> OnrampResult {
    let index = city.index_of(point.x, point.y);

    if index < 0 {
        return OnrampResult::rejected("on-ramp is outside the city", 0);
    }

    let building = city.xbld.data[index as usize] as i64;

    if building > MAX_CLEAR_BUILDING || building == tiles::RADIOACTIVE_WASTE {
        return OnrampResult::rejected("on-ramp site contains a protected building", 0);
    }

    if city.xter.data[index as usize] as i64 != terrain_ids::FLAT {
        return OnrampResult::rejected("on-ramp site is not clear terrain", 0);
    }

    let mut highway_mask = 0;
    let mut road_mask = 0;

    for (direction, offset) in DIRECTIONS.iter().enumerate() {
        let neighbor = point + *offset;
        let neighbor_index = city.index_of(neighbor.x, neighbor.y);

        if neighbor_index < 0 {
            continue;
        }

        let tile = city.xbld.data[neighbor_index as usize] as i64;

        if (tiles::HIGHWAY_STRAIGHT_1..=tiles::HIGHWAY_POWER_CROSSING_2).contains(&tile) {
            highway_mask |= 1 << direction;
        }

        if (tiles::FIRST_ROAD..=tiles::ROAD_CROSSROADS).contains(&tile) {
            road_mask |= 1 << direction;
        }
    }

    road_mask &= ROAD_MASK_BY_HIGHWAY_MASK[highway_mask as usize];

    if road_mask == 0 {
        return OnrampResult::rejected("on-ramp requires perpendicular highway and road neighbors", 0);
    }

    let cost = if args.free_mode { 0 } else { args.cost };

    if city.funds() < cost {
        return OnrampResult::rejected("insufficient funds", cost);
    }

    if preview_only {
        return OnrampResult {
            base: EditBase {
                ok: true,
                ..Default::default()
            },
            ..Default::default()
        };
    }

    if city.missing_or_resized(&super::building::PAYLOAD_IDS).is_some() {
        return OnrampResult::rejected("required city data is missing or invalid", 0);
    }

    let road_direction = road_mask.trailing_zeros() as i64;
    let ramp_tile = ramp_tile(highway_mask, road_direction);
    let road_point = point + DIRECTIONS[road_direction as usize];
    let road_index = city.index_of(road_point.x, road_point.y);
    let funds = city.funds();
    let maps = city.maps();

    replace_building(maps.buildings, maps.zones, maps.misc, road_index, tiles::ROAD_CROSSROADS);
    replace_building(maps.buildings, maps.zones, maps.misc, index, ramp_tile);

    if road_direction == 0 || road_direction == 2 {
        maps.flags[index as usize] |= flag_bits::FLIPPED as u8;
    }

    city.set_funds(funds - cost);

    let mut result = OnrampResult {
        base: EditBase::accepted("onramp", args.group, args.subtool),
        tile_id: ramp_tile,
        road_direction,
        road_point,
    };

    result.base.cost = cost;
    result.base.listed_cost = args.cost;
    result.base.free_mode = args.free_mode;

    result
}

/// The ramp that faces the road in `road_direction` beside the highway.
fn ramp_tile(highway_mask: i64, road_direction: i64) -> i64 {
    match road_direction {
        0 => {
            if highway_mask & 2 != 0 {
                tiles::HIGHWAY_ONRAMP_3
            } else {
                tiles::HIGHWAY_ONRAMP_2
            }
        }
        1 => {
            if highway_mask & 1 != 0 {
                tiles::HIGHWAY_ONRAMP_1
            } else {
                tiles::HIGHWAY_ONRAMP_4
            }
        }
        2 => {
            if highway_mask & 2 != 0 {
                tiles::HIGHWAY_ONRAMP_4
            } else {
                tiles::HIGHWAY_ONRAMP_1
            }
        }
        _ => {
            if highway_mask & 1 != 0 {
                tiles::HIGHWAY_ONRAMP_2
            } else {
                tiles::HIGHWAY_ONRAMP_3
            }
        }
    }
}
