//! Data map overlay geometry, as CityDataView.create_mesh with encoded tints.
//! The grid shader reads each tile's value through the UVs. Vertex colors only
//! mark tops and walls. The height view shows the seabed without a water surface.

const HALF_WIDTH: f32 = 16.0;
const HALF_HEIGHT: f32 = 8.0;
const TILE_WIDTH: f32 = 32.0;
const TILE_BOTTOM: f32 = 16.0;
const ALTITUDE_STEP: f32 = 12.0;
const TOP_MARGIN: f32 = 512.0;
const SIDE_MARGIN: f32 = 32.0;
const WATER_FLAG: u8 = 0x04;
const DEEP_WATER_FIRST: u8 = 0x10;
const SURFACE_WATER_FIRST: u8 = 0x30;
/// Each bit raises one dry-terrain corner in top, right, bottom, left order.
const SURFACE_CORNER_MASKS: [u8; 15] = [0x0, 0x9, 0x3, 0x6, 0xc, 0xb, 0x7, 0xe, 0xd, 0x1, 0x2, 0x4, 0x8, 0xf, 0x0];
/// TerrainCommand neighbor order and corner masks.
const NEIGHBORS: [(i32, i32, usize); 8] = [
    (0, -1, 3),
    (1, -1, 2),
    (1, 0, 6),
    (1, 1, 4),
    (0, 1, 12),
    (-1, 1, 8),
    (-1, 0, 9),
    (-1, -1, 1),
];
/// Terrain shape by the corners that higher neighbors raise. 50 is a basin.
const TERRAIN_SHAPES: [u8; 16] = [0x0, 0x9, 0xa, 0x2, 0xb, 0xd, 0x3, 0x6, 0xc, 0x1, 0xd, 0x5, 0x4, 0x8, 0x7, 50];
const TOP: [f32; 4] = [1.0, 1.0, 1.0, 1.0];
const RIGHT_WALL: [f32; 4] = [1.0, 1.0, 0.78, 1.0];
const LEFT_WALL: [f32; 4] = [1.0, 1.0, 0.65, 1.0];

type Point = [f32; 2];
type Quad = [Point; 4];

/// The display fields of one city. `altitude` holds the ALTM words.
pub struct DataCity<'a> {
    pub edge: usize,
    pub visible: i32,
    pub altitude: &'a [i32],
    pub terrain: &'a [u8],
    pub flags: &'a [u8],
}
impl DataCity<'_> {
    pub fn validate(&self) -> Result<(), String> {
        let cells = self.edge * self.edge;
        if self.edge == 0 || self.altitude.len() != cells || self.terrain.len() != cells || self.flags.len() != cells {
            return Err("invalid data map city".into());
        }
        Ok(())
    }
    fn land(&self, i: usize) -> i32 {
        self.altitude[i] & 31
    }
    fn water(&self, i: usize) -> i32 {
        (self.altitude[i] >> 5) & 31
    }
    fn wet(&self, i: usize) -> bool {
        self.flags[i] & WATER_FLAG != 0
    }
    fn visible(&self, i: usize, height_view: bool) -> bool {
        if height_view {
            return self.land(i) < self.visible;
        }
        self.visible >= 32 || (if self.wet(i) { self.water(i) } else { self.land(i) }) < self.visible
    }
    /// IsometricGeometry.tile_polygon.
    fn tile_polygon(&self, x: usize, y: usize, land_surface: bool) -> Quad {
        let i = x * self.edge + y;
        let altitude = if !land_surface && self.terrain[i] >= DEEP_WATER_FIRST {
            self.water(i)
        } else {
            self.land(i)
        };
        let left_x = SIDE_MARGIN + self.edge as f32 * HALF_WIDTH + (x as f32 - y as f32) * HALF_WIDTH;
        let left_y = TOP_MARGIN + (x + y) as f32 * HALF_HEIGHT - altitude as f32 * ALTITUDE_STEP;
        [
            [left_x + HALF_WIDTH, left_y],
            [left_x + TILE_WIDTH, left_y + HALF_HEIGHT],
            [left_x + HALF_WIDTH, left_y + TILE_BOTTOM],
            [left_x, left_y + HALF_HEIGHT],
        ]
    }
    /// IsometricGeometry.terrain_surface_polygon.
    fn surface_polygon(&self, x: usize, y: usize, land_surface: bool) -> Quad {
        let mut polygon = self.tile_polygon(x, y, land_surface);
        let i = x * self.edge + y;
        let terrain = self.terrain[i];
        if !land_surface && terrain >= DEEP_WATER_FIRST {
            return polygon;
        }
        let mut shape = (terrain & 0x0f) as usize;
        if land_surface && terrain >= SURFACE_WATER_FIRST {
            // surface water encodes connecting banks, not the ground corner mask
            let land = self.land(i);
            let mut mask = 0;
            for (dx, dy, bits) in NEIGHBORS {
                let (near_x, near_y) = (x as i32 + dx, y as i32 + dy);
                if near_x >= 0
                    && near_y >= 0
                    && (near_x as usize) < self.edge
                    && (near_y as usize) < self.edge
                    && self.land(near_x as usize * self.edge + near_y as usize) > land
                {
                    mask |= bits;
                }
            }
            shape = TERRAIN_SHAPES[mask] as usize;
        }
        if shape >= SURFACE_CORNER_MASKS.len() {
            return polygon;
        }
        for (corner, point) in polygon.iter_mut().enumerate() {
            if SURFACE_CORNER_MASKS[shape] & (1 << corner) != 0 {
                point[1] -= ALTITUDE_STEP;
            }
        }
        polygon
    }
}

#[derive(Default)]
pub struct DataMesh {
    pub vertices: Vec<Point>,
    pub colors: Vec<[f32; 4]>,
    pub uvs: Vec<Point>,
    pub indices: Vec<i32>,
}
impl DataMesh {
    fn quad(&mut self, polygon: Quad, tint: [f32; 4], x: usize, y: usize) {
        let first = self.vertices.len() as i32;
        let (u, v) = (y as f32 * 2.0, x as f32 * 2.0);
        self.vertices.extend_from_slice(&polygon);
        self.colors.extend_from_slice(&[tint; 4]);
        self.uvs
            .extend_from_slice(&[[u, v], [u + 1.0, v], [u + 1.0, v + 1.0], [u, v + 1.0]]);
        self.indices.extend([0, 1, 2, 0, 2, 3].map(|index| first + index));
    }
}

/// Build the overlay in terrain painter order, so raised foreground tiles cover
/// distant tiles. Only exposed walls get quads.
pub fn build(city: &DataCity, height_view: bool) -> DataMesh {
    let edge = city.edge;
    let mut surfaces = Vec::with_capacity(edge * edge);
    for x in 0..edge {
        for y in 0..edge {
            surfaces.push(city.surface_polygon(x, y, height_view));
        }
    }
    let mut mesh = DataMesh::default();
    let reserve = edge * edge * 5;
    mesh.vertices.reserve(reserve);
    mesh.colors.reserve(reserve);
    mesh.uvs.reserve(reserve);
    mesh.indices.reserve(reserve * 3 / 2);
    for diagonal in 0..edge * 2 - 1 {
        for y in diagonal.saturating_sub(edge - 1)..=(edge - 1).min(diagonal) {
            let x = diagonal - y;
            let i = x * edge + y;
            if !city.visible(i, height_view) {
                continue;
            }
            let polygon = surfaces[i];
            let left_x = SIDE_MARGIN + edge as f32 * HALF_WIDTH + (x as f32 - y as f32) * HALF_WIDTH;
            let left_y = TOP_MARGIN + (x + y) as f32 * HALF_HEIGHT;
            let mut ground = [
                [left_x + HALF_WIDTH, left_y],
                [left_x + TILE_WIDTH, left_y + HALF_HEIGHT],
                [left_x + HALF_WIDTH, left_y + TILE_BOTTOM],
                [left_x, left_y + HALF_HEIGHT],
            ];
            let mut left_bottom = ground[2];
            // neighbor tops cover everything below them
            if x + 1 < edge && city.visible(i + edge, height_view) {
                let neighbor = surfaces[i + edge];
                ground[1] = [polygon[1][0], polygon[1][1].max(neighbor[0][1])];
                ground[2] = [polygon[2][0], polygon[2][1].max(neighbor[3][1])];
            }
            if y + 1 < edge && city.visible(i + 1, height_view) {
                let neighbor = surfaces[i + 1];
                left_bottom = [polygon[2][0], polygon[2][1].max(neighbor[1][1])];
                ground[3] = [polygon[3][0], polygon[3][1].max(neighbor[0][1])];
            }
            for side in [1, 2] {
                if side == 2 {
                    ground[2] = left_bottom;
                }
                if polygon[side][1] < ground[side][1] || polygon[side + 1][1] < ground[side + 1][1] {
                    let tint = if side == 1 { RIGHT_WALL } else { LEFT_WALL };
                    mesh.quad([polygon[side], polygon[side + 1], ground[side + 1], ground[side]], tint, x, y);
                }
            }
            mesh.quad(polygon, TOP, x, y);
        }
    }
    mesh
}

/// The first height map value of underwater tiles. Dry tiles hold their land
/// level below it; an underwater tile holds this value plus its water depth.
pub const UNDERWATER_BASE: u8 = 32;
const MAX_DEPTH: i32 = 31;

/// Height map values: the land level of each dry tile, and the underwater base
/// plus the depth of each tile under water.
pub fn height_values(altitude: &[i32], flags: &[u8]) -> Vec<u8> {
    use super::ids::{sc2altitude_layout as layout, sc2tile_flags};
    altitude
        .iter()
        .zip(flags)
        .map(|(word, tile_flags)| {
            let land = word & layout::LAND_MASK;
            if tile_flags & sc2tile_flags::WATER == 0 {
                return land as u8;
            }
            let water = (word >> layout::WATER_SHIFT) & layout::LEVEL_MASK;
            UNDERWATER_BASE + (water - land).clamp(0, MAX_DEPTH) as u8
        })
        .collect()
}

/// Utility map values from XBIT: 2 where `supplied` is set, 1 where only
/// `connected` is set, and 0 elsewhere.
pub fn utility_values(flags: &[u8], supplied: u8, connected: u8) -> Vec<u8> {
    flags
        .iter()
        .map(|f| if f & supplied != 0 { 2 } else { u8::from(f & connected != 0) })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn city_mesh(edge: usize, altitude: &[i32], terrain: &[u8], flags: &[u8], visible: i32, height_view: bool) -> DataMesh {
        let city = DataCity {
            edge,
            visible,
            altitude,
            terrain,
            flags,
        };
        city.validate().unwrap();
        build(&city, height_view)
    }

    #[test]
    fn flat_ground_has_one_top_per_tile() {
        let mesh = city_mesh(4, &[0; 16], &[0; 16], &[0; 16], 32, false);
        assert_eq!(mesh.vertices.len(), 16 * 4);
        assert_eq!(mesh.indices.len(), 16 * 6);
        assert_eq!(mesh.vertices[0], [32.0 + 64.0 + 16.0, 512.0]);
        assert_eq!(mesh.uvs[..4], [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]]);
    }

    #[test]
    fn raised_flat_ground_draws_only_outside_walls() {
        let edge = 8;
        let mesh = city_mesh(edge, &vec![16; edge * edge], &vec![0; edge * edge], &vec![0; edge * edge], 32, true);
        assert_eq!(mesh.vertices.len(), (edge * edge + edge * 2) * 4);
        assert!(mesh.colors.contains(&RIGHT_WALL) && mesh.colors.contains(&LEFT_WALL));
    }

    #[test]
    fn height_view_shows_the_seabed_without_a_water_surface() {
        let mut altitude = vec![0; 4];
        let mut terrain = vec![0; 4];
        let mut flags = vec![0; 4];
        altitude[0] = 10 << 5;
        terrain[0] = DEEP_WATER_FIRST;
        flags[0] = WATER_FLAG;
        let mesh = city_mesh(2, &altitude, &terrain, &flags, 32, true);
        assert!(mesh.colors.iter().all(|tint| tint[3] == 1.0));
        assert_eq!(mesh.vertices.len(), 4 * 4);
    }

    #[test]
    fn clipped_tiles_are_hidden() {
        let mesh = city_mesh(2, &[5, 0, 0, 0], &[0; 4], &[0; 4], 4, false);
        assert!(mesh.uvs.iter().all(|uv| *uv != [0.0, 0.0]));
    }

    #[test]
    fn value_maps() {
        // land 5 under water 7, dry land 7, dry land 31
        let words = [5 | 7 << 5, 7, 31];
        assert_eq!(
            super::height_values(&words, &[WATER_FLAG, 0, 0]),
            vec![super::UNDERWATER_BASE + 2, 7, 31]
        );
        assert_eq!(super::utility_values(&[0xc0, 0x80, 0x40, 0], 0x40, 0x80), vec![2, 1, 2, 0]);
    }
}
