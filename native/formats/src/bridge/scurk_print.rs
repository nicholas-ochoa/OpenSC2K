//! The printable city of SCURK Place & Print for GDScript.

use godot::prelude::*;
use sc2k_assets::scurk::print::{self, Page};

/// The printable city of SCURK Place & Print.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeScurkPrint {}

#[godot_api]
impl NativeScurkPrint {
    /// The x, y, width, and height of each selected page, flat; empty when a
    /// page is outside the grid.
    #[func]
    fn page_regions(width: i64, height: i64, columns: i64, rows: i64, selected: PackedInt32Array) -> PackedInt64Array {
        let selected: Vec<i64> = selected.as_slice().iter().map(|&page| i64::from(page)).collect();

        match print::page_regions(width, height, columns, rows, &selected) {
            Some(regions) => regions.into_iter().flatten().collect(),
            None => PackedInt64Array::new(),
        }
    }

    /// A grayscale copy of RGBA8 pixels.
    #[func]
    fn monochrome(rgba: PackedByteArray) -> PackedByteArray {
        PackedByteArray::from(print::monochrome(rgba.as_slice()).as_slice())
    }

    /// The PDF document of the page JPEG images and their sizes.
    #[func]
    fn pdf(jpegs: VarArray, widths: PackedInt64Array, heights: PackedInt64Array) -> PackedByteArray {
        let images: Vec<PackedByteArray> = jpegs
            .iter_shared()
            .map(|image| image.try_to::<PackedByteArray>().unwrap_or_default())
            .collect();
        let pages: Vec<Page> = images
            .iter()
            .zip(widths.as_slice().iter().zip(heights.as_slice()))
            .map(|(jpeg, (&width, &height))| Page {
                jpeg: jpeg.as_slice(),
                width,
                height,
            })
            .collect();

        PackedByteArray::from(print::pdf(&pages).as_slice())
    }
}
