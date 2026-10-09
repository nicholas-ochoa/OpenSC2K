//! The shuffled order of the music tracks: each track plays once before any
//! track repeats, and a new round never starts with the last track.

/// A xorshift generator; the order only needs to look random.
#[derive(Clone, Debug)]
struct Generator(u64);

impl Generator {
    fn next(&mut self) -> u64 {
        let mut value = self.0;
        value ^= value << 13;
        value ^= value >> 7;
        value ^= value << 17;
        self.0 = value;
        value
    }

    /// A value from 0 through `last`.
    fn up_to(&mut self, last: usize) -> usize {
        (self.next() % (last as u64 + 1)) as usize
    }
}

#[derive(Clone, Debug)]
pub struct Shuffle {
    generator: Generator,
    remaining: Vec<i64>,
    last_track: Option<i64>,
}

impl Shuffle {
    /// A shuffle seeded with `seed`. A zero seed uses 1.
    pub fn new(seed: u64) -> Self {
        Self {
            generator: Generator(seed.max(1)),
            remaining: Vec::new(),
            last_track: None,
        }
    }

    /// The tracks that the current round has not played.
    pub fn remaining(&self) -> &[i64] {
        &self.remaining
    }

    /// Replace the tracks of the current round.
    pub fn set_remaining(&mut self, tracks: &[i64]) {
        self.remaining = tracks.to_vec();
    }

    /// Restart the generator with `seed`. A zero seed uses 1.
    pub fn seed(&mut self, seed: u64) {
        self.generator = Generator(seed.max(1));
    }

    /// A track that started outside the shuffle: the round skips it, and the
    /// next round does not start with it.
    pub fn mark_started(&mut self, track: i64) {
        self.last_track = Some(track);
        self.remaining.retain(|&remaining| remaining != track);
    }

    /// Start a new round after `track`.
    pub fn restart_after(&mut self, track: i64) {
        self.remaining.clear();
        self.last_track = Some(track);
    }

    /// The next track of the tracks `first` through `first + count - 1`.
    pub fn next_track(&mut self, first: i64, count: i64) -> i64 {
        if self.remaining.is_empty() {
            self.remaining = (first..first + count.max(1)).collect();

            for index in (1..self.remaining.len()).rev() {
                let other = self.generator.up_to(index);
                self.remaining.swap(index, other);
            }

            if self.remaining.last().copied() == self.last_track {
                let last = self.remaining.len() - 1;
                self.remaining.swap(0, last);
            }
        }

        let track = self.remaining.pop().unwrap_or(first);
        self.last_track = Some(track);

        track
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn each_round_plays_every_track_without_a_repeat_at_the_seam() {
        let mut shuffle = Shuffle::new(42);
        let mut previous = None;

        for _ in 0..20 {
            let mut round: Vec<i64> = (0..19).map(|_| shuffle.next_track(10000, 19)).collect();
            assert_ne!(Some(round[0]), previous);
            previous = round.last().copied();
            round.sort_unstable();
            assert_eq!(round, (10000..10019).collect::<Vec<_>>());
        }

        shuffle.restart_after(10003);
        let next = shuffle.next_track(10000, 19);
        shuffle.mark_started(next + 1);
        assert!(!shuffle.remaining().contains(&(next + 1)));
    }
}
