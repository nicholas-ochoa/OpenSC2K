//! The row order of the debug record tables. A table gives one sort key for
//! each row; equal keys keep their record order in both directions.

/// Row indices in key order. `descending` reverses the keys, not the order of
/// equal keys.
pub fn stable_order(keys: &[i64], descending: bool) -> Vec<i32> {
    let mut order: Vec<i32> = (0..keys.len() as i32).collect();

    order.sort_by(|&a, &b| {
        let (left, right) = (keys[a as usize], keys[b as usize]);
        let by_key = if descending { right.cmp(&left) } else { left.cmp(&right) };

        by_key.then(a.cmp(&b))
    });

    order
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn keys_sort_in_both_directions() {
        assert_eq!(stable_order(&[30, 10, 20], false), vec![1, 2, 0]);
        assert_eq!(stable_order(&[30, 10, 20], true), vec![0, 2, 1]);
    }

    #[test]
    fn equal_keys_keep_record_order() {
        assert_eq!(stable_order(&[5, 1, 5, 1], false), vec![1, 3, 0, 2]);
        assert_eq!(stable_order(&[5, 1, 5, 1], true), vec![0, 2, 1, 3]);
    }
}
