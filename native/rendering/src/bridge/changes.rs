//! Changed screen areas between two revisions of the region source chunks.

use super::super::{Rect, changes};
use super::{int, ints};
use godot::prelude::*;

/// Changed screen areas between two revisions of the region source chunks.
/// See `changes.rs`.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeCityChanges {}
#[godot_api]
impl NativeCityChanges {
    /// `request` has `edge`, `visible`, `rotation`, `view` (tile width and height,
    /// half width and height, altitude step, side and top margins), `output`,
    /// `sprite_limit`, `building_sprites`, `object_overrides`, and `before` and
    /// `after` chunk dictionaries. Returns `{ok, rects}`; `rects` holds x, y, width
    /// and height of each rectangle. `ok` is false when a full redraw is better.
    #[func]
    fn changed_rects(request: VarDictionary) -> VarDictionary {
        let chunk_data = |side: &str| {
            let chunks = request.get(side).and_then(|v| v.try_to::<VarDictionary>().ok()).unwrap_or_default();

            // Borrow the Godot arrays; a large map holds megabytes per chunk.
            ["ALTM", "XBLD", "XTER", "XZON", "XBIT", "XUND", "XTXT", "XTRF"]
                .map(|id| chunks.get(id).and_then(|v| v.try_to::<PackedByteArray>().ok()).unwrap_or_default())
        };

        let (before_arrays, after_arrays) = (chunk_data("before"), chunk_data("after"));
        let before: [&[u8]; 8] = std::array::from_fn(|i| before_arrays[i].as_slice());
        let after: [&[u8]; 8] = std::array::from_fn(|i| after_arrays[i].as_slice());
        let view = ints(&request, "view");
        let limit = request
            .get("sprite_limit")
            .and_then(|v| v.try_to::<Vector2i>().ok())
            .unwrap_or_default();
        let output = request.get("output").and_then(|v| v.try_to::<Vector2i>().ok()).unwrap_or_default();
        let edge = int(&request, "edge", 0).max(0) as usize;
        let sprites = ints(&request, "building_sprites");
        let overrides = ints(&request, "object_overrides");
        let mut result = VarDictionary::new();
        let cells = edge * edge;
        let valid = view.len() == 7
            && edge > 0
            && after[0].len() == cells * 2
            && after[1..5].iter().all(|data| data.len() == cells)
            && before.iter().zip(&after).all(|(old, new)| old.len() == new.len());
        if !valid {
            result.set("ok", false);
            result.set("rects", &PackedInt32Array::new());

            return result;
        }

        let found = changes::changed_rects(&changes::Request {
            edge,
            visible: int(&request, "visible", 32) as i32,
            rotation: int(&request, "rotation", 0) as usize,
            view: changes::View {
                tile_width: view[0],
                tile_height: view[1],
                half_width: view[2],
                half_height: view[3],
                altitude_step: view[4],
                side_margin: view[5],
                top_margin: view[6],
            },
            output: Rect::new(0, 0, output.x, output.y),
            sprite_limit: (limit.x, limit.y),
            building_sprites: &sprites,
            object_overrides: &overrides,
            before: changes::Chunks::from_planes(before),
            after: changes::Chunks::from_planes(after),
        });

        result.set("ok", found.is_some());
        let flat: Vec<i32> = found.unwrap_or_default().iter().flat_map(|r| [r.x, r.y, r.w, r.h]).collect();
        result.set("rects", &PackedInt32Array::from(flat.as_slice()));
        result
    }
}
