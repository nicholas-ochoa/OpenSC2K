//! Godot classes of the codecs. Results are dictionaries with `ok` and `error`,
//! plus the fields of each codec. The GDScript wrappers make result objects.

mod bmp;
mod crc32;
mod gif;
mod pe;
mod png;
mod sprite;
mod zip;

use godot::{
    classes::{Image, image::Format},
    prelude::*,
};

fn failure(error: &str) -> VarDictionary {
    let mut result = VarDictionary::new();
    result.set("ok", false);
    result.set("error", error);
    result
}

fn success() -> VarDictionary {
    let mut result = VarDictionary::new();
    result.set("ok", true);
    result.set("error", "");
    result
}

fn bytes(data: &[u8]) -> PackedByteArray {
    PackedByteArray::from(data)
}

fn ints(data: &[i32]) -> PackedInt32Array {
    PackedInt32Array::from(data)
}

fn rgba_image(width: usize, height: usize, rgba: &[u8]) -> Option<Gd<Image>> {
    Image::create_from_data(width as i32, height as i32, false, Format::RGBA8, &bytes(rgba))
}
