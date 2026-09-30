use super::sprites::Sprite;
use super::{Builder, Draw, Rect};

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
            let r = draw.rect;
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

    fn evict(&mut self) {
        if self.tiles.len() < TILE_LIMIT {
            return;
        }

        // Remove about one eighth of the cache at once. Tiles of the current
        // region stay, even when one region holds more tiles than the limit.
        let mut stamps: Vec<u64> = self.tiles.values().map(|t| t.used).collect();
        let (_, cutoff, _) = stamps.select_nth_unstable(TILE_LIMIT / 8);
        let cutoff = (*cutoff).min(self.stamp - 1);
        self.tiles.retain(|_, tile| tile.used > cutoff);
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

                    self.evict();
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
                out.extend(tile.draws.iter().filter(|d| d.rect.clip(bounds).area()).cloned());
            }
        }

        Ok(out)
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
            quad(&mut out, bounds, slot, bounds);
        }

        // Split the borrows so sprite uploads need no tile or image clones.
        for draw in self.collect(bounds)? {
            let clipped = draw.rect.clip(bounds);
            let slot = self.atlas.slot(draw.image, &self.sprites.images[&draw.image])?;
            let uv = Rect::new(
                slot.x + clipped.x - draw.rect.x,
                slot.y + clipped.y - draw.rect.y,
                clipped.w,
                clipped.h,
            );
            quad(&mut out, clipped, uv, bounds);
            out.draws.push(draw);
        }

        let scale = 1.0 / self.atlas.edge as f32;

        for uv in &mut out.uvs {
            uv[0] *= scale;
            uv[1] *= scale;
        }

        Ok(out)
    }
}

fn quad(out: &mut Region, rect: Rect, uv: Rect, bounds: Rect) {
    let at = out.vertices.len() as i32;
    let (x, y) = ((rect.x - bounds.x) as f32, (rect.y - bounds.y) as f32);
    let (r, b) = (x + rect.w as f32, y + rect.h as f32);
    out.vertices.extend([[x, y], [r, y], [r, b], [x, b]]);
    let (x, y) = (uv.x as f32, uv.y as f32);
    let (r, b) = (x + uv.w as f32, y + uv.h as f32);
    out.uvs.extend([[x, y], [r, y], [r, b], [x, b]]);
    out.indices.extend([at, at + 1, at + 2, at, at + 2, at + 3]);
}
