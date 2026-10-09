//! The undo of the last edit: the chunks and random states before and after
//! it. Undo works while the city still holds the state after the edit.

use crate::session::Session;
use sc2k_sim::sim::city::CHUNK_IDS;

#[derive(Clone)]
pub struct Undo {
    pub kind: &'static str,
    chunks: Vec<(&'static str, Vec<u8>, Vec<u8>)>,
    randoms: ([i64; 3], [i64; 3]),
    engine_usage: ((i64, i64), (i64, i64)),
}

/// The state before an edit.
pub struct Before {
    chunks: Vec<(&'static str, Vec<u8>)>,
    randoms: [i64; 3],
    usage: (i64, i64),
}

/// The states of the process, LFSR, and game generators.
fn random_states(session: &Session) -> [i64; 3] {
    let randoms = &session.randoms;

    [randoms.random.state, randoms.lfsr.state, randoms.game.state]
}

fn usage(session: &Session) -> (i64, i64) {
    (session.engine.day.power_usage_percent, session.engine.day.water_usage_percent)
}

impl Undo {
    pub fn capture(session: &Session) -> Before {
        Before {
            chunks: CHUNK_IDS
                .iter()
                .filter_map(|id| session.city.chunk(id).map(|chunk| (*id, chunk.data.clone())))
                .collect(),
            randoms: random_states(session),
            usage: usage(session),
        }
    }

    /// Restore the city before the edit. Fails when the city changed since.
    pub fn apply(&self, session: &mut Session) -> Result<(), String> {
        for (id, _, after) in &self.chunks {
            if session.city.chunk(id).map(|chunk| &chunk.data) != Some(after) {
                return Err("The city changed after this edit.".into());
            }
        }

        if random_states(session) != self.randoms.1 {
            return Err("The city changed after this edit.".into());
        }

        for (id, before, _) in &self.chunks {
            if let Some(chunk) = session.city.chunk_slot_mut(id) {
                chunk.data = before.clone();
            }
        }

        [session.randoms.random.state, session.randoms.lfsr.state, session.randoms.game.state] = self.randoms.0;
        (session.engine.day.power_usage_percent, session.engine.day.water_usage_percent) = self.engine_usage.0;
        session.revision += 1;
        session.map_revision += 1;

        Ok(())
    }
}

impl Before {
    /// The undo of the edit since `capture`, or nothing when it changed nothing.
    pub fn finish(self, session: &Session, kind: &'static str) -> Option<Undo> {
        let chunks: Vec<(&'static str, Vec<u8>, Vec<u8>)> = self
            .chunks
            .into_iter()
            .filter_map(|(id, before)| {
                let after = session.city.chunk(id)?.data.clone();

                (after != before).then_some((id, before, after))
            })
            .collect();

        if chunks.is_empty() {
            return None;
        }

        Some(Undo {
            kind,
            chunks,
            randoms: (self.randoms, random_states(session)),
            engine_usage: (self.usage, usage(session)),
        })
    }
}
