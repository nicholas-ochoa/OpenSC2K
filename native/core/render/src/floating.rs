//! Occlusion of ships and sailboats. They float on the water, but their sprites
//! reach past their tile. Tile painter order alone hides them under later water
//! and draws them over the bridge of their own tile. Each sprite column stands on
//! the water at its lowest opaque pixel. A static draw hides a column that stands
//! under or behind the draw's tile. The water surface hides no column.
//! `IsometricFloatingOcclusion` applies the same rule to the city view.
use super::{Config, sprites::Sprite};

/// Sprite offsets of the water surface, shore, map edge and channel artwork.
const WATER_SURFACE_FIRST: i32 = 270;
const WATER_SURFACE_LAST: i32 = 290;

/// Map geometry for floating draws.
#[derive(Clone, Copy, Debug)]
pub struct Ground {
    pub edge: i32,
    pub config: Config,
}

impl Ground {
    /// Whether a static draw of sprite `id` is the water surface.
    pub fn water_surface(self, id: i32) -> bool {
        (WATER_SURFACE_FIRST..=WATER_SURFACE_LAST).contains(&(id - self.config.base()))
    }

    /// Whether the floating column at screen `x`, which meets water at `altitude`
    /// at screen `y`, stands under or behind the tile of painter `depth`.
    pub fn hides(self, depth: i64, x: i32, y: i32, altitude: i32) -> bool {
        let c = self.config;
        let edge = i64::from(self.edge);
        let tile_y = depth % edge;
        let tile_x = depth / edge - tile_y;

        // Map x - y and x + y of the point where the column meets the water.
        let ground_x = c.side() + (self.edge + 1) * c.hw();
        let ground_y = c.top() - altitude * c.step();
        let across = (f64::from(x) + 0.5 - f64::from(ground_x)) / f64::from(c.hw());
        let along = f64::from(y - ground_y) / f64::from(c.hh());

        along + across < (2 * (tile_x + 1)) as f64 && along - across < (2 * (tile_y + 1)) as f64
    }
}

/// The row under the lowest opaque pixel of each sprite column, or -1 for an
/// empty column.
pub fn waterline(sprite: &Sprite) -> Vec<i32> {
    (0..sprite.w)
        .map(|x| {
            (0..sprite.h)
                .rev()
                .find(|y| sprite.rgba[((y * sprite.w + x) * 4 + 3) as usize] != 0)
                .map_or(-1, |y| y + 1)
        })
        .collect()
}
