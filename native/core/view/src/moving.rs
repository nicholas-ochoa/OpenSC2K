//! The draws of moving objects and animated disaster markers, as
//! IsometricMovingVisuals and IsometricDynamicCommands. Each draw belongs to
//! the tile of its object, so the painter paints it in tile order.

use super::art::ViewSprites;
use sc2k_render::{City as PainterCity, Draw, Rect};
use sc2k_sim::sim::city::City;
use sc2k_sim::sim::ids::building_tile_ids as tiles;
use sc2k_sim::sim::overlay;
use sc2k_sim::sim::things::{
    self, FIELD_DIRECTION, FIELD_DX, FIELD_DY, FIELD_PX, FIELD_PY, FIELD_STATE, FIELD_TYPE,
    FIELD_X, FIELD_Y, FIELD_Z,
};
use std::collections::HashMap;

const THING_SPRITES: [i32; 17] = [
    0, 1359, 1364, 1369, 1390, 1490, 1387, 1382, 1383, 1380, 1374, 1374, 1374, 1374, 1384, 1497,
    1495,
];
const THING_MINIMUM_VIEW: [i32; 17] = [0, 0, 2, 0, 0, 0, 1, 0, 0, 2, 2, 2, 2, 3, 0, 0, 2];
const THING_X_DIVISOR: [i32; 3] = [4, 2, 1];
const THING_Y_DIVISOR: [i32; 3] = [8, 4, 2];
const SHIP_DIRECTION_POSITION: [i32; 8] = [1, 2, 3, 4, 3, 2, 1, 0];
const SHIP_DIRECTION_FLIP: [bool; 8] = [false, false, false, false, true, true, true, false];
const THING_DIRECTION_POSITION: [i32; 4] = [0, 1, 1, 0];
const THING_DIRECTION_FLIP: [bool; 4] = [false, false, true, true];
const TRAIN_TILE_VARIANT: [i32; 32] = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 50, 50, 50, 50, 50, 10, 11, 12, 13, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0,
    0, 0, 0,
];
const TRAIN_TRANSITION_VARIANT: [i32; 8] = [0, 17, 1, 16, 0, 17, 1, 16];
const TRAIN_SPRITE_POSITION: [i32; 18] = [0, 0, 3, 3, 4, 4, 2, 1, 2, 1, 3, 3, 4, 4, 0, 0, 2, 1];
const TRAIN_SPRITE_FLIP: [bool; 18] = [
    false, true, true, false, false, true, false, false, false, false, true, false, false, true,
    false, true, false, false,
];
const TRAIN_SCREEN_X: [i32; 18] = [0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0];
const TRAIN_SCREEN_Y: [i32; 18] = [0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 8, 8, 6, 6, 0, 0, 0, 6];
const MONSTER_UPPER_FIRST_X: [i32; 2] = [-15, -3];
const MONSTER_UPPER_SECOND_X: [i32; 2] = [-24, 14];
const MONSTER_UPPER_FIRST_Y: [i32; 2] = [6, 52];
const MONSTER_UPPER_SECOND_Y: [i32; 2] = [43, 33];
const MONSTER_LOWER_FIRST_X: [i32; 2] = [-15, 2];
const MONSTER_LOWER_SECOND_X: [i32; 2] = [-20, 18];
const MONSTER_LOWER_FIRST_Y: [i32; 2] = [6, 32];
const MONSTER_LOWER_SECOND_Y: [i32; 2] = [49, 46];
/// Ships and sailboats float on the water surface.
const FLOATING_TYPES: [i64; 2] = [3, 9];
/// The marker overlays that animate, and their sprite offsets.
const SPECIAL_OVERLAYS: [(i64, &[i32]); 5] = [
    (0xfb, &[496]),
    (0xfc, &[492]),
    (0xfd, &[493, 494]),
    (0xfe, &[493, 494]),
    (0xff, &[396, 397, 398, 399]),
];
const RAISED_TERRAIN: i64 = 0x0d;
/// The first animated marker value.
const MARKER_FIRST: u8 = 0xfb;
const LARGE: usize = 2;

/// The geometry of one graphics size.
#[derive(Clone, Copy)]
struct Geometry {
    view: usize,
    tile_height: i32,
    half_width: i32,
    half_height: i32,
    step: i32,
    side: i32,
    top: i32,
    base: i32,
}

fn geometry(view: usize) -> Geometry {
    let (tile_height, half_width, half_height, step, side, top) = [
        (5, 4, 2, 3, 8, 128),
        (9, 8, 4, 6, 16, 256),
        (17, 16, 8, 12, 32, 512),
    ][view];

    Geometry {
        view,
        tile_height,
        half_width,
        half_height,
        step,
        side,
        top,
        base: 500 * view as i32,
    }
}

/// One draw of a moving object: its map cell and painter draw.
pub struct MovingDraw {
    pub cell: usize,
    pub draw: Draw,
}

/// One moving object record whose tile overlay names it.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Thing {
    pub record: i64,
    pub kind: i64,
    pub direction: i64,
    pub state: i64,
    pub x: i64,
    pub y: i64,
    pub z: i64,
    pub px: i64,
    pub py: i64,
    pub dx: i64,
    pub dy: i64,
}

const WATER_FLAG: u8 = 0x04;
const FLIPPED_FLAG: u8 = 0x02;

/// The map reads of the moving draws, over the painter city.
struct Maps<'a>(&'a PainterCity);

impl Maps<'_> {
    fn index(&self, x: i64, y: i64) -> usize {
        (x * i64::from(self.0.edge) + y) as usize
    }

    fn land_altitude(&self, x: i64, y: i64) -> i64 {
        i64::from(self.0.altitude[self.index(x, y)] & 31)
    }

    fn water_altitude(&self, x: i64, y: i64) -> i64 {
        i64::from((self.0.altitude[self.index(x, y)] >> 5) & 31)
    }

    fn is_water(&self, x: i64, y: i64) -> bool {
        self.0.flags[self.index(x, y)] & WATER_FLAG != 0
    }

    fn is_flipped(&self, x: i64, y: i64) -> bool {
        self.0.flags[self.index(x, y)] & FLIPPED_FLAG != 0
    }

    fn building_id(&self, x: i64, y: i64) -> i64 {
        i64::from(self.0.buildings[self.index(x, y)])
    }

    fn terrain_id(&self, x: i64, y: i64) -> i64 {
        i64::from(self.0.terrain[self.index(x, y)])
    }
}

struct Sprite {
    id: i32,
    flip: bool,
    train: Option<(i32, i32, i32)>,
    tornado: Option<i32>,
}

fn object_altitude(city: &Maps, x: i64, y: i64) -> i64 {
    if city.is_water(x, y) {
        city.water_altitude(x, y)
    } else {
        city.land_altitude(x, y)
    }
}

fn tile_visible(city: &Maps, x: i64, y: i64, visible: i64) -> bool {
    visible >= 32 || object_altitude(city, x, y) < visible
}

/// The sprite of a plane, helicopter, ship, police car, sailboat, or Maxis Man.
fn thing_sprite(thing: &Thing, view: usize) -> Option<Sprite> {
    let kind = thing.kind as usize;
    let direction = thing.direction as usize;
    let mut id = *THING_SPRITES.get(kind)? + (view as i32 - LARGE as i32) * 500;
    let mut flip = false;

    match kind {
        1..=3 => {
            id += *SHIP_DIRECTION_POSITION.get(direction)?;
            flip = SHIP_DIRECTION_FLIP[direction];
        }
        4 => {
            id += *THING_DIRECTION_POSITION.get(direction)?;
            flip = THING_DIRECTION_FLIP[direction];
        }
        6 if direction <= 2 => id += direction as i32,
        9 if thing.state != 0 => id = 379 + view as i32 * 500,
        9 => {
            id += *THING_DIRECTION_POSITION.get(direction)?;
            flip = THING_DIRECTION_FLIP[direction];
        }
        16 if direction <= 7 => flip = direction > 3,
        _ => return None,
    }

    Some(Sprite {
        id,
        flip,
        train: None,
        tornado: None,
    })
}

fn train_sprite(city: &Maps, thing: &Thing) -> Option<Sprite> {
    let (x, y) = (thing.x, thing.y);
    let tile = city.building_id(x, y);
    let step = 12;
    let (variant, elevation) = if tile == tiles::RAIL_BRIDGE || tile == tiles::RAIL_BRIDGE_PYLON {
        (
            i32::from(city.is_flipped(x, y)),
            (city.water_altitude(x, y) + 1) * step,
        )
    } else {
        let mut index = tile - tiles::RAIL_STRAIGHT_1;

        if !(0..=0x22).contains(&index) {
            return None;
        }

        if index > 0x12 {
            index -= 6;
        }

        if index > 0x16 {
            index -= 4;
        }

        let mut variant = TRAIN_TILE_VARIANT[index as usize];

        if variant == 50 {
            variant = *TRAIN_TRANSITION_VARIANT.get(thing.dx as usize)?;
        }

        let raised = if city.terrain_id(x, y) == RAISED_TERRAIN {
            step
        } else {
            0
        };

        (variant, city.land_altitude(x, y) * step + raised)
    };

    let variant = usize::try_from(variant)
        .ok()
        .filter(|v| *v < TRAIN_SPRITE_POSITION.len())?;

    Some(Sprite {
        id: THING_SPRITES[thing.kind as usize] + TRAIN_SPRITE_POSITION[variant],
        flip: TRAIN_SPRITE_FLIP[variant],
        train: Some((
            TRAIN_SCREEN_X[variant],
            TRAIN_SCREEN_Y[variant],
            elevation as i32,
        )),
        tornado: None,
    })
}

/// The layers of the monster: sprite, screen x and y, and flip.
fn monster_layers(
    city: &Maps,
    thing: &Thing,
    view: usize,
    phase: i64,
) -> Vec<(i32, i32, i32, bool)> {
    let altitude = object_altitude(city, thing.x, thing.y) as i32;
    let body_x = (thing.x - thing.y - 3) as i32 * 16;
    let body_y = (thing.x + thing.y) as i32 * 8 - (altitude + thing.z as i32) * 12;
    let mut head = ((phase / 20) & 1) as i32;

    if thing.dy & 0x80 != 0 {
        head = ((thing.px + thing.py + thing.x + thing.y + thing.record) & 1) as i32;
    }

    let (dx, dy) = (thing.dx as i32, thing.dy as i32);
    let (upper_x, upper_y) = (body_x - 20, body_y - 75);
    let mut layers = Vec::new();
    let (lf, ls) = ((dx & 1) as usize, ((dx >> 1) & 1) as usize);
    layers.push((
        1482 + ((dx >> 2) & 1),
        upper_x + MONSTER_UPPER_FIRST_X[lf] + MONSTER_UPPER_SECOND_X[ls],
        upper_y + MONSTER_UPPER_FIRST_Y[lf] + MONSTER_UPPER_SECOND_Y[ls],
        false,
    ));
    layers.push((
        1480 + ls as i32,
        upper_x + MONSTER_UPPER_FIRST_X[lf],
        upper_y + MONSTER_UPPER_FIRST_Y[lf],
        false,
    ));
    layers.push((1478 + lf as i32, upper_x, upper_y, false));
    let (rf, rs) = (((dx >> 3) & 1) as usize, ((dx >> 4) & 1) as usize);
    let right_upper_x = body_x + 82 - MONSTER_UPPER_FIRST_X[rf];
    layers.push((
        1482 + ((dx >> 5) & 1),
        right_upper_x - MONSTER_UPPER_SECOND_X[rs],
        upper_y + MONSTER_UPPER_FIRST_Y[rf] + MONSTER_UPPER_SECOND_Y[rs],
        true,
    ));
    layers.push((
        1480 + rs as i32,
        right_upper_x,
        upper_y + MONSTER_UPPER_FIRST_Y[rf],
        true,
    ));
    layers.push((1478 + rf as i32, body_x + 82, upper_y, true));

    if dx & 0x80 != 0 {
        layers.push((1385, body_x + 46, body_y - 18, false));
    }

    layers.push((1490 + (head & 1), body_x, body_y - 110, false));
    layers.push((1490 + (head & 1), body_x + 60, body_y - 110, true));
    let (lower_x, lower_y) = (body_x - 20, body_y - 50);
    let (df, ds) = ((dy & 1) as usize, ((dy >> 1) & 1) as usize);
    let (left_x, left_y) = (
        lower_x + MONSTER_LOWER_FIRST_X[df],
        lower_y + MONSTER_LOWER_FIRST_Y[df],
    );
    layers.push((1484 + df as i32, lower_x, lower_y, false));
    layers.push((1486 + ds as i32, left_x, left_y, false));
    layers.push((
        1488 + ((dy >> 2) & 1),
        left_x + MONSTER_LOWER_SECOND_X[ds],
        left_y + MONSTER_LOWER_SECOND_Y[ds],
        false,
    ));
    let (ef, es) = (((dy >> 3) & 1) as usize, ((dy >> 4) & 1) as usize);
    let (right_x, right_y) = (
        body_x + 80 - MONSTER_LOWER_FIRST_X[ef],
        lower_y + MONSTER_LOWER_FIRST_Y[ef],
    );
    layers.push((1484 + ef as i32, body_x + 80, lower_y, true));
    layers.push((1486 + es as i32, right_x, right_y, true));
    layers.push((
        1488 + ((dy >> 5) & 1),
        right_x - MONSTER_LOWER_SECOND_X[es],
        right_y + MONSTER_LOWER_SECOND_Y[es],
        true,
    ));

    if view != LARGE {
        let divisor = if view == 0 { 4 } else { 2 };

        for layer in &mut layers {
            layer.0 += (view as i32 - LARGE as i32) * 500;
            layer.1 /= divisor;
            layer.2 /= divisor;
        }
    }

    layers
}

fn read_thing(data: &[u8], record: i64) -> Thing {
    let field = |name| things::field(data, record, name);

    Thing {
        record,
        kind: field(FIELD_TYPE),
        direction: field(FIELD_DIRECTION),
        state: field(FIELD_STATE),
        x: field(FIELD_X),
        y: field(FIELD_Y),
        z: field(FIELD_Z),
        px: field(FIELD_PX),
        py: field(FIELD_PY),
        dx: field(FIELD_DX),
        dy: field(FIELD_DY),
    }
}

/// The painter key and draw of sprite `id` at `position`, or nothing for a missing sprite.
fn draw(
    sprites: &ViewSprites,
    id: i32,
    flip: bool,
    position: (i32, i32),
    shadow: bool,
    floating: i32,
) -> Option<Draw> {
    let sprite = sprites.get(&(id as u64 * 2))?;
    let mut draw = Draw::new(
        id as u64 * 2 + u64::from(flip),
        Rect::new(position.0, position.1, sprite.w, sprite.h),
    );
    draw.sprite = id;
    draw.flip = flip;
    draw.moving = true;
    draw.shadow = shadow;
    draw.floating = floating;

    Some(draw)
}

fn size(sprites: &ViewSprites, id: i32) -> Option<(i32, i32)> {
    sprites
        .get(&(id as u64 * 2))
        .map(|sprite| (sprite.w, sprite.h))
}

/// The draws of one moving object.
fn thing_draws(
    city: &Maps,
    sprites: &ViewSprites,
    thing: &Thing,
    g: Geometry,
    phase: i64,
) -> Vec<Draw> {
    let edge = city.0.edge;
    let (x, y) = (thing.x as i32, thing.y as i32);
    let kind = thing.kind;
    let mut draws = Vec::new();

    if kind == 5 {
        let origin = (g.side + edge * g.half_width, g.top + g.tile_height);
        let shadow = city.building_id(thing.x, thing.y) < tiles::LOWER_CLASS_HOMES_1X1_2;

        for (id, sx, sy, flip) in monster_layers(city, thing, g.view, phase) {
            let at = (origin.0 + sx, origin.1 + sy);

            if shadow {
                draws.extend(draw(
                    sprites,
                    id,
                    flip,
                    (at.0, at.1 + g.half_height * thing.z as i32),
                    true,
                    -1,
                ));
            }

            draws.extend(draw(sprites, id, flip, at, false, -1));
        }

        return draws;
    }

    let sprite = match kind {
        10 | 11 => train_sprite(city, thing),
        15 => {
            let phase = thing.px + thing.py + thing.x + thing.y + thing.record;
            let altitude = object_altitude(city, thing.x, thing.y) as i32;

            Some(Sprite {
                id: THING_SPRITES[15] + (g.view as i32 - LARGE as i32) * 500 + (phase % 3) as i32,
                flip: phase & 1 != 0,
                train: None,
                tornado: Some(altitude * g.step),
            })
        }
        _ => thing_sprite(thing, g.view).map(|mut sprite| {
            if kind == 6 {
                sprite.flip = (phase + thing.record + thing.x + thing.y) & 1 != 0;
            }

            // Nessie mirrors on each display frame
            if kind == 9 && thing.state != 0 {
                sprite.flip = phase & 1 != 0;
            }

            sprite
        }),
    };

    let Some(sprite) = sprite else {
        return draws;
    };

    let Some((width, height)) = size(sprites, sprite.id) else {
        return draws;
    };

    let column = g.side + edge * g.half_width + (x - y) * g.half_width;
    let row = g.top + (x + y) * g.half_height;
    let floating = if FLOATING_TYPES.contains(&kind) {
        object_altitude(city, thing.x, thing.y) as i32
    } else {
        -1
    };

    let position = if let Some(elevation) = sprite.tornado {
        (
            column + g.half_width - width,
            row + g.tile_height - elevation - height,
        )
    } else if let Some((screen_x, screen_y, elevation)) = sprite.train {
        let center = 32 + edge * 16 + (x - y) * 16 + 16 + screen_x;

        (
            center - width / 2,
            512 + 17 + (x + y) * 8 + screen_y - elevation - height,
        )
    } else {
        let altitude = object_altitude(city, thing.x, thing.y) as i32;
        let center = column + g.half_width + (thing.px - thing.py) as i32 / THING_X_DIVISOR[g.view];
        let top = row + g.tile_height + (thing.px + thing.py) as i32 / THING_Y_DIVISOR[g.view]
            - altitude * g.step
            - thing.z as i32 * g.half_height
            - height;

        if [1, 2, 16].contains(&kind)
            && city.building_id(thing.x, thing.y) < tiles::LOWER_CLASS_HOMES_1X1_2
        {
            draws.extend(draw(
                sprites,
                sprite.id,
                sprite.flip,
                (
                    center - width / 2,
                    top + g.half_height * (thing.z as i32 - 2),
                ),
                true,
                floating,
            ));
        }

        (center - width / 2, top)
    };

    draws.extend(draw(
        sprites,
        sprite.id,
        sprite.flip,
        position,
        false,
        floating,
    ));

    draws
}

/// The draw of an animated disaster marker on tile (x, y).
fn marker_draw(
    city: &Maps,
    sprites: &ViewSprites,
    x: i64,
    y: i64,
    marker: i64,
    g: Geometry,
    phase: i64,
) -> Option<Draw> {
    let offsets = SPECIAL_OVERLAYS
        .iter()
        .find(|(value, _)| *value == marker)?
        .1;

    if city.is_water(x, y) && marker != 0xfb && marker != 0xfc {
        return None;
    }

    let edge = i64::from(city.0.edge);
    let mut phase = phase + x * 3 + y * 5;

    if marker == 0xff {
        // mix the coordinates to break up diagonal fire patterns
        let mut seed = ((x + y * edge + 1) * 0x45d9f3b) & 0xffff_ffff;
        seed = ((seed >> 16) ^ seed) * 0x45d9f3b;
        phase = phase - x * 3 - y * 5 + (((seed >> 16) ^ seed) & 0xffff);
    }

    let offset = offsets[(phase.rem_euclid(offsets.len() as i64)) as usize];
    let id = g.base + offset;
    let (width, height) = size(sprites, id)?;
    let altitude = object_altitude(city, x, y) as i32;
    let column = g.side + edge as i32 * g.half_width + (x - y) as i32 * g.half_width;
    let base = g.top + (x + y) as i32 * g.half_height - altitude * g.step;

    draw(
        sprites,
        id,
        (phase >> 2) & 1 != 0,
        (
            column + g.half_width - width / 2,
            base + g.tile_height - height,
        ),
        false,
        -1,
    )
}

/// The cells of the animated disaster markers and their marker values.
pub fn marker_cells(city: &City) -> Vec<(usize, i64)> {
    let text = city
        .chunk("XTXT")
        .map(|chunk| chunk.data.as_slice())
        .unwrap_or_default();
    let cells = (city.map_size * city.map_size) as usize;

    // the marker of a layered or combined index is in its first byte plane; a
    // combined index above a byte is a sign or a facility, never a marker
    let mut result = Vec::new();

    // most chunks hold no marker; their test vectorizes
    for (block, bytes) in text.get(..cells).unwrap_or_default().chunks(64).enumerate() {
        if bytes
            .iter()
            .fold(0, |high, byte| high | u8::from(*byte >= MARKER_FIRST))
            == 0
        {
            continue;
        }

        for (offset, byte) in bytes.iter().enumerate() {
            let cell = block * 64 + offset;

            if *byte >= MARKER_FIRST {
                let marker = overlay::marker_at(text, cell as i64);

                if marker >= i64::from(MARKER_FIRST) {
                    result.push((cell, marker));
                }
            }
        }
    }

    result
}

/// The moving draws of `city` in graphics size `view`, by map cell. `visible`
/// is the number of altitude levels that show. `vehicles` false hides planes,
/// helicopters, ships, and trains.
/// The moving objects of `city` whose tile overlays name them.
pub fn things_of(city: &City) -> Vec<Thing> {
    let edge = city.map_size;
    let data = city
        .chunk("XTHG")
        .map(|chunk| chunk.data.as_slice())
        .unwrap_or_default();
    let text = city
        .chunk("XTXT")
        .map(|chunk| chunk.data.as_slice())
        .unwrap_or_default();

    (0..things::count(data))
        .map(|record| read_thing(data, record))
        .filter(|thing| {
            thing.kind > 0
                && (0..edge).contains(&thing.x)
                && (0..edge).contains(&thing.y)
                && overlay::read(text, thing.x * edge + thing.y) == overlay::thing_id(thing.record)
        })
        .collect()
}

#[allow(clippy::too_many_arguments)]
pub fn moving_draws(
    painter: &PainterCity,
    things: &[Thing],
    sprites: &ViewSprites,
    markers: &[(usize, i64)],
    view: usize,
    phase: i64,
    visible: i64,
    vehicles: bool,
) -> HashMap<usize, Vec<Draw>> {
    let g = geometry(view);
    let city = &Maps(painter);
    let edge = i64::from(painter.edge);
    let mut result: HashMap<usize, Vec<Draw>> = HashMap::new();

    for thing in things {
        if thing.kind as usize >= THING_MINIMUM_VIEW.len()
            || (view as i32) < THING_MINIMUM_VIEW[thing.kind as usize]
        {
            continue;
        }

        if !vehicles && [1, 2, 3, 10, 11].contains(&thing.kind) {
            continue;
        }

        if !tile_visible(city, thing.x, thing.y, visible) {
            continue;
        }

        let draws = thing_draws(city, sprites, thing, g, phase);

        if !draws.is_empty() {
            result
                .entry((thing.x * edge + thing.y) as usize)
                .or_default()
                .extend(draws);
        }
    }

    for &(cell, marker) in markers {
        let (x, y) = (cell as i64 / edge, cell as i64 % edge);

        if tile_visible(city, x, y, visible)
            && let Some(draw) = marker_draw(city, sprites, x, y, marker, g, phase)
        {
            result.entry(cell).or_default().push(draw);
        }
    }

    result
}
