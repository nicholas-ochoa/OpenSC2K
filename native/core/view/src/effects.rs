//! Transient effects: demolition dust, fires and smoke, a launching arcology,
//! and the earthquake shake, as CityEffectTiming and the effect visuals of
//! ApplicationEffectsAudio. Each frame of an effect draws on its depth tile,
//! so the painter's tile order hides it behind the tiles in front.

use super::art::ViewSprites;
use super::geometry::{ALTITUDE_STEP, HALF_HEIGHT, HALF_WIDTH, SIDE_MARGIN, TILE_HEIGHT, TOP_MARGIN, divisor};
use sc2k_render::{City as PainterCity, Draw, Rect};
use std::collections::HashMap;

pub const FRAME_MSEC: f64 = 100.0;
const LAUNCH_FIRE: &str = "launch_fire";
const LAUNCH_ARCOLOGY: &str = "launch_arcology";
const EARTHQUAKE: &str = "earthquake";
const FIRE_SPRITE: i64 = 1396;
const SMOKE_SPRITE: i64 = 1392;
const SMOKE_PERIOD: i64 = 6;
const SMOKE_FRAMES: i64 = 4;
const SMOKE_RISE: i64 = 8;
const LAUNCH_FPS: f64 = 30.0;
const LAUNCH_STILL_FRAMES: usize = 15;
const LAUNCH_FLIGHT_FRAMES: usize = 90;
const LAUNCH_ACCELERATION: f64 = 600.0;
const LAUNCH_SHAKE: [(i32, i32); 10] = [(1, 0), (0, 0), (-1, 0), (0, -1), (1, -1), (-1, 0), (0, 0), (1, 0), (-1, -1), (0, 0)];
const EARTHQUAKE_FPS: f64 = 15.0;
const EARTHQUAKE_SECONDS: f64 = 4.0;
const EARTHQUAKE_RISE_SECONDS: f64 = 0.4;
const EARTHQUAKE_FADE_SECONDS: f64 = 1.5;
/// The largest earthquake offset in view pixels; the map scales it by the zoom.
pub const EARTHQUAKE_DISTANCE: f64 = 8.0;
const EARTHQUAKE_PATTERN: [(f64, f64); 10] = [
    (1.0, 0.0),
    (-0.7, 0.25),
    (0.85, -0.2),
    (-1.0, 0.0),
    (0.6, 0.3),
    (-0.9, -0.25),
    (1.0, 0.15),
    (-0.65, 0.0),
    (0.8, -0.3),
    (-0.95, 0.2),
];
/// The most effect frames that one event list shows.
const VISUAL_LIMIT: usize = 1024;

/// One effect event, as EffectEvent.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Event {
    pub kind: String,
    pub point: (i64, i64),
    pub sprite_id: i64,
    pub screen_offset: (i64, i64),
    pub flip: bool,
    pub frame: i64,
    pub altitude: i64,
    pub frames: i64,
    pub depth_point: (i64, i64),
}

/// One sprite frame of an effect, ready to draw.
#[derive(Clone, Debug)]
struct Frame {
    /// The time it shows, from the start of its list, in milliseconds.
    start_msec: f64,
    length_msec: f64,
    cell: usize,
    sprite: i32,
    flip: bool,
    position: (i32, i32),
    size: (i32, i32),
}

#[derive(Default)]
pub struct Effects {
    frames: Vec<(f64, Frame)>,
    shake: Option<(f64, Vec<(f64, f64)>)>,
    seed: u64,
}

/// The earthquake offsets, one each 1/15 second, as parts of the distance.
pub fn earthquake_offsets() -> Vec<(f64, f64)> {
    let frames = (EARTHQUAKE_SECONDS * EARTHQUAKE_FPS).round() as usize;
    let mut offsets: Vec<(f64, f64)> = (0..frames)
        .map(|frame| {
            let seconds = frame as f64 / EARTHQUAKE_FPS;
            let rise = ((seconds + 1.0 / EARTHQUAKE_FPS) / EARTHQUAKE_RISE_SECONDS).min(1.0);
            let fade = ((EARTHQUAKE_SECONDS - seconds) / EARTHQUAKE_FADE_SECONDS).clamp(0.0, 1.0);
            let pattern = EARTHQUAKE_PATTERN[frame % EARTHQUAKE_PATTERN.len()];

            (pattern.0 * rise * fade, pattern.1 * rise * fade)
        })
        .collect();

    offsets.push((0.0, 0.0));
    offsets
}

/// The frame offsets of a launching arcology, in large view pixels: still,
/// shaking until liftoff, then flying up until its bottom passes `top`.
pub fn launch_offsets(liftoff: i64, view_divisor: i32, origin_y: i32, bottom: i32, top: i32) -> Vec<(i32, i32)> {
    let liftoff_frame = (liftoff * LAUNCH_FPS as i64 / 10) as usize;
    let mut offsets: Vec<(i32, i32)> = (0..liftoff_frame)
        .map(|frame| {
            let shake = if frame >= LAUNCH_STILL_FRAMES {
                LAUNCH_SHAKE[frame % LAUNCH_SHAKE.len()]
            } else {
                (0, 0)
            };

            (shake.0 * view_divisor, shake.1 * view_divisor)
        })
        .collect();

    for frame in 0..LAUNCH_FLIGHT_FRAMES {
        let seconds = frame as f64 / LAUNCH_FPS;
        let rise = -(LAUNCH_ACCELERATION * seconds * seconds / 2.0).round() as i32;
        offsets.push((0, rise));

        if origin_y + rise + bottom < top {
            break;
        }
    }

    offsets
}

impl Effects {
    /// Start an event list at `now_msec`.
    pub fn show(&mut self, events: &[Event], now_msec: f64, painter: &PainterCity, sprites: &ViewSprites, view: usize) {
        let events = expand_launch_fires(self.parallel_dust(events));

        for event in &events {
            if event.kind == EARTHQUAKE {
                self.shake = Some((now_msec, earthquake_offsets()));
                continue;
            }

            if event.kind == LAUNCH_ARCOLOGY {
                self.launch(event, now_msec, painter, sprites, view);
                continue;
            }

            if self.frames.len() >= VISUAL_LIMIT * 4 {
                continue;
            }

            if let Some(frame) = effect_frame(event, painter, sprites, view) {
                self.frames.push((now_msec, frame));
            }
        }
    }

    fn launch(&mut self, event: &Event, now_msec: f64, painter: &PainterCity, sprites: &ViewSprites, view: usize) {
        let id = effect_sprite_id(event.sprite_id, view);
        let Some(sprite) = sprites.get(&(id as u64 * 2)) else {
            return;
        };

        let d = divisor(view);
        let edge = painter.edge;
        let (x, y) = (event.point.0 as i32, event.point.1 as i32);
        let baseline = (TOP_MARGIN + (x + y) * HALF_HEIGHT) / d + (TILE_HEIGHT - 1) / d + 1 - event.altitude as i32 * ALTITUDE_STEP / d
            + sprite.w / 4
            - HALF_HEIGHT / d;
        let origin = ((SIDE_MARGIN + (edge + x - y) * HALF_WIDTH) / d, baseline - sprite.h);
        let depth = if event.depth_point.0 >= 0 { event.depth_point } else { event.point };
        let cell = (depth.0 * i64::from(edge) + depth.1).max(0) as usize;

        for (frame, offset) in launch_offsets(event.frames, d, origin.1 * d, sprite.h * d, 0)
            .into_iter()
            .enumerate()
        {
            self.frames.push((
                now_msec,
                Frame {
                    start_msec: frame as f64 * 1000.0 / LAUNCH_FPS,
                    length_msec: 1000.0 / LAUNCH_FPS,
                    cell,
                    sprite: id,
                    flip: event.flip,
                    position: (origin.0 + offset.0 / d, origin.1 + offset.1 / d),
                    size: (sprite.w, sprite.h),
                },
            ));
        }
    }

    /// Dust of many tiles starts together, as a group at a time.
    fn parallel_dust(&mut self, events: &[Event]) -> Vec<Event> {
        let mut groups: Vec<((i64, i64), i64)> = Vec::new();

        for event in events.iter().filter(|event| event.kind.is_empty() && event.point != (-1, -1)) {
            match groups.iter_mut().find(|(point, _)| *point == event.point) {
                Some(group) => group.1 = group.1.min(event.frame),
                None => groups.push((event.point, event.frame)),
            }
        }

        if groups.len() < 2 {
            return events.to_vec();
        }

        // presentation randomness does not consume simulation random state
        for index in (1..groups.len()).rev() {
            self.seed = self.seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
            groups.swap(index, (self.seed >> 33) as usize % (index + 1));
        }

        let delay = groups.iter().map(|(_, first)| *first).min().unwrap_or(0);

        events
            .iter()
            .map(|event| {
                let mut event = event.clone();

                if event.kind.is_empty()
                    && let Some(position) = groups.iter().position(|(point, _)| *point == event.point)
                {
                    let first = groups[position].1;
                    event.frame = event.frame - first + (position % 5) as i64 + delay;
                }

                event
            })
            .collect()
    }

    /// The effect draws that show at `now_msec`, by depth cell. Ended effects drop.
    pub fn draws(&mut self, now_msec: f64) -> HashMap<usize, Vec<Draw>> {
        self.frames
            .retain(|(start, frame)| now_msec < start + frame.start_msec + frame.length_msec);
        let mut result: HashMap<usize, Vec<Draw>> = HashMap::new();

        for (start, frame) in &self.frames {
            let since = now_msec - start;

            if since >= frame.start_msec && since < frame.start_msec + frame.length_msec {
                let key = frame.sprite as u64 * 2 + u64::from(frame.flip);
                let mut draw = Draw::new(key, Rect::new(frame.position.0, frame.position.1, frame.size.0, frame.size.1));
                draw.sprite = frame.sprite;
                draw.flip = frame.flip;
                draw.moving = true;
                result.entry(frame.cell).or_default().push(draw);
            }
        }

        result
    }

    /// The earthquake offset at `now_msec`, as parts of the distance.
    pub fn shake(&mut self, now_msec: f64) -> (f64, f64) {
        let Some((start, offsets)) = &self.shake else {
            return (0.0, 0.0);
        };

        let index = ((now_msec - start) / 1000.0 * EARTHQUAKE_FPS) as usize;

        match offsets.get(index) {
            Some(offset) => *offset,
            None => {
                self.shake = None;

                (0.0, 0.0)
            }
        }
    }

    pub fn is_empty(&self) -> bool {
        self.frames.is_empty() && self.shake.is_none()
    }
}

/// The sprite of a large view effect sprite in another view.
pub fn effect_sprite_id(large: i64, view: usize) -> i32 {
    (500 * view as i64 + large - 1000) as i32
}

/// Replace each launch fire with its frames of fire and rising smoke.
fn expand_launch_fires(events: Vec<Event>) -> Vec<Event> {
    let mut result = Vec::with_capacity(events.len());

    for event in events {
        if event.kind != LAUNCH_FIRE {
            result.push(event);
            continue;
        }

        // mix the tile coordinates so neighbor fires do not move together
        let phase = (((event.point.0 * 7 + event.point.1 * 13) * 0x45d9f3b) >> 8) & 0xffff;
        let mut smoke = Vec::new();
        let sprite = |id: i64, frame: i64, rise: i64| Event {
            kind: String::new(),
            sprite_id: id,
            frame: event.frame + frame,
            screen_offset: (event.screen_offset.0, event.screen_offset.1 + rise),
            ..event.clone()
        };

        for frame in 0..event.frames {
            let mut fire = sprite(FIRE_SPRITE + ((frame + phase) & 3), frame, 0);
            fire.flip = phase & 1 != 0;
            result.push(fire);

            if (frame + phase) % SMOKE_PERIOD != 0 {
                continue;
            }

            for rise in 0..SMOKE_FRAMES.min(event.frames - frame) {
                smoke.push(sprite(SMOKE_SPRITE + ((rise + phase) & 3), frame + rise, -SMOKE_RISE * (rise + 1)));
            }
        }

        result.extend(smoke);
    }

    result
}

/// The view position of an effect sprite of `height` view pixels, as
/// IsometricGeometry.transient_effect_position.
fn effect_frame(event: &Event, painter: &PainterCity, sprites: &ViewSprites, view: usize) -> Option<Frame> {
    let edge = i64::from(painter.edge);
    let (x, y) = event.point;

    if !(0..edge).contains(&x) || !(0..edge).contains(&y) {
        return None;
    }

    let id = effect_sprite_id(event.sprite_id, view);
    let sprite = sprites.get(&(id as u64 * 2))?;
    let d = divisor(view);
    let altitude = if event.altitude >= 0 {
        event.altitude as i32
    } else {
        (painter.altitude[(x * edge + y) as usize] >> 5) & 31
    };
    let (half_width, half_height, step) = (HALF_WIDTH / d, HALF_HEIGHT / d, ALTITUDE_STEP / d);
    let position = (
        SIDE_MARGIN / d + painter.edge * half_width + (x - y) as i32 * half_width + event.screen_offset.0 as i32 / d,
        TOP_MARGIN / d + (x + y) as i32 * half_height - altitude * step - sprite.h + event.screen_offset.1 as i32 / d,
    );
    let depth = if event.depth_point.0 >= 0 { event.depth_point } else { event.point };

    Some(Frame {
        start_msec: event.frame as f64 * FRAME_MSEC,
        length_msec: FRAME_MSEC,
        cell: (depth.0 * edge + depth.1) as usize,
        sprite: id,
        flip: event.flip,
        position,
        size: (sprite.w, sprite.h),
    })
}

/// The effect events of a value list, as the simulation results hold them.
pub fn events_of(values: &[sc2k_sim::sim::value::Value]) -> Vec<Event> {
    use sc2k_sim::sim::value::Value;

    let point = |value: &Value, name: &str, fallback: (i64, i64)| match field(value, name) {
        Some(Value::Vec2i(point)) => (point.x, point.y),
        _ => fallback,
    };

    values
        .iter()
        .map(|value| Event {
            kind: text(value, "type"),
            point: point(value, "point", (-1, -1)),
            sprite_id: int(value, "sprite_id", 0),
            screen_offset: point(value, "screen_offset", (0, 0)),
            flip: matches!(field(value, "flip"), Some(Value::Bool(true))),
            frame: int(value, "frame", 0),
            altitude: int(value, "altitude", -1),
            frames: int(value, "frames", 24),
            depth_point: point(value, "depth_point", (-1, -1)),
        })
        .collect()
}

fn field<'a>(value: &'a sc2k_sim::sim::value::Value, name: &str) -> Option<&'a sc2k_sim::sim::value::Value> {
    match value {
        sc2k_sim::sim::value::Value::Object(_, fields) => fields.iter().find(|(key, _)| *key == name).map(|(_, value)| value),
        _ => None,
    }
}

fn int(value: &sc2k_sim::sim::value::Value, name: &str, fallback: i64) -> i64 {
    match field(value, name) {
        Some(sc2k_sim::sim::value::Value::Int(number)) => *number,
        _ => fallback,
    }
}

fn text(value: &sc2k_sim::sim::value::Value, name: &str) -> String {
    match field(value, name) {
        Some(sc2k_sim::sim::value::Value::Str(text)) => text.clone(),
        _ => String::new(),
    }
}

#[cfg(test)]
mod tests {
    use super::{Effects, Event, earthquake_offsets, launch_offsets};
    use crate::art::index_sprite;
    use sc2k_render::City as PainterCity;

    #[test]
    fn effects_show_on_their_frames() {
        let painter = PainterCity {
            edge: 4,
            altitude: vec![0; 16],
            ..PainterCity::default()
        };
        let mut sprites = std::collections::HashMap::new();
        sprites.insert(1394 * 2, index_sprite(2, 2, &[1, 1, 1, 1]));
        let event = |frame| Event {
            point: (1, 1),
            sprite_id: 1394,
            frame,
            depth_point: (-1, -1),
            ..Event::default()
        };
        let mut effects = Effects::default();
        effects.show(&[event(0), event(2)], 1000.0, &painter, &sprites, 2);
        assert_eq!(effects.draws(1050.0).get(&5).map(Vec::len), Some(1));
        assert!(effects.draws(1150.0).is_empty());
        assert_eq!(effects.draws(1250.0).get(&5).map(Vec::len), Some(1));
        assert!(effects.draws(2000.0).is_empty() && effects.is_empty());
    }

    #[test]
    fn shakes_and_launches_end() {
        let offsets = earthquake_offsets();
        assert_eq!(offsets.len(), 61);
        assert_eq!(*offsets.last().unwrap(), (0.0, 0.0));
        let flight = launch_offsets(30, 1, 1000, 100, 0);
        assert_eq!(flight[..15], [(0, 0); 15]);
        assert!(flight.last().unwrap().1 < -1000);
    }
}
