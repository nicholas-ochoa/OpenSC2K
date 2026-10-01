//! A bucket grid of rectangles. Occlusion queries ask which
//! rectangles meet an area; the answer lists their indices in ascending order.

use super::Rect;

pub struct RectIndex {
    cell: i32,
    rects: Vec<Rect>,
    buckets: std::collections::HashMap<(i32, i32), Vec<u32>>,
}

impl RectIndex {
    /// Indexes the rectangles with a positive area, in cells of `cell` pixels.
    pub fn new(rects: Vec<Rect>, cell: i32) -> Self {
        let cell = cell.max(1);
        let mut buckets: std::collections::HashMap<(i32, i32), Vec<u32>> = std::collections::HashMap::new();

        for (index, rect) in rects.iter().enumerate() {
            if !rect.area() {
                continue;
            }

            let (first, last) = cells(*rect, cell);

            for y in first.1..=last.1 {
                for x in first.0..=last.0 {
                    buckets.entry((x, y)).or_default().push(index as u32);
                }
            }
        }

        Self { cell, rects, buckets }
    }

    /// The indices of the rectangles in the cells that `bounds` touches, in
    /// ascending order. A candidate need not meet `bounds` itself.
    pub fn candidates(&self, bounds: Rect) -> Vec<u32> {
        if !bounds.area() || self.buckets.is_empty() {
            return Vec::new();
        }

        let (first, last) = cells(bounds, self.cell);
        let mut found = Vec::new();

        for y in first.1..=last.1 {
            for x in first.0..=last.0 {
                if let Some(bucket) = self.buckets.get(&(x, y)) {
                    found.extend_from_slice(bucket);
                }
            }
        }

        found.sort_unstable();
        found.dedup();
        found
    }

    pub fn len(&self) -> usize {
        self.rects.len()
    }
}

// The first and last cell of a rectangle.
fn cells(rect: Rect, cell: i32) -> ((i32, i32), (i32, i32)) {
    let first = (rect.x.div_euclid(cell), rect.y.div_euclid(cell));
    let last = ((rect.x + rect.w - 1).div_euclid(cell), (rect.y + rect.h - 1).div_euclid(cell));

    (first, last)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn candidates_come_from_touched_cells() {
        let rects = vec![
            Rect::new(0, 0, 10, 10),
            Rect::new(200, 0, 10, 10),
            Rect::new(-50, -5, 300, 10),
            Rect::new(5, 5, 0, 4),
        ];
        let index = RectIndex::new(rects, 128);

        assert_eq!(index.candidates(Rect::new(1, 1, 2, 2)), vec![0, 2]);
        assert_eq!(index.candidates(Rect::new(130, 0, 2, 2)), vec![1, 2]);
        assert_eq!(index.candidates(Rect::new(300, 0, 2, 2)), Vec::<u32>::new());

        // the empty rectangle is never a candidate, and empty bounds find nothing
        assert!(!index.candidates(Rect::new(0, 0, 128, 128)).contains(&3));
        assert!(index.candidates(Rect::new(0, 0, 0, 5)).is_empty());
        assert_eq!(index.len(), 4);
    }
}
