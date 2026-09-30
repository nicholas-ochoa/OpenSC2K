//! Moving sprite pixels: occlusion by foreground silhouettes and same-tile
//! artwork, shadows over the painted city, and the train masks of crossings.
//! Images here are RGBA8 unless a function says otherwise.

/// Godot's transparent color: white with zero alpha.
const TRANSPARENT: [u8; 4] = [255, 255, 255, 0];
/// The palette index of an indexed highway road surface.
pub const ROAD_SURFACE_INDEX: u8 = 0xa1;
// Shadow palette indices: 0x5f darkens to 0x64, and the 0x74 to 0x7e band to 0x7e.
const SHADOWED_GROUND: u8 = 0x5f;
const GROUND_SHADOW: u8 = 0x64;
const SHADOW_BAND_FIRST: u8 = 0x74;
const SHADOW_BAND: u8 = 0x7e;

/// An image in rows of `channels` bytes per pixel.
pub struct Pixels<'a> {
    pub width: i32,
    pub height: i32,
    pub channels: usize,
    pub data: &'a [u8],
}
impl Pixels<'_> {
    fn at(&self, x: i32, y: i32) -> Option<&[u8]> {
        if x < 0 || y < 0 || x >= self.width || y >= self.height {
            return None;
        }
        let at = (y * self.width + x) as usize * self.channels;
        self.data.get(at..at + self.channels)
    }
    // The alpha of an RGBA8 or LA8 pixel; other formats are opaque.
    fn alpha(&self, x: i32, y: i32) -> u8 {
        self.at(x, y).map_or(0, |p| match self.channels {
            4 => p[3],
            2 => p[1],
            _ => 255,
        })
    }
    // The palette index of an indexed image: its first channel.
    fn index(&self, x: i32, y: i32) -> Option<u8> {
        self.at(x, y).map(|p| p[0])
    }
}

/// The index that a shadow makes of a palette index.
pub fn shadow_index(index: u8) -> u8 {
    match index {
        SHADOWED_GROUND => GROUND_SHADOW,
        SHADOW_BAND_FIRST..SHADOW_BAND => SHADOW_BAND,
        _ => index,
    }
}

/// The opaque pixels of `sprite` that differ from `background`, whose bottom rows
/// line up with the sprite's. Returns the RGBA8 mask.
pub fn foreground_difference(sprite: &Pixels, background: &Pixels) -> Vec<u8> {
    let mut mask = TRANSPARENT.repeat((sprite.width * sprite.height) as usize);
    let offset = sprite.height - background.height;
    for y in 0..sprite.height {
        for x in 0..sprite.width {
            let source = sprite.at(x, y).unwrap();
            if source[3] == 0 {
                continue;
            }
            if background.at(x, y - offset) != Some(source) {
                let at = ((y * sprite.width + x) * 4) as usize;
                mask[at..at + 4].copy_from_slice(source);
            }
        }
    }
    mask
}

/// Where the pixels of an indexed city image lie under a sprite: sprite pixel
/// (x, y) reads index pixel `origin + (x, y) / divisor`.
pub struct IndexSource<'a> {
    pub image: Pixels<'a>,
    pub origin: (i32, i32),
    pub divisor: i32,
}
impl IndexSource<'_> {
    fn index(&self, x: i32, y: i32) -> Option<u8> {
        self.image.index(self.origin.0 + x / self.divisor, self.origin.1 + y / self.divisor)
    }
}

/// Hides the sprite pixels under the mask, and the pixels over same-tile
/// foreground artwork. Returns the pixels, or `None` when no pixel is hidden,
/// and the hidden pixel count. Hidden pixels keep their color bytes.
pub fn occlude(sprite: &Pixels, mask: Option<&Pixels>, indices: Option<(&IndexSource, &[i32])>) -> (Option<Vec<u8>>, usize) {
    let mut visible: Option<Vec<u8>> = None;
    let mut hidden_pixels = 0;
    for y in 0..sprite.height {
        for x in 0..sprite.width {
            if sprite.alpha(x, y) == 0 {
                continue;
            }
            let mut hidden = mask.is_some_and(|m| m.alpha(x, y) > 0);
            if !hidden && let Some((source, foreground)) = indices {
                hidden = source.index(x, y).is_some_and(|index| foreground.contains(&i32::from(index)));
            }
            if hidden {
                let pixels = visible.get_or_insert_with(|| sprite.data.to_vec());
                pixels[((y * sprite.width + x) * 4 + 3) as usize] = 0;
                hidden_pixels += 1;
            }
        }
    }
    (visible, hidden_pixels)
}

/// A moving shadow: the city pixels under the opaque mask pixels, darkened
/// through the shadow indices, where the occluder does not cover them and the
/// map pixel `position + (x, y) / factor` lies inside `limit`. Returns `None`
/// when no pixel changes.
pub fn moving_shadow(
    mask: &Pixels,
    occluder: Option<&Pixels>,
    source: &IndexSource,
    position: (i32, i32),
    limit: (i32, i32),
    factor: i32,
) -> Option<Vec<u8>> {
    let mut shadow = TRANSPARENT.repeat((mask.width * mask.height) as usize);
    let mut changed = false;
    for y in 0..mask.height {
        let output_y = position.1 + y / factor;
        if output_y < 0 || output_y >= limit.1 {
            continue;
        }
        for x in 0..mask.width {
            if mask.alpha(x, y) == 0 || occluder.is_some_and(|o| o.alpha(x, y) > 0) {
                continue;
            }
            let output_x = position.0 + x / factor;
            if output_x < 0 || output_x >= limit.0 {
                continue;
            }
            let Some(index) = source.index(x, y) else {
                continue;
            };
            let darker = shadow_index(index);
            if darker != index {
                let at = ((y * mask.width + x) * 4) as usize;
                shadow[at..at + 4].copy_from_slice(&[darker, darker, darker, 255]);
                changed = true;
            }
        }
    }
    changed.then_some(shadow)
}

/// A shadow sprite drawn in palette colors: each opaque pixel over the indexed
/// city image, at `position`, takes the palette color of the darkened index.
/// Pixels outside the city image keep their color. `palette` holds 256 RGBA colors.
pub fn palette_shadow(sprite: &Pixels, city: &Pixels, position: (i32, i32), palette: &[u8]) -> Vec<u8> {
    let mut out = sprite.data.to_vec();
    for y in 0..sprite.height {
        for x in 0..sprite.width {
            if sprite.alpha(x, y) == 0 {
                continue;
            }
            if let Some(index) = city.index(position.0 + x, position.1 + y) {
                let color = usize::from(shadow_index(index)) * 4;
                let at = ((y * sprite.width + x) * 4) as usize;
                out[at..at + 4].copy_from_slice(&palette[color..color + 4]);
            }
        }
    }
    out
}

/// Darkens the pixels of `output` under the opaque pixels of `mask` at
/// `destination`. `pairs` maps each RGBA color to its shadow color.
pub fn blend_shadow(output: &mut [u8], width: i32, height: i32, mask: &Pixels, destination: (i32, i32), pairs: &[([u8; 4], [u8; 4])]) {
    for y in 0..mask.height {
        let output_y = destination.1 + y;
        if output_y < 0 || output_y >= height {
            continue;
        }
        for x in 0..mask.width {
            let output_x = destination.0 + x;
            if mask.alpha(x, y) == 0 || output_x < 0 || output_x >= width {
                continue;
            }
            let at = ((output_y * width + output_x) * 4) as usize;
            // The first rule for a color wins.
            if let Some((_, darker)) = pairs.iter().find(|(color, _)| output[at..at + 4] == color[..]) {
                output[at..at + 4].copy_from_slice(darker);
            }
        }
    }
}

/// The rows of each column within `thickness` of an indexed road surface pixel.
/// Other pixels become transparent. Separate bands keep the pillars between two
/// decks of a composite highway out of the mask.
pub fn highway_deck_mask(surface: &Pixels, thickness: i32) -> Vec<u8> {
    let mut mask = surface.data.to_vec();
    for x in 0..surface.width {
        let mut near_deck = vec![false; surface.height as usize];
        for y in 0..surface.height {
            if surface.alpha(x, y) > 0 && surface.index(x, y) == Some(ROAD_SURFACE_INDEX) {
                for row in (y - thickness).max(0)..(y + thickness + 1).min(surface.height) {
                    near_deck[row as usize] = true;
                }
            }
        }
        for (y, near) in near_deck.iter().enumerate() {
            if !near {
                let at = ((y as i32 * surface.width + x) * 4) as usize;
                mask[at..at + 4].copy_from_slice(&TRANSPARENT);
            }
        }
    }
    mask
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rgba(width: i32, height: i32, data: &[u8]) -> Pixels<'_> {
        Pixels {
            width,
            height,
            channels: 4,
            data,
        }
    }

    #[test]
    fn shadow_indices() {
        assert_eq!(shadow_index(0x5f), 0x64);
        assert_eq!(shadow_index(0x74), 0x7e);
        assert_eq!(shadow_index(0x7d), 0x7e);
        assert_eq!(shadow_index(0x7e), 0x7e);
        assert_eq!(shadow_index(0x20), 0x20);
    }

    #[test]
    fn occlusion_hides_masked_and_same_tile_pixels() {
        let sprite = [9, 9, 9, 255, 8, 8, 8, 255, 7, 7, 7, 0];
        let mask = [0, 0, 0, 0, 1, 1, 1, 255, 0, 0, 0, 255];
        let (visible, count) = occlude(&rgba(3, 1, &sprite), Some(&rgba(3, 1, &mask)), None);
        assert_eq!(count, 1);
        assert_eq!(visible.unwrap(), vec![9, 9, 9, 255, 8, 8, 8, 0, 7, 7, 7, 0]);
        let indices = [40, 41, 42];
        let source = IndexSource {
            image: Pixels {
                width: 3,
                height: 1,
                channels: 1,
                data: &indices,
            },
            origin: (0, 0),
            divisor: 1,
        };
        let (visible, count) = occlude(&rgba(3, 1, &sprite), None, Some((&source, &[40])));
        assert_eq!((count, visible.unwrap()[3]), (1, 0));
        assert_eq!(occlude(&rgba(3, 1, &sprite), None, None), (None, 0));
    }

    #[test]
    fn shadows_darken_only_shadow_colors() {
        let mask = [0, 0, 0, 255, 0, 0, 0, 255];
        let city = [0x5f, 0x20];
        let source = IndexSource {
            image: Pixels {
                width: 2,
                height: 1,
                channels: 1,
                data: &city,
            },
            origin: (0, 0),
            divisor: 1,
        };
        let shadow = moving_shadow(&rgba(2, 1, &mask), None, &source, (0, 0), (2, 1), 1).unwrap();
        assert_eq!(shadow, vec![0x64, 0x64, 0x64, 255, 255, 255, 255, 0]);
        assert!(moving_shadow(&rgba(2, 1, &mask), None, &source, (5, 0), (2, 1), 1).is_none());
        let mut output = vec![1, 1, 1, 255, 2, 2, 2, 255];
        blend_shadow(&mut output, 2, 1, &rgba(2, 1, &mask), (1, 0), &[([2, 2, 2, 255], [3, 3, 3, 255])]);
        assert_eq!(output, vec![1, 1, 1, 255, 3, 3, 3, 255]);
    }

    #[test]
    fn palette_shadows_inside_the_city() {
        let sprite = [1, 1, 1, 255, 1, 1, 1, 255];
        let city = [0x5f];
        let palette: Vec<u8> = (0..=255).flat_map(|i| [i, 0, 0, 255]).collect();
        let city_pixels = Pixels {
            width: 1,
            height: 1,
            channels: 1,
            data: &city,
        };
        let out = palette_shadow(&rgba(2, 1, &sprite), &city_pixels, (0, 0), &palette);
        assert_eq!(out, vec![0x64, 0, 0, 255, 1, 1, 1, 255]);
    }

    #[test]
    fn deck_bands_and_foreground_differences() {
        // one column: road surface at row 1, pillar rows below
        let mut column = Vec::new();
        for y in 0..6 {
            column.extend_from_slice(if y == 1 {
                &[ROAD_SURFACE_INDEX, 0, 0, 255]
            } else {
                &[200, 200, 200, 255]
            });
        }
        let deck = highway_deck_mask(&rgba(1, 6, &column), 1);
        let alpha: Vec<u8> = deck.chunks(4).map(|p| p[3]).collect();
        assert_eq!(alpha, vec![255, 255, 255, 0, 0, 0]);
        let sprite = [5, 5, 5, 255, 6, 6, 6, 255];
        let background = [5, 5, 5, 255];
        let mask = foreground_difference(&rgba(2, 1, &sprite), &rgba(1, 1, &background));
        assert_eq!(mask, vec![255, 255, 255, 0, 6, 6, 6, 255]);
    }
}
