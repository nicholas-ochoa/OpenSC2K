//! The wave sound gate for GDScript.

use godot::prelude::*;
use sc2k_audio::wave_gate::{self, CitySounds, WaveGate};

/// Which wave sounds play. See `sc2k_audio::wave_gate`.
#[derive(GodotClass)]
#[class(init, base = RefCounted)]
pub struct NativeWaveSoundGate {
    gate: WaveGate,
}

#[godot_api]
impl NativeWaveSoundGate {
    /// The base ticks that a sound lasts, or 0 for an unknown sound.
    #[func]
    fn duration_ticks(sound_id: i64) -> i64 {
        wave_gate::duration_ticks(sound_id)
    }

    #[func]
    fn event_replay_msec(sound_id: i64) -> f64 {
        wave_gate::event_replay_msec(sound_id)
    }

    /// True when the sound plays now.
    #[func]
    fn request(&mut self, sound_id: i64, ambient: bool, simulation: bool) -> bool {
        self.gate.request(sound_id, ambient, simulation)
    }

    /// Loops the sound for `plays` plays, or until `stop_loop` when `plays`
    /// is less than 1. See `sc2k_audio::sound_loop`.
    #[func]
    fn request_loop(&mut self, sound_id: i64, plays: i64) {
        self.gate.sound_loop.request(sound_id, plays);
    }

    #[func]
    fn stop_loop(&mut self) {
        self.gate.sound_loop.stop();
    }

    /// The sound that loops, or -1.
    #[func]
    fn loop_sound_id(&self) -> i64 {
        self.gate.sound_loop.sound_id.unwrap_or(-1)
    }

    #[func]
    fn advance(&mut self, delta_msec: f64) {
        self.gate.advance(delta_msec);
    }

    #[func]
    fn stop(&mut self) {
        self.gate.stop();
    }

    /// The City Sounds preference: 0 default, 1 reduced, 2 off.
    #[func]
    fn set_city_sounds(&mut self, value: i64) {
        self.gate.city_sounds = match value {
            1 => CitySounds::Reduced,
            2 => CitySounds::Off,
            _ => CitySounds::Default,
        };
    }

    #[func]
    fn city_sounds(&self) -> i64 {
        match self.gate.city_sounds {
            CitySounds::Default => 0,
            CitySounds::Reduced => 1,
            CitySounds::Off => 2,
        }
    }

    /// `{current_sound_id, remaining_ticks, accepted_count, suppressed_count}`.
    #[func]
    fn metrics(&self) -> VarDictionary {
        let mut result = VarDictionary::new();
        result.set("current_sound_id", self.gate.current_sound_id.unwrap_or(-1));
        result.set("remaining_ticks", self.gate.remaining_ticks);
        result.set("accepted_count", self.gate.accepted_count);
        result.set("suppressed_count", self.gate.suppressed_count);
        result
    }
}
