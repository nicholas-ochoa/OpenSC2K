//! Bulk Godot boundary. Each builder belongs to one region worker thread. A
//! region's draw index is immutable, so the main thread may read it later.
use super::{
    Builder, City, Config, Draw, Rect, changes, data_view, index::RegionDraws, minimap, region::TILE_LIMIT, sprites, sprites::Sprite,
};
use godot::{
    classes::{Image, image::Format},
    prelude::*,
};
use std::collections::HashMap;

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
fn int(d: &VarDictionary, k: &str, default: i64) -> i64 {
    d.get(k).and_then(|v| v.try_to().ok()).unwrap_or(default)
}
fn bytes(d: &VarDictionary, k: &str) -> Vec<u8> {
    d.get(k)
        .and_then(|v| v.try_to::<PackedByteArray>().ok())
        .map_or_else(Vec::new, |v| v.to_vec())
}
fn ints(d: &VarDictionary, k: &str) -> Vec<i32> {
    d.get(k)
        .and_then(|v| v.try_to::<PackedInt32Array>().ok())
        .map_or_else(Vec::new, |v| v.to_vec())
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
#[godot_api]
impl NativeCityRegionBuilder {
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
                mains: int(&request, "mains", 1) != 0,
                redraw_ground: int(&request, "redraw_ground", 0) != 0,
                specials: int(&request, "special_overlays", 0) != 0,
                phase: int(&request, "animation_phase", 0) as i32,
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
                Format::LA8,
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
    /// Moving object draws for raster jobs. Each draw has a map `cell`, a native
    /// `position`, a sprite `id`, `flip` and `shadow`. `images` holds the sprite
    /// images by ID. Returns an error string, or an empty string.
    #[func]
    fn set_moving(
        &mut self,
        cells: PackedInt32Array,
        positions: PackedVector2Array,
        ids: PackedInt32Array,
        flips: PackedByteArray,
        shadows: PackedByteArray,
        images: VarDictionary,
    ) -> GString {
        let Some(core) = self.core.as_mut() else {
            return GString::from("native region builder is not configured");
        };
        let count = cells.len();
        if [positions.len(), ids.len(), flips.len(), shadows.len()].iter().any(|n| *n != count) {
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

/// The published draws of one region. Queries return indices of `records`.
#[derive(GodotClass)]
#[class(base=RefCounted, no_init)]
pub struct NativeCityRegionDraws {
    draws: RegionDraws,
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

/// Data map overlay geometry. See `data_view.rs`.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeCityDataMesh {}
#[godot_api]
impl NativeCityDataMesh {
    /// `{vertices, colors, uvs, indices}`, or `{error}`. `altitude` holds the ALTM words.
    #[func]
    fn build(
        edge: i64,
        visible: i64,
        height_view: bool,
        altitude: PackedInt32Array,
        terrain: PackedByteArray,
        flags: PackedByteArray,
    ) -> VarDictionary {
        let mut result = VarDictionary::new();
        let city = data_view::DataCity {
            edge: edge.max(0) as usize,
            visible: visible as i32,
            altitude: altitude.as_slice(),
            terrain: terrain.as_slice(),
            flags: flags.as_slice(),
        };
        if let Err(error) = city.validate() {
            result.set("error", &GString::from(&error));
            return result;
        }
        let mesh = data_view::build(&city, height_view);
        let vertices: PackedVector2Array = mesh.vertices.iter().map(|v| Vector2::new(v[0], v[1])).collect();
        let colors: PackedColorArray = mesh.colors.iter().map(|c| Color::from_rgba(c[0], c[1], c[2], c[3])).collect();
        let uvs: PackedVector2Array = mesh.uvs.iter().map(|v| Vector2::new(v[0], v[1])).collect();
        result.set("vertices", &vertices);
        result.set("colors", &colors);
        result.set("uvs", &uvs);
        result.set("indices", &PackedInt32Array::from(mesh.indices.as_slice()));
        result
    }
}

/// Tile values of the data maps that have no data chunk. See `data_view.rs`.
#[godot_api(secondary)]
impl NativeCityDataMesh {
    /// The land level of each dry tile, and the underwater base plus the water
    /// depth of each underwater tile. `altitude` holds the ALTM words.
    #[func]
    fn height_values(altitude: PackedInt32Array, flags: PackedByteArray) -> PackedByteArray {
        PackedByteArray::from(data_view::height_values(altitude.as_slice(), flags.as_slice()).as_slice())
    }
    #[constant]
    const UNDERWATER_BASE: i32 = data_view::UNDERWATER_BASE as i32;
    /// 2 where the `supplied` flag is set, 1 where only `connected` is set.
    #[func]
    fn utility_values(flags: PackedByteArray, supplied: i64, connected: i64) -> PackedByteArray {
        PackedByteArray::from(data_view::utility_values(flags.as_slice(), supplied as u8, connected as u8).as_slice())
    }
}

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

/// City Map window images. See `minimap.rs`.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeCityMinimap {}
impl NativeCityMinimap {
    fn with_city<T>(request: &VarDictionary, use_city: impl FnOnce(&minimap::MinimapCity, minimap::Mode) -> T) -> Option<T> {
        let packed = |key: &str| {
            request
                .get(key)
                .and_then(|v| v.try_to::<PackedByteArray>().ok())
                .unwrap_or_default()
        };
        let (buildings, zones, flags, underground, data) = (
            packed("buildings"),
            packed("zones"),
            packed("flags"),
            packed("underground"),
            packed("data"),
        );
        let altitude = request
            .get("altitude")
            .and_then(|v| v.try_to::<PackedInt32Array>().ok())
            .unwrap_or_default();
        let mode = request.get("mode").and_then(|v| v.try_to::<GString>().ok()).unwrap_or_default();
        let city = minimap::MinimapCity {
            edge: int(request, "edge", 0).max(0) as usize,
            buildings: buildings.as_slice(),
            zones: zones.as_slice(),
            flags: flags.as_slice(),
            underground: underground.as_slice(),
            altitude: altitude.as_slice(),
            data: data.as_slice(),
        };
        city.validate().ok()?;
        Some(use_city(&city, minimap::Mode::from_name(&mode.to_string())))
    }
}
#[godot_api]
impl NativeCityMinimap {
    /// The chunk that `mode` reads, or an empty string.
    #[func]
    fn data_chunk(mode: GString) -> GString {
        GString::from(minimap::Mode::from_name(&mode.to_string()).chunk().unwrap_or(""))
    }
    /// The image edge of a map with `edge` tiles.
    #[func]
    fn image_edge(edge: i64) -> i64 {
        minimap::image_edge(edge.max(0) as usize) as i64
    }
    /// An RGBA8 image of the map. `request` has `edge`, `buildings`, `zones`,
    /// `flags`, `underground`, `altitude` (ALTM words), `mode` and `data`, the
    /// mode's data map. `palette` holds 256 RGBA colors. Returns null for invalid arrays.
    #[func]
    fn create_image(request: VarDictionary, palette: PackedByteArray) -> Option<Gd<Image>> {
        let (edge, rgba) = Self::with_city(&request, |city, mode| {
            let indices = minimap::indices(city, mode);
            (minimap::image_edge(city.edge), minimap::colorize(&indices, palette.as_slice()))
        })?;
        Image::create_from_data(
            edge as i32,
            edge as i32,
            false,
            Format::RGBA8,
            &PackedByteArray::from(rgba.as_slice()),
        )
    }
    /// The palette index of one tile, or -1 for invalid arrays.
    #[func]
    fn color_index(request: VarDictionary, x: i64, y: i64) -> i64 {
        Self::with_city(&request, |city, mode| {
            if x < 0 || y < 0 {
                0
            } else {
                i64::from(city.color_index(x as usize, y as usize, mode))
            }
        })
        .unwrap_or(-1)
    }
}
