//! The music tracks that the game chooses, as MusicDirector. The monthly
//! track is in `engine::month`.

use crate::sim::random::SimLfsrRandom;

pub const MAIN_THEME_TRACK: i64 = 10001;
pub const ABOUT_TRACK: i64 = 10011;
pub use crate::sim::engine::month::{FIRST_TRACK_ID, TRACK_COUNT};
/// The tracks that play in turn while no other track is due.
pub const GENERAL_TRACKS: [i64; 5] = [10001, 10004, 10008, 10012, 10018];
const BUDGET_TRACKS: [i64; 4] = [10016, 10005, 10002, 10010];
const NEWSPAPER_TRACKS: [i64; 5] = [10009, 10015, 10014, 10006, 10002];
pub const DISASTER_TRACK: i64 = 10004;
pub const RECREATION_TRACK: i64 = 10010;

/// The next general track and the index after it.
pub fn next_general_track(index: i64) -> (i64, i64) {
    let count = GENERAL_TRACKS.len() as i64;
    let position = index.rem_euclid(count);

    (GENERAL_TRACKS[position as usize], position + 1)
}

/// The track of the budget window. It draws one LFSR value.
pub fn budget_track(random: &mut SimLfsrRandom) -> i64 {
    BUDGET_TRACKS[random.next_mod(BUDGET_TRACKS.len() as i64) as usize]
}

/// The track of the newspaper. It draws one LFSR value.
pub fn newspaper_track(random: &mut SimLfsrRandom) -> i64 {
    NEWSPAPER_TRACKS[random.next_mod(NEWSPAPER_TRACKS.len() as i64) as usize]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn general_tracks_play_in_turn() {
        assert_eq!(next_general_track(0), (10001, 1));
        assert_eq!(next_general_track(5), (10001, 1));
        assert_eq!(next_general_track(4), (10018, 5));
        assert!(BUDGET_TRACKS.contains(&budget_track(&mut SimLfsrRandom::new(3))));
    }

    #[test]
    fn budget_and_newspaper_music_use_the_executable_tables() {
        let mut random = crate::sim::testing::sequence_lfsr(&[0, 1, 2, 3, 4]);
        let budget: Vec<i64> = (0..4).map(|_| budget_track(&mut random)).collect();
        assert_eq!(budget, vec![10016, 10005, 10002, 10010]);
        assert_eq!(newspaper_track(&mut random), 10002);
    }

    #[test]
    fn monthly_music_follows_the_speed_gate() {
        use crate::sim::engine::month::monthly_track;
        use crate::sim::testing::sequence_random;

        // a pause uses the Turtle divisor and selects one of all 19 tracks
        assert_eq!(monthly_track(1, false, &mut sequence_random(&[0, 18])), 10018);
        assert_eq!(monthly_track(2, false, &mut sequence_random(&[25])), -1, "a nonzero modulo-24 gate");
        assert_eq!(
            monthly_track(5, true, &mut sequence_random(&[0, 0])),
            -1,
            "active music selects nothing"
        );
    }
}
