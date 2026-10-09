//! Cached presentation variants. No random generator or simulation state is used.
use crate::{Builder, ids::building_tile_ids as tiles};

pub const FIRST: i32 = 6000;
pub const SPAN: i32 = 1500;

pub fn original(id: i32) -> i32 {
    if id >= FIRST { id % SPAN } else { id }
}

impl Builder {
    pub(super) fn forest_sprite(&self, x: i32, y: i32, id: i32) -> i32 {
        let city = &self.city;
        let i = city.index(x, y);
        let b = city.buildings[i];
        if !self.config.natural_forests || !(tiles::TREES_1..=tiles::TREES_7).contains(&b) {
            return id;
        }
        let mut neighbors = 0;
        for (bit, (dx, dy)) in [(0, -1), (1, 0), (0, 1), (-1, 0)].into_iter().enumerate() {
            let (nx, ny) = (x + dx, y + dy);
            if nx >= 0 && ny >= 0 && nx < city.edge && ny < city.edge {
                let n = city.index(nx, ny);
                if (tiles::TREES_4..=tiles::TREES_7).contains(&city.buildings[n])
                    && !city.wet(n)
                    && city.visible(n)
                    && (city.land(n) - city.land(i)).abs() <= 1
                {
                    neighbors |= 1 << bit;
                }
            }
        }
        // Undo the display rotation for a stable coordinate-based variant.
        let last = city.edge - 1;
        let (cx, cy) = match city.rotation {
            1 => (y, last - x),
            2 => (last - x, last - y),
            3 => (last - y, x),
            _ => (x, y),
        };
        let hash = (cx as u32).wrapping_mul(374_761_393) ^ (cy as u32).wrapping_mul(668_265_263);
        let variant = ((hash ^ (hash >> 13)) & 7) as i32;
        let selected = FIRST + (neighbors * 8 + variant) * SPAN + id;
        if self.sprites.images.contains_key(&(selected as u64 * 2)) {
            selected
        } else {
            id
        }
    }

    pub(super) fn nature_ground(&self, id: i32) -> i32 {
        let selected = FIRST + 128 * SPAN + id;
        if self.config.natural_terrain && (256..=268).contains(&(id % 500)) && self.sprites.images.contains_key(&(selected as u64 * 2)) {
            selected
        } else {
            id
        }
    }
}
