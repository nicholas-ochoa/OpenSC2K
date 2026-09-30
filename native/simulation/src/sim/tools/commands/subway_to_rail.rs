//! Subway-to-rail connections, as SubwayToRailCommand.

use super::{EditBase, ToolArgs};
use crate::gd_edit_result;
use crate::sim::city::City;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::ids::underground_tile_ids as under;
use crate::sim::tools::network::{self, MODE_RAIL, replace_building};
use crate::sim::tools::underground::place_subway_station;
use crate::sim::value::Ints32;

/// The connector checks its neighbors in this order: east, south, west, north.
const DIRECTIONS: [Vec2i; 4] = [Vec2i::new(1, 0), Vec2i::new(0, 1), Vec2i::new(-1, 0), Vec2i::new(0, -1)];

gd_edit_result! {
    pub struct SubwayToRailResult as "SubwayToRailEditResult" {
        pub tile_id: i64 = tiles::EMPTY,
        pub orientation: i64 = 0,
        pub neighbor: Vec2i = Vec2i::NONE,
    }
}

pub fn apply(city: &mut City, args: &ToolArgs, point: Vec2i, preview_only: bool) -> SubwayToRailResult {
    let edge = city.map_size;
    let index = city.index_of(point.x, point.y);

    if index < 0 {
        return SubwayToRailResult::rejected("connection is outside the city", 0);
    }

    let building = city.xbld.data[index as usize] as i64;

    if building > tiles::TREES_7 || building == tiles::RADIOACTIVE_WASTE {
        return SubwayToRailResult::rejected("connection site contains a protected building", 0);
    }

    if city.xter.data[index as usize] as i64 != terrain_ids::FLAT {
        return SubwayToRailResult::rejected("connection site is not clear terrain", 0);
    }

    // A surface rail neighbor sets the orientation. Otherwise a subway neighbor
    // sets the opposite orientation.
    let mut found = DIRECTIONS.iter().enumerate().find_map(|(direction, offset)| {
        let checked = point + *offset;

        (city.index_of(checked.x, checked.y) >= 0 && surface_rail_connects(city.building_id(checked.x, checked.y)))
            .then_some((checked, direction as i64))
    });

    if found.is_none() {
        found = DIRECTIONS.iter().enumerate().find_map(|(direction, offset)| {
            let checked = point + *offset;

            (city.index_of(checked.x, checked.y) >= 0 && subway_connects(city.underground_id(checked.x, checked.y)))
                .then_some((checked, (direction as i64 + 2) & 3))
        });
    }

    let Some((neighbor, orientation)) = found else {
        return SubwayToRailResult::rejected("connection requires an adjacent rail or subway", 0);
    };

    if preview_only {
        return SubwayToRailResult {
            base: EditBase {
                ok: true,
                ..Default::default()
            },
            ..Default::default()
        };
    }

    if city.missing_or_resized(&super::building::PAYLOAD_IDS).is_some() {
        return SubwayToRailResult::rejected("required city data is missing or invalid", 0);
    }

    let tile = tiles::RAIL_SUBWAY_ENTRANCE_1 + orientation;
    let maps = city.maps();

    place_subway_station(maps.underground, maps.terrain, maps.zones, maps.flags, maps.misc, point, edge);
    replace_building(maps.buildings, maps.zones, maps.misc, index, tile);
    maps.zones[index as usize] |= zone::CORNERS_MASK as u8;
    network::retile_surface(
        maps.buildings,
        maps.terrain,
        maps.zones,
        maps.flags,
        maps.misc,
        neighbor,
        MODE_RAIL,
        maps.text_overlays,
        edge,
    );

    let mut result = SubwayToRailResult {
        base: EditBase::accepted("subway_to_rail", args.group, args.subtool),
        tile_id: tile,
        orientation,
        neighbor,
    };
    result.base.tile_indices = Ints32(vec![index as i32]);
    result.base.listed_cost = args.cost;

    result
}

fn surface_rail_connects(tile: i64) -> bool {
    (tiles::RAIL_STRAIGHT_1..=tiles::RAIL_SLOPE_8).contains(&tile)
        || (tiles::ROAD_RAIL_CROSSING_1..=tiles::RAIL_POWER_CROSSING_2).contains(&tile)
        || (tiles::RAIL_SUBWAY_ENTRANCE_1..=tiles::RAIL_SUBWAY_ENTRANCE_4).contains(&tile)
}

fn subway_connects(tile: i64) -> bool {
    (under::SUBWAY_LR..=under::SUBWAY_LTBR).contains(&tile)
        || tile == under::PIPE_TB_SUBWAY_LR
        || tile == under::PIPE_LR_SUBWAY_TB
        || tile == under::MISSILE_SILO
        || tile == under::SUBWAY_ENTRANCE
}
