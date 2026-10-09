//! The sprite images of a graphics pack for the painter. Each pixel holds its
//! palette index in red, green, and blue, so the painted regions keep indices
//! and the frame applies the cycling palette.

use sc2k_assets::packs::graphics::{GraphicsPack, SpriteImage};
use sc2k_assets::packs::hd::HdPack;
use sc2k_render::sprites::Artwork;
use sc2k_render::sprites::Sprite;
use std::collections::HashMap;

/// The sprites of one graphics size, by painter key (sprite ID times two).
pub type ViewSprites = HashMap<u64, Sprite>;

pub struct CityArt {
    pub palette: Vec<u8>,
    /// The full-color art of an HD sprite pack, or none.
    pub hd: Option<std::sync::Arc<HdPack>>,
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
            hd: None,
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

/// A sprite in the colors of `palette`. Its LA pixels keep the palette
/// indices, which the painter reads for animated colors and the HD grid.
pub fn colored_sprite(width: usize, height: usize, pixels: &[i32], palette: &[u8]) -> Sprite {
    let mut rgba = Vec::with_capacity(pixels.len() * 4);
    let mut la = Vec::with_capacity(pixels.len() * 2);

    for &pixel in pixels {
        if pixel < 0 {
            rgba.extend([0, 0, 0, 0]);
            la.extend([0, 0]);
        } else {
            let at = pixel as usize * 3;
            let rgb = palette.get(at..at + 3).unwrap_or(&[0, 0, 0]);
            rgba.extend([rgb[0], rgb[1], rgb[2], 255]);
            la.extend([pixel as u8, 255]);
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
    /// The sprites of a view in the colors of the palette, for HD regions.
    pub fn colored(&self, view: usize) -> ViewSprites {
        let range = 500 * view as i64..500 * (view as i64 + 1);

        self.large
            .values()
            .chain(self.small_medium.values())
            .filter(|sprite| range.contains(&sprite.id))
            .map(|sprite| {
                (
                    sprite.id as u64 * 2,
                    colored_sprite(sprite.width, sprite.height, &sprite.pixels, &self.palette),
                )
            })
            .collect()
    }

    /// The HD art of a view for the sprites whose indexed size matches.
    pub fn artwork(&self, view: usize) -> std::collections::HashMap<u64, Artwork> {
        let Some(hd) = &self.hd else {
            return std::collections::HashMap::new();
        };

        let range = 500 * view as i64..500 * (view as i64 + 1);
        let mut result = std::collections::HashMap::new();

        for (id, art) in &hd.sprites {
            let Some(sprite) = self.sprite(*id).filter(|_| range.contains(id)) else {
                continue;
            };

            if hd.logical_sizes.get(id) != Some(&(sprite.width as i64, sprite.height as i64)) {
                continue;
            }

            let (image, frames, fps) = match &art.animation {
                Some(strip) => (strip, art.frames as u8, art.fps as u8),
                None => (&art.image, 1, 0),
            };

            result.insert(
                *id as u64 * 2,
                Artwork {
                    image: Sprite {
                        w: image.width as i32,
                        h: image.height as i32,
                        rgba: image.pixels.clone(),
                        la: Vec::new(),
                    },
                    height: art.height as i32,
                    frames,
                    fps,
                },
            );
        }

        result
    }
}
