//! Static surface and underground painting in map diagonal order. Draws retain
//! the original uncut sprite rectangle for pixel queries and moving occlusion.
use super::{Builder, Draw, Rect};

pub(super) const TRAFFIC: &[i32] = &[
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 2, 1, 2, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 0, 0, 1, 2, 1, 2, 0, 0,
    11, 12, 11, 12, 11, 12, 11, 12, 13, 13, 13, 13, 13, 13, 13, 13, 0, 0, 0, 0, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 0, 0,
    0, 0, 28, 29,
];
const HEAVY: &[i32] = &[
    0, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 15, 16, 17, 18, 42, 43, 44, 45, 46, 47, 48, 49, 50,
];
fn terrain_sprite(t: i32, water: bool) -> i32 {
    match t {
        0..=14 => 256 + t,
        32..=46 => 256 + t - 18,
        48..=62 => 256 + t - 34,
        64..=69 => 256 + t - 35,
        _ if water || (16..=30).contains(&t) => 270,
        _ => 256,
    }
}
fn wireframe(t: i32) -> i32 {
    305 + match t {
        0..=14 => t.min(13),
        16..=30 => (t - 16).min(13),
        32..=46 => (t - 32).min(13),
        _ => 0,
    }
}
impl Builder {
    fn add(&mut self, draws: &mut Vec<Draw>, id: i32, flip: bool, x: i32, baseline: i32) -> Result<u64, String> {
        let key = self.sprites.get(id, flip)?;
        let sprite = &self.sprites.images[&key];
        draws.push(Draw::new(key, Rect::new(x, baseline - sprite.h, sprite.w, sprite.h)));
        Ok(key)
    }
    fn ground(&self, i: usize, t: i32) -> i32 {
        if let Some(&value) = self.city.ground.get(i).filter(|v| **v >= 0) {
            return value;
        }
        let zone = self.city.zones[i] & 15;
        if zone > 0 && t == 0 && self.city.buildings[i] <= 0x1c {
            return 290 + zone as i32;
        }
        terrain_sprite(t, self.city.wet(i))
    }
    pub(super) fn paint(&mut self, x: i32, y: i32) -> Result<Vec<Draw>, String> {
        let c = self.config;
        let i = self.city.index(x, y);
        let mut draws = Vec::new();
        if c.underground || !self.city.visible(i) {
            self.paint_underground(
                &mut draws,
                x,
                y,
                if c.underground { c.pipes } else { false },
                if c.underground { c.subways } else { true },
                if c.underground { c.mains } else { true },
            )?;
            return Ok(draws);
        }
        let t = self.city.surface(x, y);
        let b = self.city.buildings[i] as i32;
        let sx = c.side() + (self.city.edge + x - y) * c.hw();
        let flat = c.top() + (x + y) * c.hh() + c.height();
        let base = flat - (if t >= 16 { self.city.water(i) } else { self.city.land(i) }) * c.step();
        if x == self.city.edge - 1 || y == self.city.edge - 1 {
            for level in 0..self.city.land(i) {
                self.add(&mut draws, c.base() + 269, false, sx, flat - level * c.step())?;
            }
            if self.city.wet(i) {
                for level in self.city.land(i)..self.city.water(i) {
                    self.add(&mut draws, c.base() + 284, false, sx, flat - level * c.step())?;
                }
            }
        }
        let composite = (0x61..=0x6b).contains(&b);
        if b < 0x70 && !composite {
            self.add(&mut draws, c.base() + self.ground(i, t), false, sx, base)?;
        }
        let anchor = b <= 0x60 || (0x6c..=0x6f).contains(&b) || self.city.zones[i] & [0x80, 0x10, 0x20, 0x40][self.city.rotation] != 0;
        if b > 0 && anchor {
            if composite && (c.view != 0 || c.redraw_ground) {
                for (dx, dy, px, py) in [
                    (0, 0, 0, 0),
                    (0, -1, c.hw(), -c.hh()),
                    (1, -1, c.hw() * 2, 0),
                    (1, 0, c.hw(), c.hh()),
                ] {
                    let (nx, ny) = (x + dx, y + dy);
                    if nx >= 0 && ny >= 0 && nx < self.city.edge && ny < self.city.edge {
                        let n = self.city.index(nx, ny);
                        let id = c.base() + terrain_sprite(self.city.terrain[n] as i32, self.city.wet(n));
                        self.add(&mut draws, id, false, sx + px, base + py)?;
                    }
                }
            }
            let flip = (self.city.flags[i] & 2 != 0) ^ (b >= 0x70 && self.city.rotation & 1 != 0);
            let image = self.sprites.get(c.base() + b, flip)?;
            let width = self.sprites.images[&image].w;
            let offset = if composite {
                c.hh()
            } else if b >= 0x70 {
                width / 4 - c.hh()
            } else if t == 13 {
                -c.step()
            } else {
                0
            };
            let baseline = flat - self.city.object(i) * c.step() + offset;
            self.add(&mut draws, c.base() + b, flip, sx, baseline)?;
            if let Some((id, traffic_flip)) = self.traffic_sprite(x, y, b) {
                let traffic = self.sprites.get(id, traffic_flip)?;
                let masked = self.sprites.traffic(traffic, image);
                let sprite = &self.sprites.images[&masked];
                draws.push(Draw::new(masked, Rect::new(sx, baseline - sprite.h, sprite.w, sprite.h)));
            }
            if b >= 0x70 && self.city.flags[i] & 0xc0 == 0x80 {
                let key = self.sprites.get(c.base() + 386, false)?;
                let marker_width = self.sprites.images[&key].w;
                self.add(&mut draws, c.base() + 386, false, sx + width / 2 - marker_width / 2, baseline)?;
            }
        }
        if let Some(&offset) = self.city.dispatch.get(&i) {
            let key = self.sprites.get(c.base() + offset, false)?;
            let width = self.sprites.images[&key].w;
            self.add(
                &mut draws,
                c.base() + offset,
                false,
                sx + c.hw() - width / 2,
                flat - self.city.land(i) * c.step(),
            )?;
        }
        let depth = ((x + y) * self.city.edge + y) as i64;
        let mut foreground = 0;
        for draw in &mut draws {
            // Masked traffic changes color, not the foreground silhouette.
            if draw.image >= 1_u64 << 32 {
                continue;
            }
            draw.sprite = (draw.image / 2) as i32;
            draw.flip = draw.image & 1 != 0;
            draw.depth = depth;
            draw.order = (depth << 16) | foreground;
            foreground += 1;
            if draw.sprite == c.base() + b && b > 0 {
                configure_train(draw, b, c.base(), c.view);
            }
        }
        Ok(draws)
    }
    fn traffic_sprite(&self, x: i32, y: i32, b: i32) -> Option<(i32, bool)> {
        let mut variant = *TRAFFIC.get((b - 0x1d) as usize)?;
        if variant == 0 {
            return None;
        }
        let density = self.city.density(x, y);
        let (low, high) = if (0x49..=0x50).contains(&b) || (0x61..=0x6b).contains(&b) {
            (28, 56)
        } else {
            (85, 170)
        };
        if density <= low {
            return None;
        }
        let mut flip = self.city.flags[self.city.index(x, y)] & 2 != 0;
        if variant == 11 && x & 1 != 0 {
            variant = 12;
        } else if variant == 12 {
            flip = true;
            if y & 1 != 0 {
                variant = 11;
            }
        }
        if density > high {
            variant = *HEAVY.get(variant as usize)?;
        }
        if variant == 0 || (self.config.view == 0 && variant > 27) {
            return None;
        }
        Some((self.config.base() + 399 + variant, flip))
    }
    fn paint_underground(&mut self, draws: &mut Vec<Draw>, x: i32, y: i32, pipes: bool, subways: bool, mains: bool) -> Result<(), String> {
        let c = self.config;
        let i = self.city.index(x, y);
        let visible = self.city.visible(i);
        let sx = c.side() + (self.city.edge + x - y) * c.hw();
        let baseline = c.top() + (x + y) * c.hh() - self.city.land(i) * c.step() + c.height();
        let wire = c.base() + wireframe(self.city.terrain[i] as i32);
        let key = self.sprites.get(wire, false)?;
        let top = baseline - self.sprites.images[&key].h;
        let levels = (self.city.altitude[i] >> 10) & 31;
        if levels > 0 && (self.city.visible >= 32 || self.city.land(i) - (levels - 1).max(0) < self.city.visible) {
            let sprite = c.base() + if levels == 1 { 62 + self.city.terrain[i] as i32 } else { 352 };
            self.add(
                draws,
                sprite,
                false,
                sx,
                baseline + if levels > 1 { (levels - 1) * c.step() } else { 0 },
            )?;
        }
        let mut under = self.city.underground[i] as i32;
        if !visible
            && (!subways
                || !(self.city.visible >= 32 || self.city.land(i) - 1 < self.city.visible)
                || !((1..16).contains(&under) || [31, 32, 35].contains(&under)))
        {
            return Ok(());
        }
        if !subways {
            under = match under {
                31 => 17,
                32 => 16,
                1..=15 | 35 => 0,
                _ => under,
            };
        }
        let piped = self.city.flags[i] & 32 != 0;
        let watered = self.city.flags[i] & 16 != 0;
        let pipes = pipes && visible;
        let mains = mains && visible;
        let mut ids = Vec::new();
        if (16..=32).contains(&under) {
            if !mains {
                ids.push(match under {
                    31 => c.base() + 318 + 1,
                    32 => c.base() + 318 + 2,
                    _ => wire,
                });
            } else {
                ids.push(c.base() + 318 + under + if piped && watered { 116 } else { 0 });
            }
        } else if under == 0 {
            ids.push(if !pipes || !piped {
                wire
            } else {
                c.base() + if watered { 467 } else { 351 }
            });
        } else {
            ids.push(c.base() + 318 + under);
            if pipes && piped {
                ids.push(c.base() + if watered { 467 } else { 351 });
            }
        }
        for id in ids {
            let key = self.sprites.get(id, false)?;
            let h = self.sprites.images[&key].h;
            self.add(draws, id, false, sx, top + h)?;
        }
        Ok(())
    }
}
fn configure_train(d: &mut Draw, b: i32, base: i32, view: i32) {
    d.reference = match b {
        14..=28 => -1,
        0x4d => base + 0x2d,
        0x4e => base + 0x2c,
        0x43 => base + 0x1d,
        0x44 => base + 0x1e,
        0x47 => base + 0x2c,
        0x48 => base + 0x2d,
        0x4f => base + 0x49,
        0x50 => base + 0x4a,
        _ => 0,
    };
    d.ignore = (14..=28).contains(&b) || [0x43, 0x44, 0x47, 0x48].contains(&b);
    if (0x49..=0x50).contains(&b) || (0x61..=0x6b).contains(&b) {
        d.thickness = view + 1;
        d.requires_depth = true;
        if [0x4f, 0x50].contains(&b) {
            d.deck = d.reference;
        }
    }
}
