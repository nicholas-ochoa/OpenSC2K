//! The disaster sound loop of SIMCITY.EXE 0x00480480 and 0x0047fda0. One
//! loop plays at a time, beside the other wave sounds. The simulation starts
//! the siren and fire loops, and stops the loop when the disaster ends.
//!
//! A counted loop stops after its plays. In SIMCITY.EXE, 0x0047fda0 clears
//! the count but does not stop the looping sound, so the siren continues
//! until another loop or the end of the disaster.

use crate::wave_gate::duration_ticks;

/// While the siren plays its counted plays, other loop requests wait.
const SOUND_SIREN: i64 = 520;

#[derive(Clone, Debug, Default)]
pub struct SoundLoop {
    pub sound_id: Option<i64>,
    /// The plays of a counted loop, or 0 for a loop until a stop request.
    pub plays: i64,
    /// The base ticks left of a counted loop.
    remaining_ticks: i64,
    /// The loop that starts after the siren (0x004ea854).
    queued: Option<i64>,
}

impl SoundLoop {
    /// Loops the sound for `plays` plays, or until a stop request when
    /// `plays` is less than 1. A request for the sound that loops changes
    /// nothing.
    pub fn request(&mut self, sound_id: i64, plays: i64) {
        let duration = duration_ticks(sound_id);

        if duration == 0 || self.sound_id == Some(sound_id) {
            return;
        }

        if self.sound_id == Some(SOUND_SIREN) && self.remaining_ticks > 0 {
            self.queued = Some(sound_id);

            return;
        }

        self.sound_id = Some(sound_id);
        self.plays = plays.max(0);
        self.remaining_ticks = duration * self.plays;
    }

    /// One base tick. When the counted plays end, a queued loop starts, or
    /// the loop stops.
    pub fn tick(&mut self) {
        if self.remaining_ticks <= 0 {
            return;
        }

        self.remaining_ticks -= 1;

        if self.remaining_ticks > 0 {
            return;
        }

        match self.queued.take() {
            Some(next) => {
                self.sound_id = Some(next);
                self.plays = 0;
            }
            None => self.stop(),
        }
    }

    pub fn stop(&mut self) {
        *self = Self::default();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const SOUND_FIRE: i64 = 507;
    const SOUND_FLOOD: i64 = 511;

    fn ticks(sound_loop: &mut SoundLoop, count: i64) {
        for _ in 0..count {
            sound_loop.tick();
        }
    }

    #[test]
    fn the_fire_loop_waits_for_the_siren_plays() {
        let mut sound_loop = SoundLoop::default();
        sound_loop.request(SOUND_SIREN, 3);
        sound_loop.request(SOUND_FIRE, -1);
        assert_eq!(
            (sound_loop.sound_id, sound_loop.plays),
            (Some(SOUND_SIREN), 3),
            "the fire waits for the siren"
        );
        ticks(&mut sound_loop, duration_ticks(SOUND_SIREN) * 3 - 1);
        assert_eq!(sound_loop.sound_id, Some(SOUND_SIREN), "the siren plays three times");
        sound_loop.tick();
        assert_eq!(
            (sound_loop.sound_id, sound_loop.plays),
            (Some(SOUND_FIRE), 0),
            "the fire loop follows the siren"
        );
        ticks(&mut sound_loop, 1000);
        assert_eq!(sound_loop.sound_id, Some(SOUND_FIRE), "the fire loops until a stop request");
        sound_loop.stop();
        assert_eq!(sound_loop.sound_id, None);
    }

    #[test]
    fn the_siren_stops_after_its_plays() {
        let mut sound_loop = SoundLoop::default();
        sound_loop.request(SOUND_SIREN, 3);
        ticks(&mut sound_loop, duration_ticks(SOUND_SIREN) * 3);
        assert_eq!(sound_loop.sound_id, None, "the siren stops after three plays");
        sound_loop.request(SOUND_FLOOD, -1);
        assert_eq!(sound_loop.sound_id, Some(SOUND_FLOOD), "a later loop starts at once");
        sound_loop.request(0, -1);
        assert_eq!(sound_loop.sound_id, Some(SOUND_FLOOD), "an unknown sound does not loop");
    }
}
