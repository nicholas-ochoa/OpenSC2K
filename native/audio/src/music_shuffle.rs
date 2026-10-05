//! The shuffled order of the music tracks for GDScript.

use godot::prelude::*;
use sc2k_audio::shuffle::Shuffle;
use std::time::{SystemTime, UNIX_EPOCH};

/// A shuffle of the music tracks, seeded from the clock.
#[derive(GodotClass)]
#[class(base = RefCounted)]
pub struct NativeMusicShuffle {
    shuffle: Shuffle,
}

#[godot_api]
impl IRefCounted for NativeMusicShuffle {
    fn init(_base: Base<RefCounted>) -> Self {
        let seed = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_or(1, |time| time.as_nanos() as u64);

        Self {
            shuffle: Shuffle::new(seed),
        }
    }
}

#[godot_api]
impl NativeMusicShuffle {
    /// The tracks that the current round has not played.
    #[func]
    fn remaining(&self) -> PackedInt64Array {
        PackedInt64Array::from(self.shuffle.remaining())
    }

    /// Replace the tracks of the current round.
    #[func]
    fn set_remaining(&mut self, tracks: PackedInt64Array) {
        self.shuffle.set_remaining(tracks.as_slice());
    }

    /// Restart the order with `seed`, for a repeatable test.
    #[func]
    fn seed(&mut self, seed: i64) {
        self.shuffle.seed(seed as u64);
    }

    /// A track that started outside the shuffle.
    #[func]
    fn mark_started(&mut self, track: i64) {
        self.shuffle.mark_started(track);
    }

    /// Start a new round after `track`.
    #[func]
    fn restart_after(&mut self, track: i64) {
        self.shuffle.restart_after(track);
    }

    /// The next track of the tracks `first` through `first + count - 1`.
    #[func]
    fn next_track(&mut self, first: i64, count: i64) -> i64 {
        self.shuffle.next_track(first, count)
    }
}
