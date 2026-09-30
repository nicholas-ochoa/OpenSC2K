//! Road tunnels through a hill, as TunnelCommand.

use super::{DIRECTIONS, EditBase, MAX_CLEAR_BUILDING, ToolArgs};
use crate::gd_edit_result;
use crate::sim::city::City;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2altitude_layout as altitude_layout;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::ids::underground_tile_ids as under;
use crate::sim::tools::network::{self, MODE_ROAD, replace_building};

pub const CONFIRMATION_UNSELECTED: i64 = -1;
pub const CONFIRMATION_CANCELLED: i64 = 0;
pub const CONFIRMATION_CONFIRMED: i64 = 1;

/// A tunnel may not pass more than this many levels under its entrance.
const MAX_DEPTH: i64 = 30;

/// The chunks that NetworkState.city_payloads checks.
pub const PAYLOAD_IDS: [&str; 8] = ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "MISC"];

gd_edit_result! {
    pub struct TunnelResult as "TunnelEditResult" {
        pub start: Vec2i = Vec2i::NONE,
        pub finish: Vec2i = Vec2i::NONE,
        pub start_tile: i64 = tiles::EMPTY,
        pub finish_tile: i64 = tiles::EMPTY,
        pub confirmation_required: bool = false,
        pub cancelled: bool = false,
    }
}

pub fn apply(city: &mut City, args: &ToolArgs, start: Vec2i, confirmation: i64) -> TunnelResult {
    let edge = city.map_size;
    let start_index = city.index_of(start.x, start.y);

    if start_index < 0 {
        return TunnelResult::rejected("tunnel entrance is outside the city", 0);
    }

    let start_building = city.xbld.data[start_index as usize] as i64;

    if start_building > MAX_CLEAR_BUILDING || start_building == tiles::RADIOACTIVE_WASTE {
        return TunnelResult::rejected("tunnel entrance contains a protected building", 0);
    }

    if city.xund.data[start_index as usize] as i64 != under::EMPTY {
        return TunnelResult::rejected("tunnel entrance conflicts with an underground network", 0);
    }

    let start_terrain = city.xter.data[start_index as usize] as i64;

    if !(terrain_ids::SLOPE_TOP_LEFT..=terrain_ids::SLOPE_BOTTOM_LEFT).contains(&start_terrain) {
        return TunnelResult::rejected("tunnel entrance requires a cardinal slope", 0);
    }

    let direction = DIRECTIONS[((start_terrain + 2) & 3) as usize];
    let start_altitude = city.land_altitude(start.x, start.y);

    // Walk into the hill until the ground is back at the entrance level.
    let mut current = start;

    loop {
        if current.x < 0 || current.x > edge - 2 || current.y < 0 || current.y > edge - 2 {
            return TunnelResult::rejected("tunnel cannot reach an opposite slope", 0);
        }

        let current_index = city.index_of(current.x, current.y);
        let word = city.altitude_word(current_index);

        if word & altitude_layout::TUNNEL_MASK != 0 {
            return TunnelResult::rejected("tunnel path conflicts with another tunnel", 0);
        }

        let difference = (word & altitude_layout::LEVEL_MASK) - start_altitude;

        if difference > MAX_DEPTH {
            return TunnelResult::rejected("tunnel path is too deep", 0);
        }

        if difference == 1 && underground_blocks_tunnel(city.xund.data[current_index as usize] as i64) {
            return TunnelResult::rejected("tunnel path conflicts with an underground network", 0);
        }

        current = current + direction;

        if city.index_of(current.x, current.y) < 0 || city.land_altitude(current.x, current.y) <= start_altitude {
            break;
        }
    }

    let finish = current;
    let finish_index = city.index_of(finish.x, finish.y);
    let expected_terrain = ((start_terrain + 1) & 3) + 1;

    if finish_index < 0 || city.xter.data[finish_index as usize] as i64 != expected_terrain {
        return TunnelResult::rejected("tunnel cannot reach an opposite slope", 0);
    }

    let mut points = Vec::new();
    current = start;

    loop {
        points.push(current);

        if current == finish {
            break;
        }

        current = current + direction;
    }

    let listed_cost = points.len() as i64 * args.cost;
    let cost = if args.free_mode { 0 } else { listed_cost };

    if confirmation == CONFIRMATION_UNSELECTED || confirmation == CONFIRMATION_CANCELLED {
        let unselected = confirmation == CONFIRMATION_UNSELECTED;
        let message = if unselected {
            "tunnel construction confirmation is required"
        } else {
            "tunnel construction canceled"
        };
        let mut proposal = TunnelResult::rejected(message, cost);
        proposal.confirmation_required = unselected;
        proposal.cancelled = !unselected;
        proposal.start = start;
        proposal.finish = finish;
        proposal.base.points = points;
        proposal.base.listed_cost = listed_cost;
        proposal.base.free_mode = args.free_mode;

        return proposal;
    }

    if confirmation != CONFIRMATION_CONFIRMED {
        return TunnelResult::rejected("tunnel confirmation choice is invalid", 0);
    }

    if city.funds() < cost {
        return TunnelResult::rejected("insufficient funds", cost);
    }

    if city.missing_or_resized(&PAYLOAD_IDS).is_some() {
        return TunnelResult::rejected("required city data is missing or invalid", 0);
    }

    let funds = city.funds();
    let start_tile = start_terrain + (tiles::TUNNEL_FIRST - 1);
    let finish_tile = ((start_terrain + 1) & 3) + tiles::TUNNEL_FIRST;
    let levels: Vec<i64> = points
        .iter()
        .map(|point| city.land_altitude(point.x, point.y) - start_altitude + 1)
        .collect();
    let maps = city.maps();

    replace_building(maps.buildings, maps.zones, maps.misc, start_index, start_tile);
    set_tunnel_level(maps.altitude, start_index, 1);
    retile_adjacent_roads(
        maps.buildings,
        maps.terrain,
        maps.zones,
        maps.flags,
        maps.misc,
        maps.text_overlays,
        start,
        edge,
    );

    for point_index in 1..points.len().saturating_sub(1) {
        let point = points[point_index];
        set_tunnel_level(maps.altitude, point.x * edge + point.y, levels[point_index]);
    }

    replace_building(maps.buildings, maps.zones, maps.misc, finish_index, finish_tile);
    set_tunnel_level(maps.altitude, finish_index, 1);
    retile_adjacent_roads(
        maps.buildings,
        maps.terrain,
        maps.zones,
        maps.flags,
        maps.misc,
        maps.text_overlays,
        finish,
        edge,
    );
    city.set_funds(funds - cost);

    let mut result = TunnelResult {
        base: EditBase::accepted("tunnel", args.group, args.subtool),
        start,
        finish,
        start_tile,
        finish_tile,
        ..Default::default()
    };
    result.base.points = points;
    result.base.cost = cost;
    result.base.listed_cost = listed_cost;
    result.base.free_mode = args.free_mode;

    result
}

fn underground_blocks_tunnel(tile: i64) -> bool {
    (under::SUBWAY_LR..=under::PIPE_LR_SUBWAY_TB).contains(&tile) || tile == under::MISSILE_SILO || tile == under::SUBWAY_ENTRANCE
}

/// Replace the tunnel level of a word and keep its land and water heights.
fn set_tunnel_level(altitude: &mut [u8], index: i64, level: i64) {
    let data_mask = altitude_layout::LAND_MASK | altitude_layout::WATER_MASK;
    let offset = (index * 2) as usize;
    let mut word = ((altitude[offset] as i64) << 8) | altitude[offset + 1] as i64;
    word = (word & data_mask) | ((level & altitude_layout::LEVEL_MASK) << altitude_layout::TUNNEL_SHIFT);
    altitude[offset] = (word >> 8) as u8;
    altitude[offset + 1] = word as u8;
}

#[allow(clippy::too_many_arguments)]
fn retile_adjacent_roads(
    buildings: &mut [u8],
    terrain: &[u8],
    zones: &[u8],
    flags: &[u8],
    misc: &mut [u8],
    text_overlays: &[u8],
    point: Vec2i,
    edge: i64,
) {
    for offset in DIRECTIONS {
        let neighbor = point + offset;

        if super::in_bounds(neighbor, edge) {
            network::retile_surface(buildings, terrain, zones, flags, misc, neighbor, MODE_ROAD, text_overlays, edge);
        }
    }
}
