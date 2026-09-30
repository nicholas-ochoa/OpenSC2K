//! Immutable draw list of one published region. A bucket grid answers pixel
//! and foreground queries without a Godot object for each draw.
use super::{Draw, Rect};
use std::collections::HashMap;

const CELL: i32 = 64;

#[derive(Default)]
pub struct RegionDraws {
    pub draws: Vec<Draw>,
    origin: (i32, i32),
    columns: i32,
    rows: i32,
    // Compressed rows: draws of cell n are entries[starts[n]..starts[n + 1]].
    starts: Vec<u32>,
    entries: Vec<u32>,
}

impl RegionDraws {
    pub fn new(draws: Vec<Draw>) -> Self {
        let rects: Vec<Rect> = draws.iter().map(|d| d.rect).filter(|r| r.area()).collect();

        if rects.is_empty() {
            return Self {
                draws,
                ..Default::default()
            };
        }

        let left = rects.iter().map(|r| r.x).min().unwrap().div_euclid(CELL);
        let top = rects.iter().map(|r| r.y).min().unwrap().div_euclid(CELL);
        let right = rects.iter().map(|r| r.x + r.w - 1).max().unwrap().div_euclid(CELL);
        let bottom = rects.iter().map(|r| r.y + r.h - 1).max().unwrap().div_euclid(CELL);
        let mut index = Self {
            origin: (left, top),
            columns: right - left + 1,
            rows: bottom - top + 1,
            ..Default::default()
        };

        let cells = (index.columns * index.rows) as usize;
        let mut counts = vec![0_u32; cells + 1];

        for draw in &draws {
            index.each_cell(draw.rect, |cell| counts[cell + 1] += 1);
        }

        for n in 0..cells {
            counts[n + 1] += counts[n];
        }

        let mut next = counts.clone();
        let mut entries = vec![0; counts[cells] as usize];

        for (at, draw) in draws.iter().enumerate() {
            index.each_cell(draw.rect, |cell| {
                entries[next[cell] as usize] = at as u32;
                next[cell] += 1;
            });
        }

        index.starts = counts;
        index.entries = entries;
        index.draws = draws;
        index
    }

    fn each_cell(&self, rect: Rect, mut visit: impl FnMut(usize)) {
        if !rect.area() || self.columns == 0 {
            return;
        }

        let x0 = (rect.x.div_euclid(CELL) - self.origin.0).max(0);
        let y0 = (rect.y.div_euclid(CELL) - self.origin.1).max(0);
        let x1 = ((rect.x + rect.w - 1).div_euclid(CELL) - self.origin.0).min(self.columns - 1);
        let y1 = ((rect.y + rect.h - 1).div_euclid(CELL) - self.origin.1).min(self.rows - 1);

        for y in y0..=y1 {
            for x in x0..=x1 {
                visit((y * self.columns + x) as usize);
            }
        }
    }
    /// Draw indices in painter order whose rectangles, multiplied by `scale`,
    /// intersect `bounds`. `occluders` keeps only foreground commands.
    pub fn candidates(&self, bounds: Rect, scale: i32, occluders: bool) -> Vec<u32> {
        let scale = scale.max(1);

        if !bounds.area() {
            return Vec::new();
        }

        let first = (bounds.x.div_euclid(scale), bounds.y.div_euclid(scale));
        let last = (
            (bounds.x + bounds.w - 1).div_euclid(scale),
            (bounds.y + bounds.h - 1).div_euclid(scale),
        );
        let native = Rect::new(first.0, first.1, last.0 - first.0 + 1, last.1 - first.1 + 1);
        let mut found = Vec::new();
        self.each_cell(native, |cell| {
            found.extend_from_slice(&self.entries[self.starts[cell] as usize..self.starts[cell + 1] as usize]);
        });

        found.sort_unstable();
        found.dedup();
        found.retain(|&at| {
            let d = &self.draws[at as usize];
            let r = Rect::new(d.rect.x * scale, d.rect.y * scale, d.rect.w * scale, d.rect.h * scale);
            (!occluders || d.depth >= 0) && r.clip(bounds).area()
        });

        found
    }

    /// Native rectangles of the foreground commands that differ from `before`.
    pub fn changed(&self, before: &Self) -> Vec<Rect> {
        let mut previous: HashMap<i64, &Draw> = before.draws.iter().filter(|d| d.depth >= 0).map(|d| (d.order, d)).collect();
        let mut result = Vec::new();

        for draw in self.draws.iter().filter(|d| d.depth >= 0) {
            if let Some(old) = previous.remove(&draw.order) {
                if same_command(old, draw) {
                    continue;
                }

                result.push(old.rect);
            }

            result.push(draw.rect);
        }

        let mut removed: Vec<&Draw> = previous.into_values().collect();
        removed.sort_unstable_by_key(|d| d.order);
        result.extend(removed.iter().map(|d| d.rect));
        result
    }
}

fn same_command(a: &Draw, b: &Draw) -> bool {
    a.sprite == b.sprite
        && a.flip == b.flip
        && a.rect == b.rect
        && a.depth == b.depth
        && a.ignore == b.ignore
        && a.reference == b.reference
        && a.thickness == b.thickness
        && a.deck == b.deck
        && a.requires_depth == b.requires_depth
}
