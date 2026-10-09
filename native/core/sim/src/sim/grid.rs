//! Coordinates for legacy coarse grids and SC2X per-tile grids, as CityDataGrid.

pub fn valid(data: &[u8], map_edge: i64, legacy_scale: i64) -> bool {
    let size = data.len() as i64;

    size == map_edge * map_edge || size == (map_edge / legacy_scale) * (map_edge / legacy_scale)
}

pub fn edge(data: &[u8], map_edge: i64) -> i64 {
    let size = data.len() as i64;

    if size == map_edge * map_edge {
        return map_edge;
    }

    if size == (map_edge / 2) * (map_edge / 2) {
        return map_edge / 2;
    }

    if size == (map_edge / 4) * (map_edge / 4) {
        return map_edge / 4;
    }

    0
}

#[inline]
pub fn index(data: &[u8], map_edge: i64, x: i64, y: i64) -> i64 {
    let grid_edge = edge(data, map_edge);

    if grid_edge == 0 || x < 0 || y < 0 || x >= map_edge || y >= map_edge {
        return -1;
    }

    let scale = map_edge / grid_edge;

    (x / scale) * grid_edge + y / scale
}

pub fn expand(data: &[u8], map_edge: i64) -> Vec<u8> {
    let grid_edge = edge(data, map_edge);

    if grid_edge == 0 {
        return Vec::new();
    }

    let scale = map_edge / grid_edge;
    let mut result = vec![0u8; (map_edge * map_edge) as usize];

    for x in 0..map_edge {
        for y in 0..map_edge {
            result[(x * map_edge + y) as usize] = data[((x / scale) * grid_edge + y / scale) as usize];
        }
    }

    result
}
