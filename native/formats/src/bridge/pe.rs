//! Resources of 32-bit Windows executables.

use super::{bytes, failure, ints, rgba_image, success};
use godot::{
    classes::{Image, image::Format},
    prelude::*,
};
use sc2k_formats::pe;

/// Resources of 32-bit Windows executables. Each call takes the file bytes.
/// See `pe.rs`.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativePeResources {}
impl NativePeResources {
    fn name(value: &Variant) -> Option<(Option<u32>, String)> {
        if let Ok(id) = value.try_to::<i64>() {
            return u32::try_from(id)
                .ok()
                .filter(|id| *id <= 0xffff)
                .map(|id| (Some(id), String::new()));
        }

        value.try_to::<GString>().ok().map(|text| (None, text.to_string()))
    }

    fn dib_fields(result: &mut VarDictionary, dib: &[u8]) {
        let header = pe::dib_header(dib);
        result.set("bytes", &bytes(dib));
        result.set("width", i64::from(header.width));
        result.set("height", i64::from(header.height));
        result.set("bits_per_pixel", i64::from(header.bits_per_pixel));
        result.set("compression", i64::from(header.compression));
        result.set("color_count", i64::from(header.color_count));
    }

    fn indexed_fields(result: &mut VarDictionary, image: &pe::Indexed) {
        result.set("width", image.width as i64);
        result.set("height", image.height as i64);
        result.set("pixels", &ints(&image.pixels));
    }

    fn with_bitmap(data: &PackedByteArray, name: &Variant, use_dib: impl FnOnce(&[u8], &pe::Name) -> VarDictionary) -> VarDictionary {
        let Some((id, text)) = Self::name(name) else {
            return failure("bitmap resource ID is outside the valid range");
        };

        let name = id.map_or(pe::Name::Text(&text), pe::Name::Id);

        if matches!(name, pe::Name::Text("")) {
            return failure("bitmap resource name is empty");
        }

        let directory = match pe::Directory::open(data.as_slice()) {
            Ok(directory) => directory,
            Err(error) => return failure(&error),
        };

        match directory.bitmap(&name) {
            Ok(dib) => use_dib(dib, &name),
            Err(error) => failure(&error),
        }
    }
}

#[godot_api]
impl NativePeResources {
    /// An empty string when the file has a readable resource directory, else the error.
    #[func]
    fn directory_error(data: PackedByteArray) -> GString {
        GString::from(&pe::Directory::open(data.as_slice()).err().unwrap_or_default())
    }

    /// `{ok, error, pixels, consumed}`: BI_RLE8 data as top-down palette indices.
    #[func]
    fn decode_rle8(data: PackedByteArray, width: i64, height: i64) -> VarDictionary {
        if !(1..=4096).contains(&width) || !(1..=4096).contains(&height) {
            return failure("RLE8 dimensions must be 1 through 4096");
        }

        match pe::decode_rle8(data.as_slice(), width as usize, height as usize) {
            Ok((pixels, consumed)) => {
                let mut result = success();
                result.set("pixels", &ints(&pixels));
                result.set("consumed", consumed as i64);
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// The file offset of a relative virtual address, or -1.
    #[func]
    fn rva_offset(data: PackedByteArray, rva: i64) -> i64 {
        pe::Directory::open(data.as_slice()).ok().and_then(|d| d.offset(rva)).unwrap_or(-1)
    }

    /// `{ok, error, width, height, pixels}` of an 8-bit uncompressed or RLE8 DIB.
    /// `name` names the resource in errors.
    #[func]
    fn dib_indexed8(dib: PackedByteArray, name: Variant) -> VarDictionary {
        let text = name.to_string();

        match pe::decode_indexed8(dib.as_slice(), &pe::Name::Text(&text)) {
            Ok(image) => {
                let mut result = success();
                Self::indexed_fields(&mut result, &image);
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// `{ok, error, ids}`: the numeric bitmap IDs in ascending order.
    #[func]
    fn bitmap_ids(data: PackedByteArray) -> VarDictionary {
        match pe::Directory::open(data.as_slice()).and_then(|d| d.bitmap_ids()) {
            Ok(ids) => {
                let mut result = success();
                result.set("ids", &ints(&ids));
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// `{ok, error, bytes, width, height, bits_per_pixel, compression, color_count}`.
    /// `name` is a numeric ID or a resource name.
    #[func]
    fn bitmap_dib(data: PackedByteArray, name: Variant) -> VarDictionary {
        Self::with_bitmap(&data, &name, |dib, _| {
            let mut result = success();
            Self::dib_fields(&mut result, dib);
            result
        })
    }

    /// `{ok, error, width, height, pixels}` of an 8-bit uncompressed or RLE8 bitmap.
    #[func]
    fn bitmap_indexed8(data: PackedByteArray, name: Variant) -> VarDictionary {
        Self::with_bitmap(&data, &name, |dib, name| match pe::decode_indexed8(dib, name) {
            Ok(image) => {
                let mut result = success();
                Self::indexed_fields(&mut result, &image);
                result
            }
            Err(error) => failure(&error),
        })
    }

    /// `{ok, error, entries}`: indexed images of many bitmaps. The first failure stops the batch.
    #[func]
    fn bitmaps_indexed8(data: PackedByteArray, ids: PackedInt32Array) -> VarDictionary {
        let directory = match pe::Directory::open(data.as_slice()) {
            Ok(directory) => directory,
            Err(error) => return failure(&error),
        };

        let mut entries = VarArray::new();

        for id in ids.as_slice() {
            let Ok(id) = u32::try_from(*id)
                .map_err(|_| ())
                .and_then(|id| if id <= 0xffff { Ok(id) } else { Err(()) })
            else {
                return failure("bitmap resource ID is outside the valid range");
            };

            let name = pe::Name::Id(id);

            match directory.bitmap(&name).and_then(|dib| pe::decode_indexed8(dib, &name)) {
                Ok(image) => {
                    let mut entry = success();
                    Self::indexed_fields(&mut entry, &image);
                    entries.push(&entry.to_variant());
                }
                Err(error) => return failure(&error),
            }
        }

        let mut result = success();
        result.set("entries", &entries);
        result
    }

    /// `{ok, error, image}`: the bitmap decoded by Godot. RLE8 rows are expanded first.
    #[func]
    fn bitmap_image(data: PackedByteArray, name: Variant) -> VarDictionary {
        Self::with_bitmap(&data, &name, |dib, name| {
            let mut owned = dib.to_vec();

            if pe::dib_header(dib).compression == pe::RLE8 {
                match pe::decode_indexed8(dib, name) {
                    Ok(image) => owned = pe::expand_rle8_dib(dib, &image),
                    Err(error) => return failure(&error),
                }
            }

            let wrapped = match pe::wrap_dib(&owned) {
                Ok(wrapped) => wrapped,
                Err(error) => return failure(&error),
            };

            let mut image = Image::new_gd();
            let error = image.load_bmp_from_buffer(&bytes(&wrapped));

            if error != godot::global::Error::OK {
                return failure(&format!(
                    "cannot decode PE bitmap resource {name}: {}",
                    godot::global::error_string(i64::from(error.ord()))
                ));
            }

            let mut result = success();
            result.set("image", &image);
            result
        })
    }

    /// `{ok, error, width, height, pixels}` of a 4-bit uncompressed DIB.
    #[func]
    fn dib_indexed4(dib: PackedByteArray) -> VarDictionary {
        match pe::decode_indexed4(dib.as_slice()) {
            Ok(image) => {
                let mut result = success();
                Self::indexed_fields(&mut result, &image);
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// `{ok, error, bytes}` of an icon (3), cursor (1), icon group (14) or cursor group (12).
    #[func]
    fn icon_resource(data: PackedByteArray, type_id: i64, id: i64) -> VarDictionary {
        if !(0..=65535).contains(&id) {
            return failure("Invalid icon/cursor resource ID or type");
        }

        match pe::Directory::open(data.as_slice()).and_then(|d| d.icon_resource(type_id.clamp(0, 255) as u32, id as u32)) {
            Ok(resource) => {
                let mut result = success();
                result.set("bytes", &bytes(resource));
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// `{ok, error, entries}`. Each entry is `[id, width, height, planes, bits, length]`.
    #[func]
    fn decode_icon_group(data: PackedByteArray, cursor: bool) -> VarDictionary {
        match pe::decode_group(data.as_slice(), cursor) {
            Ok(entries) => {
                let mut list = VarArray::new();

                for e in entries {
                    let values = PackedInt64Array::from([e.id, e.width, e.height, e.planes, e.bits, e.length].map(i64::from).as_slice());
                    list.push(&values.to_variant());
                }

                let mut result = success();
                result.set("entries", &list);
                result
            }
            Err(error) => failure(&error),
        }
    }
    /// `{ok, error, width, height, bits, hotspot, palette, pixels, and_mask,
    /// inverting_pixels, trailing_bytes}`. `palette` holds RGB colors.
    #[func]
    fn decode_icon(data: PackedByteArray, cursor: bool) -> VarDictionary {
        match pe::decode_icon(data.as_slice(), cursor) {
            Ok(icon) => {
                let mut result = success();
                result.set("width", icon.width as i64);
                result.set("height", icon.height as i64);
                result.set("bits", i64::from(icon.bits));
                result.set("hotspot", Vector2i::new(icon.hotspot.0 as i32, icon.hotspot.1 as i32));
                result.set("palette", &bytes(&icon.palette));
                result.set("pixels", &ints(&icon.pixels));
                result.set("and_mask", &bytes(&icon.and_mask));
                result.set("inverting_pixels", icon.inverting_pixels as i64);
                result.set("trailing_bytes", icon.trailing_bytes as i64);
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// An RGBA8 image: the AND mask makes pixels transparent. `palette` holds RGB colors.
    #[func]
    fn icon_transparent(
        width: i64,
        height: i64,
        pixels: PackedInt32Array,
        and_mask: PackedByteArray,
        palette: PackedByteArray,
    ) -> Option<Gd<Image>> {
        let valid = Self::valid_icon(width, height, &pixels, &and_mask, &palette);
        valid.then(|| {
            rgba_image(
                width as usize,
                height as usize,
                &pe::icon_transparent(pixels.as_slice(), and_mask.as_slice(), palette.as_slice()),
            )
        })?
    }

    /// An RGBA8 image of the icon over `background`, which has the icon's size.
    #[func]
    fn icon_composite(
        width: i64,
        height: i64,
        pixels: PackedInt32Array,
        and_mask: PackedByteArray,
        palette: PackedByteArray,
        background: Gd<Image>,
    ) -> Option<Gd<Image>> {
        if !Self::valid_icon(width, height, &pixels, &and_mask, &palette)
            || background.get_width() as i64 != width
            || background.get_height() as i64 != height
        {
            return None;
        }

        let mut backdrop = Image::create_from_data(
            background.get_width(),
            background.get_height(),
            false,
            background.get_format(),
            &background.get_data(),
        )?;
        backdrop.convert(Format::RGBA8);
        let rgba = pe::icon_composite(
            pixels.as_slice(),
            and_mask.as_slice(),
            palette.as_slice(),
            backdrop.get_data().as_slice(),
        );
        rgba_image(width as usize, height as usize, &rgba)
    }
}

impl NativePeResources {
    fn valid_icon(width: i64, height: i64, pixels: &PackedInt32Array, and_mask: &PackedByteArray, palette: &PackedByteArray) -> bool {
        let colors = palette.len() / 3;
        pixels.len() as i64 == width * height
            && and_mask.len() == pixels.len()
            && pixels.as_slice().iter().all(|p| (0..colors as i32).contains(p))
    }
}
