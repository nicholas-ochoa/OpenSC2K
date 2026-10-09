use super::sprites::{ARTWORK_PADDING, Sprite};
use super::{Builder, Draw, Rect, effects, surface_grid};

/// Each quad has a vertex color that tells the shader how to draw it. These
/// are byte values of the red channel. Other channels hold the details.
const INDEXED: [f32; 4] = [1.0; 4];
const ARTWORK_TAG: u8 = 2;
/// The art of a power warning marker. The palette phase tints it.
const POWER_WARNING_TAG: u8 = 50;
/// An animation strip at 8 or 5 frames each second. Green is the frame count,
/// and blue and alpha are the frame stride in texels.
const ANIMATION_TAG: u8 = 64;
const SLOW_ANIMATION_TAG: u8 = 65;
/// Masked traffic: red from 80 through 111 and green give the x of a texel
/// record, and blue and alpha give its y. Refer to `traffic_record`.
const TRAFFIC_TAG: u8 = 80;
const POWER_WARNING_SPRITE: i32 = 386;
/// HD effects. A waterfall: green is the view, and blue and alpha are the
/// position in the sprite, from 0 to 1.
const WATERFALL_TAG: u8 = 49;
/// The indexed sprite under underground HD art: the shader draws pipe water.
const PIPE_FLOW_TAG: u8 = 52;
const WATERFALL_SPRITE: i32 = 284;

// The least recently used tiles leave the cache above this count. Regions keep
// their own draw lists, so eviction never changes a published region.
pub const TILE_LIMIT: usize = 65_536;
// A cached tile owns immutable, uncut draws. Region clipping never modifies it.
pub(super) struct Tile {
    pub draws: Vec<Draw>,
    pub revision: u64,
    pub used: u64,
}

// Tile sprite bounds relative to the tile anchor. A width of -1 is unknown.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) struct Bounds {
    x: i16,
    y: i16,
    w: i16,
    h: i16,
}

impl Bounds {
    pub const UNKNOWN: Self = Self { x: 0, y: 0, w: -1, h: 0 };

    fn known(self) -> bool {
        self.w >= 0
    }
}

#[derive(Default)]
pub struct Region {
    pub vertices: Vec<[f32; 2]>,
    pub uvs: Vec<[f32; 2]>,
    pub colors: Vec<[f32; 4]>,
    pub indices: Vec<i32>,
    pub draws: Vec<Draw>,
}

fn floor(a: i32, b: i32) -> i32 {
    a.div_euclid(b)
}

fn ceil(a: i32, b: i32) -> i32 {
    -(-a).div_euclid(b)
}

impl Builder {
    fn anchor(&self, x: i32, y: i32) -> (i32, i32) {
        let c = self.config;
        (
            c.side() + (self.city.edge + x - y) * c.hw(),
            c.top() + (x + y) * c.hh() + c.height(),
        )
    }

    fn tile_bounds(&self, x: i32, y: i32) -> Option<Rect> {
        let b = self.bounds[self.city.index(x, y)];
        let (ax, ay) = self.anchor(x, y);
        b.known()
            .then(|| Rect::new(ax + i32::from(b.x), ay + i32::from(b.y), i32::from(b.w), i32::from(b.h)))
    }

    fn store_bounds(&mut self, x: i32, y: i32, draws: &[Draw]) -> Rect {
        let (ax, ay) = self.anchor(x, y);
        let mut union: Option<Rect> = None;

        for draw in draws {
            let r = self.sprites.artwork_rect(draw);
            union = Some(match union {
                None => r,
                Some(u) => {
                    let (x0, y0) = (u.x.min(r.x), u.y.min(r.y));
                    Rect::new(x0, y0, (u.x + u.w).max(r.x + r.w) - x0, (u.y + u.h).max(r.y + r.h) - y0)
                }
            });
        }

        let rect = union.unwrap_or(Rect::new(ax, ay, 0, 0));

        // Bounds outside the packed range stay unknown; every region then visits the tile.
        if let [Ok(bx), Ok(by), Ok(bw), Ok(bh)] = [rect.x - ax, rect.y - ay, rect.w, rect.h].map(i16::try_from) {
            let i = self.city.index(x, y);
            self.bounds[i] = Bounds {
                x: bx,
                y: by,
                w: bw,
                h: bh,
            };
        }

        rect
    }

    /// Whether the cache has room for one more tile after the eviction.
    fn evict(&mut self) -> bool {
        if self.tiles.len() < TILE_LIMIT {
            return true;
        }

        // Remove about one eighth of the cache at once. Tiles of the current
        // region stay, even when one region holds more tiles than the limit.
        let mut stamps: Vec<u64> = self.tiles.values().map(|t| t.used).collect();
        let (_, cutoff, _) = stamps.select_nth_unstable(TILE_LIMIT / 8);
        let cutoff = (*cutoff).min(self.stamp - 1);
        self.tiles.retain(|_, tile| tile.used > cutoff);
        self.tiles.len() < TILE_LIMIT
    }

    /// The uncut draws that meet `bounds`, in painter order. Tiles are cached.
    pub fn collect(&mut self, bounds: Rect) -> Result<Vec<Draw>, String> {
        self.stamp += 1;
        let mut out = Vec::new();
        let c = self.config;
        let (width, height) = self.sprite_limit;
        let origin = c.side() + self.city.edge * c.hw();
        let bottom = c.height() + width / 4 + 1 + if c.underground { 31 * c.step() } else { 0 };
        let top = (if c.underground { 32 } else { self.maximum_altitude + 1 }) * c.step() + height;
        let first = floor(bounds.y - c.top() - bottom, c.hh()).max(0);
        let last = ceil(bounds.y + bounds.h - c.top() + top, c.hh()).min(2 * (self.city.edge - 1));
        let diff_first = floor(bounds.x - origin - width - c.hw() * 2 - 1, c.hw());
        let diff_last = ceil(bounds.x + bounds.w - origin + width, c.hw());

        // A region with more tiles than the limit fills the cache. Its other
        // tiles are not cached, so each tile does not scan the full cache again.
        let mut cache_full = false;

        for diagonal in first..=last {
            let first_y = 0.max(diagonal - self.city.edge + 1).max(ceil(diagonal - diff_last, 2));
            let last_y = (self.city.edge - 1).min(diagonal).min(floor(diagonal - diff_first, 2));

            for y in first_y..=last_y {
                let x = diagonal - y;

                // The candidate span uses the largest sprite. Known bounds
                // skip most candidates without a cache lookup or a painter call.
                if self.tile_bounds(x, y).is_some_and(|b| !b.clip(bounds).area()) {
                    continue;
                }

                let i = self.city.index(x, y);

                if !self.tiles.contains_key(&i) {
                    let draws = self.paint(x, y)?;
                    self.builds += 1;

                    // Cache only the tiles that a region uses.
                    if !self.store_bounds(x, y, &draws).clip(bounds).area() {
                        continue;
                    }

                    cache_full = cache_full || !self.evict();

                    if cache_full {
                        out.extend(draws.into_iter().filter(|d| self.sprites.artwork_rect(d).clip(bounds).area()));
                        continue;
                    }

                    self.tiles.insert(
                        i,
                        Tile {
                            draws,
                            revision: self.revision,
                            used: self.stamp,
                        },
                    );
                }

                // Count a tile once when a region first uses it after an update.
                let tile = self.tiles.get_mut(&i).unwrap();

                if tile.revision != self.revision {
                    tile.revision = self.revision;
                    self.reuses += 1;
                }

                tile.used = self.stamp;
                out.extend(
                    tile.draws
                        .iter()
                        .filter(|d| self.sprites.artwork_rect(d).clip(bounds).area())
                        .cloned(),
                );
            }
        }

        Ok(out)
    }

    /// Adds the art of the draws that meet `bounds` to the atlas, tallest first.
    /// In painter order, small sprites first break up the atlas, and tall
    /// animation strips then do not fit.
    fn reserve_artwork(&mut self, draws: &[Draw], bounds: Rect) -> Result<(), String> {
        let mut pending: Vec<u64> = draws
            .iter()
            .filter(|draw| !draw.shadow && self.sprites.artwork_rect(draw).clip(bounds).area())
            .filter_map(|draw| self.sprites.artwork_source(draw.image).map(|(source, _)| source))
            .filter(|&source| !self.atlas.has_artwork(source))
            .collect();

        pending.sort_unstable();
        pending.dedup();
        pending.sort_by_key(|key| {
            let artwork = &self.sprites.artwork[key];
            let height = artwork.image.h + i32::from(artwork.frames) * 2;
            (std::cmp::Reverse(height), std::cmp::Reverse(artwork.image.w), *key)
        });

        for key in pending {
            self.atlas.artwork_slot(key, &self.sprites.artwork[&key])?;
        }

        Ok(())
    }

    /// One quad of full-color art in the place of an indexed draw.
    pub(super) fn artwork_quad(&mut self, out: &mut Region, draw: &Draw, source: u64, mirrored: bool, bounds: Rect) -> Result<(), String> {
        let rect = self.sprites.artwork_rect(draw);
        let clipped = rect.clip(bounds);

        if !clipped.area() {
            return Ok(());
        }

        let artwork = &self.sprites.artwork[&source];
        let slot = self.atlas.artwork_slot(source, artwork)?;
        let frames = i32::from(artwork.frames.max(1));
        let frame_height = artwork.image.h / frames;
        let (stride, top) = if frames > 1 {
            (frame_height + ARTWORK_PADDING * 2, slot.y + ARTWORK_PADDING)
        } else {
            (0, slot.y)
        };

        // Physical texels for each logical pixel.
        let sx = artwork.image.w as f32 / rect.w as f32;
        let sy = frame_height as f32 / rect.h as f32;
        let offset_x = (clipped.x - rect.x) as f32 * sx;
        let width = clipped.w as f32 * sx;
        let uv = [
            slot.x as f32 + if mirrored { artwork.image.w as f32 - offset_x } else { offset_x },
            top as f32 + (clipped.y - rect.y) as f32 * sy,
            if mirrored { -width } else { width },
            clipped.h as f32 * sy,
        ];

        let fps_tag = if artwork.fps == 5 { SLOW_ANIMATION_TAG } else { ANIMATION_TAG };
        let mut color = if let Some(mask) = self.sprites.traffic_masks.get(&draw.image) {
            let mask_slot = self.atlas.mask_slot(draw.image, mask)?;
            let record = self.atlas.record_slot(
                draw.image,
                &[
                    slot.x,
                    top,
                    artwork.image.w,
                    frame_height,
                    (frames << 8) | i32::from(artwork.fps),
                    stride,
                    mask_slot.x,
                    mask_slot.y,
                    mask.w,
                    mask.h,
                    i32::from(mirrored),
                    0,
                ],
            )?;

            [
                byte(i32::from(TRAFFIC_TAG) + (record.x >> 8)),
                byte(record.x & 255),
                byte(record.y >> 8),
                byte(record.y & 255),
            ]
        } else if self.waterfall_flow(draw) {
            // the sprite position of each corner selects the top and the falling faces
            let corners = [
                (
                    (clipped.x - rect.x) as f32 / rect.w as f32,
                    (clipped.y - rect.y) as f32 / rect.h as f32,
                ),
                (
                    (clipped.x + clipped.w - rect.x) as f32 / rect.w as f32,
                    (clipped.y - rect.y) as f32 / rect.h as f32,
                ),
                (
                    (clipped.x + clipped.w - rect.x) as f32 / rect.w as f32,
                    (clipped.y + clipped.h - rect.y) as f32 / rect.h as f32,
                ),
                (
                    (clipped.x - rect.x) as f32 / rect.w as f32,
                    (clipped.y + clipped.h - rect.y) as f32 / rect.h as f32,
                ),
            ];
            let view = byte(self.config.view);
            let colors = corners.map(|(u, v)| [byte(i32::from(WATERFALL_TAG)), view, u, v]);

            // the falling water replaces the drift of a water strip: the UVs
            // select frame 0, the still image
            quad(out, clipped, uv, bounds, colors[0]);
            let count = out.colors.len();
            out.colors[count - 4..].copy_from_slice(&colors);

            return Ok(());
        } else if frames > 1 {
            [byte(i32::from(fps_tag)), byte(frames), byte(stride >> 8), byte(stride & 255)]
        } else if !draw.moving && draw.sprite.rem_euclid(500) == POWER_WARNING_SPRITE {
            [byte(i32::from(POWER_WARNING_TAG)), 0.0, 0.0, 1.0]
        } else {
            [byte(i32::from(ARTWORK_TAG)), 0.0, 0.0, 1.0]
        };

        if draw.emission_disabled {
            color[0] += byte(128);
        }
        quad(out, clipped, uv, bounds, color);
        Ok(())
    }

    /// Whether a draw is a waterfall with the falling water effect.
    fn waterfall_flow(&self, draw: &Draw) -> bool {
        self.config.effects & effects::WATERFALL != 0 && !draw.moving && draw.sprite.rem_euclid(500) == WATERFALL_SPRITE
    }

    /// The optional effects after the art of a draw: grid lines, and in the
    /// underground view the indexed sprite whose pipe water the shader draws
    /// over the art. Nothing plays over the animated colors of city art.
    fn artwork_effects(&mut self, out: &mut Region, draw: &Draw, bounds: Rect) -> Result<(), String> {
        let effects = self.config.effects;

        if effects & effects::GRID != 0 && draw.surface_grid != 0 {
            surface_grid::append(out, draw, bounds, &self.sprites.images[&draw.image]);
        }

        if !self.config.underground || effects & effects::PIPE_FLOW == 0 {
            return Ok(());
        }

        let tag = PIPE_FLOW_TAG;

        let clipped = draw.rect.clip(bounds);

        if !clipped.area() {
            return Ok(());
        }

        let slot = self.atlas.slot(draw.image, &self.sprites.images[&draw.image])?;
        let uv = [
            (slot.x + clipped.x - draw.rect.x) as f32,
            (slot.y + clipped.y - draw.rect.y) as f32,
            clipped.w as f32,
            clipped.h as f32,
        ];
        quad(out, clipped, uv, bounds, [byte(i32::from(tag)), 0.0, 0.0, 1.0]);
        Ok(())
    }

    pub fn region(&mut self, bounds: Rect) -> Result<Region, String> {
        let mut out = Region::default();

        if self.config.underground {
            let key = u64::MAX;
            self.sprites.images.entry(key).or_insert_with(|| Sprite {
                w: 1,
                h: 1,
                rgba: vec![255; 4],
                la: vec![255; 2],
            });

            let slot = self.atlas.slot(key, &self.sprites.images[&key])?;
            let uv = [slot.x as f32, slot.y as f32, slot.w as f32, slot.h as f32];
            quad(&mut out, bounds, uv, bounds, INDEXED);
        }

        let draws = self.collect(bounds)?;
        let with_artwork = !self.sprites.artwork.is_empty();

        if with_artwork {
            self.reserve_artwork(&draws, bounds)?;
        }

        for draw in draws {
            let artwork = if with_artwork && !draw.shadow {
                self.sprites.artwork_source(draw.image)
            } else {
                None
            };

            match artwork {
                Some((source, mirrored)) => {
                    self.artwork_quad(&mut out, &draw, source, mirrored, bounds)?;
                    self.artwork_effects(&mut out, &draw, bounds)?;
                }
                None => {
                    let clipped = draw.rect.clip(bounds);
                    let slot = self.atlas.slot(draw.image, &self.sprites.images[&draw.image])?;
                    let uv = [
                        (slot.x + clipped.x - draw.rect.x) as f32,
                        (slot.y + clipped.y - draw.rect.y) as f32,
                        clipped.w as f32,
                        clipped.h as f32,
                    ];
                    // Red bit 7 disables emission on this building, not its shared atlas sprite.
                    let color = if draw.emission_disabled {
                        [byte(128), 1.0, 1.0, 1.0]
                    } else {
                        INDEXED
                    };
                    quad(&mut out, clipped, uv, bounds, color);
                }
            }

            out.draws.push(draw);
        }

        let scale = 1.0 / self.atlas.edge as f32;

        for (uv, color) in out.uvs.iter_mut().zip(&out.colors) {
            if !surface_grid::is_grid_color(color) {
                uv[0] *= scale;
                uv[1] *= scale;
            }
        }

        Ok(out)
    }
}

fn quad(out: &mut Region, rect: Rect, uv: [f32; 4], bounds: Rect, color: [f32; 4]) {
    let at = out.vertices.len() as i32;
    let (x, y) = ((rect.x - bounds.x) as f32, (rect.y - bounds.y) as f32);
    let (r, b) = (x + rect.w as f32, y + rect.h as f32);
    out.vertices.extend([[x, y], [r, y], [r, b], [x, b]]);
    let [x, y, w, h] = uv;
    let (r, b) = (x + w, y + h);
    out.uvs.extend([[x, y], [r, y], [r, b], [x, b]]);
    out.colors.extend([color; 4]);
    out.indices.extend([at, at + 1, at + 2, at, at + 2, at + 3]);
}

fn byte(value: i32) -> f32 {
    value as f32 / 255.0
}
