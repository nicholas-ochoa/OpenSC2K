//! Godot classes of the view queries: rectangle indices and region plans.

use super::super::{Rect, rect_index::RectIndex, region_plan};
use godot::prelude::*;

/// Rectangles in a bucket grid, for occlusion queries.
#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct NativeRectIndex {
    base: Base<RefCounted>,
    index: RectIndex,
}

#[godot_api]
impl IRefCounted for NativeRectIndex {
    fn init(base: Base<RefCounted>) -> Self {
        Self {
            base,
            index: RectIndex::new(Vec::new(), 1),
        }
    }
}

#[godot_api]
impl NativeRectIndex {
    /// An index of `rects`, which holds x, y, width and height of each rectangle,
    /// scaled by `scale`, in cells of `cell` pixels.
    #[func]
    fn build(rects: PackedInt32Array, scale: i64, cell: i64) -> Gd<NativeRectIndex> {
        let scale = scale.max(1) as i32;
        let list = rects
            .as_slice()
            .chunks_exact(4)
            .map(|r| Rect::new(r[0] * scale, r[1] * scale, r[2] * scale, r[3] * scale))
            .collect();

        Gd::from_init_fn(|base| Self {
            base,
            index: RectIndex::new(list, cell as i32),
        })
    }

    /// The indices of the rectangles in the cells that `bounds` touches, ascending.
    #[func]
    fn candidates(&self, bounds: Rect2i) -> PackedInt32Array {
        let rect = Rect::new(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y);

        self.index.candidates(rect).iter().map(|&at| at as i32).collect()
    }

    #[func]
    fn is_empty(&self) -> bool {
        self.index.len() == 0
    }
}

/// Region plans of the city view. See `region_plan.rs`.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeRegionPlan {}

#[godot_api]
impl NativeRegionPlan {
    /// `{visible, nearby}`: region keys in drawing order. `viewport` is in native
    /// pixels inside `image_size`; `movement` is the travel since the last plan.
    #[func]
    fn plan(viewport: Rect2i, image_size: Vector2i, edge: i64, gpu: bool, movement: Vector2) -> VarDictionary {
        let plan = region_plan::plan(&region_plan::Viewport {
            rect: Rect::new(viewport.position.x, viewport.position.y, viewport.size.x, viewport.size.y),
            size: (image_size.x, image_size.y),
            edge: edge as i32,
            gpu,
            movement: (movement.x, movement.y),
        });

        let keys = |list: &[(i32, i32)]| -> Array<Vector2i> { list.iter().map(|&(x, y)| Vector2i::new(x, y)).collect() };

        let mut result = VarDictionary::new();
        result.set("visible", &keys(&plan.visible));
        result.set("nearby", &keys(&plan.nearby));
        result
    }

    /// The keys of the regions that the rectangles touch.
    #[func]
    fn keys_for(rects: Array<Rect2i>, edge: i64) -> Array<Vector2i> {
        let list: Vec<Rect> = rects
            .iter_shared()
            .map(|r| Rect::new(r.position.x, r.position.y, r.size.x, r.size.y))
            .collect();

        region_plan::keys_for(&list, edge as i32)
            .iter()
            .map(|&(x, y)| Vector2i::new(x, y))
            .collect()
    }
}
