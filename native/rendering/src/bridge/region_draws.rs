//! The published draws of one region. A region's draw index is immutable, so
//! the main thread may read it later.

use super::super::{Rect, index::RegionDraws};
use godot::prelude::*;

/// The published draws of one region. Queries return indices of `records`.
#[derive(GodotClass)]
#[class(base=RefCounted, no_init)]
pub struct NativeCityRegionDraws {
    pub(super) draws: RegionDraws,
}

#[godot_api]
impl NativeCityRegionDraws {
    /// Draw indices in painter order that intersect `bounds`, with draw
    /// rectangles multiplied by `scale`. `occluders` omits masked traffic.
    #[func]
    fn candidates(&self, bounds: Rect2i, scale: i64, occluders: bool) -> PackedInt32Array {
        let bounds = Rect::new(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y);
        let found = self.draws.candidates(bounds, scale as i32, occluders);
        found.iter().map(|&at| at as i32).collect()
    }

    /// Line segments of the draw rectangles that intersect `bounds`, scaled by
    /// `scale`, as point pairs for `draw_multiline`. `occluders` keeps only
    /// foreground commands. At most `limit` rectangles return.
    #[func]
    fn outline_segments(&self, bounds: Rect2i, scale: i64, occluders: bool, limit: i64) -> PackedVector2Array {
        let bounds = Rect::new(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y);
        let rects = self.draws.outlines(bounds, scale as i32, occluders, limit.max(0) as usize);
        let mut segments = PackedVector2Array::new();

        for rect in rects {
            let (left, top) = (rect.x as f32, rect.y as f32);
            let (right, bottom) = ((rect.x + rect.w) as f32, (rect.y + rect.h) as f32);
            let corners = [
                Vector2::new(left, top),
                Vector2::new(right, top),
                Vector2::new(right, bottom),
                Vector2::new(left, bottom),
            ];

            for side in 0..4 {
                segments.push(corners[side]);
                segments.push(corners[(side + 1) % 4]);
            }
        }

        segments
    }

    /// Rows of painter index, center x, center y and depth of the draws that
    /// intersect `bounds`, scaled by `scale`. At most `limit` draws return.
    #[func]
    fn draw_labels(&self, bounds: Rect2i, scale: i64, limit: i64) -> PackedInt32Array {
        let bounds = Rect::new(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y);
        let mut rows = PackedInt32Array::new();

        for (index, rect) in self.draws.labels(bounds, scale as i32, limit.max(0) as usize) {
            let depth = self.draws.draws[index as usize].depth;
            rows.extend([
                index as i32,
                rect.x + rect.w / 2,
                rect.y + rect.h / 2,
                depth.clamp(-1, i32::MAX as i64) as i32,
            ]);
        }

        rows
    }

    #[constant]
    const LABEL_ROW: i32 = 4;

    /// Unscaled rectangles of the foreground commands that differ from `before`.
    #[func]
    fn changed_foreground(&self, before: Gd<NativeCityRegionDraws>) -> Array<Rect2i> {
        let changed = self.draws.changed(&before.bind().draws);
        changed.iter().map(|r| Rect2i::from_components(r.x, r.y, r.w, r.h)).collect()
    }
}
