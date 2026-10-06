//! SCURK pixel edits and selection masks for GDScript.

use godot::prelude::*;
use sc2k_assets::scurk::{pixels, selection};

fn pair(value: Vector2i) -> (i64, i64) {
    (i64::from(value.x), i64::from(value.y))
}

fn ints(values: &[i32]) -> PackedInt32Array {
    PackedInt32Array::from(values)
}

/// SCURK pixel edits and selection masks.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeScurkPixels {}

#[godot_api]
impl NativeScurkPixels {
    /// `{width, height, pixels}` of a rectangle of the image.
    #[func]
    fn copy_region(source: PackedInt32Array, width: i64, height: i64, start: Vector2i, finish: Vector2i) -> VarDictionary {
        let region = pixels::copy_region(source.as_slice(), width, height, pair(start), pair(finish));
        let mut result = VarDictionary::new();
        result.set("width", region.width as i64);
        result.set("height", region.height as i64);
        result.set("pixels", &ints(&region.pixels));
        result
    }

    #[func]
    fn paste_region(
        target: PackedInt32Array,
        target_width: i64,
        target_height: i64,
        at: Vector2i,
        source: PackedInt32Array,
        source_width: i64,
        source_height: i64,
    ) -> PackedInt32Array {
        ints(&pixels::paste_region(
            target.as_slice(),
            target_width,
            target_height,
            pair(at),
            source.as_slice(),
            source_width,
            source_height,
        ))
    }

    #[func]
    fn rotate_counterclockwise(source: PackedInt32Array, width: i64, height: i64) -> PackedInt32Array {
        ints(&pixels::rotate_counterclockwise(source.as_slice(), width, height))
    }

    #[func]
    fn flip_horizontal(source: PackedInt32Array, width: i64, height: i64) -> PackedInt32Array {
        ints(&pixels::flip_horizontal(source.as_slice(), width, height))
    }

    #[func]
    fn flip_vertical(source: PackedInt32Array, width: i64, height: i64) -> PackedInt32Array {
        ints(&pixels::flip_vertical(source.as_slice(), width, height))
    }

    /// The 8 by 8 texture of eight row masks.
    #[func]
    fn pattern_pixels(rows: PackedByteArray) -> PackedInt32Array {
        match <[u8; 8]>::try_from(rows.as_slice()) {
            Ok(rows) => ints(&pixels::pattern_pixels(&rows)),
            Err(_) => PackedInt32Array::new(),
        }
    }

    #[func]
    #[allow(clippy::too_many_arguments)]
    fn flood_fill_texture(
        source: PackedInt32Array,
        width: i64,
        height: i64,
        start: Vector2i,
        selected_color: i64,
        pattern: PackedInt32Array,
        pattern_width: i64,
        pattern_height: i64,
    ) -> PackedInt32Array {
        let color = selected_color.clamp(i64::from(i32::MIN), i64::from(i32::MAX)) as i32;

        ints(&pixels::flood_fill_texture(
            source.as_slice(),
            width,
            height,
            pair(start),
            color,
            pattern.as_slice(),
            pattern_width,
            pattern_height,
        ))
    }

    #[func]
    fn texture_color(point: Vector2i, selected_color: i64, pattern: PackedInt32Array, pattern_width: i64, pattern_height: i64) -> i64 {
        i64::from(pixels::texture_color(
            pair(point),
            selected_color as i32,
            pattern.as_slice(),
            pattern_width,
            pattern_height,
        ))
    }

    #[func]
    fn resolve_texture_value(source: i64, selected_color: i64) -> i64 {
        i64::from(pixels::resolve_texture_value(
            source.clamp(i64::from(i32::MIN), i64::from(i32::MAX)) as i32,
            selected_color as i32,
        ))
    }

    /// The points of a line as flat x, y pairs.
    #[func]
    fn line_points(start: Vector2i, finish: Vector2i) -> PackedInt64Array {
        pixels::line_points(pair(start), pair(finish))
            .into_iter()
            .flat_map(|(x, y)| [x, y])
            .collect()
    }

    /// A path of flat x, y pairs without its L-shaped corner pixels.
    #[func]
    fn pixel_perfect_path(points: PackedInt64Array) -> PackedInt64Array {
        let points: Vec<(i64, i64)> = points.as_slice().chunks_exact(2).map(|pair| (pair[0], pair[1])).collect();

        pixels::pixel_perfect_path(&points).into_iter().flat_map(|(x, y)| [x, y]).collect()
    }

    #[func]
    fn rectangle_mask(width: i64, height: i64, start: Vector2i, finish: Vector2i) -> PackedByteArray {
        PackedByteArray::from(selection::rectangle(width, height, pair(start), pair(finish)).as_slice())
    }

    #[func]
    fn wand_mask(source: PackedInt32Array, width: i64, height: i64, start: Vector2i) -> PackedByteArray {
        PackedByteArray::from(selection::wand(source.as_slice(), width, height, pair(start)).as_slice())
    }

    #[func]
    fn translated_mask(mask: PackedByteArray, width: i64, height: i64, delta: Vector2i) -> PackedByteArray {
        PackedByteArray::from(selection::translated(mask.as_slice(), width, height, pair(delta)).as_slice())
    }

    #[func]
    fn combine_masks(mask: PackedByteArray, value: PackedByteArray, mode: i64) -> PackedByteArray {
        PackedByteArray::from(selection::combine(mask.as_slice(), value.as_slice(), mode).as_slice())
    }

    #[func]
    fn mask_bounds(mask: PackedByteArray, width: i64, height: i64) -> Rect2i {
        let [x, y, w, h] = selection::bounds(mask.as_slice(), width, height);

        Rect2i::new(Vector2i::new(x as i32, y as i32), Vector2i::new(w as i32, h as i32))
    }
}
