//! Cosmetic sprite data follows the original atlas, silhouette and painter order.
use crate::{Draw, Rect, sprites::Sprite};
use std::collections::HashMap;

fn sample(key: u64, sprite: &Sprite, artwork: &HashMap<u64, Sprite>, x: i32, y: i32) -> [u8; 4] {
    let base = if key & (1 << 32) != 0 { (key >> 16) & 0xffff } else { key };
    let Some(mask) = artwork.get(&(base & !1)) else { return [0; 4] };
    if mask.w != sprite.w || mask.h != sprite.h {
        return [0; 4];
    }
    let sx = if base & 1 != 0 { mask.w - 1 - x } else { x };
    let at = ((y * mask.w + sx) * 4) as usize;
    let alpha = sprite.la[((y * sprite.w + x) * 2 + 1) as usize];
    let mut out: [u8; 4] = mask.rgba[at..at + 4].try_into().unwrap();
    out[3] = ((u16::from(out[3]) * u16::from(alpha)) / 255) as u8;
    out
}

pub fn atlas(edge: i32, slots: &HashMap<u64, Rect>, sprites: &HashMap<u64, Sprite>, artwork: &HashMap<u64, Sprite>) -> Vec<u8> {
    let mut out = vec![0; edge as usize * edge as usize * 4];
    for (&key, rect) in slots {
        let Some(sprite) = sprites.get(&key) else { continue };
        for y in 0..rect.h {
            for x in 0..rect.w {
                let at = (((rect.y + y) * edge + rect.x + x) * 4) as usize;
                out[at..at + 4].copy_from_slice(&sample(key, sprite, artwork, x, y));
            }
        }
    }
    out
}

pub fn raster(bounds: Rect, draws: &[Draw], sprites: &HashMap<u64, Sprite>, artwork: &HashMap<u64, Sprite>) -> Vec<u8> {
    let mut out = vec![0; bounds.w as usize * bounds.h as usize * 4];
    for draw in draws {
        if draw.shadow {
            continue;
        }
        let Some(sprite) = sprites.get(&draw.image) else { continue };
        let clipped = draw.rect.clip(bounds);
        for y in clipped.y..clipped.y + clipped.h {
            for x in clipped.x..clipped.x + clipped.w {
                let sx = x - draw.rect.x;
                let sy = y - draw.rect.y;
                if sprite.la[((sy * sprite.w + sx) * 2 + 1) as usize] == 0 {
                    continue;
                }
                let at = (((y - bounds.y) * bounds.w + x - bounds.x) * 4) as usize;
                // An opaque non-emissive foreground pixel clears lights behind it.
                out[at..at + 4].copy_from_slice(&sample(draw.image, sprite, artwork, sx, sy));
            }
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    fn sprite(rgba: Vec<u8>, alpha: &[u8]) -> Sprite {
        Sprite {
            w: alpha.len() as i32,
            h: 1,
            rgba,
            la: alpha.iter().flat_map(|a| [0, *a]).collect(),
        }
    }
    #[test]
    fn colors_gradients_flips_and_traffic_keep_the_original_silhouette() {
        let artwork = HashMap::from([(2, sprite(vec![255, 0, 0, 64, 0, 128, 255, 192], &[255, 255]))]);
        let original = sprite(vec![0; 8], &[255, 255]);
        assert_eq!(sample(2, &original, &artwork, 0, 0), [255, 0, 0, 64]);
        assert_eq!(sample(3, &original, &artwork, 0, 0), [0, 128, 255, 192]);
        let traffic = sprite(vec![0; 8], &[0, 255]);
        assert_eq!(sample((1 << 32) | (2 << 16), &traffic, &artwork, 0, 0)[3], 0);
        assert_eq!(sample((1 << 32) | (2 << 16), &traffic, &artwork, 1, 0), [0, 128, 255, 192]);
    }
    #[test]
    fn foreground_clears_hidden_emission_and_transparency_keeps_it() {
        let sprites = HashMap::from([(2, sprite(vec![0; 8], &[255, 255])), (4, sprite(vec![0; 8], &[255, 0]))]);
        let artwork = HashMap::from([(2, sprite(vec![255; 8], &[255, 255]))]);
        let bounds = Rect::new(0, 0, 2, 1);
        let draws = [Draw::new(2, bounds), Draw::new(4, bounds)];
        assert_eq!(raster(bounds, &draws, &sprites, &artwork), vec![0, 0, 0, 0, 255, 255, 255, 255]);
        let slots = HashMap::from([(2, bounds)]);
        assert_eq!(atlas(2, &slots, &sprites, &artwork)[..8], [255; 8]);
    }
}
