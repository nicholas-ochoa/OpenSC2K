//! Bring the painter city up to date with the simulation city by comparing
//! their maps block by block, and change only the cells that differ.

use sc2k_render::City as PainterCity;
use sc2k_sim::sim::city::City;

/// Cells compared at once before the cells of a differing block are compared.
const BLOCK: usize = 256;

/// Copy the differing bytes of `source` into `target` and mark their cells.
/// `cells` maps a byte index to its cell.
fn sync_bytes(target: &mut [u8], source: &[u8], changed: &mut Vec<usize>, cells: usize) {
    if target.len() != source.len() || target == source {
        return;
    }

    for (block, (a, b)) in target.chunks_mut(BLOCK).zip(source.chunks(BLOCK)).enumerate() {
        if a == b {
            continue;
        }

        for (offset, (x, y)) in a.iter_mut().zip(b).enumerate() {
            if x != y {
                *x = *y;
                changed.push((block * BLOCK + offset) % cells);
            }
        }
    }
}

/// Update `painter` from `city`. `altitude_bytes` keeps the ALTM bytes of the
/// last update, so only differing blocks decode. Returns the changed cells,
/// unsorted, with repeats.
pub fn sync(painter: &mut PainterCity, city: &City, altitude_bytes: &mut Vec<u8>) -> Vec<usize> {
    let cells = painter.altitude.len();
    let mut changed = Vec::new();
    let chunk = |id: &str| city.chunk(id).map(|chunk| chunk.data.as_slice()).unwrap_or_default();

    sync_bytes(&mut painter.terrain, chunk("XTER"), &mut changed, cells);
    sync_bytes(&mut painter.buildings, chunk("XBLD"), &mut changed, cells);
    sync_bytes(&mut painter.zones, chunk("XZON"), &mut changed, cells);
    sync_bytes(&mut painter.flags, chunk("XBIT"), &mut changed, cells);
    sync_bytes(&mut painter.underground, chunk("XUND"), &mut changed, cells);

    // the static painter reads the overlays only for the dispatch sprites,
    // which the dispatch map below compares; the painter keeps no copy
    let text = chunk("XTXT");

    let altitude = chunk("ALTM");

    if altitude.len() == cells * 2 {
        if altitude_bytes.len() != altitude.len() {
            *altitude_bytes = vec![0; altitude.len()];
            painter.altitude.iter_mut().for_each(|word| *word = -1);
        }

        for (block, (words, cached)) in altitude.chunks(BLOCK * 2).zip(altitude_bytes.chunks_mut(BLOCK * 2)).enumerate() {
            if words == cached {
                continue;
            }

            cached.copy_from_slice(words);
            let start = block * BLOCK;

            for (offset, word) in words.chunks_exact(2).enumerate() {
                let value = i32::from(u16::from_be_bytes([word[0], word[1]]));
                let slot = &mut painter.altitude[start + offset];

                if *slot != value {
                    *slot = value;
                    changed.push(start + offset);
                }
            }
        }
    }

    let traffic = chunk("XTRF");

    if !traffic.is_empty() && painter.traffic != traffic && traffic.len() as i64 == city.decoded_size("XTRF") {
        let side = traffic.len().isqrt().max(1);
        let scale = (painter.edge as usize / side).max(1);
        let old = std::mem::replace(&mut painter.traffic, traffic.to_vec());

        for (block, (a, b)) in old.iter().zip(traffic).enumerate() {
            if old.len() != traffic.len() || traffic_band(*a) != traffic_band(*b) {
                let (bx, by) = (block / side * scale, block % side * scale);

                for x in bx..(bx + scale).min(painter.edge as usize) {
                    for y in by..(by + scale).min(painter.edge as usize) {
                        changed.push(x * painter.edge as usize + y);
                    }
                }
            }
        }
    }

    let dispatch = dispatch_sprites(chunk("XTHG"), text, painter.edge);

    for cell in painter.dispatch.keys().chain(dispatch.keys()) {
        if painter.dispatch.get(cell) != dispatch.get(cell) {
            changed.push(*cell);
        }
    }

    painter.dispatch = dispatch;

    changed
}

/// Traffic sprites change only at these density limits.
fn traffic_band(density: u8) -> usize {
    [28, 56, 85, 170].iter().filter(|limit| density > **limit).count()
}

/// The sprite offsets of the stationary dispatch units by map cell, as
/// `sc2k_render::City::set_dispatch` reads them from XTHG and XTXT.
pub fn dispatch_sprites(things: &[u8], text: &[u8], edge: i32) -> std::collections::HashMap<usize, i32> {
    use sc2k_sim::sim::{overlay, things as records};

    let mut result = std::collections::HashMap::new();

    // record zero has no dispatch sprite in the reference painter
    for record in 1..records::count(things) {
        let sprite = match records::field(things, record, records::FIELD_TYPE) {
            7 => 382,
            8 => 383,
            14 => 384,
            _ => continue,
        };
        let (x, y) = (
            records::field(things, record, records::FIELD_X),
            records::field(things, record, records::FIELD_Y),
        );

        if x >= i64::from(edge) || y >= i64::from(edge) {
            continue;
        }

        let cell = x * i64::from(edge) + y;

        if overlay::read(text, cell) == overlay::thing_id(record) {
            result.insert(cell as usize, sprite);
        }
    }

    result
}
