//! Painted regions of one graphics size, kept as palette indices. A region
//! paints on first use. A city change drops only the regions that the
//! changed tiles can reach.

use super::art::CityArt;
use super::geometry::{divisor, view_size};
use sc2k_render::{Builder, City, Config, Rect};
use std::collections::HashMap;

/// The edge of a region in view pixels.
pub const REGION: i32 = 256;
/// A pixel without paint.
pub const CLEAR: u16 = u16::MAX;
/// The palette index of the painter's redraw target color.
const TARGET_INDEX: u8 = 0xa1;
const ATLAS_EDGE: i32 = 2048;
/// The most regions that stay in memory.
const REGION_LIMIT: usize = 512;

/// The tile and margin sizes of each graphics size: tile width and height,
/// half width and height, altitude step, side and top margins.
const SIZES: [(i32, i32, i32, i32, i32, i32, i32); 3] = [(8, 5, 4, 2, 3, 8, 128), (16, 9, 8, 4, 6, 16, 256), (32, 17, 16, 8, 12, 32, 512)];

/// The display choices that change the painted pixels.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Options {
    pub underground: bool,
    pub pipes: bool,
    pub subways: bool,
    pub water_mains: bool,
    pub tunnels: bool,
}

impl Default for Options {
    fn default() -> Self {
        Self {
            underground: false,
            pipes: true,
            subways: true,
            water_mains: true,
            tunnels: true,
        }
    }
}

pub struct Region {
    pub x: i32,
    pub y: i32,
    pub width: i32,
    pub height: i32,
    /// A palette index for each pixel, or `CLEAR`.
    pub indices: Vec<u16>,
    used: u64,
}

pub struct Regions {
    pub view: usize,
    pub options: Options,
    builder: Builder,
    regions: HashMap<(i32, i32), Region>,
    sprite_limit: (i32, i32),
    clock: u64,
    /// The ALTM bytes of the last sync.
    altitude_bytes: Vec<u8>,
}

/// Shadows darken 0x74 through 0x7e to 0x7e, and 0x5f to 0x64.
fn shadow_pairs() -> Vec<([u8; 4], [u8; 4])> {
    let gray = |index: u8| [index, index, index, 255];
    let mut pairs: Vec<([u8; 4], [u8; 4])> = (0x74..=0x7e).rev().map(|index| (gray(index), gray(0x7e))).collect();
    pairs.push((gray(0x5f), gray(0x64)));
    pairs
}

impl Regions {
    pub fn new(city: City, art: &CityArt, view: usize, options: Options) -> Result<Self, String> {
        let config = Config {
            view: view as i32,
            underground: options.underground,
            pipes: options.pipes,
            subways: options.subways,
            tunnels: options.tunnels,
            mains: options.water_mains,
            redraw_ground: false,
            specials: false,
            phase: 0,
            effects: 0,
        };
        let target = [TARGET_INDEX, TARGET_INDEX, TARGET_INDEX, 255];
        let mut builder = Builder::new(city, config, art.views[view].clone(), target, ATLAS_EDGE, false)?;

        for (from, to) in shadow_pairs() {
            builder.shadows.insert(from, to);
        }

        let sprite_limit = builder.sprite_limit;

        Ok(Self {
            view,
            options,
            builder,
            regions: HashMap::new(),
            sprite_limit,
            clock: 0,
            altitude_bytes: Vec::new(),
        })
    }

    pub fn city(&self) -> &City {
        &self.builder.city
    }

    /// The view pixel size of the whole map.
    pub fn size(&self) -> (i32, i32) {
        view_size(self.view, self.builder.city.edge)
    }

    /// Apply a scene update to the maps. The regions that the changed tiles
    /// reach paint again.
    pub fn apply(&mut self, update: &super::scene::Update) {
        let mut changed = self.builder.edit_city(|city| super::scene::apply(city, update));

        if changed.len() > self.builder.city.altitude.len() / 8 {
            self.regions.clear();

            return;
        }

        changed.sort_unstable();
        changed.dedup();
        self.drop_cells(&changed);
    }

    /// The maps, for a new set of regions.
    pub fn into_city(self) -> City {
        self.builder.city
    }

    /// Bring the maps up to date with the simulation city in place. The
    /// regions that the changed tiles reach paint again.
    pub fn sync(&mut self, city: &sc2k_sim::sim::city::City) {
        let altitude_bytes = &mut self.altitude_bytes;
        let mut changed = self.builder.edit_city(|painter| super::sync::sync(painter, city, altitude_bytes));

        if changed.len() > self.builder.city.altitude.len() / 8 {
            self.regions.clear();

            return;
        }

        changed.sort_unstable();
        changed.dedup();
        self.drop_cells(&changed);
    }

    /// Drop the regions that the sprites of the tiles of `cells` can reach.
    fn drop_cells(&mut self, cells: &[usize]) {
        if self.regions.is_empty() {
            return;
        }

        let edge = self.builder.city.edge;
        let (width, height) = self.size();
        let columns = (width + REGION - 1) / REGION + 1;
        let rows = (height + REGION - 1) / REGION + 1;
        let mut dirty = vec![false; (columns * rows) as usize];

        for &cell in cells {
            let bounds = self.potential_bounds(cell as i32 / edge, cell as i32 % edge, edge);

            for (x, y) in region_keys(bounds) {
                if (0..columns).contains(&x) && (0..rows).contains(&y) {
                    dirty[(y * columns + x) as usize] = true;
                }
            }
        }

        self.regions
            .retain(|(x, y), _| !(*x >= 0 && *y >= 0 && *x < columns && *y < rows && dirty[(*y * columns + *x) as usize]));
    }

    /// Replace the city maps. The regions that the changed tiles reach paint again.
    pub fn update(&mut self, city: City) {
        let changed = changed_cells(&self.builder.city, &city);

        if changed.len() > city.altitude.len() / 8 {
            self.regions.clear();
        } else {
            let edge = city.edge;

            for cell in changed {
                let bounds = self.potential_bounds(cell as i32 / edge, cell as i32 % edge, edge);
                self.regions
                    .retain(|_, region| !intersects(bounds, Rect::new(region.x, region.y, region.width, region.height)));
            }
        }

        self.builder.update(city);
    }

    /// Replace the moving object draws. The regions under changed draws paint again.
    pub fn set_moving(&mut self, mut moving: HashMap<usize, Vec<sc2k_render::Draw>>) {
        // the painter keeps a mirrored copy of each flipped sprite
        for draws in moving.values_mut() {
            draws.retain(|draw| self.builder.sprites.get(draw.sprite, draw.flip).is_ok());
        }

        for rect in self.builder.update_moving(moving) {
            self.regions
                .retain(|_, region| !intersects(rect, Rect::new(region.x, region.y, region.width, region.height)));
        }
    }

    /// The view rectangle that the sprites of tile (x, y) can touch.
    fn potential_bounds(&self, x: i32, y: i32, edge: i32) -> Rect {
        let (tile_width, tile_height, half_width, half_height, step, side, top_margin) = SIZES[self.view];
        let (limit_width, limit_height) = self.sprite_limit;
        let screen_x = side + edge * half_width + (x - y) * half_width;
        let base = top_margin + (x + y) * half_height;
        let top = base - 32 * step - limit_height;
        let bottom = base + tile_height + limit_width / 4 + 1;

        Rect::new(screen_x - limit_width, top, tile_width + limit_width * 2 + 1, bottom - top)
    }

    /// The painted region at region coordinates (rx, ry).
    pub fn region(&mut self, rx: i32, ry: i32) -> Option<&Region> {
        self.clock += 1;
        let clock = self.clock;

        if !self.regions.contains_key(&(rx, ry)) {
            let (width, height) = self.size();
            let bounds = Rect::new(rx * REGION, ry * REGION, REGION, REGION).clip(Rect::new(0, 0, width, height));

            if !bounds.area() {
                return None;
            }

            let (rgba, _) = self.builder.raster(bounds, [0, 0, 0, 0]).ok()?;
            let indices = rgba
                .chunks_exact(4)
                .map(|pixel| if pixel[3] == 0 { CLEAR } else { u16::from(pixel[0]) })
                .collect();

            if self.regions.len() >= REGION_LIMIT {
                self.evict();
            }

            self.regions.insert(
                (rx, ry),
                Region {
                    x: bounds.x,
                    y: bounds.y,
                    width: bounds.w,
                    height: bounds.h,
                    indices,
                    used: clock,
                },
            );
        }

        let region = self.regions.get_mut(&(rx, ry))?;
        region.used = clock;

        Some(region)
    }

    fn evict(&mut self) {
        let mut ages: Vec<((i32, i32), u64)> = self.regions.iter().map(|(key, region)| (*key, region.used)).collect();
        ages.sort_by_key(|(_, used)| *used);

        for (key, _) in ages.into_iter().take(REGION_LIMIT / 4) {
            self.regions.remove(&key);
        }
    }

    pub fn divisor(&self) -> i32 {
        divisor(self.view)
    }
}

/// The keys of the regions that `rect` meets.
fn region_keys(rect: Rect) -> impl Iterator<Item = (i32, i32)> {
    let (x0, y0) = (rect.x.div_euclid(REGION), rect.y.div_euclid(REGION));
    let (x1, y1) = ((rect.x + rect.w - 1).div_euclid(REGION), (rect.y + rect.h - 1).div_euclid(REGION));

    (y0..=y1).flat_map(move |y| (x0..=x1).map(move |x| (x, y)))
}

#[allow(dead_code)]
fn intersects(a: Rect, b: Rect) -> bool {
    a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h
}

/// The cells whose drawings can differ between two cities of one size.
pub fn changed_cells(old: &City, new: &City) -> Vec<usize> {
    let cells = new.altitude.len();

    if old.altitude.len() != cells || old.traffic != new.traffic && old.traffic.len() != new.traffic.len() {
        return (0..cells).collect();
    }

    let mut changed = vec![false; cells];
    let mut mark = |a: &[u8], b: &[u8]| {
        if a != b {
            for (cell, (x, y)) in a.iter().zip(b).enumerate() {
                changed[cell] |= x != y;
            }
        }
    };

    mark(&old.terrain, &new.terrain);
    mark(&old.buildings, &new.buildings);
    mark(&old.zones, &new.zones);
    mark(&old.flags, &new.flags);
    mark(&old.underground, &new.underground);

    if old.overlays != new.overlays {
        let planes = new.overlays.len() / cells.max(1);

        for (cell, flag) in changed.iter_mut().enumerate() {
            *flag |= (0..planes.max(1)).any(|plane| old.overlays.get(plane * cells + cell) != new.overlays.get(plane * cells + cell));
        }
    }

    for (cell, (a, b)) in old.altitude.iter().zip(&new.altitude).enumerate() {
        changed[cell] |= a != b;
    }

    if old.traffic != new.traffic {
        // a traffic block covers several cells; repaint the cells of changed blocks
        let side = new.traffic.len().isqrt().max(1);
        let scale = (new.edge as usize / side).max(1);

        for (block, (a, b)) in old.traffic.iter().zip(&new.traffic).enumerate() {
            if a != b {
                let (bx, by) = (block / side * scale, block % side * scale);

                for x in bx..(bx + scale).min(new.edge as usize) {
                    for y in by..(by + scale).min(new.edge as usize) {
                        changed[x * new.edge as usize + y] = true;
                    }
                }
            }
        }
    }

    for cell in old.dispatch.keys().chain(new.dispatch.keys()) {
        if old.dispatch.get(cell) != new.dispatch.get(cell) {
            changed[*cell] = true;
        }
    }

    changed.iter().enumerate().filter(|(_, c)| **c).map(|(cell, _)| cell).collect()
}
