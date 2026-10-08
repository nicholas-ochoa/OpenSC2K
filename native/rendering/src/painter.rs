//! Static surface and underground painting in map diagonal order. Draws retain
//! the original uncut sprite rectangle for pixel queries and moving occlusion.
use super::ids::{
    building_tile_ids as tiles, sc2altitude_layout as altitude, sc2tile_flags as flags, sc2zone_layout as zone,
    terrain_tile_ids as terrain, underground_tile_ids as under,
};

use super::{Builder, Draw, Rect};

// Sprite offsets in each view's artwork.
const TERRAIN_SPRITES: i32 = 256;

/// The flat water surface. Deep and unknown water terrain draw it.
const WATER_SPRITE: i32 = 270;
const CHANNEL_SPRITES: i32 = 285;
const LAND_SIDE_SPRITE: i32 = 269;
const WATER_SIDE_SPRITE: i32 = 284;

/// One ground sprite for each zone type follows this offset.
const ZONE_GROUND_SPRITES: i32 = 290;
const TERRAIN_WIREFRAME_FIRST: i32 = 0x131;
const SUBWAY_AND_PIPE_FIRST: i32 = 0x13e;
const PIPED_TERRAIN: i32 = 0x15f;
const DEEP_TUNNEL: i32 = 0x160;

/// Watered pipes use the pipe sprites this far on.
const WATERED_PIPE_OFFSET: i32 = 0x74;
const WATERED_TERRAIN: i32 = 0x1d3;

/// A one-level tunnel draws the tunnel sprite of its terrain shape.
const TUNNEL_SPRITES: i32 = 62;
const POWER_MARKER_SPRITE: i32 = 386;

/// The underground layers that a tile paints.
#[derive(Clone, Copy)]
struct UndergroundLayers {
    pipes: bool,
    subways: bool,
    mains: bool,
    tunnels: bool,
}

const TRAFFIC_SPRITES: i32 = 399;

/// The small artwork has no traffic variants above this one.
const SMALL_TRAFFIC_LAST: i32 = 27;
// Traffic density thresholds of roads and rails, and of highways.
const TRAFFIC_THRESHOLDS: (i32, i32) = (85, 170);
const HIGHWAY_TRAFFIC_THRESHOLDS: (i32, i32) = (28, 56);
// Traffic variants that alternate by tile parity.
const LANE_EVEN: i32 = 11;
const LANE_ODD: i32 = 12;

/// The zone corner bit that anchors a building at each compass rotation.
const ANCHOR_CORNERS: [u8; 4] = [0x80, 0x10, 0x20, 0x40];

/// XBIT power bits of a powerable building without power.
const UNPOWERED: u8 = flags::POWERABLE;

/// The traffic variant of each building from ROAD_STRAIGHT_1; 0 draws no traffic.
pub(super) const TRAFFIC: &[i32] = &[
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 2, 1, 2, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 0, 0, 1, 2, 1, 2, 0, 0,
    11, 12, 11, 12, 11, 12, 11, 12, 13, 13, 13, 13, 13, 13, 13, 13, 0, 0, 0, 0, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 0, 0,
    0, 0, 28, 29,
];

/// The heavy traffic variant of each light variant.
const HEAVY: &[i32] = &[
    0, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 15, 16, 17, 18, 42, 43, 44, 45, 46, 47, 48, 49, 50,
];

// Disaster marker overlays and their sprite offsets. Fire cycles four frames;
// riots cycle two.
const TOXIC_OVERLAY: i32 = 0xfb;
const FLOOD_OVERLAY: i32 = 0xfc;
const RIOT_OVERLAY_FORWARD: i32 = 0xfd;
const RIOT_OVERLAY_REVERSE: i32 = 0xfe;
const FIRE_OVERLAY: i32 = 0xff;

fn special_sprites(overlay: i32) -> &'static [i32] {
    match overlay {
        TOXIC_OVERLAY => &[496],
        FLOOD_OVERLAY => &[492],
        RIOT_OVERLAY_FORWARD | RIOT_OVERLAY_REVERSE => &[493, 494],
        FIRE_OVERLAY => &[396, 397, 398, 399],
        _ => &[],
    }
}

// Fire mixes the tile coordinates with this hash to break up diagonal patterns.
const FIRE_PHASE_HASH: u32 = 0x045d_9f3b;

fn terrain_sprite(t: u8, water: bool) -> i32 {
    // Shore and surface water shapes share the water shape sprites.
    match t {
        terrain::LAND_FIRST..=terrain::LAND_DRAW_LAST => TERRAIN_SPRITES + i32::from(t),
        terrain::SHORE_FIRST..=terrain::FORBIDDEN_COAST => WATER_SPRITE + i32::from(t - terrain::SHORE_FIRST),
        terrain::SURFACE_WATER_FIRST..=terrain::WATERFALL => WATER_SPRITE + i32::from(t - terrain::SURFACE_WATER_FIRST),
        terrain::CHANNEL_FIRST..=terrain::CHANNEL_LAST => CHANNEL_SPRITES + i32::from(t - terrain::CHANNEL_FIRST),
        _ if water || (terrain::DEEP_WATER_FIRST..=terrain::DEEP_WATER_DRAW_LAST).contains(&t) => WATER_SPRITE,
        _ => TERRAIN_SPRITES,
    }
}

// The underground wireframe of a land, deep water or shore shape.
fn wireframe(t: u8) -> i32 {
    let shape = |first: u8| i32::from(t - first).min(13);
    TERRAIN_WIREFRAME_FIRST
        + match t {
            terrain::LAND_FIRST..=terrain::LAND_DRAW_LAST => shape(terrain::LAND_FIRST),
            terrain::DEEP_WATER_FIRST..=terrain::DEEP_WATER_DRAW_LAST => shape(terrain::DEEP_WATER_FIRST),
            terrain::SHORE_FIRST..=terrain::FORBIDDEN_COAST => shape(terrain::SHORE_FIRST),
            _ => 0,
        }
}

impl Builder {
    /// Uncovered terrain for coastal distance queries, even beneath developed
    /// lots. Buildings and their cached draw bounds cannot hide the shoreline.
    pub(super) fn coastal_terrain(&mut self, bounds: Rect) -> Result<Vec<Draw>, String> {
        let c = self.config;
        let origin = c.side() + self.city.edge * c.hw();
        let first = ((bounds.y - c.top() - c.height()).div_euclid(c.hh()) - 2).max(0);
        let last = ((bounds.y + bounds.h - c.top() + 31 * c.step()).div_euclid(c.hh()) + 4).min(2 * (self.city.edge - 1));
        let diff_first = (bounds.x - origin - 2 * c.hw()).div_euclid(c.hw());
        let diff_last = (bounds.x + bounds.w - origin).div_euclid(c.hw()) + 1;
        let mut out = Vec::new();
        for diagonal in first..=last {
            let first_y = 0.max(diagonal - self.city.edge + 1).max((diagonal - diff_last + 1).div_euclid(2));
            let last_y = (self.city.edge - 1).min(diagonal).min((diagonal - diff_first).div_euclid(2));
            for y in first_y..=last_y {
                let x = diagonal - y;
                let i = self.city.index(x, y);
                let t = self.city.surface(x, y);
                let offset = terrain_sprite(t, self.city.wet(i));
                if offset == WATER_SIDE_SPRITE {
                    continue;
                }
                let altitude = if t >= terrain::DEEP_WATER_FIRST {
                    self.city.water(i)
                } else {
                    self.city.land(i)
                };
                let baseline = c.top() + diagonal * c.hh() + c.height() - altitude * c.step();
                let sx = origin + (x - y) * c.hw();
                // Avoid requiring artwork for candidates outside the band.
                if !Rect::new(sx, baseline - 4 * c.hh() - c.step(), 2 * c.hw(), 4 * c.hh() + c.step())
                    .clip(bounds)
                    .area()
                {
                    continue;
                }
                let mut tile = Vec::new();
                self.add(&mut tile, c.base() + offset, false, sx, baseline)?;
                for mut draw in tile {
                    draw.depth = i64::from(diagonal * self.city.edge + y);
                    if draw.rect.clip(bounds).area() {
                        out.push(draw);
                    }
                }
            }
        }
        Ok(out)
    }

    fn add(&mut self, draws: &mut Vec<Draw>, id: i32, flip: bool, x: i32, baseline: i32) -> Result<u64, String> {
        let key = self.sprites.get(id, flip)?;
        let sprite = &self.sprites.images[&key];
        let mut draw = Draw::new(key, Rect::new(x, baseline - sprite.h, sprite.w, sprite.h));
        draw.sprite = id;
        draw.flip = flip;
        draws.push(draw);
        Ok(key)
    }

    fn ground(&self, i: usize, t: u8) -> i32 {
        if let Some(&value) = self.city.ground.get(i).filter(|v| **v >= 0) {
            return value;
        }

        // Zones show on flat open ground, trees, rubble and power lines.
        let zone_type = self.city.zones[i] & zone::TYPE_MASK;

        if zone_type > 0 && t == terrain::FLAT && self.city.buildings[i] <= tiles::POWER_LINE_CROSSROADS {
            return ZONE_GROUND_SPRITES + i32::from(zone_type);
        }

        terrain_sprite(t, self.city.wet(i))
    }

    pub(super) fn paint(&mut self, x: i32, y: i32) -> Result<Vec<Draw>, String> {
        let c = self.config;
        let i = self.city.index(x, y);
        let mut draws = Vec::new();

        if c.underground || !self.city.visible(i) {
            let layers = if c.underground {
                UndergroundLayers {
                    pipes: c.pipes,
                    subways: c.subways,
                    mains: c.mains,
                    tunnels: c.tunnels,
                }
            } else {
                UndergroundLayers {
                    pipes: false,
                    subways: true,
                    mains: true,
                    tunnels: true,
                }
            };
            self.paint_underground(&mut draws, x, y, layers)?;

            return Ok(draws);
        }

        let t = self.city.surface(x, y);
        let b = self.city.buildings[i];
        let sprite = self.forest_sprite(x, y, c.base() + i32::from(b));
        let sx = c.side() + (self.city.edge + x - y) * c.hw();
        let flat = c.top() + (x + y) * c.hh() + c.height();
        let base = flat
            - (if t >= terrain::DEEP_WATER_FIRST {
                self.city.water(i)
            } else {
                self.city.land(i)
            }) * c.step();
        if x == self.city.edge - 1 || y == self.city.edge - 1 {
            for level in 0..self.city.land(i) {
                self.add(&mut draws, c.base() + LAND_SIDE_SPRITE, false, sx, flat - level * c.step())?;
            }

            if self.city.wet(i) {
                for level in self.city.land(i)..self.city.water(i) {
                    self.add(&mut draws, c.base() + WATER_SIDE_SPRITE, false, sx, flat - level * c.step())?;
                }
            }
        }

        let composite = (tiles::HIGHWAY_SLOPE_1..=tiles::REINFORCED_HIGHWAY_BRIDGE).contains(&b);
        let developed = b >= tiles::DEVELOPED_FIRST;

        if !developed && !composite {
            self.add(&mut draws, self.nature_ground(c.base() + self.ground(i, t)), false, sx, base)?;
        }

        // Composite highways and buildings draw from one compass-selected corner.
        let anchor = b <= tiles::HIGHWAY_ONRAMP_4
            || (tiles::RAIL_SUBWAY_ENTRANCE_1..=tiles::RAIL_SUBWAY_ENTRANCE_4).contains(&b)
            || self.city.zones[i] & ANCHOR_CORNERS[self.city.rotation] != 0;
        if b != tiles::EMPTY && anchor {
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
                        let id = c.base() + terrain_sprite(self.city.terrain[n], self.city.wet(n));
                        self.add(&mut draws, id, false, sx + px, base + py)?;
                    }
                }
            }

            // An odd compass rotation mirrors buildings, not networks.
            let flip =
                sprite < crate::nature::FIRST && ((self.city.flags[i] & flags::FLIPPED != 0) ^ (developed && self.city.rotation & 1 != 0));
            let image = self.sprites.get(sprite, flip)?;
            let width = self.sprites.images[&image].w;
            let offset = if composite {
                c.hh()
            } else if developed {
                width / 4 - c.hh()
            } else if t == terrain::RAISED {
                -c.step()
            } else {
                0
            };

            let baseline = flat - self.city.object(i) * c.step() + offset;
            self.add(&mut draws, sprite, flip, sx, baseline)?;

            if let Some((id, traffic_flip)) = self.traffic_sprite(x, y, b) {
                let traffic = self.sprites.get(id, traffic_flip)?;
                let masked = self.sprites.traffic(traffic, image);
                let sprite = &self.sprites.images[&masked];
                let mut draw = Draw::new(masked, Rect::new(sx, baseline - sprite.h, sprite.w, sprite.h));

                // The masked traffic draw names its sprite but is no foreground.
                draw.sprite = id;
                draw.flip = traffic_flip;
                draws.push(draw);
            }

            if developed && self.city.flags[i] & flags::POWER_MASK == UNPOWERED {
                let key = self.sprites.get(c.base() + POWER_MARKER_SPRITE, false)?;
                let marker_width = self.sprites.images[&key].w;
                self.add(
                    &mut draws,
                    c.base() + POWER_MARKER_SPRITE,
                    false,
                    sx + width / 2 - marker_width / 2,
                    baseline,
                )?;
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

        if let Some(moving) = self.moving.get(&i) {
            draws.extend(moving.iter().cloned());
        }

        if c.specials {
            self.paint_special(&mut draws, x, y)?;
        }

        let depth = ((x + y) * self.city.edge + y) as i64;
        let mut foreground = 0;

        for draw in &mut draws {
            // Masked traffic changes color, not the foreground silhouette.
            if draw.image >= 1_u64 << 32 || draw.moving {
                continue;
            }

            draw.depth = depth;
            draw.order = (depth << 16) | foreground;
            foreground += 1;

            if draw.sprite == sprite && b != tiles::EMPTY {
                configure_train(draw, b, c.base(), c.view);
            }
        }

        Ok(draws)
    }

    /// The animated marker of a disaster tile, as `special_overlay_visual`.
    fn paint_special(&mut self, draws: &mut Vec<Draw>, x: i32, y: i32) -> Result<(), String> {
        let c = self.config;
        let i = self.city.index(x, y);
        let overlay = self.city.marker(i);
        let offsets = special_sprites(overlay);

        if offsets.is_empty() || (self.city.wet(i) && overlay != TOXIC_OVERLAY && overlay != FLOOD_OVERLAY) {
            return Ok(());
        }

        let mut phase = c.phase + x * 3 + y * 5;

        if overlay == FIRE_OVERLAY {
            let mut seed = ((x + y * self.city.edge + 1) as u32).wrapping_mul(FIRE_PHASE_HASH);
            seed = ((seed >> 16) ^ seed).wrapping_mul(FIRE_PHASE_HASH);
            phase = c.phase + (((seed >> 16) ^ seed) & 0xffff) as i32;
        }

        let id = c.base() + offsets[phase.rem_euclid(offsets.len() as i32) as usize];
        let flip = (phase >> 2) & 1 != 0;
        let key = self.sprites.get(id, flip)?;
        let width = self.sprites.images[&key].w;
        let sx = c.side() + (self.city.edge + x - y) * c.hw();
        let baseline = c.top() + (x + y) * c.hh() + c.height() - self.city.object(i) * c.step();
        self.add(draws, id, flip, sx + c.hw() - width / 2, baseline)?;
        Ok(())
    }

    fn traffic_sprite(&self, x: i32, y: i32, b: u8) -> Option<(i32, bool)> {
        if self.config.individual_traffic
            && ((tiles::ROAD_STRAIGHT_1..=tiles::ROAD_CROSSROADS).contains(&b)
                || (tiles::TUNNEL_ENTRANCE_1..=tiles::TUNNEL_ENTRANCE_2).contains(&b)
                || (tiles::ROAD_POWER_CROSSING_1..=tiles::RAISING_BRIDGE_CLOSED).contains(&b)
                || (tiles::HIGHWAY_ONRAMP_1..=tiles::REINFORCED_HIGHWAY_BRIDGE).contains(&b))
        {
            return None;
        }
        let mut variant = *TRAFFIC.get(usize::from(b.checked_sub(tiles::ROAD_STRAIGHT_1)?))?;

        if variant == 0 {
            return None;
        }

        let density = self.city.density(x, y);
        let (low, high) = if is_highway(b) {
            HIGHWAY_TRAFFIC_THRESHOLDS
        } else {
            TRAFFIC_THRESHOLDS
        };

        if density <= low {
            return None;
        }

        let mut flip = self.city.flags[self.city.index(x, y)] & flags::FLIPPED != 0;

        if variant == LANE_EVEN && x & 1 != 0 {
            variant = LANE_ODD;
        } else if variant == LANE_ODD {
            flip = true;

            if y & 1 != 0 {
                variant = LANE_EVEN;
            }
        }

        if density > high {
            variant = *HEAVY.get(variant as usize)?;
        }

        if variant == 0 || (self.config.view == 0 && variant > SMALL_TRAFFIC_LAST) {
            return None;
        }

        Some((self.config.base() + TRAFFIC_SPRITES + variant, flip))
    }

    fn paint_underground(&mut self, draws: &mut Vec<Draw>, x: i32, y: i32, layers: UndergroundLayers) -> Result<(), String> {
        let UndergroundLayers {
            pipes,
            subways,
            mains,
            tunnels,
        } = layers;
        let c = self.config;
        let i = self.city.index(x, y);
        let visible = self.city.visible(i);
        let sx = c.side() + (self.city.edge + x - y) * c.hw();
        let baseline = c.top() + (x + y) * c.hh() - self.city.land(i) * c.step() + c.height();
        let wire = c.base() + wireframe(self.city.terrain[i]);
        let key = self.sprites.get(wire, false)?;
        let top = baseline - self.sprites.images[&key].h;
        let levels = (self.city.altitude[i] >> altitude::TUNNEL_SHIFT) & altitude::LEVEL_MASK;

        if tunnels && levels > 0 && (self.city.visible >= 32 || self.city.land(i) - (levels - 1).max(0) < self.city.visible) {
            let sprite = c.base()
                + if levels == 1 {
                    TUNNEL_SPRITES + i32::from(self.city.terrain[i])
                } else {
                    DEEP_TUNNEL
                };
            self.add(
                draws,
                sprite,
                false,
                sx,
                baseline + if levels > 1 { (levels - 1) * c.step() } else { 0 },
            )?;
        }

        let mut tile = self.city.underground[i];

        // Below a cutaway, only subways show, one level under the terrain.
        if !visible
            && (!subways
                || !(self.city.visible >= 32 || self.city.land(i) - 1 < self.city.visible)
                || !(under::SUBWAY_FIRST..=under::SUBWAY_LAST).contains(&tile)
                    && ![under::PIPE_TB_SUBWAY_LR, under::PIPE_LR_SUBWAY_TB, under::SUBWAY_ENTRANCE].contains(&tile))
        {
            return Ok(());
        }

        if !subways {
            tile = match tile {
                under::PIPE_TB_SUBWAY_LR => under::PIPE_TB,
                under::PIPE_LR_SUBWAY_TB => under::PIPE_LR,
                under::SUBWAY_FIRST..=under::SUBWAY_LAST | under::SUBWAY_ENTRANCE => under::EMPTY,
                _ => tile,
            };
        }

        let under_sprite = c.base() + SUBWAY_AND_PIPE_FIRST + i32::from(tile);
        let piped = self.city.flags[i] & flags::PIPED != 0;
        let watered = self.city.flags[i] & flags::WATERED != 0;
        let pipes = pipes && visible;
        let mains = mains && visible;
        let mut ids = Vec::new();
        let service = c.base() + if watered { WATERED_TERRAIN } else { PIPED_TERRAIN };

        if (under::PIPE_FIRST..=under::PIPE_LR_SUBWAY_TB).contains(&tile) {
            // Hidden water mains leave the subway of a crossing, or the wireframe.
            if !mains {
                ids.push(match tile {
                    under::PIPE_TB_SUBWAY_LR => c.base() + SUBWAY_AND_PIPE_FIRST + i32::from(under::SUBWAY_LR),
                    under::PIPE_LR_SUBWAY_TB => c.base() + SUBWAY_AND_PIPE_FIRST + i32::from(under::SUBWAY_TB),
                    _ => wire,
                });
            } else {
                ids.push(under_sprite + if piped && watered { WATERED_PIPE_OFFSET } else { 0 });
            }
        } else if tile == under::EMPTY {
            ids.push(if !pipes || !piped { wire } else { service });
        } else {
            ids.push(under_sprite);

            if pipes && piped {
                ids.push(service);
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

fn is_highway(b: u8) -> bool {
    (tiles::HIGHWAY_STRAIGHT_1..=tiles::HIGHWAY_POWER_CROSSING_2).contains(&b)
        || (tiles::HIGHWAY_SLOPE_1..=tiles::REINFORCED_HIGHWAY_BRIDGE).contains(&b)
}

// Train masks: power lines never cover a train, a crossing subtracts its ground
// network, and a raised highway deck keeps only the bands around its road surface.
fn configure_train(d: &mut Draw, b: u8, base: i32, view: i32) {
    use tiles::*;
    let power_line = (POWER_LINE_STRAIGHT_1..=POWER_LINE_CROSSROADS).contains(&b);
    let ground = match b {
        HIGHWAY_RAIL_CROSSING_1 | RAIL_POWER_CROSSING_2 => Some(RAIL_STRAIGHT_2),
        HIGHWAY_RAIL_CROSSING_2 | RAIL_POWER_CROSSING_1 => Some(RAIL_STRAIGHT_1),
        ROAD_POWER_CROSSING_1 => Some(ROAD_STRAIGHT_1),
        ROAD_POWER_CROSSING_2 => Some(ROAD_STRAIGHT_2),
        HIGHWAY_POWER_CROSSING_1 => Some(HIGHWAY_STRAIGHT_1),
        HIGHWAY_POWER_CROSSING_2 => Some(HIGHWAY_STRAIGHT_2),
        _ => None,
    };

    d.reference = if power_line {
        -1
    } else {
        ground.map_or(0, |tile| base + i32::from(tile))
    };

    d.ignore = power_line
        || [
            ROAD_POWER_CROSSING_1,
            ROAD_POWER_CROSSING_2,
            RAIL_POWER_CROSSING_1,
            RAIL_POWER_CROSSING_2,
        ]
        .contains(&b);
    if is_highway(b) {
        d.thickness = view + 1;
        d.requires_depth = true;

        if [HIGHWAY_POWER_CROSSING_1, HIGHWAY_POWER_CROSSING_2].contains(&b) {
            d.deck = d.reference;
        }
    }
}
