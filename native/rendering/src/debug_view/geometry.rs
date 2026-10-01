//! Tile tops of a map window for the debug tile layer. The UVs hold two units
//! for each tile, as in the data map overlay, so the shader finds the tile and
//! its position inside the tile.

use crate::data_view::{DataCity, Point};

/// One window of tile tops. `tiles` counts the tops in the mesh.
#[derive(Default)]
pub struct WindowMesh {
    pub vertices: Vec<Point>,
    pub uvs: Vec<Point>,
    pub indices: Vec<i32>,
    pub tiles: usize,
}

/// A tile rectangle: columns `x0..x1` and rows `y0..y1`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct TileWindow {
    pub x0: usize,
    pub y0: usize,
    pub x1: usize,
    pub y1: usize,
}

impl TileWindow {
    /// The window, clipped to a map of `edge` tiles.
    pub fn clipped(x0: i64, y0: i64, x1: i64, y1: i64, edge: usize) -> Self {
        let clip = |value: i64| value.clamp(0, edge as i64) as usize;

        Self {
            x0: clip(x0),
            y0: clip(y0),
            x1: clip(x1),
            y1: clip(y1),
        }
    }

    pub fn is_empty(self) -> bool {
        self.x0 >= self.x1 || self.y0 >= self.y1
    }

    pub fn area(self) -> usize {
        if self.is_empty() {
            return 0;
        }

        (self.x1 - self.x0) * (self.y1 - self.y0)
    }
}

/// The visible tile tops in `window`, in terrain painter order. Hidden tiles
/// above the visible terrain level get no top.
pub fn window_tops(city: &DataCity, window: TileWindow) -> WindowMesh {
    let mut mesh = WindowMesh::default();

    if window.is_empty() {
        return mesh;
    }

    let reserve = window.area() * 4;
    mesh.vertices.reserve(reserve);
    mesh.uvs.reserve(reserve);
    mesh.indices.reserve(window.area() * 6);

    let width = window.x1 - window.x0;
    let height = window.y1 - window.y0;

    for diagonal in 0..width + height - 1 {
        let first = diagonal.saturating_sub(width - 1);
        let last = (height - 1).min(diagonal);

        for row in first..=last {
            let x = window.x0 + diagonal - row;
            let y = window.y0 + row;
            let i = x * city.edge + y;

            if !city.visible(i, false) {
                continue;
            }

            add_top(&mut mesh, city.surface_polygon(x, y, false), x, y);
        }
    }

    mesh
}

fn add_top(mesh: &mut WindowMesh, polygon: [Point; 4], x: usize, y: usize) {
    let first = mesh.vertices.len() as i32;
    let (u, v) = (y as f32 * 2.0, x as f32 * 2.0);

    mesh.vertices.extend_from_slice(&polygon);
    mesh.uvs
        .extend_from_slice(&[[u, v], [u + 1.0, v], [u + 1.0, v + 1.0], [u, v + 1.0]]);
    mesh.indices.extend([0, 1, 2, 0, 2, 3].map(|index| first + index));
    mesh.tiles += 1;
}

#[cfg(test)]
mod tests {
    use super::*;

    fn flat_city(edge: usize, altitude: &[i32], terrain: &[u8], flags: &[u8], visible: i32) -> DataCity<'static> {
        let leak = |values: Vec<i32>| -> &'static [i32] { Box::leak(values.into_boxed_slice()) };
        let leak_bytes = |values: Vec<u8>| -> &'static [u8] { Box::leak(values.into_boxed_slice()) };

        DataCity {
            edge,
            visible,
            altitude: leak(altitude.to_vec()),
            terrain: leak_bytes(terrain.to_vec()),
            flags: leak_bytes(flags.to_vec()),
        }
    }

    #[test]
    fn window_has_one_top_for_each_tile_inside_it() {
        let city = flat_city(8, &[0; 64], &[0; 64], &[0; 64], 32);
        let mesh = window_tops(&city, TileWindow::clipped(2, 3, 5, 7, 8));

        assert_eq!(mesh.tiles, 3 * 4);
        assert_eq!(mesh.vertices.len(), 12 * 4);
        assert_eq!(mesh.indices.len(), 12 * 6);
    }

    #[test]
    fn uvs_name_the_tile() {
        let city = flat_city(4, &[0; 16], &[0; 16], &[0; 16], 32);
        let mesh = window_tops(&city, TileWindow::clipped(2, 1, 3, 2, 4));

        assert_eq!(mesh.uvs[0], [2.0, 4.0]);
        assert_eq!(mesh.uvs[2], [3.0, 5.0]);
    }

    #[test]
    fn windows_clip_to_the_map() {
        let window = TileWindow::clipped(-5, -1, 20, 3, 8);

        assert_eq!(
            window,
            TileWindow {
                x0: 0,
                y0: 0,
                x1: 8,
                y1: 3
            }
        );
        assert!(TileWindow::clipped(9, 0, 12, 4, 8).is_empty());
    }

    #[test]
    fn hidden_levels_get_no_top() {
        let mut altitude = vec![0; 4];
        altitude[0] = 6;
        let city = flat_city(2, &altitude, &[0; 4], &[0; 4], 4);
        let mesh = window_tops(&city, TileWindow::clipped(0, 0, 2, 2, 2));

        assert_eq!(mesh.tiles, 3);
    }
}
