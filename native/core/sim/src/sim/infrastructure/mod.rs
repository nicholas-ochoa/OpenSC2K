//! Power, water, and traffic scans.

pub mod power;
pub mod traffic;
pub mod water;

use crate::sim::ids::sc2tile_flags as flag_bits;

/// The original 512-slot trace queue for SC2 cities. A push into a full queue
/// drops the oldest entry, so a very wide network can lose tiles.
pub struct TraceQueue {
    entries: [i64; Self::SIZE],
    head: usize,
    tail: usize,
}

impl TraceQueue {
    const SIZE: usize = 512;

    pub fn new(start: i64) -> Self {
        let mut queue = Self {
            entries: [0; Self::SIZE],
            head: 0,
            tail: 0,
        };
        queue.push(start);
        queue
    }

    pub fn is_empty(&self) -> bool {
        self.head == self.tail
    }

    pub fn push(&mut self, index: i64) {
        self.entries[self.tail] = index;
        self.tail = (self.tail + 1) & (Self::SIZE - 1);

        if self.tail == self.head {
            self.head = (self.head + 1) & (Self::SIZE - 1);
        }
    }

    pub fn pop(&mut self) -> i64 {
        let index = self.entries[self.head];
        self.head = (self.head + 1) & (Self::SIZE - 1);
        index
    }
}

/// PowerPhase._queue_neighbors: queue each neighbor whose mark bit equals `mark`.
pub fn queue_neighbors(flags: &[u8], queue: &mut TraceQueue, x: i64, y: i64, mark: i64, map_edge: i64) {
    let marked = |index: i64| flags[index as usize] as i64 & flag_bits::MARK == mark;

    if y > 0 && marked(x * map_edge + y - 1) {
        queue.push(x * map_edge + y - 1);
    }

    if x > 0 && marked((x - 1) * map_edge + y) {
        queue.push((x - 1) * map_edge + y);
    }

    if y < map_edge - 1 && marked(x * map_edge + y + 1) {
        queue.push(x * map_edge + y + 1);
    }

    if x < map_edge - 1 && marked((x + 1) * map_edge + y) {
        queue.push((x + 1) * map_edge + y);
    }
}

/// Sc2TileFlags.without: a copy of the flags with `bits` cleared.
pub fn flags_without(flags: &[u8], bits: i64) -> Vec<u8> {
    let keep = (!bits & 0xff) as u8;

    flags.iter().map(|&flag| flag & keep).collect()
}

/// Tiles that hold one of the building ids, in ascending index order. This is
/// the order of a scan by x, then by y.
pub fn building_indices(buildings: &[u8], ids: &[i64]) -> Vec<i64> {
    let mut wanted = [false; 256];

    for &id in ids {
        if (0..256).contains(&id) {
            wanted[id as usize] = true;
        }
    }

    buildings
        .iter()
        .enumerate()
        .filter(|(_, building)| wanted[**building as usize])
        .map(|(index, _)| index as i64)
        .collect()
}
