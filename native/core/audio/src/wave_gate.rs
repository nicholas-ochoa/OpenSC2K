//! Which wave sounds play, as WaveSoundGate: one sound plays at a time, and
//! moving objects and simulation events wait for their replay delays. The
//! City Sounds preference controls the vehicle sounds; disaster sounds and
//! player feedback always play. The disaster loop is `sound_loop`.

use crate::sound_loop::SoundLoop;

const SOUND_FIRST: i64 = 500;
const SOUND_LAST: i64 = 529;
const SOUND_EXPLODE: i64 = 504;
const SOUND_FLOOD: i64 = 511;
const BASE_TICK_MSEC: f64 = 200.0;
const MINIMUM_REPLAY_TICKS: i64 = 3;
/// Presentation preference: the ambient delay that all moving objects share.
const AMBIENT_REPLAY_MSEC: f64 = 15000.0;
/// Presentation preference: the delay before a simulation event sound plays again.
const EVENT_REPLAY_MSEC: f64 = 10000.0;
/// Presentation preference: the flood and buildings that a disaster destroys repeat sooner.
const EVENT_REPLAY_OVERRIDES: [(i64, f64); 2] = [(SOUND_FLOOD, 3000.0), (SOUND_EXPLODE, 1000.0)];
/// Presentation preference: the delay after any vehicle sound when city sounds are reduced.
const REDUCED_REPLAY_MSEC: f64 = 30000.0;
/// The helicopter, ship, airplane takeoff and landing, train, and the
/// sailboat, which uses the zoo roar.
const VEHICLE_SOUNDS: [i64; 6] = [510, 517, 518, 519, 524, 527];
/// The executable table at 0x004ea858 before its initialization pass.
const RAW_DURATION_MSEC: [i64; 30] = [
    492, 153, 1485, 129, 1156, 221, 1064, 1657, 1510, 1511, 2264, 886, 2766, 2203, 473, 625, 782, 1223, 2444, 1308, 2468, 971, 2194, 1414,
    2338, 1165, 1937, 2359, 1510, 1613,
];

/// The City Sounds preference.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum CitySounds {
    #[default]
    Default,
    Reduced,
    Off,
}

/// The base ticks that a sound lasts, or 0 for an unknown sound.
pub fn duration_ticks(sound_id: i64) -> i64 {
    if !(SOUND_FIRST..=SOUND_LAST).contains(&sound_id) {
        return 0;
    }

    RAW_DURATION_MSEC[(sound_id - SOUND_FIRST) as usize] / 200 + 1
}

pub fn event_replay_msec(sound_id: i64) -> f64 {
    EVENT_REPLAY_OVERRIDES
        .iter()
        .find(|(sound, _)| *sound == sound_id)
        .map_or(EVENT_REPLAY_MSEC, |(_, delay)| *delay)
}

#[derive(Clone, Debug, Default)]
pub struct WaveGate {
    ambient_remaining: Vec<(i64, f64)>,
    event_remaining: Vec<(i64, f64)>,
    pub current_sound_id: Option<i64>,
    pub remaining_ticks: i64,
    pub accepted_count: i64,
    pub suppressed_count: i64,
    pub city_sounds: CitySounds,
    reduced_remaining_msec: f64,
    tick_accumulator_msec: f64,
    pub sound_loop: SoundLoop,
}

fn delay(delays: &[(i64, f64)], sound_id: i64) -> f64 {
    delays
        .iter()
        .find(|(sound, _)| *sound == sound_id)
        .map_or(0.0, |(_, remaining)| *remaining)
}

fn set_delay(delays: &mut Vec<(i64, f64)>, sound_id: i64, value: f64) {
    match delays.iter_mut().find(|(sound, _)| *sound == sound_id) {
        Some(entry) => entry.1 = value,
        None => delays.push((sound_id, value)),
    }
}

impl WaveGate {
    /// True when the sound plays now. `ambient` requests come from moving
    /// objects, `simulation` requests from other simulation events; both wait
    /// for their replay delay. Other requests are player feedback. A moving
    /// object that is not a vehicle, such as a tornado that destroys a
    /// building, waits for the event delay.
    pub fn request(&mut self, sound_id: i64, ambient: bool, simulation: bool) -> bool {
        let total_ticks = duration_ticks(sound_id);

        if total_ticks == 0 {
            return false;
        }

        let city_sound = ambient && VEHICLE_SOUNDS.contains(&sound_id);
        let (ambient, simulation) = if ambient && !city_sound {
            (false, true)
        } else {
            (ambient, simulation)
        };
        let muted = self.city_sounds == CitySounds::Off || (self.city_sounds == CitySounds::Reduced && self.reduced_remaining_msec > 0.0);
        let waiting = (ambient && delay(&self.ambient_remaining, sound_id) > 0.0)
            || (simulation && !ambient && delay(&self.event_remaining, sound_id) > 0.0);
        let repeating = self.current_sound_id == Some(sound_id)
            && self.remaining_ticks > 0
            && total_ticks - self.remaining_ticks < MINIMUM_REPLAY_TICKS;

        if (city_sound && muted) || waiting || repeating {
            self.suppressed_count += 1;

            return false;
        }

        self.current_sound_id = Some(sound_id);
        self.remaining_ticks = total_ticks;

        if ambient {
            set_delay(&mut self.ambient_remaining, sound_id, AMBIENT_REPLAY_MSEC);
        } else if simulation {
            set_delay(&mut self.event_remaining, sound_id, event_replay_msec(sound_id));
        }

        if city_sound && self.city_sounds == CitySounds::Reduced {
            self.reduced_remaining_msec = REDUCED_REPLAY_MSEC;
        }

        self.accepted_count += 1;

        true
    }

    pub fn advance(&mut self, delta_msec: f64) {
        if delta_msec <= 0.0 {
            return;
        }

        self.reduced_remaining_msec = (self.reduced_remaining_msec - delta_msec).max(0.0);

        for delays in [&mut self.ambient_remaining, &mut self.event_remaining] {
            delays.retain_mut(|(_, remaining)| {
                *remaining -= delta_msec;
                *remaining > 0.0
            });
        }

        self.tick_accumulator_msec += delta_msec;

        while self.tick_accumulator_msec >= BASE_TICK_MSEC {
            self.tick_accumulator_msec -= BASE_TICK_MSEC;
            self.sound_loop.tick();

            if self.remaining_ticks <= 0 {
                continue;
            }

            self.remaining_ticks -= 1;

            if self.remaining_ticks == 0 {
                self.current_sound_id = None;
            }
        }
    }

    pub fn stop(&mut self) {
        self.ambient_remaining.clear();
        self.event_remaining.clear();
        self.reduced_remaining_msec = 0.0;
        self.current_sound_id = None;
        self.remaining_ticks = 0;
        self.tick_accumulator_msec = 0.0;
        self.sound_loop.stop();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_sound_waits_for_its_replay_delay() {
        let mut gate = WaveGate::default();
        assert_eq!(duration_ticks(500), 3);
        assert!(gate.request(509, false, true));
        assert!(!gate.request(509, false, true), "the same sound waits");
        gate.advance(10_000.0);
        assert!(gate.request(509, false, true));
        assert_eq!((gate.accepted_count, gate.suppressed_count), (2, 1));
    }

    #[test]
    fn reduced_city_sounds_share_one_delay() {
        let mut gate = WaveGate {
            city_sounds: CitySounds::Reduced,
            ..WaveGate::default()
        };
        assert!(gate.request(510, true, false));
        gate.advance(1000.0);
        assert!(!gate.request(517, true, false), "another vehicle waits for the shared delay");
        assert!(gate.request(504, true, false), "a disaster sound from a moving object plays");
        gate.stop();
        assert_eq!((gate.current_sound_id, gate.remaining_ticks), (None, 0));
    }
}
