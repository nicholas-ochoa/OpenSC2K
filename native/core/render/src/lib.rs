//! Worker-owned region preparation. No simulation state or GPU objects live here,
//! and the crate has no engine types. A front end copies a display snapshot once
//! per revision. Inner loops use Rust arrays; the front end receives only
//! completed geometry and immutable sprite images.
pub mod changes;
pub mod compositing;
pub mod data_view;
pub mod debug_view;
pub mod floating;
pub mod ids;
pub mod index;
pub mod minimap;
pub mod nature;
pub mod painter;
pub mod raster;
pub mod rect_index;
pub mod region;
pub mod region_plan;
pub mod sprites;
pub mod surface_grid;
pub mod visual_auxiliary;
pub mod water_reflections;

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
            .unwrap_or_else(|| if self.wet(i) { self.water(i) } else { self.land(i) })
    }

    fn visible(&self, i: usize) -> bool {
        self.visible >= 32 || (if self.wet(i) { self.water(i) } else { self.land(i) }) < self.visible
    }

    /// The top value of a tile, as OverlayData.read.
    fn overlay(&self, i: usize) -> i32 {
        let cells = (self.edge * self.edge) as usize;

        if i >= cells || self.overlays.len() < cells || changes::overlay_cells(self.overlays.len()) != cells {
            return i32::from(*self.overlays.get(i).unwrap_or(&0));
        }

        changes::overlay(&self.overlays, i)
    }

    /// The marker byte of a tile: the first plane of every layout.
    fn marker(&self, i: usize) -> i32 {
        i32::from(*self.overlays.get(i).unwrap_or(&0))
    }

    pub fn set_dispatch(&mut self, things: &[u8]) {
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

            let coordinate =
                |field| i32::from(things[offset + field]) | if wide { i32::from(things[high + offset + field]) << 8 } else { 0 };
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

    fn traffic_scale(&self) -> Option<(usize, i32)> {
        let side = self.traffic.len().isqrt();

        if side == 0 || side * side != self.traffic.len() || self.edge % side as i32 != 0 {
            return None;
        }

        Some((side, self.edge / side as i32))
    }

    fn density(&self, x: i32, y: i32) -> i32 {
        let Some((side, scale)) = self.traffic_scale() else {
            return 0;
        };

        self.traffic[(x / scale) as usize * side + (y / scale) as usize] as i32
    }

    /// The terrain shape to draw. Surface water and channels at the land level
    /// beside higher land show the waterfall.
    fn surface(&self, x: i32, y: i32) -> u8 {
        use ids::terrain_tile_ids::{CHANNEL_LAST, SURFACE_WATER_FIRST, WATERFALL};
        let i = self.index(x, y);
        let t = self.terrain[i];

        if !(SURFACE_WATER_FIRST..=CHANNEL_LAST).contains(&t) || t == WATERFALL || self.water(i) != self.land(i) {
            return t;
        }

        for (dx, dy) in [(0, -1), (1, 0), (0, 1), (-1, 0)] {
            let (nx, ny) = (x + dx, y + dy);

            if nx >= 0 && ny >= 0 && nx < self.edge && ny < self.edge && self.land(self.index(nx, ny)) > self.land(i) {
                return ids::terrain_tile_ids::WATERFALL;
            }
        }

        t
    }

    pub fn validate(&self) -> Result<(), String> {
        let cells = (self.edge as usize)
            .checked_mul(self.edge as usize)
            .ok_or("invalid map dimensions")?;
        if !(1..=4096).contains(&self.edge)
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
    pub tunnels: bool,
    pub mains: bool,
    pub redraw_ground: bool,
    /// Draw the animated fire, flood and radiation markers as tile sprites.
    /// Previews use this; the city view draws them as moving sprites.
    pub specials: bool,
    /// Cosmetic cars replace the classic patterns on supported road tiles.
    pub individual_traffic: bool,
    /// Display-only natural terrain and woodland variants.
    pub natural_forests: bool,
    pub natural_terrain: bool,
    /// The animation phase of special overlays.
    pub phase: i32,
    /// The optional HD effects: the bits of `effects`.
    pub effects: i32,
}

/// Optional effects on HD art. Each bit turns on one effect.
pub mod effects {
    /// Thin tile grid lines on HD ground.
    pub const GRID: i32 = 1;
    /// Falling water on waterfalls.
    pub const WATERFALL: i32 = 2;
    /// Flowing water in watered underground pipes.
    pub const PIPE_FLOW: i32 = 4;
}

impl Config {
    pub fn divisor(self) -> i32 {
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
    /// A moving object sprite that a raster job adds to its tile. It is no
    /// static foreground.
    pub moving: bool,
    /// A shadow: its opaque pixels darken the pixels below through the palette.
    pub shadow: bool,
    /// The water altitude under a ship or sailboat, or -1. See `floating.rs`.
    pub floating: i32,
    /// The grid lines of HD ground. Refer to `surface_grid`.
    pub surface_grid: u16,
    /// Only building emission is disabled; its silhouette and seasonal art remain.
    pub emission_disabled: bool,
}

impl Draw {
    pub fn new(image: u64, rect: Rect) -> Self {
        Self {
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
            moving: false,
            shadow: false,
            floating: -1,
            surface_grid: 0,
            emission_disabled: false,
        }
    }
}

pub struct Builder {
    pub city: City,
    pub config: Config,
    pub sprites: sprites::Sprites,
    pub atlas: sprites::Atlas,
    tiles: HashMap<usize, region::Tile>,
    // Sprite bounds of each painted map cell, relative to its anchor. Bounds
    // outlive evicted draws, so a region skips known cells outside it.
    bounds: Vec<region::Bounds>,
    // The painter revision. A cached tile counts one reuse per revision.
    revision: u64,
    // The region serial. The tile cache evicts the least recently used tiles.
    stamp: u64,
    pub builds: i64,
    pub reuses: i64,
    maximum_altitude: i32,
    // The largest sprite of this artwork. It limits the region candidate span.
    pub sprite_limit: (i32, i32),
    /// Moving object draws of raster jobs, by map cell. A tile paints them
    /// after its static sprites, as the original painter does.
    pub moving: HashMap<usize, Vec<Draw>>,
    /// Shadow colors: each RGBA color and the darker color that a shadow makes.
    pub shadows: HashMap<[u8; 4], [u8; 4]>,
}

impl Builder {
    /// `pack_atlas` packs all unflipped artwork of the view for GPU regions. Raster
    /// builders leave the atlas empty.
    pub fn new(
        city: City,
        config: Config,
        images: HashMap<u64, Sprite>,
        target: [u8; 4],
        atlas_edge: i32,
        pack_atlas: bool,
    ) -> Result<Self, String> {
        let mut sprite_limit = (0, 0);
        let mut artwork: Vec<u64> = Vec::new();

        for (key, sprite) in &images {
            let id = (*key / 2) as i32;

            let original = nature::original(id);
            if *key & 1 == 0 && original >= config.base() && original < config.base() + 500 {
                sprite_limit = (sprite_limit.0.max(sprite.w), sprite_limit.1.max(sprite.h));
                artwork.push(*key);
            }
        }

        let cells = city.altitude.len();
        let mut builder = Self {
            maximum_altitude: maximum_altitude(&city),
            city,
            config,
            sprites: sprites::Sprites::new(images, target),
            atlas: sprites::Atlas::new(atlas_edge),
            tiles: HashMap::new(),
            bounds: vec![region::Bounds::UNKNOWN; cells],
            revision: 0,
            stamp: 0,
            builds: 0,
            reuses: 0,
            sprite_limit,
            moving: HashMap::new(),
            shadows: HashMap::new(),
        };
        // Pack all unflipped artwork once. Scrolling then seldom adds a sprite,
        // so the main thread seldom uploads a changed atlas. Tall sprites
        // first make shelf rows with less unused space.
        artwork.sort_by_key(|key| {
            let sprite = &builder.sprites.images[key];
            (std::cmp::Reverse(sprite.h), std::cmp::Reverse(sprite.w), *key)
        });

        if pack_atlas {
            for key in artwork {
                builder.atlas.slot(key, &builder.sprites.images[&key])?;
            }
        }

        Ok(builder)
    }

    pub fn update(&mut self, city: City) {
        let cells = self.bounds.len();
        let old = &self.city;
        let mut changed = vec![false; cells];
        mark(&old.altitude, &city.altitude, &mut changed);
        mark(&old.terrain, &city.terrain, &mut changed);
        mark(&old.buildings, &city.buildings, &mut changed);
        mark(&old.zones, &city.zones, &mut changed);
        mark(&old.flags, &city.flags, &mut changed);
        mark(&old.underground, &city.underground, &mut changed);

        if old.overlays != city.overlays {
            for (i, cell) in changed.iter_mut().enumerate() {
                *cell |= old.overlay(i) != city.overlay(i) || old.marker(i) != city.marker(i);
            }
        }

        // Negative and absent overrides both mean no override.
        for (before, after) in [(&old.ground, &city.ground), (&old.objects, &city.objects)] {
            if before != after {
                let value = |values: &Vec<i32>, i: usize| values.get(i).copied().filter(|v| *v >= 0).unwrap_or(-1);

                for (i, cell) in changed.iter_mut().enumerate() {
                    *cell |= value(before, i) != value(after, i);
                }
            }
        }

        if old.dispatch != city.dispatch {
            for (i, sprite) in old.dispatch.iter().chain(city.dispatch.iter()) {
                if old.dispatch.get(i) != Some(sprite) || city.dispatch.get(i) != Some(sprite) {
                    changed[*i] = true;
                }
            }
        }

        if old.traffic != city.traffic {
            match (old.traffic_scale(), city.traffic_scale()) {
                (Some((side, scale)), Some(_)) if old.traffic.len() == city.traffic.len() => {
                    // Only the traffic band of a block changes its drawings.
                    for (t, (a, b)) in old.traffic.iter().zip(&city.traffic).enumerate() {
                        if traffic_band(*a) != traffic_band(*b) {
                            let (bx, by) = ((t / side) as i32 * scale, (t % side) as i32 * scale);

                            for x in bx..bx + scale {
                                for y in by..by + scale {
                                    changed[city.index(x, y)] = true;
                                }
                            }
                        }
                    }
                }
                (None, None) => {}
                _ => changed.fill(true),
            }
        }

        if old.altitude != city.altitude || old.objects != city.objects {
            self.maximum_altitude = maximum_altitude(&city);
        }

        let edited: Vec<usize> = changed.iter().enumerate().filter(|(_, c)| **c).map(|(i, _)| i).collect();
        self.city = city;

        if edited.len() > cells / 8 {
            self.tiles.clear();
            self.bounds.fill(region::Bounds::UNKNOWN);
        } else {
            // A tile reads its own cell and its eight neighbors: shoreline
            // waterfalls, composite ground, and nothing farther.
            let edge = self.city.edge;

            for i in edited {
                let (x, y) = (i as i32 / edge, i as i32 % edge);

                for nx in (x - 1).max(0)..=(x + 1).min(edge - 1) {
                    for ny in (y - 1).max(0)..=(y + 1).min(edge - 1) {
                        let n = self.city.index(nx, ny);
                        self.bounds[n] = region::Bounds::UNKNOWN;
                        self.tiles.remove(&n);
                    }
                }
            }
        }

        self.revision += 1;
    }

    /// Replaces the moving object draws. Painted tiles are painted again.
    pub fn set_moving(&mut self, moving: HashMap<usize, Vec<Draw>>) {
        self.moving = moving;
        self.tiles.clear();
        self.bounds.fill(region::Bounds::UNKNOWN);
        self.revision += 1;
    }

    /// Change the city maps in place. `edit` returns the cells that it changed;
    /// their tiles and the tiles beside them paint again.
    pub fn edit_city(&mut self, edit: impl FnOnce(&mut City) -> Vec<usize>) -> Vec<usize> {
        let changed = edit(&mut self.city);

        if changed.is_empty() {
            return changed;
        }

        self.maximum_altitude = maximum_altitude(&self.city);
        let edge = self.city.edge;

        if changed.len() > self.bounds.len() / 8 {
            self.tiles.clear();
            self.bounds.fill(region::Bounds::UNKNOWN);
        } else {
            for &i in &changed {
                let (x, y) = (i as i32 / edge, i as i32 % edge);

                for nx in (x - 1).max(0)..=(x + 1).min(edge - 1) {
                    for ny in (y - 1).max(0)..=(y + 1).min(edge - 1) {
                        let n = self.city.index(nx, ny);
                        self.bounds[n] = region::Bounds::UNKNOWN;
                        self.tiles.remove(&n);
                    }
                }
            }
        }

        self.revision += 1;

        changed
    }

    /// Replaces the moving object draws, and paints again only the tiles whose
    /// draws changed. Returns the old and new rectangles of the changed draws.
    pub fn update_moving(&mut self, moving: HashMap<usize, Vec<Draw>>) -> Vec<Rect> {
        let key = |draw: &Draw| (draw.image, draw.rect, draw.sprite, draw.flip, draw.shadow, draw.floating);
        let same = |a: &[Draw], b: &[Draw]| a.len() == b.len() && a.iter().zip(b).all(|(x, y)| key(x) == key(y));
        let mut changed = Vec::new();

        for cell in self.moving.keys().chain(moving.keys()) {
            let before = self.moving.get(cell).map_or(&[][..], Vec::as_slice);
            let after = moving.get(cell).map_or(&[][..], Vec::as_slice);

            if !same(before, after) {
                changed.extend(before.iter().chain(after).map(|draw| draw.rect));

                if *cell < self.bounds.len() {
                    self.tiles.remove(cell);
                    self.bounds[*cell] = region::Bounds::UNKNOWN;
                }
            }
        }

        if !changed.is_empty() {
            self.revision += 1;
        }

        self.moving = moving;

        changed
    }

    pub fn cached_tiles(&self) -> usize {
        self.tiles.len()
    }
}

fn mark<T: PartialEq>(old: &[T], new: &[T], changed: &mut [bool]) {
    if old != new {
        for ((cell, a), b) in changed.iter_mut().zip(old).zip(new) {
            *cell |= a != b;
        }
    }
}

// Traffic sprites change only at these density limits.
fn traffic_band(density: u8) -> usize {
    [28, 56, 85, 170].iter().filter(|limit| density > **limit).count()
}

fn maximum_altitude(city: &City) -> i32 {
    city.altitude
        .iter()
        .map(|v| (v & 31).max((v >> 5) & 31))
        .chain(city.objects.iter().copied())
        .max()
        .unwrap_or(0)
        .clamp(0, 31)
}

#[cfg(test)]
mod tests;
