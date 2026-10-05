//! Network tiles on the ground and under it, as NetworkTiles.

use super::rules::{reuses_surface, reuses_underground};
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::underground_tile_ids as under;
use crate::sim::tools::Maps;
use crate::sim::tools::network::{
    MODE_PIPE, MODE_POWER, MODE_RAIL, MODE_ROAD, MODE_SUBWAY, grade_surface_terrain, replace_building, retile_surface_neighborhood,
};

use crate::sim::tools::underground::{replace_underground, retile_neighborhood};

/// NetworkTiles._surface_replacement: the tile that a new network makes of an
/// existing one, or -1 when it cannot cross it.
fn surface_replacement(old_tile: i64, mode: i64) -> i64 {
    use tiles::*;

    if old_tile < POWER_LINE_FIRST {
        return match mode {
            MODE_ROAD => FIRST_ROAD,
            MODE_RAIL => RAIL_FIRST,
            _ => POWER_LINE_FIRST,
        };
    }

    match (mode, old_tile) {
        (MODE_ROAD, POWER_LINE_FIRST) => ROAD_POWER_CROSSING_2,
        (MODE_ROAD, POWER_LINE_STRAIGHT_2) => ROAD_POWER_CROSSING_1,
        (MODE_ROAD, RAIL_FIRST) => ROAD_RAIL_CROSSING_2,
        (MODE_ROAD, RAIL_STRAIGHT_2) => ROAD_RAIL_CROSSING_1,
        (MODE_ROAD, HIGHWAY_STRAIGHT_1) => HIGHWAY_ROAD_CROSSING_1,
        (MODE_ROAD, HIGHWAY_STRAIGHT_2) => HIGHWAY_ROAD_CROSSING_2,
        (MODE_RAIL, POWER_LINE_FIRST) => RAIL_POWER_CROSSING_2,
        (MODE_RAIL, POWER_LINE_STRAIGHT_2) => RAIL_POWER_CROSSING_1,
        (MODE_RAIL, FIRST_ROAD) => ROAD_RAIL_CROSSING_1,
        (MODE_RAIL, ROAD_STRAIGHT_2) => ROAD_RAIL_CROSSING_2,
        (MODE_RAIL, HIGHWAY_STRAIGHT_1) => HIGHWAY_RAIL_CROSSING_1,
        (MODE_RAIL, HIGHWAY_STRAIGHT_2) => HIGHWAY_RAIL_CROSSING_2,
        (MODE_POWER, FIRST_ROAD) => ROAD_POWER_CROSSING_1,
        (MODE_POWER, ROAD_STRAIGHT_2) => ROAD_POWER_CROSSING_2,
        (MODE_POWER, RAIL_FIRST) => RAIL_POWER_CROSSING_1,
        (MODE_POWER, RAIL_STRAIGHT_2) => RAIL_POWER_CROSSING_2,
        (MODE_POWER, HIGHWAY_STRAIGHT_1) => HIGHWAY_POWER_CROSSING_1,
        (MODE_POWER, HIGHWAY_STRAIGHT_2) => HIGHWAY_POWER_CROSSING_2,
        _ => -1,
    }
}

/// NetworkTiles._place_surface: grade the ground, place the network tile, and
/// retile the tile and its neighbors. A bridge bank retiles without the
/// connection labels.
pub fn place_surface(maps: &mut Maps, point: Vec2i, mode: i64, direction: i64, with_labels: bool) {
    let edge = maps.map_edge;
    let index = point.x * edge + point.y;
    let i = index as usize;

    if reuses_surface(maps.buildings[i] as i64, mode) {
        return;
    }

    grade_surface_terrain(maps.terrain, maps.flags, point, direction, edge);
    let new_tile = surface_replacement(maps.buildings[i] as i64, mode);

    if new_tile < 0 {
        return;
    }

    replace_building(maps.buildings, maps.zones, maps.misc, index, new_tile);

    if mode == MODE_POWER {
        maps.flags[i] |= flag_bits::POWERABLE as u8;
    } else {
        maps.zones[i] &= zone::CORNERS_MASK as u8;
    }

    let labels: &[u8] = if with_labels { maps.text_overlays } else { &[] };
    retile_surface_neighborhood(
        maps.buildings,
        maps.terrain,
        maps.zones,
        maps.flags,
        maps.misc,
        point,
        mode,
        labels,
        edge,
    );
}

/// NetworkTiles._place_underground: a pipe or subway, crossing the other network.
pub fn place_underground(maps: &mut Maps, point: Vec2i, pipes: bool, direction: i64) {
    let edge = maps.map_edge;
    let index = point.x * edge + point.y;
    let i = index as usize;
    let old_tile = maps.underground[i] as i64;

    if reuses_underground(old_tile, if pipes { MODE_PIPE } else { MODE_SUBWAY }) {
        return;
    }

    let new_tile = match (pipes, old_tile) {
        (true, under::EMPTY) => under::PIPE_FIRST,
        (true, under::SUBWAY_FIRST) => under::PIPE_TB_SUBWAY_LR,
        (true, under::SUBWAY_TB) => under::PIPE_LR_SUBWAY_TB,
        (false, under::EMPTY) => under::SUBWAY_FIRST,
        (false, under::PIPE_LR) => under::PIPE_LR_SUBWAY_TB,
        (false, under::PIPE_TB) => under::PIPE_TB_SUBWAY_LR,
        _ => return,
    };

    if pipes {
        maps.flags[i] |= flag_bits::PIPED as u8;
    }

    grade_surface_terrain(maps.terrain, maps.flags, point, direction, edge);
    replace_underground(maps.underground, maps.zones, maps.misc, index, new_tile);
    retile_neighborhood(maps.underground, maps.terrain, point, pipes, edge);
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::city::{Chunk, City};
    use crate::sim::tools::commands::DIRECTIONS;
    use crate::sim::tools::network::retile_surface;

    fn city(edge: i64) -> City {
        let cells = (edge * edge) as usize;
        let mut city = City::new(edge, 2);

        for chunk in [
            &mut city.xbld,
            &mut city.xter,
            &mut city.xzon,
            &mut city.xund,
            &mut city.xbit,
            &mut city.xtxt,
        ] {
            *chunk = Chunk::new(vec![0; cells]);
        }

        city.altm = Chunk::new(vec![0; cells * 2]);
        city.misc = Chunk::new(vec![0; 4800]);
        city
    }

    /// A subway leaves a pipe bend or junction as it is.
    #[test]
    fn subways_keep_pipe_bends() {
        let mut city = city(128);
        let point = Vec2i::new(21, 20);
        let index = (point.x * 128 + point.y) as usize;

        for pipe in 0x12..0x1f {
            for direction in 0..4 {
                city.xund.data[index] = pipe;
                place_underground(&mut city.maps(), point, false, direction);
                assert_eq!(city.xund.data[index], pipe);
            }
        }
    }

    /// A slope beside a straight line does not make a side junction.
    #[test]
    fn slopes_make_no_false_junctions() {
        for edge in [128, 512] {
            let mut city = city(edge);
            let point = Vec2i::new(edge - 12, edge - 12);
            let center = (point.x * edge + point.y) as usize;

            for (mode, base) in [
                (MODE_ROAD, tiles::ROAD_STRAIGHT_1),
                (MODE_RAIL, tiles::RAIL_STRAIGHT_1),
                (MODE_POWER, tiles::POWER_LINE_STRAIGHT_1),
            ] {
                for direction in 0..4usize {
                    let near = point + DIRECTIONS[direction];
                    let cross = DIRECTIONS[(direction + 1) % 4];
                    let cells = [point, near, point + cross, point - cross];

                    for cell in cells {
                        let index = (cell.x * edge + cell.y) as usize;
                        city.xbld.data[index] = base as u8;
                        city.xbit.data[index] |= flag_bits::POWERABLE as u8;
                    }

                    let near_index = (near.x * edge + near.y) as usize;
                    city.xter.data[near_index] = if direction % 2 == 0 { 1 } else { 2 };
                    city.xbld.data[near_index] = (base + if direction % 2 == 0 { 2 } else { 3 }) as u8;

                    let maps = city.maps();
                    retile_surface(
                        maps.buildings,
                        maps.terrain,
                        maps.zones,
                        maps.flags,
                        maps.misc,
                        point,
                        mode,
                        maps.text_overlays,
                        edge,
                    );
                    assert_eq!(
                        city.xbld.data[center] as i64,
                        base + if direction % 2 == 0 { 1 } else { 0 },
                        "mode {mode} direction {direction}"
                    );

                    for cell in cells {
                        let index = (cell.x * edge + cell.y) as usize;
                        city.xbld.data[index] = 0;
                        city.xbit.data[index] = 0;
                    }

                    city.xter.data[near_index] = 0;
                }
            }
        }
    }
}
