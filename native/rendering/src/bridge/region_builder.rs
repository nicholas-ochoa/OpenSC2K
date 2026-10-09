//! The region builder of the city view. Each builder belongs to one region
//! worker thread.

use super::region_draws::NativeCityRegionDraws;
use super::{bytes, int, ints};
use godot::{
    classes::{Image, image::Format},
    prelude::*,
};
use sc2k_render::{Builder, City, Config, Draw, Rect, index::RegionDraws, region::TILE_LIMIT, sprites, sprites::Sprite};

use std::collections::HashMap;

/// The decoded size limit of the animation strips of one view.
const MAX_ANIMATION_BYTES: usize = 128 * 1024 * 1024;

#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct NativeCityRegionBuilder {
    base: Base<RefCounted>,
    core: Option<Builder>,
    images: HashMap<u64, Gd<Image>>,
}

#[godot_api]
impl IRefCounted for NativeCityRegionBuilder {
    fn init(base: Base<RefCounted>) -> Self {
        Self {
            base,
            core: None,
            images: HashMap::new(),
        }
    }
}

// RGBA and LA pixels of a Godot image of any format.
fn sprite_from_image(image: &Gd<Image>) -> Result<Sprite, String> {
    let (w, h) = (image.get_width(), image.get_height());

    if w <= 0 || h <= 0 || w > 8190 || h > 8190 {
        return Err("invalid sprite dimensions".into());
    }

    let mut rgba = Image::create_from_data(w, h, false, image.get_format(), &image.get_data()).ok_or("invalid sprite pixels")?;
    rgba.convert(Format::RGBA8);
    let data = rgba.get_data().to_vec();
    let mut la = Image::create_from_data(w, h, false, Format::RGBA8, &rgba.get_data()).ok_or("invalid sprite pixels")?;
    la.convert(Format::LA8);
    Ok(Sprite {
        w,
        h,
        rgba: data,
        la: la.get_data().to_vec(),
    })
}

/// Reads the full-color art of the view from `request`:
///
/// - `hd_sprites`: sprite ID to RGBA image.
/// - `hd_heights`: sprite ID to the logical height of the art, when it is not
///   the height of the sprite.
/// - `hd_animations`: sprite ID to a strip of equal frames, top to bottom.
/// - `hd_frames`, `hd_fps`: sprite ID to the frame count and the frame rate.
///
/// A sprite with an animation shows the animation. The other images are still.
fn configure_artwork(core: &mut Builder, request: &VarDictionary) -> Result<(), String> {
    let dictionary = |name: &str| -> Result<Option<AnyDictionary>, String> {
        request
            .get(name)
            .map(|value| value.try_to::<AnyDictionary>().map_err(|_| format!("invalid {name}")))
            .transpose()
    };

    let Some(stills) = dictionary("hd_sprites")? else {
        return Ok(());
    };

    let heights = dictionary("hd_heights")?;
    let animations = dictionary("hd_animations")?;
    let frame_counts = dictionary("hd_frames")?;
    let frame_rates = dictionary("hd_fps")?;
    let entry = |dictionary: &Option<AnyDictionary>, id: i64| dictionary.as_ref().and_then(|d| d.get(id));
    let mut animation_bytes = 0_usize;

    for (key, value) in stills.iter_shared() {
        let id = key.try_to::<i64>().map_err(|_| "invalid HD sprite ID")?;
        let image_key = id as u64 * 2;

        let Some(original) = core.sprites.images.get(&image_key) else {
            return Err(format!("HD sprite {id} has no indexed sprite"));
        };

        let original_height = original.h;
        let height = match entry(&heights, id) {
            Some(value) => value.try_to::<i64>().map_err(|_| "invalid HD sprite height")? as i32,
            None => original_height,
        };

        if height < original_height || height > sprites::ATLAS_LIMIT {
            return Err(format!("HD sprite {id} is shorter than its indexed sprite"));
        }

        let (image, frames, fps) = match entry(&animations, id) {
            Some(strip) => {
                let frames = entry(&frame_counts, id)
                    .and_then(|value| value.try_to::<i64>().ok())
                    .ok_or("missing HD animation frame count")?;
                let fps = entry(&frame_rates, id).and_then(|value| value.try_to::<i64>().ok()).unwrap_or(8);

                if !(2..=32).contains(&frames) || ![5, 8].contains(&fps) {
                    return Err(format!("HD animation {id} needs 2 to 32 frames at 5 or 8 frames each second"));
                }

                let image = artwork_image(&strip)?;

                let padding = (frames as i32 + 1) * sprites::ARTWORK_PADDING * 2;

                if image.h % frames as i32 != 0 || image.h + padding > sprites::ATLAS_LIMIT {
                    return Err(format!("HD animation {id} has frames of different sizes or does not fit the atlas"));
                }

                animation_bytes += image.rgba.len();
                (image, frames as u8, fps as u8)
            }
            None => (artwork_image(&value)?, 1, 0),
        };

        if animation_bytes > MAX_ANIMATION_BYTES {
            return Err("HD animations use more than 128 MiB in one view".into());
        }

        core.sprite_limit.1 = core.sprite_limit.1.max(height);
        core.sprites.artwork.insert(
            image_key,
            sprites::Artwork {
                image,
                height,
                frames,
                fps,
            },
        );
    }

    Ok(())
}

/// The RGBA pixels of a full-color image.
fn artwork_image(value: &Variant) -> Result<Sprite, String> {
    let image = value.try_to::<Gd<Image>>().map_err(|_| "invalid HD sprite image")?;
    let (w, h) = (image.get_width(), image.get_height());

    if w <= 0 || h <= 0 || w + 2 > sprites::ATLAS_LIMIT || h + 2 > sprites::ATLAS_LIMIT {
        return Err("invalid HD sprite dimensions".into());
    }

    let mut rgba = Image::create_from_data(w, h, false, image.get_format(), &image.get_data()).ok_or("invalid HD sprite pixels")?;
    rgba.convert(Format::RGBA8);

    Ok(Sprite {
        w,
        h,
        rgba: rgba.get_data().to_vec(),
        la: Vec::new(),
    })
}

fn city(d: &VarDictionary) -> Result<City, String> {
    let mut c = City {
        edge: int(d, "edge", 0) as i32,
        visible: int(d, "visible", 32) as i32,
        rotation: int(d, "rotation", 0) as usize,
        altitude: ints(d, "altitude"),
        terrain: bytes(d, "terrain"),
        buildings: bytes(d, "buildings"),
        zones: bytes(d, "zones"),
        flags: bytes(d, "flags"),
        overlays: bytes(d, "overlays"),
        underground: bytes(d, "underground"),
        ground: ints(d, "ground"),
        objects: ints(d, "objects"),
        traffic: bytes(d, "traffic"),
        dispatch: HashMap::new(),
    };

    c.validate()?;
    c.set_dispatch(&bytes(d, "things"));
    Ok(c)
}

fn auxiliary_images(images: &VarDictionary) -> HashMap<u64, Sprite> {
    images
        .iter_shared()
        .filter_map(|(key, value)| {
            let id = key.try_to::<i64>().ok()?;
            let image = value.try_to::<Gd<Image>>().ok()?;
            Some((id as u64 * 2, sprite_from_image(&image).ok()?))
        })
        .collect()
}

#[godot_api]
impl NativeCityRegionBuilder {
    #[func]
    fn auxiliary_atlas(&self, images: VarDictionary) -> Option<Gd<Image>> {
        if images.is_empty() {
            return None;
        }
        let core = self.core.as_ref()?;
        let pixels = sc2k_render::visual_auxiliary::atlas(core.atlas.edge, &core.atlas.slots, &core.sprites, &auxiliary_images(&images));
        Image::create_from_data(
            core.atlas.edge,
            core.atlas.edge,
            false,
            Format::RGBA8,
            &PackedByteArray::from(pixels.as_slice()),
        )
    }

    #[func]
    fn auxiliary_raster(&mut self, bounds: Rect2i, images: VarDictionary, emission: bool) -> Option<Gd<Image>> {
        if images.is_empty() {
            return None;
        }
        let core = self.core.as_mut()?;
        let rect = Rect::new(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y);
        if !rect.area() {
            return None;
        }
        let draws = core.collect(rect).ok()?;
        let pixels = sc2k_render::visual_auxiliary::raster(rect, &draws, &core.sprites.images, &auxiliary_images(&images), emission);
        Image::create_from_data(rect.w, rect.h, false, Format::RGBA8, &PackedByteArray::from(pixels.as_slice()))
    }

    #[func]
    fn water_reflections(
        &mut self,
        bounds: Rect2i,
        water_indices: PackedByteArray,
        emission: VarDictionary,
        seasons: VarDictionary,
    ) -> VarDictionary {
        let mut result = VarDictionary::new();
        let Some(core) = self.core.as_mut() else { return result };
        let rect = Rect::new(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y);
        if !rect.area() || rect.w > 2048 || rect.h > 2048 || water_indices.len() != 256 {
            result.set("error", "invalid water reflection bounds or palette");
            return result;
        }
        let pixels = match core.water_pixels(
            rect,
            water_indices.as_slice(),
            &auxiliary_images(&emission),
            &auxiliary_images(&seasons),
        ) {
            Ok(pixels) => pixels,
            Err(error) => {
                result.set("error", &GString::from(&error));
                return result;
            }
        };
        if !pixels.surface.chunks_exact(4).any(|p| p[3] != 0) {
            return result;
        }
        for (name, bytes) in [
            ("surface", pixels.surface),
            ("reflected", pixels.reflected),
            ("emission", pixels.emission),
            ("seasons", pixels.seasons),
            ("seabed", pixels.seabed),
        ] {
            let image = Image::create_from_data(rect.w, rect.h, false, Format::RGBA8, &PackedByteArray::from(bytes.as_slice()))
                .expect("validated water bounds");
            result.set(name, &image);
        }
        result
    }

    #[func]
    fn configure(&mut self, request: VarDictionary, images: VarDictionary, target: i64) -> GString {
        let previous_revision = self.core.as_ref().map_or(0, |core| core.atlas.revision + 1);
        self.core = None;
        self.images.clear();
        let result: Result<(), String> = (|| {
            let city = city(&request)?;
            let view = int(&request, "view", -1) as i32;

            if !(0..=2).contains(&view) {
                return Err("invalid native region view".to_string());
            }

            let config = Config {
                view,
                underground: int(&request, "underground_mode", 0) != 0,
                pipes: int(&request, "pipes", 1) != 0,
                subways: int(&request, "subways", 1) != 0,
                tunnels: int(&request, "tunnels", 1) != 0,
                mains: int(&request, "mains", 1) != 0,
                redraw_ground: int(&request, "redraw_ground", 0) != 0,
                specials: int(&request, "special_overlays", 0) != 0,
                individual_traffic: int(&request, "individual_traffic", 0) != 0,
                natural_forests: int(&request, "natural_forests", 0) != 0,
                natural_terrain: int(&request, "natural_terrain", 0) != 0,
                phase: int(&request, "animation_phase", 0) as i32,
                effects: int(&request, "hd_effects", 0) as i32,
            };

            let mut sprites = HashMap::new();

            for (key, value) in images.iter_shared() {
                let id = key.try_to::<i64>().map_err(|_| "invalid sprite ID")?;
                let image = value.try_to::<Gd<Image>>().map_err(|_| "invalid sprite image")?;
                let sprite = sprite_from_image(&image)?;
                let rgba = Image::create_from_data(
                    sprite.w,
                    sprite.h,
                    false,
                    Format::RGBA8,
                    &PackedByteArray::from(sprite.rgba.as_slice()),
                )
                .ok_or("invalid sprite pixels")?;
                sprites.insert(id as u64 * 2, sprite);
                self.images.insert(id as u64 * 2, rgba);
            }

            let atlas_edge = int(&request, "atlas_edge", 2048) as i32;

            if !(32..=8192).contains(&atlas_edge) || !(atlas_edge as u32).is_power_of_two() {
                return Err("invalid native atlas dimensions".into());
            }

            let pack_atlas = int(&request, "atlas", 1) != 0;
            let mut core = Builder::new(city, config, sprites, (target as u32).to_be_bytes(), atlas_edge, pack_atlas)?;
            core.atlas.revision += previous_revision;

            configure_artwork(&mut core, &request)?;

            // Shadow pairs: each packed RGBA color and the color that a shadow makes of it.
            for pair in ints(&request, "shadow_colors").chunks_exact(2) {
                core.shadows.insert((pair[0] as u32).to_be_bytes(), (pair[1] as u32).to_be_bytes());
            }

            self.core = Some(core);
            Ok(())
        })();
        GString::from(&result.err().unwrap_or_default())
    }

    #[func]
    fn tile_cache_limit() -> i64 {
        TILE_LIMIT as i64
    }

    #[func]
    fn cached_tile_count(&self) -> i64 {
        self.core.as_ref().map_or(0, |core| core.cached_tiles() as i64)
    }

    #[func]
    fn update_city(&mut self, request: VarDictionary) -> GString {
        let result: Result<(), String> = (|| {
            let city = city(&request)?;
            let core = self.core.as_mut().ok_or("native region builder is not configured")?;

            if city.edge != core.city.edge || city.rotation != core.city.rotation || city.visible != core.city.visible {
                return Err("native region layout changed without configure".into());
            }

            core.update(city);
            Ok(())
        })();
        GString::from(&result.err().unwrap_or_default())
    }

    #[func]
    fn build(&mut self, bounds: Rect2i, atlas_revision: i64) -> VarDictionary {
        let mut result = VarDictionary::new();
        let Some(core) = self.core.as_mut() else {
            result.set("error", "native region builder is not configured");

            return result;
        };

        let clipped = Rect::new(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y).clip(Rect::new(
            0,
            0,
            (64 + core.city.edge * 32) / core.config.divisor(),
            (896 + core.city.edge * 16) / core.config.divisor(),
        ));

        if !clipped.area() {
            result.set("error", "empty GPU region");

            return result;
        }

        let before = core.builds;
        let region = match core.region(clipped) {
            Ok(region) => region,
            Err(error) => {
                result.set("error", &GString::from(&error));

                return result;
            }
        };

        let vertices: PackedVector2Array = region.vertices.iter().map(|v| Vector2::new(v[0], v[1])).collect();
        let uvs: PackedVector2Array = region.uvs.iter().map(|v| Vector2::new(v[0], v[1])).collect();
        result.set("vertices", &vertices);
        result.set("uvs", &uvs);
        let colors: PackedColorArray = region.colors.iter().map(|c| Color::from_rgba(c[0], c[1], c[2], c[3])).collect();
        result.set("colors", &colors);
        result.set("indices", &PackedInt32Array::from(region.indices.as_slice()));
        let (records, images) = Self::records(&mut self.images, &core.sprites, &region.draws);
        result.set("records", &records);
        result.set("images", &images);
        result.set(
            "draws",
            &Gd::from_object(NativeCityRegionDraws {
                draws: RegionDraws::new(region.draws),
            }),
        );
        result.set("builds", core.builds - before);
        result.set("total_builds", core.builds);
        result.set("cached_tiles", core.cached_tiles() as i64);
        result.set("total_reuses", core.reuses);
        result.set("atlas_revision", core.atlas.revision);
        result.set("atlas_edge", core.atlas.edge);

        if atlas_revision != core.atlas.revision {
            let image = Image::create_from_data(
                core.atlas.edge,
                core.atlas.edge,
                false,
                Format::RGBA8,
                &PackedByteArray::from(core.atlas.data.as_slice()),
            )
            .expect("validated atlas dimensions");
            result.set("atlas", &image);
        }

        result.set("bounds", Rect2i::from_components(clipped.x, clipped.y, clipped.w, clipped.h));
        result
    }
}

#[godot_api(secondary)]
impl NativeCityRegionBuilder {
    /// CPU pixels of `bounds`: `{image, bounds, records, images, draws}`, or `{error}`.
    /// `background` is a packed RGBA color. Records and images are as in `build`.
    #[func]
    fn raster(&mut self, bounds: Rect2i, background: i64) -> VarDictionary {
        let mut result = VarDictionary::new();
        let Some(core) = self.core.as_mut() else {
            result.set("error", "native region builder is not configured");

            return result;
        };

        let clipped = Rect::new(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y).clip(Rect::new(
            0,
            0,
            (64 + core.city.edge * 32) / core.config.divisor(),
            (896 + core.city.edge * 16) / core.config.divisor(),
        ));

        if !clipped.area() {
            result.set("error", "empty region");

            return result;
        }

        let (pixels, draws) = match core.raster(clipped, (background as u32).to_be_bytes()) {
            Ok(value) => value,
            Err(error) => {
                result.set("error", &GString::from(&error));

                return result;
            }
        };

        let image = Image::create_from_data(
            clipped.w,
            clipped.h,
            false,
            Format::RGBA8,
            &PackedByteArray::from(pixels.as_slice()),
        )
        .expect("clipped region dimensions");
        let (records, images) = Self::records(&mut self.images, &core.sprites, &draws);
        result.set("image", &image);
        result.set("bounds", Rect2i::from_components(clipped.x, clipped.y, clipped.w, clipped.h));
        result.set("records", &records);
        result.set("images", &images);
        result.set(
            "draws",
            &Gd::from_object(NativeCityRegionDraws {
                draws: RegionDraws::new(draws),
            }),
        );
        result
    }

    /// CPU pixels of `bounds` with the full-color art, at `factor` (1, 2 or 4)
    /// pixels for each view pixel: `{image, bounds}`, or `{error}`. `frame`
    /// selects the frame of animation strips.
    #[func]
    fn raster_artwork(&mut self, bounds: Rect2i, background: i64, factor: i64, frame: i64) -> VarDictionary {
        let mut result = VarDictionary::new();
        let Some(core) = self.core.as_mut() else {
            result.set("error", "native region builder is not configured");

            return result;
        };

        let clipped = Rect::new(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y).clip(Rect::new(
            0,
            0,
            (64 + core.city.edge * 32) / core.config.divisor(),
            (896 + core.city.edge * 16) / core.config.divisor(),
        ));

        if !clipped.area() {
            result.set("error", "empty region");

            return result;
        }

        let factor = factor as i32;

        let pixels = match core.raster_artwork(clipped, (background as u32).to_be_bytes(), factor, frame) {
            Ok((pixels, _)) => pixels,
            Err(error) => {
                result.set("error", &GString::from(&error));

                return result;
            }
        };

        let image = Image::create_from_data(
            clipped.w * factor,
            clipped.h * factor,
            false,
            Format::RGBA8,
            &PackedByteArray::from(pixels.as_slice()),
        )
        .expect("clipped region dimensions");
        result.set("image", &image);
        result.set("bounds", Rect2i::from_components(clipped.x, clipped.y, clipped.w, clipped.h));
        result
    }

    /// Moving object draws for raster jobs. Each draw has a map `cell`, a native
    /// `position`, a sprite `id`, `flip`, `shadow` and the `floating` water altitude
    /// of a ship or sailboat, or -1. `images` holds the sprite images by ID.
    /// Returns an error string, or an empty string.
    #[func]
    #[allow(clippy::too_many_arguments)]
    fn set_moving(
        &mut self,
        cells: PackedInt32Array,
        positions: PackedVector2Array,
        ids: PackedInt32Array,
        flips: PackedByteArray,
        shadows: PackedByteArray,
        floating: PackedInt32Array,
        images: VarDictionary,
    ) -> GString {
        let Some(core) = self.core.as_mut() else {
            return GString::from("native region builder is not configured");
        };

        let count = cells.len();

        if [positions.len(), ids.len(), flips.len(), shadows.len(), floating.len()]
            .iter()
            .any(|n| *n != count)
        {
            return GString::from("moving draw fields differ in length");
        }

        let mut moving: HashMap<usize, Vec<Draw>> = HashMap::new();

        for at in 0..count {
            let id = ids.as_slice()[at];
            let key = id as u64 * 2;

            if let std::collections::hash_map::Entry::Vacant(slot) = core.sprites.images.entry(key) {
                let Some(image) = images.get(id).and_then(|v| v.try_to::<Gd<Image>>().ok()) else {
                    return GString::from(&format!("missing moving sprite {id}"));
                };

                match sprite_from_image(&image) {
                    Ok(sprite) => {
                        slot.insert(sprite);
                    }
                    Err(error) => return GString::from(&error),
                }
            }

            let image = match core.sprites.get(id, flips.as_slice()[at] != 0) {
                Ok(image) => image,
                Err(error) => return GString::from(&error),
            };

            let sprite = &core.sprites.images[&image];
            let position = positions.as_slice()[at];
            let mut draw = Draw::new(image, Rect::new(position.x as i32, position.y as i32, sprite.w, sprite.h));
            draw.sprite = id;
            draw.flip = flips.as_slice()[at] != 0;
            draw.moving = true;
            draw.shadow = shadows.as_slice()[at] != 0;
            draw.floating = floating.as_slice()[at];
            moving.entry(cells.as_slice()[at].max(0) as usize).or_default().push(draw);
        }

        core.set_moving(moving);
        GString::new()
    }

    /// Every sprite ID that the configured city needs and the artwork lacks, in
    /// ascending order.
    #[func]
    fn missing_sprites(&mut self) -> PackedInt32Array {
        self.core.as_mut().map_or_else(PackedInt32Array::new, |core| {
            PackedInt32Array::from(core.missing_sprites().as_slice())
        })
    }

    /// The tiles of the tile window `window` that need missing artwork:
    /// `{cells, sprites, all}`. `cells` holds map cell indices, `sprites` the
    /// lowest missing sprite of each cell, and `all` every missing sprite ID.
    #[func]
    fn missing_tiles(&mut self, window: Rect2i) -> VarDictionary {
        let mut result = VarDictionary::new();
        let window = Rect::new(window.position.x, window.position.y, window.size.x, window.size.y);
        let found = self.core.as_mut().map(|core| core.missing_tiles(window)).unwrap_or_default();

        result.set("cells", &PackedInt32Array::from(found.cells.as_slice()));
        result.set("sprites", &PackedInt32Array::from(found.sprites.as_slice()));
        result.set("all", &PackedInt32Array::from(found.all.as_slice()));
        result
    }

    /// The uncut draws that meet `bounds` in painter order, without pixels:
    /// `{records, images}`, or `{error}`.
    #[func]
    fn draw_records(&mut self, bounds: Rect2i) -> VarDictionary {
        let mut result = VarDictionary::new();
        let Some(core) = self.core.as_mut() else {
            result.set("error", "native region builder is not configured");

            return result;
        };

        let rect = Rect::new(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y);

        match core.collect(rect) {
            Ok(draws) => {
                let (records, images) = Self::records(&mut self.images, &core.sprites, &draws);
                result.set("records", &records);
                result.set("images", &images);
            }
            Err(error) => result.set("error", &GString::from(&error)),
        }

        result
    }

    /// The uncut draws of the tiles in painter order: `{records, images}`, or
    /// `{error}`. `tiles` holds x and y of each tile.
    #[func]
    fn tile_draws(&mut self, tiles: PackedInt32Array) -> VarDictionary {
        let mut result = VarDictionary::new();
        let Some(core) = self.core.as_mut() else {
            result.set("error", "native region builder is not configured");

            return result;
        };

        let mut draws = Vec::new();

        for tile in tiles.as_slice().chunks_exact(2) {
            match core.tile_draws(tile[0], tile[1]) {
                Ok(found) => draws.extend(found),
                Err(error) => {
                    result.set("error", &GString::from(&error));

                    return result;
                }
            }
        }

        let (records, images) = Self::records(&mut self.images, &core.sprites, &draws);
        result.set("records", &records);
        result.set("images", &images);
        result
    }
}

impl NativeCityRegionBuilder {
    // Draw records and the images that they index. Each image is made once.
    fn records(cache: &mut HashMap<u64, Gd<Image>>, sprites: &sprites::Sprites, draws: &[Draw]) -> (PackedInt64Array, VarArray) {
        let mut records = Vec::with_capacity(draws.len() * RECORD_SIZE);
        let mut images = VarArray::new();
        let mut slots: HashMap<u64, i64> = HashMap::new();

        for d in draws {
            let slot = *slots.entry(d.image).or_insert_with(|| {
                let image = cache.entry(d.image).or_insert_with(|| {
                    let s = &sprites.images[&d.image];
                    Image::create_from_data(s.w, s.h, false, Format::RGBA8, &PackedByteArray::from(s.rgba.as_slice()))
                        .expect("validated sprite dimensions")
                });

                images.push(&image.to_variant());
                images.len() as i64 - 1
            });

            records.extend([
                d.rect.x as i64,
                d.rect.y as i64,
                d.rect.w as i64,
                d.rect.h as i64,
                slot,
                d.sprite as i64,
                i64::from(d.flip),
                d.depth,
                d.order,
                i64::from(d.ignore),
                d.reference as i64,
                d.thickness as i64,
                d.deck as i64,
                i64::from(d.requires_depth),
            ]);
        }

        (PackedInt64Array::from(records.as_slice()), images)
    }
}

/// The fields of each draw record in `build` results.
const RECORD_SIZE: usize = 14;
