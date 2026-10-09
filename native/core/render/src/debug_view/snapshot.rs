//! A copy of the tile arrays, and the tiles that changed since the copy. The
//! layer value of a tile holds one bit for each array that changed. The
//! current arrays are compared where they are, without a copy.

/// One bit for each compared array.
pub const CHANGED_BUILDING: u8 = 0x01;
pub const CHANGED_ZONE: u8 = 0x02;
pub const CHANGED_TERRAIN: u8 = 0x04;
pub const CHANGED_ALTITUDE: u8 = 0x08;
pub const CHANGED_UNDERGROUND: u8 = 0x10;
pub const CHANGED_OVERLAY: u8 = 0x20;
pub const CHANGED_FLAGS: u8 = 0x40;
pub const PLANES: usize = 7;

/// The tile arrays of one moment, borrowed from Godot or from a snapshot.
/// Overlays may hold more planes; the comparison reads the first byte plane,
/// the marker and narrow ID of each tile.
#[derive(Clone, Copy, Default)]
pub struct Tiles<'a> {
    pub edge: usize,
    pub buildings: &'a [u8],
    pub zones: &'a [u8],
    pub terrain: &'a [u8],
    pub altitude: &'a [i32],
    pub underground: &'a [u8],
    pub overlays: &'a [u8],
    pub flags: &'a [u8],
}

/// An owned copy of the tile arrays.
#[derive(Clone, Default)]
pub struct Snapshot {
    pub edge: usize,
    pub buildings: Vec<u8>,
    pub zones: Vec<u8>,
    pub terrain: Vec<u8>,
    pub altitude: Vec<i32>,
    pub underground: Vec<u8>,
    pub overlays: Vec<u8>,
    pub flags: Vec<u8>,
}

/// The changed bits of each tile and the changed tiles of each plane.
#[derive(Default)]
pub struct Difference {
    pub values: Vec<u8>,
    pub counts: [usize; PLANES],
    pub tiles: usize,
}

impl Snapshot {
    /// A copy of `tiles`. Overlays keep their first plane.
    pub fn copy(tiles: &Tiles) -> Self {
        let cells = tiles.cells();

        Self {
            edge: tiles.edge,
            buildings: tiles.buildings.to_vec(),
            zones: tiles.zones.to_vec(),
            terrain: tiles.terrain.to_vec(),
            altitude: tiles.altitude.to_vec(),
            underground: tiles.underground.to_vec(),
            overlays: tiles.overlays[..cells.min(tiles.overlays.len())].to_vec(),
            flags: tiles.flags.to_vec(),
        }
    }

    pub fn tiles(&self) -> Tiles<'_> {
        Tiles {
            edge: self.edge,
            buildings: &self.buildings,
            zones: &self.zones,
            terrain: &self.terrain,
            altitude: &self.altitude,
            underground: &self.underground,
            overlays: &self.overlays,
            flags: &self.flags,
        }
    }
}

impl Tiles<'_> {
    pub fn cells(&self) -> usize {
        self.edge * self.edge
    }

    /// True when every array holds one value for each tile.
    pub fn is_complete(&self) -> bool {
        let cells = self.cells();

        cells > 0
            && self.buildings.len() == cells
            && self.zones.len() == cells
            && self.terrain.len() == cells
            && self.altitude.len() == cells
            && self.underground.len() == cells
            && self.overlays.len() >= cells
            && self.flags.len() == cells
    }

    /// The changed tiles from `self` to `after`. Maps of other sizes have no
    /// comparable tiles. `ignored_flags` leaves out flag bits such as MARK.
    pub fn difference(&self, after: &Tiles, ignored_flags: u8) -> Difference {
        let cells = self.cells();
        let mut result = Difference {
            values: vec![0; after.cells()],
            ..Default::default()
        };

        if self.edge != after.edge || !self.is_complete() || !after.is_complete() {
            return result;
        }

        let keep = !ignored_flags;

        for i in 0..cells {
            let mut bits = 0;
            bits |= changed(self.buildings[i], after.buildings[i], CHANGED_BUILDING);
            bits |= changed(self.zones[i], after.zones[i], CHANGED_ZONE);
            bits |= changed(self.terrain[i], after.terrain[i], CHANGED_TERRAIN);
            bits |= changed(self.altitude[i], after.altitude[i], CHANGED_ALTITUDE);
            bits |= changed(self.underground[i], after.underground[i], CHANGED_UNDERGROUND);
            bits |= changed(self.overlays[i], after.overlays[i], CHANGED_OVERLAY);
            bits |= changed(self.flags[i] & keep, after.flags[i] & keep, CHANGED_FLAGS);

            if bits == 0 {
                continue;
            }

            result.values[i] = bits;
            result.tiles += 1;

            for (plane, count) in result.counts.iter_mut().enumerate() {
                *count += usize::from(bits & (1 << plane) != 0);
            }
        }

        result
    }
}

fn changed<T: PartialEq>(before: T, after: T, bit: u8) -> u8 {
    if before == after { 0 } else { bit }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn snapshot(edge: usize) -> Snapshot {
        let cells = edge * edge;

        Snapshot {
            edge,
            buildings: vec![0; cells],
            zones: vec![0; cells],
            terrain: vec![0; cells],
            altitude: vec![0; cells],
            underground: vec![0; cells],
            overlays: vec![0; cells],
            flags: vec![0; cells],
        }
    }

    #[test]
    fn each_array_sets_its_own_bit() {
        let before = snapshot(2);
        let mut after = before.clone();
        after.buildings[0] = 7;
        after.zones[0] = 1;
        after.altitude[1] = 3;
        after.flags[3] = 0x40;

        let difference = before.tiles().difference(&after.tiles(), 0);

        assert_eq!(
            difference.values,
            vec![CHANGED_BUILDING | CHANGED_ZONE, CHANGED_ALTITUDE, 0, CHANGED_FLAGS]
        );
        assert_eq!(difference.tiles, 3);
        assert_eq!(difference.counts[0], 1);
        assert_eq!(difference.counts[3], 1);
    }

    #[test]
    fn ignored_flags_do_not_count() {
        let before = snapshot(2);
        let mut after = before.clone();
        after.flags[0] = 0x08;

        assert_eq!(before.tiles().difference(&after.tiles(), 0x08).tiles, 0);
        assert_eq!(before.tiles().difference(&after.tiles(), 0).tiles, 1);
    }

    #[test]
    fn other_map_sizes_do_not_compare() {
        let difference = snapshot(2).tiles().difference(&snapshot(4).tiles(), 0);

        assert_eq!(difference.tiles, 0);
        assert_eq!(difference.values.len(), 16);
    }
}
