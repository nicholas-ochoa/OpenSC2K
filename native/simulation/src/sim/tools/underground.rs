//! Underground pipes and subways, as BuildingUnderground.

use super::network::allows_connection;
use crate::sim::bytes::{read_u32_be, write_u32_be};
use crate::sim::geom::Vec2i;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::ids::underground_tile_ids as under;
use crate::sim::network::SHAPE_OFFSET_BY_CONNECTION_MASK as NETWORK_SHAPES;

const FORCED_TERRAIN_SHAPES: [i64; 16] = [0, 2, 3, 4, 5, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1];

fn forced_terrain(shape: i64) -> bool {
    matches!(shape, 1 | 2 | 3 | 4 | 9 | 10 | 11 | 12)
}

pub fn is_subway_tile(tile: i64) -> bool {
    (tile > under::EMPTY && tile < under::PIPE_FIRST)
        || tile == under::PIPE_TB_SUBWAY_LR
        || tile == under::PIPE_LR_SUBWAY_TB
        || tile == under::MISSILE_SILO
        || tile == under::SUBWAY_ENTRANCE
}

/// BuildingUnderground._replace_underground: keep the subway count outside
/// military zones.
pub fn replace_underground(underground: &mut [u8], zones: &[u8], misc: &mut [u8], index: i64, new_tile: i64) {
    let old_tile = underground[index as usize] as i64;

    if old_tile == new_tile {
        return;
    }

    if zones[index as usize] as i64 & zone::TYPE_MASK != zone::MILITARY {
        let mask = super::network::count_mask(underground.len());
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

pub fn underground_connects(tile: i64, pipes: bool) -> bool {
    if pipes {
        return (under::PIPE_FIRST..=under::PIPE_LAST).contains(&tile)
            || tile == under::PIPE_TB_SUBWAY_LR
            || tile == under::PIPE_LR_SUBWAY_TB;
    }

    (under::SUBWAY_FIRST..=under::SUBWAY_LAST).contains(&tile)
        || tile == under::SUBWAY_ENTRANCE
        || tile == under::PIPE_TB_SUBWAY_LR
        || tile == under::PIPE_LR_SUBWAY_TB
        || tile == under::MISSILE_SILO
}

pub fn retile_neighborhood(underground: &mut [u8], terrain: &[u8], point: Vec2i, pipes: bool, map_edge: i64) {
    retile_underground(underground, terrain, point, pipes, map_edge);

    for offset in [Vec2i::new(-1, 0), Vec2i::new(1, 0), Vec2i::new(0, -1), Vec2i::new(0, 1)] {
        let near = point + offset;

        if near.x >= 0 && near.x < map_edge && near.y >= 0 && near.y < map_edge {
            retile_underground(underground, terrain, near, pipes, map_edge);
        }
    }
}

pub fn retile_underground(underground: &mut [u8], terrain: &[u8], point: Vec2i, pipes: bool, map_edge: i64) {
    let index = (point.x * map_edge + point.y) as usize;
    let current = underground[index] as i64;

    if pipes {
        if !(under::PIPE_FIRST..=under::PIPE_LAST).contains(&current) {
            return;
        }
    } else if !(under::SUBWAY_FIRST..=under::SUBWAY_LAST).contains(&current) {
        return;
    }

    let terrain_shape = if terrain[index] as i64 <= terrain_ids::SURFACE_WATER_FIRST {
        terrain[index] as i64 & terrain_ids::SHAPE_MASK
    } else {
        0
    };
    let base = if pipes { under::PIPE_FIRST } else { under::SUBWAY_FIRST };

    if forced_terrain(terrain_shape) {
        underground[index] = (base + FORCED_TERRAIN_SHAPES[terrain_shape as usize]) as u8;

        return;
    }

    let mut connections = 0;

    if point.x > 0 {
        let west = ((point.x - 1) * map_edge + point.y) as usize;

        if underground_connects(underground[west] as i64, pipes) && allows_connection(terrain[west] as i64, 1) {
            connections |= 8;
        }
    }

    if point.x < map_edge - 1 {
        let east = ((point.x + 1) * map_edge + point.y) as usize;

        if underground_connects(underground[east] as i64, pipes) && allows_connection(terrain[east] as i64, 1) {
            connections |= 2;
        }
    }

    if point.y > 0 {
        let north = (point.x * map_edge + point.y - 1) as usize;

        if underground_connects(underground[north] as i64, pipes) && allows_connection(terrain[north] as i64, 0) {
            connections |= 1;
        }
    }

    if point.y < map_edge - 1 {
        let south = (point.x * map_edge + point.y + 1) as usize;

        if underground_connects(underground[south] as i64, pipes) && allows_connection(terrain[south] as i64, 0) {
            connections |= 4;
        }
    }

    if pipes && connections == 0 {
        connections = 15;
    }

    underground[index] = (base + NETWORK_SHAPES[connections as usize]) as u8;
}
