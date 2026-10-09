//! Cosmetic sprite data follows the original atlas, silhouette and painter order.
use crate::{
    Draw, Rect,
    sprites::{ARTWORK_PADDING, ARTWORK_SLOT, Artwork, Sprite, Sprites},
};
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

// HD art keeps the original logical width and bottom edge. Repeat the mask
// per animation frame, using exactly the padding layout of Atlas::artwork_slot.
fn artwork_sample(key: u64, source: &Artwork, sprite: &Sprite, masks: &HashMap<u64, Sprite>, x: i32, y: i32) -> [u8; 4] {
    let frames = i32::from(source.frames.max(1));
    let frame_height = source.image.h / frames;
    let stride = if frames > 1 {
        frame_height + ARTWORK_PADDING * 2
    } else {
        frame_height
    };
    let row = if frames > 1 {
        (y % stride - ARTWORK_PADDING).clamp(0, frame_height - 1)
    } else {
        y
    };
    let sx = x * sprite.w / source.image.w;
    let sy = row * source.height / frame_height - (source.height - sprite.h);
    if sy < 0 || sy >= sprite.h {
        return [0; 4];
    }
    let mut color = sample(key, sprite, masks, sx, sy);
    let frame = y / stride;
    let alpha = source.image.rgba[(((frame * frame_height + row) * source.image.w + x) * 4 + 3) as usize];
    color[3] = ((u16::from(color[3]) * u16::from(alpha)) / 255) as u8;
    color
}

pub fn atlas(edge: i32, slots: &HashMap<u64, Rect>, sprites: &Sprites, artwork: &HashMap<u64, Sprite>) -> Vec<u8> {
    let mut out = vec![0; edge as usize * edge as usize * 4];
    for (&key, rect) in slots {
        let original_key = key & !ARTWORK_SLOT;
        let Some(sprite) = sprites.images.get(&original_key) else {
            continue;
        };
        let hd = if key & ARTWORK_SLOT != 0 {
            sprites.artwork.get(&original_key)
        } else {
            None
        };
        for y in 0..rect.h {
            for x in 0..rect.w {
                let color = match hd {
                    Some(source) => artwork_sample(original_key, source, sprite, artwork, x, y),
                    None => sample(key, sprite, artwork, x, y),
                };
                let at = (((rect.y + y) * edge + rect.x + x) * 4) as usize;
                out[at..at + 4].copy_from_slice(&color);
            }
        }
    }
    out
}

pub fn raster(bounds: Rect, draws: &[Draw], sprites: &HashMap<u64, Sprite>, artwork: &HashMap<u64, Sprite>, emission: bool) -> Vec<u8> {
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
                let color = if emission && draw.emission_disabled {
                    [0; 4]
                } else {
                    sample(draw.image, sprite, artwork, sx, sy)
                };
                out[at..at + 4].copy_from_slice(&color);
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
        assert_eq!(
            raster(bounds, &draws, &sprites, &artwork, true),
            vec![0, 0, 0, 0, 255, 255, 255, 255]
        );
        let slots = HashMap::from([(2, bounds)]);
        assert_eq!(atlas(2, &slots, &Sprites::new(sprites, [0; 4]), &artwork)[..8], [255; 8]);
    }

    #[test]
    fn unpowered_foreground_blocks_lights_but_keeps_seasons() {
        let sprites = HashMap::from([(2, sprite(vec![0; 8], &[255, 255]))]);
        let masks = HashMap::from([(2, sprite(vec![255; 8], &[255, 255]))]);
        let bounds = Rect::new(0, 0, 2, 1);
        let mut front = Draw::new(2, Rect::new(0, 0, 1, 1));
        front.emission_disabled = true;
        let draws = [Draw::new(2, bounds), front];
        assert_eq!(raster(bounds, &draws, &sprites, &masks, true), [vec![0; 4], vec![255; 4]].concat());
        assert_eq!(raster(bounds, &draws, &sprites, &masks, false), vec![255; 8]);
    }

    #[test]
    fn hd_masks_follow_density_bottom_alignment_and_padded_animation_frames() {
        use crate::sprites::Atlas;
        let mut sprites = Sprites::new(HashMap::from([(2, sprite(vec![0; 8], &[255, 255]))]), [0; 4]);
        let masks = HashMap::from([(2, sprite(vec![255, 0, 0, 255, 0, 255, 0, 128], &[255, 255]))]);
        let mut image = Sprite {
            w: 4,
            h: 8,
            rgba: vec![255; 4 * 8 * 4],
            la: vec![255; 4 * 8 * 2],
        };
        // A transparent HD pixel must not emit; another animation frame stays lit.
        image.rgba[(2 * 4 * 4) + 3] = 0;
        sprites.artwork.insert(
            2,
            Artwork {
                image,
                height: 2,
                frames: 2,
                fps: 8,
            },
        );
        let mut packed = Atlas::new(32);
        let slot = packed.artwork_slot(2, &sprites.artwork[&2]).unwrap();
        let rgba = atlas(packed.edge, &packed.slots, &sprites, &masks);
        let pixel = |x: i32, y: i32| -> &[u8] {
            let at = (((slot.y + y) * packed.edge + slot.x + x) * 4) as usize;
            &rgba[at..at + 4]
        };
        assert_eq!(
            pixel(0, 2),
            [0; 4],
            "taller art must not shift the bottom-aligned original mask upwards"
        );
        assert_eq!(pixel(0, 4)[3], 0, "transparent HD pixels clear emission");
        assert_eq!(pixel(1, 4), [255, 0, 0, 255]);
        assert_eq!(pixel(3, 4), [0, 255, 0, 128]);
        assert_eq!(pixel(0, 12), [255, 0, 0, 255], "each padded frame receives its own mask");
        assert_eq!(pixel(0, 15), pixel(0, 13), "bottom padding repeats the final frame row");
    }
}
