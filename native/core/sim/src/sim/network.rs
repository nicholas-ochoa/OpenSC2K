//! Network membership of building and underground tiles, as NetworkTileMembership.

use super::ids::building_tile_ids as tiles;
use super::ids::underground_tile_ids as under;

/// NetworkTopology: add the offset to the network's first tile ID.
/// The mask bits are north = 1, east = 2, south = 4, and west = 8.
pub const SHAPE_OFFSET_BY_CONNECTION_MASK: [i64; 16] = [0, 0, 1, 6, 0, 0, 7, 11, 1, 9, 1, 10, 8, 13, 12, 14];

#[inline]
pub fn surface_road(tile: i64) -> bool {
    (tiles::FIRST_ROAD..=tiles::LAST_ROAD).contains(&tile)
        || (tiles::TUNNEL_FIRST..=tiles::ROAD_RAIL_CROSSING_2).contains(&tile)
        || tile == tiles::HIGHWAY_ROAD_CROSSING_1
        || tile == tiles::HIGHWAY_ROAD_CROSSING_2
        || (tiles::ONRAMP_FIRST..=tiles::ONRAMP_LAST).contains(&tile)
}

#[inline]
pub fn rail(tile: i64) -> bool {
    (tiles::RAIL_FIRST..=tiles::RAIL_LAST).contains(&tile)
        || (tiles::ROAD_RAIL_CROSSING_1..=tiles::RAIL_POWER_CROSSING_2).contains(&tile)
        || (tiles::RAIL_SUBWAY_FIRST..=tiles::RAIL_SUBWAY_LAST).contains(&tile)
        || tile == tiles::HIGHWAY_RAIL_CROSSING_1
        || tile == tiles::HIGHWAY_RAIL_CROSSING_2
}

#[inline]
pub fn subway(tile: i64) -> bool {
    (tile > under::EMPTY && tile < under::PIPE_FIRST)
        || tile == under::PIPE_TB_SUBWAY_LR
        || tile == under::PIPE_LR_SUBWAY_TB
        || tile == under::MISSILE_SILO
        || tile == under::SUBWAY_ENTRANCE
}
