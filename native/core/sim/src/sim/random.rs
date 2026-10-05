//! The three process random generators of the original. Keep them separate.
//!
//! A generator can delegate its draws to a script. The bridge uses this for
//! test generators that replace the draws of the GDScript classes. Each method
//! delegates on its own, so a script can replace only some methods.

/// Draws for a scripted SimRandom.
pub trait SimRandomScript {
    fn next_u15(&mut self) -> i64;
}

/// Draws for a scripted SimLfsrRandom.
pub trait LfsrRandomScript {
    fn next_word(&mut self) -> i64;
    fn next_mask(&mut self, mask: i64) -> i64;
    fn next_mod(&mut self, divisor: i64) -> i64;
}

/// Draws for a scripted GameLcgRandom.
pub trait GameRandomScript {
    fn next_mod(&mut self, divisor: i64) -> i64;
}

/// The C runtime generator of the original process.
#[derive(Default)]
pub struct SimRandom {
    pub state: i64,
    pub script: Option<Box<dyn SimRandomScript>>,
}

impl SimRandom {
    const MULTIPLIER: i64 = 214013;
    const INCREMENT: i64 = 2531011;

    pub fn new(seed: i64) -> Self {
        Self {
            state: seed & 0xffff_ffff,
            script: None,
        }
    }

    #[inline]
    pub fn next_u15(&mut self) -> i64 {
        if let Some(script) = self.script.as_mut() {
            return script.next_u15();
        }

        self.state = (self.state.wrapping_mul(Self::MULTIPLIER).wrapping_add(Self::INCREMENT)) & 0xffff_ffff;

        (self.state >> 16) & 0x7fff
    }
}

/// The 16-bit feedback shift register.
#[derive(Default)]
pub struct SimLfsrRandom {
    pub state: i64,
    pub script: Option<Box<dyn LfsrRandomScript>>,
}

impl SimLfsrRandom {
    const FEEDBACK: i64 = 0x1bf5;

    pub fn new(seed: i64) -> Self {
        Self {
            state: seed & 0xffff,
            script: None,
        }
    }

    #[inline]
    pub fn next_word(&mut self) -> i64 {
        if let Some(script) = self.script.as_mut() {
            return script.next_word();
        }

        if self.state & 0x8000 != 0 {
            self.state = ((self.state << 1) ^ Self::FEEDBACK) & 0xffff;
        } else {
            self.state = (self.state << 1) & 0xffff;
        }

        self.state
    }

    #[inline]
    pub fn next_mask(&mut self, mask: i64) -> i64 {
        if let Some(script) = self.script.as_mut() {
            return script.next_mask(mask);
        }

        self.next_word() & mask
    }

    #[inline]
    pub fn next_mod(&mut self, divisor: i64) -> i64 {
        if let Some(script) = self.script.as_mut() {
            return script.next_mod(divisor);
        }

        if divisor <= 0 {
            return 0;
        }

        self.next_word() % divisor
    }
}

/// The game library generator.
#[derive(Default)]
pub struct GameLcgRandom {
    pub state: i64,
    pub script: Option<Box<dyn GameRandomScript>>,
}

impl GameLcgRandom {
    const MULTIPLIER: i64 = 1103515245;
    const INCREMENT: i64 = 12345;

    pub fn new(seed: i64) -> Self {
        Self {
            state: seed & 0xffff_ffff,
            script: None,
        }
    }

    #[inline]
    pub fn next_mod(&mut self, divisor: i64) -> i64 {
        if let Some(script) = self.script.as_mut() {
            return script.next_mod(divisor);
        }

        if divisor <= 0 {
            return 0;
        }

        self.state = (self.state.wrapping_mul(Self::MULTIPLIER).wrapping_add(Self::INCREMENT)) & 0xffff_ffff;

        ((self.state >> 16) & 0x7fff) % divisor
    }
}

/// All three generators. The simulation passes them together.
#[derive(Default)]
pub struct Randoms {
    pub random: SimRandom,
    pub lfsr: SimLfsrRandom,
    pub game: GameLcgRandom,
}

impl Randoms {
    pub fn new(random: i64, lfsr: i64, game: i64) -> Self {
        Self {
            random: SimRandom::new(random),
            lfsr: SimLfsrRandom::new(lfsr),
            game: GameLcgRandom::new(game),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sim_random_matches_the_c_runtime() {
        let mut random = SimRandom::new(1);
        assert_eq!(random.next_u15(), 41);
        assert_eq!(random.next_u15(), 18467);
        assert_eq!(random.next_u15(), 6334);
    }

    #[test]
    fn lfsr_feeds_back_the_high_bit() {
        let mut random = SimLfsrRandom::new(0x8000);
        assert_eq!(random.next_word(), 0x1bf5);
        assert_eq!(random.next_word(), 0x37ea);
    }

    struct Zero;

    impl SimRandomScript for Zero {
        fn next_u15(&mut self) -> i64 {
            0
        }
    }

    #[test]
    fn a_script_replaces_the_draws() {
        let mut random = SimRandom::new(1);
        random.script = Some(Box::new(Zero));
        assert_eq!(random.next_u15(), 0);
        assert_eq!(random.state, 1);
    }
}
