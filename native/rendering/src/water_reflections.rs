//! Indexed sprite reflections on visible, horizontal water. Display snapshots only.
//! Pixel centres reflect about each column's projected footprint at the receiving
//! water altitude. No simulation state, random state or original pixels change.
use crate::{Builder, City, Config, Draw, Rect, sprites::Sprite};
use std::collections::HashMap;

pub struct WaterPixels {
    pub surface: Vec<u8>,
    pub reflected: Vec<u8>,
    pub emission: Vec<u8>,
    pub seasons: Vec<u8>,
    pub seabed: Vec<u8>,
}

pub fn mirrored_row(row: i32, contact: i32, object_altitude: i32, water_altitude: i32, step: i32) -> i32 {
    // Reflect pixel centres, not their upper edges: (y + .5)' = 2*p - (y + .5).
    2 * (contact + (object_altitude - water_altitude) * step) - row - 1
}

fn cell(city: &City, depth: i64) -> Option<usize> {
    if depth < 0 {
        return None;
    }
    let y = depth % i64::from(city.edge);
    let x = depth / i64::from(city.edge) - y;
    (x >= 0 && y >= 0 && x < i64::from(city.edge) && y < i64::from(city.edge)).then(|| city.index(x as i32, y as i32))
}

fn horizontal_water(draw: &Draw, city: &City, config: Config) -> Option<usize> {
    let offset = draw.sprite - config.base();
    if !(270..=290).contains(&offset) || offset == 284 || draw.moving || draw.shadow {
        return None;
    }
    let i = cell(city, draw.depth)?;
    let t = city.terrain[i];
    (city.wet(i) || (0x10..=0x1e).contains(&t) || (0x20..=0x45).contains(&t)).then_some(i)
}

fn contact_row(draw: &Draw, column: i32, developed: bool) -> i32 {
    // Developed SC2K sprites stand on a diamond footprint. Its front boundary
    // slopes up by half a pixel per column from the centre to either edge.
    // Trees and narrow props use their painter's point anchor instead.
    let inset = if developed {
        ((2 * column + 1 - draw.rect.w).abs() - 1).max(0) / 4
    } else {
        0
    };
    draw.rect.y + draw.rect.h - inset
}

fn auxiliary(artwork: &HashMap<u64, Sprite>, draw: &Draw, sprite: &Sprite, x: i32, y: i32) -> [u8; 4] {
    let Some(mask) = artwork.get(&((draw.sprite as u64) * 2)) else {
        return [0; 4];
    };
    if mask.w != sprite.w || mask.h != sprite.h {
        return [0; 4];
    }
    let x = if draw.flip { mask.w - 1 - x } else { x };
    mask.rgba[((y * mask.w + x) * 4) as usize..((y * mask.w + x) * 4 + 4) as usize]
        .try_into()
        .unwrap()
}

fn plane_cell(city: &City, c: Config, x: i32, y: i32, water: i32) -> Option<usize> {
    let across = (f64::from(x) + 0.5 - f64::from(c.side() + (city.edge + 1) * c.hw())) / f64::from(c.hw());
    let along = (f64::from(y) + 0.5 - f64::from(c.top() - water * c.step())) / f64::from(c.hh());
    let tx = ((along + across) / 2.0).floor() as i32;
    let ty = ((along - across) / 2.0).floor() as i32;
    (tx >= 0 && ty >= 0 && tx < city.edge && ty < city.edge).then(|| city.index(tx, ty))
}

fn unobstructed(city: &City, c: Config, x: i32, start: i32, end: i32, level: i32) -> bool {
    let mut entered_water = false;
    // A reflection may leave its own bank. It may not cross a second raised
    // bank, island or another water level to reach an unrelated water surface.
    for y in (start..=end).step_by(c.hh().max(1) as usize) {
        let Some(i) = plane_cell(city, c, x, y, level) else { return false };
        let wet = city.wet(i) || (0x10..=0x1e).contains(&city.terrain[i]) || (0x30..=0x45).contains(&city.terrain[i]);
        if wet && city.water(i) == level {
            entered_water = true;
        } else if entered_water && city.land(i) >= level {
            return false;
        }
    }
    entered_water
}

impl Builder {
    pub fn water_pixels(
        &mut self,
        bounds: Rect,
        water_indices: &[u8],
        emission: &HashMap<u64, Sprite>,
        seasons: &HashMap<u64, Sprite>,
    ) -> Result<WaterPixels, String> {
        let bytes = bounds.w as usize * bounds.h as usize * 4;
        let mut out = WaterPixels {
            surface: vec![0; bytes],
            reflected: vec![0; bytes],
            emission: vec![0; bytes],
            seasons: vec![0; bytes],
            seabed: vec![0; bytes],
        };
        if self.config.underground || water_indices.len() != 256 {
            return Ok(out);
        }
        let mut levels = [false; 32];
        for draw in self.collect(bounds)? {
            let sprite = &self.sprites.images[&draw.image];
            let water = horizontal_water(&draw, &self.city, self.config);
            let clipped = draw.rect.clip(bounds);
            for y in clipped.y..clipped.y + clipped.h {
                for x in clipped.x..clipped.x + clipped.w {
                    let src = (((y - draw.rect.y) * sprite.w + x - draw.rect.x) * 4) as usize;
                    if sprite.rgba[src + 3] == 0 {
                        continue;
                    }
                    let dst = (((y - bounds.y) * bounds.w + x - bounds.x) * 4) as usize;
                    out.surface[dst..dst + 4].fill(0);
                    if let Some(i) = water.filter(|_| water_indices[sprite.rgba[src] as usize] != 0) {
                        let level = self.city.water(i);
                        levels[level as usize] = true;
                        out.surface[dst..dst + 4].copy_from_slice(&[level as u8 + 1, sprite.rgba[src], 0, 255]);
                    }
                }
            }
        }
        if !out.surface.chunks_exact(4).any(|p| p[3] != 0) {
            return Ok(out);
        }
        // Include source sprites outside the output region. A tall source above
        // the viewport may still reflect inside it. The bound covers every saved
        // altitude and the largest sprite in this configured artwork.
        let reach = self.sprite_limit.1 + 62 * self.config.step() + self.sprite_limit.0;
        let sources = self.collect(Rect::new(bounds.x, bounds.y - reach, bounds.w, bounds.h + 2 * reach))?;
        seabed_pixels(&mut out.seabed, bounds, &sources, &self.city, self.config);
        let mut owners = vec![i64::MIN; bytes / 4];
        for draw in &sources {
            let Some(i) = cell(&self.city, draw.depth) else { continue };
            if draw.shadow
                || draw.moving
                || draw.sprite != self.config.base() + i32::from(self.city.buildings[i])
                || self.city.buildings[i] == 0
                || draw.image >= 1_u64 << 32
            {
                continue;
            }
            let sprite = &self.sprites.images[&draw.image];
            let altitude = self.city.object(i);
            let developed = self.city.buildings[i] >= crate::ids::building_tile_ids::DEVELOPED_FIRST;
            for (level, present) in levels.iter().enumerate() {
                if !present || altitude < level as i32 {
                    continue;
                }
                let level = level as i32;
                let far = mirrored_row(draw.rect.y, draw.rect.y + draw.rect.h, altitude, level, self.config.step());
                let near = mirrored_row(
                    draw.rect.y + draw.rect.h - 1,
                    draw.rect.y + draw.rect.h - draw.rect.w / 4,
                    altitude,
                    level,
                    self.config.step(),
                );
                if !Rect::new(draw.rect.x, near, draw.rect.w, far - near + 1).clip(bounds).area() {
                    continue;
                }
                let first = (bounds.x - draw.rect.x).max(0);
                let last = (bounds.x + bounds.w - draw.rect.x).min(sprite.w);
                for sx in first..last {
                    let contact = contact_row(draw, sx, developed);
                    let plane = contact + (altitude - level) * self.config.step();
                    // Land obstructions are checked once per column and receiver
                    // tile span, rather than once for every reflected pixel.
                    let mut visibility = HashMap::new();
                    for sy in 0..sprite.h {
                        let src = ((sy * sprite.w + sx) * 4) as usize;
                        if sprite.rgba[src + 3] == 0 || draw.rect.y + sy >= contact {
                            continue;
                        }
                        let y = mirrored_row(draw.rect.y + sy, contact, altitude, level, self.config.step());
                        if y < bounds.y || y >= bounds.y + bounds.h {
                            continue;
                        }
                        let x = draw.rect.x + sx;
                        let pixel = ((y - bounds.y) * bounds.w + x - bounds.x) as usize;
                        let dst = pixel * 4;
                        if out.surface[dst] != level as u8 + 1 || out.surface[dst + 3] == 0 || owners[pixel] > draw.order {
                            continue;
                        }
                        let receiver = plane_cell(&self.city, self.config, x, y, level);
                        let visible = *visibility
                            .entry(receiver)
                            .or_insert_with(|| unobstructed(&self.city, self.config, x, plane, y, level));
                        if !visible {
                            continue;
                        }
                        let distance = (y - plane).max(0);
                        let fade = (255 - distance * self.config.divisor()).max(0) as u8;
                        owners[pixel] = draw.order;
                        out.reflected[dst..dst + 4].copy_from_slice(&[sprite.rgba[src], 0, 0, fade]);
                        out.emission[dst..dst + 4].copy_from_slice(&auxiliary(emission, draw, sprite, sx, sy));
                        out.seasons[dst..dst + 4].copy_from_slice(&auxiliary(seasons, draw, sprite, sx, sy));
                    }
                }
            }
        }
        Ok(out)
    }
}

fn seabed_pixels(out: &mut [u8], bounds: Rect, sources: &[Draw], city: &City, config: Config) {
    let data = crate::data_view::DataCity {
        edge: city.edge as usize,
        visible: city.visible,
        altitude: &city.altitude,
        terrain: &city.terrain,
        flags: &city.flags,
    };
    let mut painted = std::collections::HashSet::new();
    for draw in sources {
        let Some(i) = cell(city, draw.depth) else { continue };
        if !painted.insert(i) {
            continue;
        }
        let (x, y) = (i / city.edge as usize, i % city.edge as usize);
        // Reuse the height-map's actual seabed polygons, including deep-water
        // slopes and stream banks. These are not random textures or flat tiles.
        let polygon = data.surface_polygon(x, y, true);
        let flat = [
            512.0 + (x + y) as f32 * 8.0,
            520.0 + (x + y) as f32 * 8.0,
            528.0 + (x + y) as f32 * 8.0,
            520.0 + (x + y) as f32 * 8.0,
        ];
        let heights: [f32; 4] = std::array::from_fn(|n| (flat[n] - polygon[n][1]) / 12.0);
        let points = polygon.map(|p| [p[0] / config.divisor() as f32, p[1] / config.divisor() as f32]);
        for tri in [[0, 1, 2], [0, 2, 3]] {
            let vertices = tri.map(|n| points[n]);
            let z = tri.map(|n| heights[n]);
            seabed_triangle(out, bounds, vertices, z);
        }
    }
}

fn seabed_triangle(out: &mut [u8], bounds: Rect, p: [[f32; 2]; 3], h: [f32; 3]) {
    let cross = |a: [f32; 2], b: [f32; 2], c: [f32; 2]| (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
    let area = cross(p[0], p[1], p[2]);
    if area.abs() < 0.001 {
        return;
    }
    let left = p.iter().map(|v| v[0].floor() as i32).min().unwrap().max(bounds.x);
    let right = p.iter().map(|v| v[0].ceil() as i32).max().unwrap().min(bounds.x + bounds.w);
    let top = p.iter().map(|v| v[1].floor() as i32).min().unwrap().max(bounds.y);
    let bottom = p.iter().map(|v| v[1].ceil() as i32).max().unwrap().min(bounds.y + bounds.h);
    // Constant face shading makes the actual slopes readable through water.
    let shade = (190.0 + (h[0] - h[1]) * 35.0 + (h[0] - h[2]) * 22.0).clamp(60.0, 255.0) as u8;
    for y in top..bottom {
        for x in left..right {
            let q = [x as f32 + 0.5, y as f32 + 0.5];
            let weights = [
                cross(p[1], p[2], q) / area,
                cross(p[2], p[0], q) / area,
                cross(p[0], p[1], q) / area,
            ];
            if weights.iter().any(|v| *v < -0.0001) {
                continue;
            }
            let altitude = weights.iter().zip(h).map(|(weight, height)| weight * height).sum::<f32>();
            let at = (((y - bounds.y) * bounds.w + x - bounds.x) * 4) as usize;
            out[at..at + 4].copy_from_slice(&[(altitude * 255.0 / 31.0).clamp(0.0, 255.0) as u8, shade, 0, 255]);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fixture(view: i32) -> Builder {
        let edge = 4;
        let cells = (edge * edge) as usize;
        let mut city = City {
            edge,
            visible: 32,
            altitude: vec![0; cells],
            terrain: vec![0x10; cells],
            buildings: vec![0; cells],
            zones: vec![0; cells],
            flags: vec![4; cells],
            overlays: vec![0; cells],
            underground: vec![0; cells],
            ..Default::default()
        };
        city.flags[0] = 0;
        city.terrain[0] = 0;
        city.buildings[0] = 0x70;
        city.zones[0] = 0x80;
        let config = Config {
            view,
            underground: false,
            pipes: true,
            subways: true,
            tunnels: true,
            mains: true,
            redraw_ground: false,
            specials: false,
            phase: 0,
        };
        let w = config.hw() * 2;
        let h = config.hh() * 2 + 1;
        let mut water = Sprite {
            w,
            h,
            rgba: vec![0; (w * h * 4) as usize],
            la: vec![0; (w * h * 2) as usize],
        };
        for y in 0..h {
            for x in 0..w {
                if (2 * x + 1 - w).abs() + 2 * (y - config.hh()).abs() <= w {
                    let at = (y * w + x) as usize;
                    water.rgba[at * 4..at * 4 + 4].copy_from_slice(&[96, 96, 96, 255]);
                    water.la[at * 2..at * 2 + 2].copy_from_slice(&[96, 255]);
                }
            }
        }
        let mut building = water.clone();
        building.h = h + 24 / config.divisor();
        building.rgba = vec![0; (building.w * building.h * 4) as usize];
        building.la = vec![0; (building.w * building.h * 2) as usize];
        for y in 0..building.h {
            for x in 0..building.w {
                let at = (y * building.w + x) as usize;
                let index = (40 + y % 20 + x % 5) as u8;
                building.rgba[at * 4..at * 4 + 4].copy_from_slice(&[index, index, index, 255]);
                building.la[at * 2..at * 2 + 2].copy_from_slice(&[index, 255]);
            }
        }
        let images = HashMap::from([
            (((config.base() + 270) * 2) as u64, water.clone()),
            (((config.base() + 256) * 2) as u64, water.clone()),
            (((config.base() + 284) * 2) as u64, water),
            (((config.base() + 0x70) * 2) as u64, building),
        ]);
        Builder::new(city, config, images, [161; 4], 2048, false).unwrap()
    }

    #[test]
    fn actual_sprite_pixels_reflect_only_on_visible_water_at_all_art_sizes() {
        for view in 0..3 {
            let mut builder = fixture(view);
            let c = builder.config;
            let bounds = Rect::new(c.side(), c.top() - 32 / c.divisor(), 160 / c.divisor(), 160 / c.divisor());
            let original_altitude = builder.city.altitude.clone();
            let original_terrain = builder.city.terrain.clone();
            let mut indices = [0; 256];
            indices[96] = 1;
            let result = builder.water_pixels(bounds, &indices, &HashMap::new(), &HashMap::new()).unwrap();
            assert!(result.surface.chunks_exact(4).any(|p| p[3] != 0));
            assert!(result.reflected.chunks_exact(4).any(|p| p[3] != 0), "no reflection in view {view}");
            for (surface, reflected) in result.surface.chunks_exact(4).zip(result.reflected.chunks_exact(4)) {
                if reflected[3] != 0 {
                    assert_eq!(surface[3], 255);
                    assert!((40..=63).contains(&reflected[0]), "reflection invented a source color");
                }
            }
            assert_eq!(builder.city.altitude, original_altitude);
            assert_eq!(builder.city.terrain, original_terrain);
            let disabled = builder.water_pixels(bounds, &[0; 256], &HashMap::new(), &HashMap::new()).unwrap();
            assert!(disabled.surface.iter().all(|v| *v == 0));
        }
    }

    #[test]
    fn waterfalls_and_blue_building_pixels_are_not_receiving_surfaces() {
        let mut builder = fixture(2);
        let mut draw = Draw::new(0, Rect::default());
        draw.depth = 4;
        draw.sprite = 1284;
        assert!(horizontal_water(&draw, &builder.city, builder.config).is_none());
        draw.sprite = 1112;
        assert!(horizontal_water(&draw, &builder.city, builder.config).is_none());
        builder.city.flags[4] = 0;
        builder.city.terrain[4] = 0;
        draw.sprite = 1270;
        assert!(horizontal_water(&draw, &builder.city, builder.config).is_none());
    }

    #[test]
    fn seabed_preserves_actual_sloped_heights() {
        let mut output = vec![0; 16 * 16 * 4];
        seabed_triangle(
            &mut output,
            Rect::new(0, 0, 16, 16),
            [[0.0, 0.0], [16.0, 0.0], [0.0, 16.0]],
            [1.0, 3.0, 1.0],
        );
        let near = output[(2 * 16 + 1) * 4];
        let raised = output[(2 * 16 + 10) * 4];
        assert!(raised > near, "stored slope was flattened");
        assert_eq!(output[(15 * 16 + 15) * 4 + 3], 0);
    }

    #[test]
    fn separate_regions_include_offscreen_sources_and_match_the_whole_pass() {
        let mut builder = fixture(2);
        let c = builder.config;
        let whole = Rect::new(c.side(), c.top() - 32, 160, 160);
        let mut indices = [0; 256];
        indices[96] = 1;
        let expected = builder.water_pixels(whole, &indices, &HashMap::new(), &HashMap::new()).unwrap();
        let parts = [Rect::new(whole.x, whole.y, 80, 160), Rect::new(whole.x + 80, whole.y + 48, 80, 112)];
        for part in parts {
            let actual = builder.water_pixels(part, &indices, &HashMap::new(), &HashMap::new()).unwrap();
            for (all, section) in [
                (&expected.surface, &actual.surface),
                (&expected.reflected, &actual.reflected),
                (&expected.seabed, &actual.seabed),
            ] {
                for y in 0..part.h {
                    let start = (((part.y - whole.y + y) * whole.w + part.x - whole.x) * 4) as usize;
                    let local = (y * part.w * 4) as usize;
                    assert_eq!(
                        &all[start..start + part.w as usize * 4],
                        &section[local..local + part.w as usize * 4]
                    );
                }
            }
        }
    }

    #[test]
    fn an_island_blocks_a_reflection_from_reaching_another_water_body() {
        let mut builder = fixture(2);
        let c = builder.config;
        let x = c.side() + (builder.city.edge + 1) * c.hw() - 1;
        assert!(unobstructed(&builder.city, c, x, c.top() + c.hh(), c.top() + 7 * c.hh(), 0));
        let island = builder.city.index(2, 2);
        builder.city.flags[island] = 0;
        builder.city.terrain[island] = 0;
        builder.city.altitude[island] = 1;
        assert!(!unobstructed(&builder.city, c, x, c.top() + c.hh(), c.top() + 7 * c.hh(), 0));
    }

    #[test]
    fn pixel_centres_reflect_exactly_at_each_altitude_and_zoom() {
        for step in [3, 6, 12] {
            for water in [0, 4, 31] {
                let contact = 100;
                let altitude = 31;
                let row = 79;
                let reflected = mirrored_row(row, contact, altitude, water, step);
                assert_eq!(reflected + row + 1, 2 * (contact + (altitude - water) * step));
                assert_eq!(mirrored_row(reflected, contact, altitude, water, step), row);
            }
        }
    }

    #[test]
    fn footprint_columns_and_flips_preserve_alignment() {
        let draw = Draw::new(0, Rect::new(0, 20, 32, 80));
        assert_eq!(contact_row(&draw, 0, true), 93);
        assert_eq!(contact_row(&draw, 15, true), 100);
        for x in 0..32 {
            assert_eq!(contact_row(&draw, x, true), contact_row(&draw, 31 - x, true));
            assert_eq!(contact_row(&draw, x, false), 100);
        }
    }
}
