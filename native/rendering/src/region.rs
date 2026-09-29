use super::sprites::Sprite;
use super::{Builder, Draw, Rect};

const TILE_LIMIT: usize = 16_384;
// A cached tile owns immutable, uncut draws. Region clipping never modifies it.
pub(super) struct Tile {
    pub draws: Vec<Draw>,
    pub pending_reuse: bool,
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
    pub fn region(&mut self, bounds: Rect) -> Result<Region, String> {
        let mut out = Region::default();
        let c = self.config;
        if c.underground {
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
        let mut width = 0;
        let mut height = 0;
        for (key, sprite) in &self.sprites.images {
            if *key < (1 << 32)
                && (*key / 2) as i32 >= c.base()
                && ((*key / 2) as i32) < c.base() + 500
            {
                width = width.max(sprite.w);
                height = height.max(sprite.h);
            }
        }
        let origin = c.side() + self.city.edge * c.hw();
        let bottom = c.height() + width / 4 + 1 + if c.underground { 31 * c.step() } else { 0 };
        let top = (if c.underground {
            32
        } else {
            self.maximum_altitude + 1
        }) * c.step()
            + height;
        let first = floor(bounds.y - c.top() - bottom, c.hh()).max(0);
        let last = ceil(bounds.y + bounds.h - c.top() + top, c.hh()).min(2 * (self.city.edge - 1));
        let diff_first = floor(bounds.x - origin - width - c.hw() * 2 - 1, c.hw());
        let diff_last = ceil(bounds.x + bounds.w - origin + width, c.hw());
        for diagonal in first..=last {
            let first_y = 0
                .max(diagonal - self.city.edge + 1)
                .max(ceil(diagonal - diff_last, 2));
            let last_y = (self.city.edge - 1)
                .min(diagonal)
                .min(floor(diagonal - diff_first, 2));
            for y in first_y..=last_y {
                let x = diagonal - y;
                let i = self.city.index(x, y);
                if !self.tiles.contains_key(&i) {
                    let mut draws = self.paint(x, y)?;
                    for draw in &mut draws {
                        self.serial += 1;
                        draw.id = self.serial;
                    }
                    if self.tiles.len() >= TILE_LIMIT {
                        for _ in 0..1024 {
                            if let Some(key) = self.queue.pop_front() {
                                self.remove_tile(key);
                            }
                        }
                    }
                    self.tiles.insert(
                        i,
                        Tile {
                            draws,
                            pending_reuse: false,
                        },
                    );
                    self.queue.push_back(i);
                    self.builds += 1;
                }
                // Count a tile once when a region first uses it after an update.
                // Snapshot validation alone does not constitute reuse.
                let tile = self.tiles.get_mut(&i).unwrap();
                if tile.pending_reuse {
                    tile.pending_reuse = false;
                    self.reuses += 1;
                }
                // Split the borrows so sprite uploads need no tile or image clones.
                for draw in &tile.draws {
                    let clipped = draw.rect.clip(bounds);
                    if !clipped.area() {
                        continue;
                    }
                    let slot = self
                        .atlas
                        .slot(draw.image, &self.sprites.images[&draw.image])?;
                    let uv = Rect::new(
                        slot.x + clipped.x - draw.rect.x,
                        slot.y + clipped.y - draw.rect.y,
                        clipped.w,
                        clipped.h,
                    );
                    quad(&mut out, clipped, uv, bounds);
                    out.draws.push(draw.clone());
                }
            }
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
