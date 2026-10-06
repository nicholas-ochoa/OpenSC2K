//! The sprite images of a graphics pack for the painter. Each pixel holds its
//! palette index in red, green, and blue, so the painted regions keep indices
//! and the frame applies the cycling palette.

use sc2k_assets::packs::graphics::{GraphicsPack, SpriteImage};
use sc2k_render::sprites::Sprite;
use std::collections::HashMap;

/// The sprites of one graphics size, by painter key (sprite ID times two).
pub type ViewSprites = HashMap<u64, Sprite>;

pub struct CityArt {
    pub palette: Vec<u8>,
    pub views: [ViewSprites; 3],
    /// The large sprites by ID, for moving objects and previews.
    pub large: HashMap<i64, SpriteImage>,
    pub small_medium: HashMap<i64, SpriteImage>,
}

/// An index-encoded sprite: (i, i, i, 255), or clear for -1.
pub fn index_sprite(width: usize, height: usize, pixels: &[i32]) -> Sprite {
    let mut rgba = Vec::with_capacity(pixels.len() * 4);
    let mut la = Vec::with_capacity(pixels.len() * 2);

    for &pixel in pixels {
        if pixel < 0 {
            rgba.extend([0, 0, 0, 0]);
            la.extend([0, 0]);
        } else {
            let index = pixel as u8;
            rgba.extend([index, index, index, 255]);
            la.extend([index, 255]);
        }
    }

    Sprite {
        w: width as i32,
        h: height as i32,
        rgba,
        la,
    }
}

impl CityArt {
    pub fn new(pack: &GraphicsPack) -> Self {
        let mut views: [ViewSprites; 3] = Default::default();
        let mut large = HashMap::new();
        let mut small_medium = HashMap::new();

        // a later sprite with an ID replaces the earlier one
        for sprite in &pack.large_sprites {
            large.insert(sprite.id, sprite.clone());
        }

        for sprite in &pack.small_medium_sprites {
            small_medium.insert(sprite.id, sprite.clone());
        }

        for sprite in large.values().chain(small_medium.values()) {
            let view = match sprite.id {
                0..500 => 0,
                500..1000 => 1,
                1000..1500 => 2,
                _ => continue,
            };

            views[view].insert(sprite.id as u64 * 2, index_sprite(sprite.width, sprite.height, &sprite.pixels));
        }

        Self {
            palette: pack.palette.clone(),
            views,
            large,
            small_medium,
        }
    }

    pub fn sprite(&self, id: i64) -> Option<&SpriteImage> {
        if id >= 1000 {
            self.large.get(&id)
        } else {
            self.small_medium.get(&id)
        }
    }
}
