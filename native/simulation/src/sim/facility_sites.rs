//! The map footprint of each MicroSim record, as CityRecords.microsim_sites.
//! XMIC stores no position, so the footprint comes from the XTXT tiles that
//! name the record. A moving thing over a facility tile keeps the facility in
//! its saved label, so the scan follows the things on a tile.

use super::{overlay, things};

/// Values in each record of the result: min x, min y, max x, max y and tiles.
pub const BOUNDS: usize = 5;
const FIRST_FACILITY_ID: i64 = 51;
const THING_X: i64 = 3;
const THING_Y: i64 = 4;
const THING_LABEL: i64 = 10;

/// The bounds of each of `records` MicroSim records. A record with no tile has
/// a tile count of 0.
pub fn bounds(overlays: &[u8], thing_data: &[u8], edge: i64, records: usize) -> Vec<i32> {
    let cells = edge * edge;
    let mut result = vec![0_i32; records * BOUNDS];

    if edge <= 0 || overlays.len() < cells as usize {
        return result;
    }

    let layered = overlay::is_layered(overlays);
    let wide = overlays.len() as i64 != cells;
    let thing_records = things::count(thing_data);

    for index in 0..cells {
        let mut id = if layered {
            overlay::facility(overlays, index)
        } else if wide {
            i64::from(overlays[index as usize]) | i64::from(overlays[(cells + index) as usize]) << 8
        } else {
            i64::from(overlays[index as usize])
        };

        if id < FIRST_FACILITY_ID {
            continue;
        }

        let (x, y) = (index / edge, index % edge);
        let mut hops = 0;

        // the label under a moving thing on its own tile names the facility
        while overlay::is_thing(id) && hops < thing_records {
            let record = overlay::thing_record(id);

            if record <= 0
                || record >= thing_records
                || things::field(thing_data, record, 0) == 0
                || things::field(thing_data, record, THING_X) != x
                || things::field(thing_data, record, THING_Y) != y
            {
                break;
            }

            id = things::field(thing_data, record, THING_LABEL);
            hops += 1;
        }

        if !overlay::is_facility(id) {
            continue;
        }

        let record = overlay::facility_record(id);

        if record < 0 || record as usize >= records {
            continue;
        }

        add(
            &mut result[record as usize * BOUNDS..(record as usize + 1) * BOUNDS],
            x as i32,
            y as i32,
        );
    }

    result
}

fn add(bounds: &mut [i32], x: i32, y: i32) {
    if bounds[4] == 0 {
        bounds[..4].copy_from_slice(&[x, y, x, y]);
    } else {
        bounds[0] = bounds[0].min(x);
        bounds[1] = bounds[1].min(y);
        bounds[2] = bounds[2].max(x);
        bounds[3] = bounds[3].max(y);
    }

    bounds[4] += 1;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn narrow_overlays_give_each_record_its_footprint() {
        let edge = 8;
        let mut overlays = vec![0_u8; 64];

        // record 2 covers a 2 x 2 site at (3, 4)
        for (x, y) in [(3, 4), (3, 5), (4, 4), (4, 5)] {
            overlays[(x * edge + y) as usize] = (overlay::facility_id(2)) as u8;
        }

        let bounds = bounds(&overlays, &[], edge, 4);

        assert_eq!(&bounds[2 * BOUNDS..3 * BOUNDS], &[3, 4, 4, 5, 4]);
        assert_eq!(bounds[BOUNDS + 4], 0, "record 1 has no tile");
    }

    #[test]
    fn signs_and_markers_name_no_record() {
        let mut overlays = vec![0_u8; 16];
        overlays[0] = 12;
        overlays[1] = 0xfa;

        assert!(bounds(&overlays, &[], 4, 150).iter().all(|value| *value == 0));
    }
}
