//! View rotation, as CityRotationCommand. Rotation rewrites the saved city
//! coordinates, the tile numbers that hold a direction, and the thing records.

use crate::sim::bytes::{read_u32_be, write_u32_be};
use crate::sim::city::City;
use crate::sim::geom::Vec2i;
use crate::sim::grid;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::ids::underground_tile_ids as under;
use crate::sim::things;
use crate::sim::value::{ToValue, Value};

const FLIP_FLAG: u8 = 0x02;

#[derive(Clone, Debug, Default)]
pub struct RotationResult {
    pub old_compass: i64,
    pub new_compass: i64,
}

impl ToValue for RotationResult {
    fn to_value(&self) -> Value {
        Value::Dict(vec![
            (Value::Str("old_compass".into()), Value::Int(self.old_compass)),
            (Value::Str("new_compass".into()), Value::Int(self.new_compass)),
        ])
    }
}

/// Rotate the city one quarter turn. The caller checks the chunk sizes.
/// Only the chunks that change are marked written.
pub fn rotate(city: &mut City, counter_clockwise: bool) -> RotationResult {
    let map_edge = city.map_size;
    let surface_table = surface_table(counter_clockwise);

    let altitude = rotate_grid(&city.altm.data, map_edge, 2, counter_clockwise);
    let original = std::mem::replace(&mut city.altm.data, altitude);
    city.altm.commit_if_changed(&original);

    let terrain = rotate_byte_grid(&city.xter.data, map_edge, counter_clockwise, &terrain_table(counter_clockwise));
    let original = std::mem::replace(&mut city.xter.data, terrain);
    city.xter.commit_if_changed(&original);

    let original_buildings = city.xbld.data.clone();
    city.xbld.data = rotate_byte_grid(&city.xbld.data, map_edge, counter_clockwise, &surface_table);

    let original_zones = std::mem::take(&mut city.xzon.data);
    city.xzon.data = rotate_grid(&original_zones, map_edge, 1, counter_clockwise);

    let underground = rotate_byte_grid(&city.xund.data, map_edge, counter_clockwise, &underground_table(counter_clockwise));
    let original = std::mem::replace(&mut city.xund.data, underground);
    city.xund.commit_if_changed(&original);

    let cells = (map_edge * map_edge) as usize;
    let text = &city.xtxt.data;
    let mut rotated_text = rotate_grid(&text[..cells.min(text.len())], map_edge, 1, counter_clockwise);

    if text.len() > cells {
        rotated_text.extend(rotate_grid(&text[cells..], map_edge, 1, counter_clockwise));
    }

    let original = std::mem::replace(&mut city.xtxt.data, rotated_text);
    city.xtxt.commit_if_changed(&original);

    let original_flags = std::mem::take(&mut city.xbit.data);
    city.xbit.data = rotate_grid(&original_flags, map_edge, 1, counter_clockwise);

    let original_misc = city.misc.data.clone();
    rotate_surface_tile_counts(&mut city.misc.data, &surface_table);
    rotate_special_surface(
        &mut city.xbld.data,
        &city.xzon.data,
        &mut city.xbit.data,
        &mut city.misc.data,
        &surface_table,
        counter_clockwise,
    );
    city.xbld.commit_if_changed(&original_buildings);
    city.xzon.commit_if_changed(&original_zones);
    city.xbit.commit_if_changed(&original_flags);

    for chunk in [
        &mut city.xtrf,
        &mut city.xplt,
        &mut city.xval,
        &mut city.xcrm,
        &mut city.xplc,
        &mut city.xfir,
        &mut city.xpop,
        &mut city.xrog,
    ] {
        let edge = grid::edge(&chunk.data, map_edge);
        let rotated = rotate_grid(&chunk.data, edge, 1, counter_clockwise);
        let original = std::mem::replace(&mut chunk.data, rotated);
        chunk.commit_if_changed(&original);
    }

    let original_things = city.xthg.data.clone();
    rotate_things(&mut city.xthg.data, counter_clockwise, map_edge);
    city.xthg.commit_if_changed(&original_things);

    let old_compass = read_u32_be(&city.misc.data, misc_layout::COMPASS) & 3;
    let new_compass = (old_compass + if counter_clockwise { 1 } else { 3 }) & 3;
    write_u32_be(&mut city.misc.data, misc_layout::COMPASS, new_compass);
    city.misc.commit_if_changed(&original_misc);

    RotationResult { old_compass, new_compass }
}

/// Where a map point goes after one quarter turn, or (-1, -1) outside the map.
pub fn rotate_point(point: Vec2i, size: i64, counter_clockwise: bool) -> Vec2i {
    if size < 1 || point.x < 0 || point.x >= size || point.y < 0 || point.y >= size {
        return Vec2i::NONE;
    }

    if counter_clockwise {
        Vec2i::new(point.y, size - 1 - point.x)
    } else {
        Vec2i::new(size - 1 - point.y, point.x)
    }
}

/// Rotate a grid of `record_size` byte records. A grid that is not `size` by
/// `size` records keeps its other bytes as zero, as the GDScript rotation did.
fn rotate_grid(input: &[u8], size: i64, record_size: usize, counter_clockwise: bool) -> Vec<u8> {
    let mut output = vec![0; input.len()];
    let size = size.max(0) as usize;

    if size * size * record_size > input.len() {
        return rotate_grid_checked(input, size, record_size, counter_clockwise);
    }

    // scan x first to match the original rotation order
    for old_x in 0..size {
        for old_y in 0..size {
            let (x, y) = if counter_clockwise {
                (old_y, size - 1 - old_x)
            } else {
                (size - 1 - old_y, old_x)
            };
            let source = (old_x * size + old_y) * record_size;
            let destination = (x * size + y) * record_size;
            output[destination..destination + record_size].copy_from_slice(&input[source..source + record_size]);
        }
    }

    output
}

/// A short grid. GDScript reads past the end as an error; keep the bytes that exist.
fn rotate_grid_checked(input: &[u8], size: usize, record_size: usize, counter_clockwise: bool) -> Vec<u8> {
    let mut output = vec![0; input.len()];

    for old_x in 0..size {
        for old_y in 0..size {
            let (x, y) = if counter_clockwise {
                (old_y, size - 1 - old_x)
            } else {
                (size - 1 - old_y, old_x)
            };
            let source = (old_x * size + old_y) * record_size;
            let destination = (x * size + y) * record_size;

            for byte in 0..record_size {
                if source + byte < input.len() && destination + byte < output.len() {
                    output[destination + byte] = input[source + byte];
                }
            }
        }
    }

    output
}

fn rotate_byte_grid(input: &[u8], size: i64, counter_clockwise: bool, mapping: &[u8]) -> Vec<u8> {
    let mut output = rotate_grid(input, size, 1, counter_clockwise);

    for value in &mut output {
        if (*value as usize) < mapping.len() {
            *value = mapping[*value as usize];
        }
    }

    output
}

fn identity_table(size: i64) -> Vec<u8> {
    (0..size).map(|index| index as u8).collect()
}

fn swap(table: &mut [u8], first: i64, second: i64) {
    table[first as usize] = second as u8;
    table[second as usize] = first as u8;
}

fn set_cycle(table: &mut [u8], cycle: [i64; 4], counter_clockwise: bool) {
    for index in 0..4 {
        let target = if counter_clockwise { index + 3 } else { index + 1 };
        table[cycle[index] as usize] = cycle[target % 4] as u8;
    }
}

/// The surface tile number has a direction baked into it too.
pub fn surface_table(counter_clockwise: bool) -> Vec<u8> {
    let mut table = identity_table(tiles::COUNT);

    for (first, second) in [
        (tiles::POWER_LINE_STRAIGHT_1, tiles::POWER_LINE_STRAIGHT_2),
        (tiles::ROAD_STRAIGHT_1, tiles::ROAD_STRAIGHT_2),
        (tiles::RAIL_STRAIGHT_1, tiles::RAIL_STRAIGHT_2),
        (tiles::ROAD_POWER_CROSSING_1, tiles::ROAD_POWER_CROSSING_2),
        (tiles::ROAD_RAIL_CROSSING_1, tiles::ROAD_RAIL_CROSSING_2),
        (tiles::RAIL_POWER_CROSSING_1, tiles::RAIL_POWER_CROSSING_2),
        (tiles::HIGHWAY_STRAIGHT_1, tiles::HIGHWAY_STRAIGHT_2),
        (tiles::HIGHWAY_ROAD_CROSSING_1, tiles::HIGHWAY_ROAD_CROSSING_2),
        (tiles::HIGHWAY_RAIL_CROSSING_1, tiles::HIGHWAY_RAIL_CROSSING_2),
        (tiles::HIGHWAY_POWER_CROSSING_1, tiles::HIGHWAY_POWER_CROSSING_2),
        (tiles::SUSPENSION_BRIDGE_1, tiles::SUSPENSION_BRIDGE_5),
        (tiles::SUSPENSION_BRIDGE_2, tiles::SUSPENSION_BRIDGE_4),
    ] {
        swap(&mut table, first, second);
    }

    for cycle in [
        [
            tiles::POWER_LINE_SLOPE_1,
            tiles::POWER_LINE_SLOPE_2,
            tiles::POWER_LINE_SLOPE_3,
            tiles::POWER_LINE_SLOPE_4,
        ],
        [
            tiles::POWER_LINE_CURVE_1,
            tiles::POWER_LINE_CURVE_2,
            tiles::POWER_LINE_CURVE_3,
            tiles::POWER_LINE_CURVE_4,
        ],
        [
            tiles::POWER_LINE_JUNCTION_1,
            tiles::POWER_LINE_JUNCTION_2,
            tiles::POWER_LINE_JUNCTION_3,
            tiles::POWER_LINE_JUNCTION_4,
        ],
        [tiles::ROAD_SLOPE_1, tiles::ROAD_SLOPE_2, tiles::ROAD_SLOPE_3, tiles::ROAD_SLOPE_4],
        [tiles::ROAD_CURVE_1, tiles::ROAD_CURVE_2, tiles::ROAD_CURVE_3, tiles::ROAD_CURVE_4],
        [
            tiles::ROAD_JUNCTION_1,
            tiles::ROAD_JUNCTION_2,
            tiles::ROAD_JUNCTION_3,
            tiles::ROAD_JUNCTION_4,
        ],
        [tiles::RAIL_SLOPE_1, tiles::RAIL_SLOPE_2, tiles::RAIL_SLOPE_3, tiles::RAIL_SLOPE_4],
        [tiles::RAIL_CURVE_1, tiles::RAIL_CURVE_2, tiles::RAIL_CURVE_3, tiles::RAIL_CURVE_4],
        [
            tiles::RAIL_JUNCTION_1,
            tiles::RAIL_JUNCTION_2,
            tiles::RAIL_JUNCTION_3,
            tiles::RAIL_JUNCTION_4,
        ],
        [tiles::RAIL_SLOPE_5, tiles::RAIL_SLOPE_6, tiles::RAIL_SLOPE_7, tiles::RAIL_SLOPE_8],
        [
            tiles::TUNNEL_ENTRANCE_1,
            tiles::TUNNEL_ENTRANCE_2,
            tiles::TUNNEL_ENTRANCE_3,
            tiles::TUNNEL_ENTRANCE_4,
        ],
        [
            tiles::HIGHWAY_SLOPE_1,
            tiles::HIGHWAY_SLOPE_2,
            tiles::HIGHWAY_SLOPE_3,
            tiles::HIGHWAY_SLOPE_4,
        ],
        [
            tiles::HIGHWAY_CURVE_1,
            tiles::HIGHWAY_CURVE_2,
            tiles::HIGHWAY_CURVE_3,
            tiles::HIGHWAY_CURVE_4,
        ],
        [
            tiles::RAIL_SUBWAY_ENTRANCE_1,
            tiles::RAIL_SUBWAY_ENTRANCE_2,
            tiles::RAIL_SUBWAY_ENTRANCE_3,
            tiles::RAIL_SUBWAY_ENTRANCE_4,
        ],
    ] {
        set_cycle(&mut table, cycle, counter_clockwise);
    }

    table
}

/// Four turns do not recover unused terrain numbers. They become flat land.
pub fn terrain_table(counter_clockwise: bool) -> Vec<u8> {
    let mut table = identity_table(terrain_ids::ROTATION_TABLE_SIZE);

    for invalid in [
        terrain_ids::UNUSED_0E,
        terrain_ids::UNUSED_0F,
        terrain_ids::UNUSED_1E,
        terrain_ids::UNUSED_1F,
        terrain_ids::UNUSED_2F,
        terrain_ids::UNUSED_3F,
        terrain_ids::UNUSED_46,
        terrain_ids::UNUSED_47,
    ] {
        table[invalid as usize] = terrain_ids::FLAT as u8;
    }

    swap(&mut table, terrain_ids::CHANNEL_NS, terrain_ids::CHANNEL_EW);

    for cycle in [
        [
            terrain_ids::SLOPE_TOP_LEFT,
            terrain_ids::SLOPE_TOP_RIGHT,
            terrain_ids::SLOPE_BOTTOM_RIGHT,
            terrain_ids::SLOPE_BOTTOM_LEFT,
        ],
        [
            terrain_ids::RAISED_EXCEPT_BOTTOM,
            terrain_ids::RAISED_EXCEPT_LEFT,
            terrain_ids::RAISED_EXCEPT_TOP,
            terrain_ids::RAISED_EXCEPT_RIGHT,
        ],
        [
            terrain_ids::CORNER_TOP,
            terrain_ids::CORNER_RIGHT,
            terrain_ids::CORNER_BOTTOM,
            terrain_ids::CORNER_LEFT,
        ],
        [
            terrain_ids::DEEP_WATER_SLOPE_TOP_LEFT,
            terrain_ids::DEEP_WATER_SLOPE_TOP_RIGHT,
            terrain_ids::DEEP_WATER_SLOPE_BOTTOM_RIGHT,
            terrain_ids::DEEP_WATER_SLOPE_BOTTOM_LEFT,
        ],
        [
            terrain_ids::DEEP_WATER_RAISED_EXCEPT_BOTTOM,
            terrain_ids::DEEP_WATER_RAISED_EXCEPT_LEFT,
            terrain_ids::DEEP_WATER_RAISED_EXCEPT_TOP,
            terrain_ids::DEEP_WATER_RAISED_EXCEPT_RIGHT,
        ],
        [
            terrain_ids::DEEP_WATER_CORNER_TOP,
            terrain_ids::DEEP_WATER_CORNER_RIGHT,
            terrain_ids::DEEP_WATER_CORNER_BOTTOM,
            terrain_ids::DEEP_WATER_CORNER_LEFT,
        ],
        [
            terrain_ids::SHORE_SLOPE_TOP_LEFT,
            terrain_ids::SHORE_SLOPE_TOP_RIGHT,
            terrain_ids::SHORE_SLOPE_BOTTOM_RIGHT,
            terrain_ids::SHORE_SLOPE_BOTTOM_LEFT,
        ],
        [
            terrain_ids::SHORE_RAISED_EXCEPT_BOTTOM,
            terrain_ids::SHORE_RAISED_EXCEPT_LEFT,
            terrain_ids::SHORE_RAISED_EXCEPT_TOP,
            terrain_ids::SHORE_RAISED_EXCEPT_RIGHT,
        ],
        [
            terrain_ids::SHORE_CORNER_TOP,
            terrain_ids::SHORE_CORNER_RIGHT,
            terrain_ids::SHORE_CORNER_BOTTOM,
            terrain_ids::SHORE_CORNER_LEFT,
        ],
        [
            terrain_ids::SURFACE_WATER_NES,
            terrain_ids::SURFACE_WATER_ESW,
            terrain_ids::SURFACE_WATER_NSW,
            terrain_ids::SURFACE_WATER_NEW,
        ],
        [
            terrain_ids::SURFACE_WATER_ES,
            terrain_ids::SURFACE_WATER_SW,
            terrain_ids::SURFACE_WATER_NW,
            terrain_ids::SURFACE_WATER_NE,
        ],
        [
            terrain_ids::SURFACE_WATER_BANK_NW,
            terrain_ids::SURFACE_WATER_BANK_NE,
            terrain_ids::SURFACE_WATER_BANK_SE,
            terrain_ids::SURFACE_WATER_BANK_SW,
        ],
        [
            terrain_ids::CHANNEL_E,
            terrain_ids::CHANNEL_S,
            terrain_ids::CHANNEL_W,
            terrain_ids::CHANNEL_N,
        ],
    ] {
        set_cycle(&mut table, cycle, counter_clockwise);
    }

    table
}

pub fn underground_table(counter_clockwise: bool) -> Vec<u8> {
    let mut table = identity_table(under::ROTATION_TABLE_SIZE);

    for invalid in [under::UNUSED_24, under::UNUSED_25, under::UNUSED_26, under::UNUSED_27] {
        table[invalid as usize] = under::EMPTY as u8;
    }

    for (first, second) in [
        (under::SUBWAY_LR, under::SUBWAY_TB),
        (under::PIPE_LR, under::PIPE_TB),
        (under::PIPE_TB_SUBWAY_LR, under::PIPE_LR_SUBWAY_TB),
    ] {
        swap(&mut table, first, second);
    }

    for cycle in [
        [under::SUBWAY_HTB, under::SUBWAY_LHR, under::SUBWAY_THB, under::SUBWAY_HLR],
        [under::SUBWAY_BR, under::SUBWAY_BL, under::SUBWAY_TL, under::SUBWAY_TR],
        [under::SUBWAY_RTB, under::SUBWAY_LBR, under::SUBWAY_TLB, under::SUBWAY_LTR],
        [under::PIPE_HTB, under::PIPE_LHR, under::PIPE_THB, under::PIPE_HLR],
        [under::PIPE_BR, under::PIPE_BL, under::PIPE_TL, under::PIPE_TR],
        [under::PIPE_RTB, under::PIPE_LBR, under::PIPE_TLB, under::PIPE_LTR],
    ] {
        set_cycle(&mut table, cycle, counter_clockwise);
    }

    table
}

/// Orientation of ramps and bridges uses both the tile number and the flip bit.
fn rotate_special_surface(
    buildings: &mut [u8],
    zones: &[u8],
    flags: &mut [u8],
    misc: &mut [u8],
    surface_table: &[u8],
    counter_clockwise: bool,
) {
    let ramp_tiles = if counter_clockwise {
        [
            tiles::HIGHWAY_ONRAMP_2,
            tiles::HIGHWAY_ONRAMP_1,
            tiles::HIGHWAY_ONRAMP_4,
            tiles::HIGHWAY_ONRAMP_3,
            tiles::HIGHWAY_ONRAMP_4,
            tiles::HIGHWAY_ONRAMP_3,
            tiles::HIGHWAY_ONRAMP_2,
            tiles::HIGHWAY_ONRAMP_1,
        ]
    } else {
        [
            tiles::HIGHWAY_ONRAMP_4,
            tiles::HIGHWAY_ONRAMP_3,
            tiles::HIGHWAY_ONRAMP_2,
            tiles::HIGHWAY_ONRAMP_1,
            tiles::HIGHWAY_ONRAMP_2,
            tiles::HIGHWAY_ONRAMP_1,
            tiles::HIGHWAY_ONRAMP_4,
            tiles::HIGHWAY_ONRAMP_3,
        ]
    };
    let not_flipped = !flag_bits::FLIPPED as u8;

    for index in 0..buildings.len() {
        let tile = buildings[index] as i64;
        let flipped = flags[index] & FLIP_FLAG != 0;

        if (tiles::HIGHWAY_ONRAMP_1..=tiles::HIGHWAY_ONRAMP_4).contains(&tile) {
            let ramp_index = (tile - tiles::HIGHWAY_ONRAMP_1) as usize + if flipped { 4 } else { 0 };
            replace_building(buildings, zones, misc, index, ramp_tiles[ramp_index]);
            flags[index] = (flags[index] & not_flipped) | if ramp_index < 4 { FLIP_FLAG } else { 0 };
            continue;
        }

        if !((tiles::SUSPENSION_BRIDGE_1..=tiles::POWER_BRIDGE).contains(&tile)
            || tile == tiles::HIGHWAY_BRIDGE
            || tile == tiles::REINFORCED_HIGHWAY_BRIDGE)
        {
            continue;
        }

        if flipped {
            flags[index] &= not_flipped;

            if !counter_clockwise {
                replace_building(buildings, zones, misc, index, surface_table[tile as usize] as i64);
            }
        } else {
            flags[index] |= FLIP_FLAG;

            if counter_clockwise {
                replace_building(buildings, zones, misc, index, surface_table[tile as usize] as i64);
            }
        }
    }
}

/// Rotate the road counts too, or MISC disagrees with XBLD.
fn rotate_surface_tile_counts(misc: &mut [u8], surface_table: &[u8]) {
    let old_counts = (0..tiles::DEVELOPED_FIRST)
        .map(|tile| read_u32_be(misc, misc_layout::TILE_COUNTS + tile * 4))
        .collect::<Vec<i64>>();

    for tile in 0..tiles::DEVELOPED_FIRST {
        write_u32_be(
            misc,
            misc_layout::TILE_COUNTS + surface_table[tile as usize] as i64 * 4,
            old_counts[tile as usize],
        );
    }
}

/// Counts wrap at 16 bits on the 128 map. Military tiles do not count.
pub fn replace_building(buildings: &mut [u8], zones: &[u8], misc: &mut [u8], index: usize, new_tile: i64) {
    let old_tile = buildings[index] as i64;

    if old_tile == new_tile {
        return;
    }

    if zones[index] as i64 & zone::TYPE_MASK != zone::MILITARY {
        let mask = if buildings.len() == 16384 { 0xffff } else { 0xffff_ffff };
        let old_offset = misc_layout::TILE_COUNTS + old_tile * 4;
        let new_offset = misc_layout::TILE_COUNTS + new_tile * 4;
        write_u32_be(misc, old_offset, (read_u32_be(misc, old_offset) - 1) & mask);
        write_u32_be(misc, new_offset, (read_u32_be(misc, new_offset) + 1) & mask);
    }

    buildings[index] = new_tile as u8;
}

/// These bytes are coordinates until the object decides that they are not.
fn rotate_things(data: &mut [u8], counter_clockwise: bool, map_edge: i64) {
    let edge = map_edge - 1;

    for record in 1..things::count(data) {
        let offset = record * things::RECORD_SIZE;
        let kind = things::read(data, offset);

        if kind == 0 {
            continue;
        }

        if kind == things::TYPE_SHIP && map_edge > 128 {
            let home = things::ship_home(data, record, Vec2i::NONE);
            let rotated = if counter_clockwise {
                Vec2i::new(home.y, edge - home.x)
            } else {
                Vec2i::new(edge - home.y, home.x)
            };
            things::set_ship_home(data, record, rotated);
        }

        rotate_pair(data, offset + things::FIELD_X, counter_clockwise, edge);

        if (things::TYPE_TRAIN_ENGINE..=things::TYPE_SUBWAY_CAR).contains(&kind) {
            let turn = if counter_clockwise { -1 } else { 1 };
            things::write(data, offset + 1, (things::read(data, offset + 1) + turn) & 3);
            things::write(data, offset + 8, (things::read(data, offset + 8) + turn * 2) & 7);
            rotate_pair(data, offset + things::FIELD_PX, counter_clockwise, edge);
            continue;
        }

        things::write(
            data,
            offset + 1,
            (things::read(data, offset + 1) + if counter_clockwise { -2 } else { 2 }) & 7,
        );
        rotate_pair(data, offset + things::FIELD_DX, counter_clockwise, edge);

        if kind == things::TYPE_AIRPLANE {
            let turn = if counter_clockwise { -0x20 } else { 0x20 };
            let state = things::read(data, offset + 2);
            things::write(data, offset + 2, ((state + turn) & 0x70) | (state & 0x0f));
        }
    }
}

/// Rotate the (x, y) coordinate pair at `index` and `index + 1`.
fn rotate_pair(data: &mut [u8], index: i64, counter_clockwise: bool, edge: i64) {
    let old_x = things::read(data, index);
    let old_y = things::read(data, index + 1);

    if counter_clockwise {
        things::write(data, index, old_y);
        things::write(data, index + 1, edge - old_x);
    } else {
        things::write(data, index, edge - old_y);
        things::write(data, index + 1, old_x);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn is_permutation(table: &[u8]) -> bool {
        let mut seen = vec![false; table.len()];

        table
            .iter()
            .all(|&value| (value as usize) < table.len() && !std::mem::replace(&mut seen[value as usize], true))
    }

    #[test]
    fn points_turn_back_after_opposite_turns() {
        for size in [1, 2, 128, 1024] {
            for point in [Vec2i::new(0, 0), Vec2i::new(size - 1, 0), Vec2i::new(0, size - 1)] {
                let turned = rotate_point(point, size, false);

                assert_eq!(rotate_point(turned, size, true), point);
            }
        }

        assert_eq!(rotate_point(Vec2i::new(0, 0), 128, false), Vec2i::new(127, 0));
        assert_eq!(rotate_point(Vec2i::new(0, 0), 128, true), Vec2i::new(0, 127));
        assert_eq!(rotate_point(Vec2i::new(128, 0), 128, true), Vec2i::NONE);
    }

    #[test]
    fn surface_and_underground_tables_undo_each_other() {
        for (clockwise, counter) in [
            (surface_table(false), surface_table(true)),
            (underground_table(false)[..0x24].to_vec(), underground_table(true)[..0x24].to_vec()),
        ] {
            assert!(is_permutation(&clockwise));

            for (tile, &turned) in clockwise.iter().enumerate() {
                assert_eq!(counter[turned as usize] as usize, tile);
            }
        }

        assert_eq!(surface_table(false)[tiles::ROAD_STRAIGHT_1 as usize] as i64, tiles::ROAD_STRAIGHT_2);
        assert_eq!(surface_table(false)[tiles::ROAD_CURVE_1 as usize] as i64, tiles::ROAD_CURVE_2);
        assert_eq!(surface_table(true)[tiles::ROAD_CURVE_1 as usize] as i64, tiles::ROAD_CURVE_4);
    }

    #[test]
    fn tables_match_the_recovered_game_tables() {
        assert_eq!(surface_table(true)[tiles::ROAD_SLOPE_1 as usize], 0x22);
        assert_eq!(surface_table(false)[tiles::ROAD_SLOPE_1 as usize], 0x20);
        assert_eq!(terrain_table(true)[0x01], 0x04);
        assert_eq!(terrain_table(false)[0x01], 0x02);
        assert_eq!(underground_table(true)[under::SUBWAY_HTB as usize], 0x06);
        assert_eq!(underground_table(false)[under::SUBWAY_HTB as usize], 0x04);
    }

    #[test]
    fn terrain_table_clears_unused_numbers() {
        let table = terrain_table(false);

        assert_eq!(table[terrain_ids::UNUSED_0E as usize] as i64, terrain_ids::FLAT);
        assert_eq!(table[terrain_ids::CHANNEL_NS as usize] as i64, terrain_ids::CHANNEL_EW);
        assert_eq!(table[terrain_ids::SLOPE_TOP_LEFT as usize] as i64, terrain_ids::SLOPE_TOP_RIGHT);
    }

    #[test]
    fn grids_turn_records_and_restore_after_four_turns() {
        let input = (0..32).map(|value| value as u8).collect::<Vec<u8>>();
        let turned = rotate_grid(&input, 4, 2, false);

        assert_eq!(&turned[(3 * 4) * 2..(3 * 4) * 2 + 2], &input[0..2]);

        let mut output = input.clone();

        for _ in 0..4 {
            output = rotate_grid(&output, 4, 2, true);
        }

        assert_eq!(output, input);
    }

    #[test]
    fn ramps_turn_and_keep_counts() {
        let mut buildings = vec![0u8; 16384];
        let zones = vec![0u8; 16384];
        let mut flags = vec![0u8; 16384];
        let mut misc = vec![0u8; misc_layout::SIZE as usize];
        buildings[5] = tiles::HIGHWAY_ONRAMP_1 as u8;
        write_u32_be(&mut misc, misc_layout::TILE_COUNTS + tiles::HIGHWAY_ONRAMP_1 * 4, 1);

        rotate_special_surface(&mut buildings, &zones, &mut flags, &mut misc, &surface_table(false), false);

        assert_eq!(buildings[5] as i64, tiles::HIGHWAY_ONRAMP_4);
        assert_eq!(flags[5], FLIP_FLAG);
        assert_eq!(read_u32_be(&misc, misc_layout::TILE_COUNTS + tiles::HIGHWAY_ONRAMP_1 * 4), 0);
        assert_eq!(read_u32_be(&misc, misc_layout::TILE_COUNTS + tiles::HIGHWAY_ONRAMP_4 * 4), 1);
    }

    #[test]
    fn replaced_tile_counts_wrap_by_map_size() {
        for (cells, expected) in [(16384usize, 0), (65536, 0x1_0000)] {
            let mut buildings = vec![0u8; cells];
            let zones = vec![0u8; cells];
            let mut misc = vec![0u8; misc_layout::SIZE as usize];
            write_u32_be(&mut misc, misc_layout::TILE_COUNTS + 0x1d * 4, 0xffff);

            replace_building(&mut buildings, &zones, &mut misc, cells - 1, 0x1d);

            assert_eq!(read_u32_be(&misc, misc_layout::TILE_COUNTS + 0x1d * 4), expected);
        }
    }
}
