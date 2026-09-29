//! Worker-owned region preparation. No simulation state or GPU objects live here.
//! The bridge copies a display snapshot once per revision. Inner loops use Rust
//! arrays; Godot receives only completed geometry and immutable sprite images.
mod bridge;
mod painter;
mod region;
mod sprites;

use sprites::Sprite;
use std::collections::HashMap;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Rect {
    pub x: i32,
    pub y: i32,
    pub w: i32,
    pub h: i32,
}
impl Rect {
    pub fn new(x: i32, y: i32, w: i32, h: i32) -> Self {
        Self { x, y, w, h }
    }
    pub fn clip(self, other: Self) -> Self {
        let x = self.x.max(other.x);
        let y = self.y.max(other.y);
        Self::new(
            x,
            y,
            (self.x + self.w).min(other.x + other.w) - x,
            (self.y + self.h).min(other.y + other.h) - y,
        )
    }
    pub fn area(self) -> bool {
        self.w > 0 && self.h > 0
    }
}

#[derive(Clone, Debug, Default)]
pub struct City {
    pub edge: i32,
    pub visible: i32,
    pub rotation: usize,
    pub altitude: Vec<i32>,
    pub terrain: Vec<u8>,
    pub buildings: Vec<u8>,
    pub zones: Vec<u8>,
    pub flags: Vec<u8>,
    pub overlays: Vec<u8>,
    pub underground: Vec<u8>,
    pub ground: Vec<i32>,
    pub objects: Vec<i32>,
    pub traffic: Vec<u8>,
    // Sprite offsets of stationary dispatch objects, indexed by map cell.
    pub dispatch: HashMap<usize, i32>,
}
impl City {
    fn index(&self, x: i32, y: i32) -> usize {
        (x * self.edge + y) as usize
    }
    fn land(&self, i: usize) -> i32 {
        self.altitude[i] & 31
    }
    fn water(&self, i: usize) -> i32 {
        (self.altitude[i] >> 5) & 31
    }
    fn wet(&self, i: usize) -> bool {
        self.flags[i] & 4 != 0
    }
    fn object(&self, i: usize) -> i32 {
        self.objects
            .get(i)
            .copied()
            .filter(|v| *v >= 0)
            .unwrap_or_else(|| {
                if self.wet(i) {
                    self.water(i)
                } else {
                    self.land(i)
                }
            })
    }
    fn visible(&self, i: usize) -> bool {
        self.visible >= 32
            || (if self.wet(i) {
                self.water(i)
            } else {
                self.land(i)
            }) < self.visible
    }
    fn overlay(&self, i: usize) -> i32 {
        let cells = (self.edge * self.edge) as usize;
        i32::from(*self.overlays.get(i).unwrap_or(&0))
            | (i32::from(*self.overlays.get(cells + i).unwrap_or(&0)) << 8)
    }
    fn set_dispatch(&mut self, things: &[u8]) {
        // XTHG keeps 12-byte records. Extended payloads have equal low and
        // high planes; X and Y widen, while the dispatch type stays a byte.
        let wide = things.len() > 480;
        let count = things.len() / if wide { 24 } else { 12 };
        let high = things.len() / 2;
        self.dispatch.clear();
        // Record zero has no dispatch sprite in the reference painter.
        for record in 1..count {
            let offset = record * 12;
            let sprite = match things[offset] {
                7 => 382,
                8 => 383,
                14 => 384,
                _ => continue,
            };
            let coordinate = |field| {
                i32::from(things[offset + field])
                    | if wide {
                        i32::from(things[high + offset + field]) << 8
                    } else {
                        0
                    }
            };
            let (x, y) = (coordinate(3), coordinate(4));
            if x >= self.edge || y >= self.edge {
                continue;
            }
            let overlay = if record < 40 {
                201 + record as i32
            } else {
                8192 + record as i32 - 40
            };
            let index = self.index(x, y);
            if self.overlay(index) == overlay {
                self.dispatch.insert(index, sprite);
            }
        }
    }
    fn density(&self, x: i32, y: i32) -> i32 {
        let side = self.traffic.len().isqrt() as i32;
        if side == 0 || side * side != self.traffic.len() as i32 || self.edge % side != 0 {
            return 0;
        }
        let scale = self.edge / side;
        self.traffic[(x / scale * side + y / scale) as usize] as i32
    }
    fn surface(&self, x: i32, y: i32) -> i32 {
        let i = self.index(x, y);
        let t = self.terrain[i] as i32;
        if !(0x30..=0x45).contains(&t) || t == 0x3e || self.water(i) != self.land(i) {
            return t;
        }
        for (dx, dy) in [(0, -1), (1, 0), (0, 1), (-1, 0)] {
            let (nx, ny) = (x + dx, y + dy);
            if nx >= 0
                && ny >= 0
                && nx < self.edge
                && ny < self.edge
                && self.land(self.index(nx, ny)) > self.land(i)
            {
                return 0x3e;
            }
        }
        t
    }
    pub fn validate(&self) -> Result<(), String> {
        let cells = (self.edge as usize)
            .checked_mul(self.edge as usize)
            .ok_or("invalid map dimensions")?;
        if !(1..=1024).contains(&self.edge)
            || self.rotation > 3
            || self.altitude.len() != cells
            || [
                self.terrain.len(),
                self.buildings.len(),
                self.zones.len(),
                self.flags.len(),
                self.underground.len(),
            ]
            .iter()
            .any(|n| *n != cells)
        {
            return Err("invalid native region city arrays".into());
        }
        Ok(())
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Config {
    pub view: i32,
    pub underground: bool,
    pub pipes: bool,
    pub subways: bool,
    pub mains: bool,
    pub redraw_ground: bool,
}
impl Config {
    fn divisor(self) -> i32 {
        4 >> self.view
    }
    fn hw(self) -> i32 {
        16 / self.divisor()
    }
    fn hh(self) -> i32 {
        8 / self.divisor()
    }
    fn step(self) -> i32 {
        12 / self.divisor()
    }
    fn top(self) -> i32 {
        512 / self.divisor()
    }
    fn side(self) -> i32 {
        32 / self.divisor()
    }
    fn height(self) -> i32 {
        16 / self.divisor() + 1
    }
    fn base(self) -> i32 {
        500 * self.view
    }
}

#[derive(Clone, Debug)]
pub struct Draw {
    pub id: i64,
    pub image: u64,
    pub rect: Rect,
    pub sprite: i32,
    pub flip: bool,
    pub depth: i64,
    pub order: i64,
    pub ignore: bool,
    pub reference: i32,
    pub thickness: i32,
    pub deck: i32,
    pub requires_depth: bool,
}
impl Draw {
    fn new(image: u64, rect: Rect) -> Self {
        Self {
            id: 0,
            image,
            rect,
            sprite: -1,
            flip: false,
            depth: -1,
            order: -1,
            ignore: false,
            reference: 0,
            thickness: 0,
            deck: 0,
            requires_depth: false,
        }
    }
}

pub struct Builder {
    pub city: City,
    pub config: Config,
    pub sprites: sprites::Sprites,
    pub atlas: sprites::Atlas,
    tiles: HashMap<usize, region::Tile>,
    queue: std::collections::VecDeque<usize>,
    serial: i64,
    pub builds: i64,
    pub reuses: i64,
    pub evicted: Vec<i64>,
    maximum_altitude: i32,
}
impl Builder {
    pub fn new(city: City, config: Config, images: HashMap<u64, Sprite>, target: [u8; 4]) -> Self {
        let maximum_altitude = city
            .altitude
            .iter()
            .map(|v| (v & 31).max((v >> 5) & 31))
            .chain(city.objects.iter().copied())
            .max()
            .unwrap_or(0)
            .clamp(0, 31);
        Self {
            city,
            config,
            sprites: sprites::Sprites::new(images, target),
            atlas: sprites::Atlas::new(),
            tiles: HashMap::new(),
            queue: Default::default(),
            serial: 0,
            builds: 0,
            reuses: 0,
            evicted: Vec::new(),
            maximum_altitude,
        }
    }
    pub fn update(&mut self, city: City) {
        // Exact snapshot comparisons include neighbors and dispatch records. They
        // avoid hash collisions and preserve cached geometry after unrelated edits.
        let old = &self.city;
        let mut invalid = Vec::new();
        for (&i, tile) in &mut self.tiles {
            let (x, y) = (i as i32 / city.edge, i as i32 % city.edge);
            let same = old.altitude[i] == city.altitude[i]
                && old.terrain[i] == city.terrain[i]
                && old.buildings[i] == city.buildings[i]
                && old.zones[i] == city.zones[i]
                && old.flags[i] == city.flags[i]
                && old.underground[i] == city.underground[i]
                && old.overlay(i) == city.overlay(i)
                && old.ground.get(i) == city.ground.get(i)
                && old.objects.get(i) == city.objects.get(i)
                && old.density(x, y) == city.density(x, y)
                && old.dispatch.get(&i) == city.dispatch.get(&i)
                && old.surface(x, y) == city.surface(x, y);
            let neighbors = [(0, -1), (1, -1), (1, 0)].iter().all(|(dx, dy)| {
                let (nx, ny) = (x + dx, y + dy);
                if nx < 0 || ny < 0 || nx >= city.edge || ny >= city.edge {
                    return true;
                }
                let n = city.index(nx, ny);
                old.terrain[n] == city.terrain[n] && old.wet(n) == city.wet(n)
            });
            if !same || !neighbors {
                invalid.push(i);
            } else {
                tile.pending_reuse = true;
            }
        }
        for i in invalid {
            self.remove_tile(i);
        }
        self.queue.retain(|i| self.tiles.contains_key(i));
        self.maximum_altitude = city
            .altitude
            .iter()
            .map(|v| (v & 31).max((v >> 5) & 31))
            .chain(city.objects.iter().copied())
            .max()
            .unwrap_or(0)
            .clamp(0, 31);
        self.city = city;
    }
    fn remove_tile(&mut self, i: usize) {
        if let Some(tile) = self.tiles.remove(&i) {
            self.evicted.extend(tile.draws.iter().map(|d| d.id));
        }
    }
}

use godot::prelude::*;
struct OpenSc2kRendering;
#[gdextension(entry_symbol = opensc2k_rendering_init)]
unsafe impl ExtensionLibrary for OpenSc2kRendering {}

#[cfg(test)]
mod tests;
