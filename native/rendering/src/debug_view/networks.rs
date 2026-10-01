//! Connected networks of one XBIT flag, such as the tiles that conduct power or
//! hold pipes. Tiles connect to their four side neighbors. The layer value of
//! a tile names its network: 1 to 127 for a network with no supplied tile, and
//! 128 to 255 for a network with a supplied tile.

/// The first layer value of a supplied network.
pub const SUPPLIED_BASE: u8 = 128;
const HUES: u32 = 127;

/// Network labels and the counts of the debug metrics.
#[derive(Default)]
pub struct Networks {
    pub values: Vec<u8>,
    pub count: usize,
    pub supplied: usize,
    pub largest: usize,
}

/// Label the networks of the tiles whose flags hold `member`. `supplied`
/// marks the tiles that receive the utility.
pub fn label(flags: &[u8], edge: usize, member: u8, supplied: u8) -> Networks {
    let cells = edge * edge;
    let mut result = Networks {
        values: vec![0; cells],
        ..Default::default()
    };

    if flags.len() < cells {
        return result;
    }

    let mut seen = vec![false; cells];
    let mut stack = Vec::new();
    let mut members = Vec::new();

    for start in 0..cells {
        if seen[start] || flags[start] & member == 0 {
            continue;
        }

        seen[start] = true;
        stack.push(start);
        members.clear();
        let mut has_supply = false;

        while let Some(i) = stack.pop() {
            members.push(i);
            has_supply |= flags[i] & supplied != 0;

            for near in neighbors(i, edge) {
                if !seen[near] && flags[near] & member != 0 {
                    seen[near] = true;
                    stack.push(near);
                }
            }
        }

        result.count += 1;
        result.largest = result.largest.max(members.len());
        result.supplied += usize::from(has_supply);
        let value = network_value(result.count, has_supply);

        for &i in &members {
            result.values[i] = value;
        }
    }

    result
}

/// A spread of hues, so that neighboring networks seldom share a color.
fn network_value(ordinal: usize, supplied: bool) -> u8 {
    let hue = (ordinal as u32).wrapping_mul(37) % HUES + 1;
    let base = if supplied { SUPPLIED_BASE } else { 0 };

    base + hue as u8
}

fn neighbors(i: usize, edge: usize) -> impl Iterator<Item = usize> {
    let (x, y) = (i / edge, i % edge);
    let left = (x > 0).then(|| i - edge);
    let right = (x + 1 < edge).then(|| i + edge);
    let up = (y > 0).then(|| i - 1);
    let down = (y + 1 < edge).then(|| i + 1);

    [left, right, up, down].into_iter().flatten()
}

#[cfg(test)]
mod tests {
    use super::*;

    const LINE: u8 = 0x80;
    const POWERED: u8 = 0x40;

    #[test]
    fn side_neighbors_join_one_network() {
        // two networks on a 3 x 3 map: an L in the top rows and one corner tile
        let flags = [LINE, LINE, 0, LINE, 0, 0, 0, 0, LINE | POWERED];
        let networks = label(&flags, 3, LINE, POWERED);

        assert_eq!(networks.count, 2);
        assert_eq!(networks.supplied, 1);
        assert_eq!(networks.largest, 3);
        assert_eq!(networks.values[0], networks.values[1]);
        assert_eq!(networks.values[0], networks.values[3]);
        assert!(networks.values[0] < SUPPLIED_BASE);
        assert!(networks.values[8] >= SUPPLIED_BASE);
        assert_eq!(networks.values[2], 0);
    }

    #[test]
    fn diagonal_tiles_do_not_connect() {
        let flags = [LINE, 0, 0, LINE];

        assert_eq!(label(&flags, 2, LINE, POWERED).count, 2);
    }

    #[test]
    fn values_stay_inside_their_half() {
        for ordinal in 1..1000 {
            let unsupplied = network_value(ordinal, false);
            let supplied = network_value(ordinal, true);

            assert!((1..SUPPLIED_BASE).contains(&unsupplied));
            assert!(supplied > SUPPLIED_BASE);
        }
    }
}
