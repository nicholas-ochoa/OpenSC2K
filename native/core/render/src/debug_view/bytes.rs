//! Byte differences of two copies of a chunk, for the chunk browser.

/// The offsets of the first `limit` differing bytes, and the count of all of
/// them. Bytes past the end of the shorter copy count as different.
pub fn differences(before: &[u8], after: &[u8], limit: usize) -> (Vec<i32>, usize) {
    let shared = before.len().min(after.len());
    let mut offsets = Vec::new();
    let mut count = before.len().max(after.len()) - shared;

    for (offset, (a, b)) in before[..shared].iter().zip(&after[..shared]).enumerate() {
        if a == b {
            continue;
        }

        count += 1;

        if offsets.len() < limit {
            offsets.push(offset as i32);
        }
    }

    for offset in shared..before.len().max(after.len()) {
        if offsets.len() >= limit {
            break;
        }

        offsets.push(offset as i32);
    }

    (offsets, count)
}

/// The first index of each byte value in `data`, or -1 for a value that does
/// not occur. The Tile Counts table locates each building ID with it.
pub fn first_indices(data: &[u8]) -> Vec<i32> {
    let mut result = vec![-1_i32; 256];
    let mut missing = 256;

    for (index, value) in data.iter().enumerate() {
        let slot = &mut result[*value as usize];

        if *slot < 0 {
            *slot = index as i32;
            missing -= 1;

            if missing == 0 {
                break;
            }
        }
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn first_indices_name_the_first_tile_of_each_value() {
        let found = first_indices(&[7, 3, 7, 0, 3]);

        assert_eq!((found[7], found[3], found[0], found[1]), (0, 1, 3, -1));
    }

    #[test]
    fn differences_list_offsets_and_count_all() {
        let (offsets, count) = differences(&[1, 2, 3, 4], &[1, 9, 3, 8], 1);

        assert_eq!(offsets, vec![1]);
        assert_eq!(count, 2);
    }

    #[test]
    fn a_longer_copy_differs_at_its_extra_bytes() {
        let (offsets, count) = differences(&[1, 2], &[1, 2, 7, 7], 10);

        assert_eq!(offsets, vec![2, 3]);
        assert_eq!(count, 2);
    }

    #[test]
    fn equal_copies_have_no_differences() {
        assert_eq!(differences(&[5; 64], &[5; 64], 10), (Vec::new(), 0));
    }
}
