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

    /// Unscaled rectangles of the foreground commands that differ from `before`.
    #[func]
    fn changed_foreground(&self, before: Gd<NativeCityRegionDraws>) -> Array<Rect2i> {
        let changed = self.draws.changed(&before.bind().draws);
        changed.iter().map(|r| Rect2i::from_components(r.x, r.y, r.w, r.h)).collect()
    }
}
