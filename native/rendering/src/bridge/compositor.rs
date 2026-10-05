//! Moving sprite pixels.

use godot::{
    classes::{Image, image::Format},
    prelude::*,
};
use sc2k_render::compositing;

/// Moving sprite pixels. See `compositing.rs`. Sprite and mask images are RGBA8;
/// indexed city images may also be L8 or LA8.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeSpriteCompositor {}
struct ImageBytes {
    width: i32,
    height: i32,
    channels: usize,
    data: PackedByteArray,
}

impl ImageBytes {
    fn of(image: &Gd<Image>) -> Self {
        let channels = match image.get_format() {
            Format::L8 => 1,
            Format::LA8 => 2,
            Format::RGBA8 => 4,
            _ => 0,
        };

        if channels == 0 {
            let mut copy = Image::create_from_data(image.get_width(), image.get_height(), false, image.get_format(), &image.get_data())
                .expect("image of its own size");
            copy.convert(Format::RGBA8);

            return Self::of(&copy);
        }

        Self {
            width: image.get_width(),
            height: image.get_height(),
            channels,
            data: image.get_data(),
        }
    }

    fn pixels(&self) -> compositing::Pixels<'_> {
        compositing::Pixels {
            width: self.width,
            height: self.height,
            channels: self.channels,
            data: self.data.as_slice(),
        }
    }
}

fn rgba_image(width: i32, height: i32, data: &[u8]) -> Gd<Image> {
    Image::create_from_data(width, height, false, Format::RGBA8, &PackedByteArray::from(data)).expect("RGBA8 pixels of the given size")
}

#[godot_api]
impl NativeSpriteCompositor {
    /// The opaque sprite pixels that differ from `background`, whose bottom rows
    /// line up with the sprite's.
    #[func]
    fn foreground_difference_mask(sprite: Gd<Image>, background: Gd<Image>) -> Gd<Image> {
        let (a, b) = (ImageBytes::of(&sprite), ImageBytes::of(&background));
        rgba_image(a.width, a.height, &compositing::foreground_difference(&a.pixels(), &b.pixels()))
    }

    /// `{image, occluded_pixels}`: the sprite with the pixels under `mask` hidden, and
    /// the pixels whose `index_image` index is in `indices`. Sprite pixel (x, y)
    /// reads index pixel `index_origin + (x, y)`. An unchanged sprite returns itself.
    #[func]
    fn occlude(
        sprite: Gd<Image>,
        mask: Option<Gd<Image>>,
        index_image: Option<Gd<Image>>,
        index_origin: Vector2i,
        indices: PackedInt32Array,
    ) -> VarDictionary {
        let source = ImageBytes::of(&sprite);
        let mask = mask.as_ref().map(ImageBytes::of);
        let index_bytes = index_image.as_ref().filter(|_| !indices.is_empty()).map(ImageBytes::of);
        let index_source = index_bytes.as_ref().map(|image| compositing::IndexSource {
            image: image.pixels(),
            origin: (index_origin.x, index_origin.y),
            divisor: 1,
        });

        let mask_pixels = mask.as_ref().map(ImageBytes::pixels);
        let (visible, count) = compositing::occlude(
            &source.pixels(),
            mask_pixels.as_ref(),
            index_source.as_ref().map(|s| (s, indices.as_slice())),
        );
        let format = sprite.get_format();
        let image = visible.map_or(sprite, |data| {
            let mut image = rgba_image(source.width, source.height, &data);

            // A sprite in another format gets its own format back.
            if format != Format::RGBA8 {
                image.convert(format);
            }

            image
        });

        let mut result = VarDictionary::new();
        result.set("image", &image);
        result.set("occluded_pixels", count as i64);
        result
    }

    /// The shadow of a moving sprite over an indexed city image, or null when it
    /// changes no pixel. Mask pixel (x, y) lies on map pixel `position + (x, y) /
    /// factor`, which must be inside `limit`. `index_image` holds the whole map when
    /// `map_image` is set, else the area under the mask at the mask's size.
    #[func]
    fn moving_shadow(
        mask: Gd<Image>,
        occluder: Option<Gd<Image>>,
        index_image: Gd<Image>,
        map_image: bool,
        position: Vector2i,
        limit: Vector2i,
        factor: i64,
    ) -> Option<Gd<Image>> {
        let factor = factor.max(1) as i32;
        let mask_bytes = ImageBytes::of(&mask);
        let occluder = occluder.as_ref().map(ImageBytes::of);
        let index = ImageBytes::of(&index_image);
        let source = compositing::IndexSource {
            image: index.pixels(),
            origin: if map_image { (position.x, position.y) } else { (0, 0) },
            divisor: if map_image { factor } else { 1 },
        };

        let occluder_pixels = occluder.as_ref().map(ImageBytes::pixels);
        compositing::moving_shadow(
            &mask_bytes.pixels(),
            occluder_pixels.as_ref(),
            &source,
            (position.x, position.y),
            (limit.x, limit.y),
            factor,
        )
        .map(|data| rgba_image(mask_bytes.width, mask_bytes.height, &data))
    }

    /// A shadow sprite in palette colors over the indexed `city` image at
    /// `position`. `palette` holds 256 RGBA colors.
    #[func]
    fn palette_shadow(sprite: Gd<Image>, city: Gd<Image>, position: Vector2i, palette: PackedByteArray) -> Gd<Image> {
        let (sprite_bytes, city_bytes) = (ImageBytes::of(&sprite), ImageBytes::of(&city));

        if palette.len() != 1024 || sprite_bytes.channels != 4 {
            return sprite;
        }

        let data = compositing::palette_shadow(
            &sprite_bytes.pixels(),
            &city_bytes.pixels(),
            (position.x, position.y),
            palette.as_slice(),
        );
        rgba_image(sprite_bytes.width, sprite_bytes.height, &data)
    }

    /// Darkens the RGBA8 `output` under the opaque pixels of `mask` at
    /// `destination`. `shadow_colors` holds packed RGBA pairs; the first pair of a
    /// color wins.
    #[func]
    fn blend_shadow(mut output: Gd<Image>, mask: Gd<Image>, destination: Vector2i, shadow_colors: PackedInt32Array) {
        if output.get_format() != Format::RGBA8 {
            return;
        }

        let pairs: Vec<([u8; 4], [u8; 4])> = shadow_colors
            .as_slice()
            .chunks_exact(2)
            .map(|p| ((p[0] as u32).to_be_bytes(), (p[1] as u32).to_be_bytes()))
            .collect();
        let mask_bytes = ImageBytes::of(&mask);
        let (width, height) = (output.get_width(), output.get_height());
        let mut data = output.get_data().to_vec();
        compositing::blend_shadow(
            &mut data,
            width,
            height,
            &mask_bytes.pixels(),
            (destination.x, destination.y),
            &pairs,
        );
        output.set_data(width, height, false, Format::RGBA8, &PackedByteArray::from(data.as_slice()));
    }

    /// The parts of an indexed surface within `thickness` rows of its road deck.
    #[func]
    fn highway_train_deck_mask(surface: Gd<Image>, thickness: i64) -> Gd<Image> {
        let mut rgba = ImageBytes::of(&surface);

        if rgba.channels != 4 {
            let mut copy = Image::create_from_data(
                surface.get_width(),
                surface.get_height(),
                false,
                surface.get_format(),
                &surface.get_data(),
            )
            .expect("image of its own size");
            copy.convert(Format::RGBA8);
            rgba = ImageBytes::of(&copy);
        }

        rgba_image(
            rgba.width,
            rgba.height,
            &compositing::highway_deck_mask(&rgba.pixels(), thickness as i32),
        )
    }
}
