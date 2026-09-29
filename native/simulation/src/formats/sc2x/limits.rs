//! Default record budgets and ordinary vehicle caps of new SC2X cities.
//!
//! Collection headers hold physical capacities. An imported collection may be
//! larger than its profile; the profile then limits only new allocation.

/// The capacities and ordinary vehicle caps of one map size.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Profile {
    pub edge: usize,
    pub facilities: usize,
    pub signs: usize,
    pub things: usize,
    pub airplanes: usize,
    pub helicopters: usize,
    pub ships: usize,
    pub sailboats: usize,
    /// Surface and subway engines together. Each train also uses two car records.
    pub trains: usize,
}

impl Profile {
    /// Individual facility records: every slot from 10 upward.
    pub fn individual_facilities(&self) -> usize {
        self.facilities - super::xmic::INDIVIDUAL_FIRST
    }

    /// Normally usable moving-object records: every slot except reserved slot 0.
    pub fn usable_things(&self) -> usize {
        self.things - 1
    }

    /// The records that all ordinary vehicles use at their caps.
    pub fn records_at_caps(&self) -> usize {
        self.airplanes + self.helicopters + self.ships + self.sailboats + self.trains * 3
    }
}

const fn profile(edge: usize, facilities: usize, signs: usize, things: usize, caps: [usize; 5]) -> Profile {
    Profile {
        edge,
        facilities,
        signs,
        things,
        airplanes: caps[0],
        helicopters: caps[1],
        ships: caps[2],
        sailboats: caps[3],
        trains: caps[4],
    }
}

/// Section 3 of the format plan. The 2048 profile is a storage target only;
/// the game does not create or run 2048 maps.
pub const PROFILES: [Profile; 10] = [
    profile(16, 64, 16, 16, [1, 1, 1, 1, 1]),
    profile(32, 64, 16, 32, [2, 1, 1, 2, 1]),
    profile(64, 128, 32, 64, [2, 1, 1, 4, 8]),
    profile(128, 256, 128, 128, [2, 1, 1, 4, 8]),
    profile(256, 512, 256, 256, [4, 2, 2, 8, 16]),
    profile(384, 1024, 256, 384, [4, 2, 2, 8, 16]),
    profile(512, 1024, 512, 512, [8, 4, 4, 16, 32]),
    profile(640, 1024, 512, 512, [8, 4, 4, 16, 32]),
    profile(1024, 2048, 512, 512, [16, 8, 8, 32, 64]),
    profile(2048, 8192, 512, 1024, [32, 16, 16, 32, 128]),
];

pub fn profile_for(edge: usize) -> Option<Profile> {
    PROFILES.iter().copied().find(|profile| profile.edge == edge)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn profiles_match_the_plan_tables() {
        let usable: Vec<(usize, usize, usize)> = PROFILES
            .iter()
            .map(|profile| (profile.individual_facilities(), profile.usable_things(), profile.records_at_caps()))
            .collect();
        assert_eq!(
            usable,
            vec![
                (54, 15, 7),
                (54, 31, 9),
                (118, 63, 32),
                (246, 127, 32),
                (502, 255, 64),
                (1014, 383, 64),
                (1014, 511, 128),
                (1014, 511, 128),
                (2038, 511, 256),
                (8182, 1023, 480),
            ]
        );

        for profile in PROFILES {
            assert!(
                profile.records_at_caps() <= profile.usable_things(),
                "{} caps fit the pool",
                profile.edge
            );
        }

        assert!(profile_for(100).is_none());
    }
}
