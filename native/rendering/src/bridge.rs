//! Bulk Godot boundary. Each instance belongs to one existing region worker.
use super::{Builder, City, Config, Rect, sprites::Sprite};
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
            };
            let mut sprites = HashMap::new();
            for (key, value) in images.iter_shared() {
                let id = key.try_to::<i64>().map_err(|_| "invalid sprite ID")?;
                let image = value
                    .try_to::<Gd<Image>>()
                    .map_err(|_| "invalid sprite image")?;
                let (w, h) = (image.get_width(), image.get_height());
                if w <= 0 || h <= 0 || w > 8190 || h > 8190 {
                    return Err("invalid sprite dimensions".into());
                }
                let mut rgba =
                    Image::create_from_data(w, h, false, image.get_format(), &image.get_data())
                        .ok_or("invalid sprite pixels")?;
                rgba.convert(Format::RGBA8);
                let data = rgba.get_data().to_vec();
                let mut la = Image::create_from_data(w, h, false, Format::RGBA8, &rgba.get_data())
                    .ok_or("invalid sprite pixels")?;
                la.convert(Format::LA8);
                sprites.insert(
                    id as u64 * 2,
                    Sprite {
                        w,
                        h,
                        rgba: data,
                        la: la.get_data().to_vec(),
                    },
                );
                self.images.insert(id as u64 * 2, rgba);
            }
            self.core = Some(Builder::new(
                city,
                config,
                sprites,
                (target as u32).to_be_bytes(),
            ));
            let atlas_edge = int(&request, "atlas_edge", 2048) as i32;
            if !(32..=8192).contains(&atlas_edge) || !(atlas_edge as u32).is_power_of_two() {
                self.core = None;
                return Err("invalid native atlas dimensions".into());
            }
            let core = self.core.as_mut().unwrap();
            core.atlas.edge = atlas_edge;
            core.atlas.data = vec![0; atlas_edge as usize * atlas_edge as usize * 2];
            core.atlas.revision = previous_revision;
            Ok(())
        })();
        GString::from(&result.err().unwrap_or_default())
    }
    #[func]
    fn update_city(&mut self, request: VarDictionary) -> GString {
        let result: Result<(), String> = (|| {
            let city = city(&request)?;
            let core = self
                .core
                .as_mut()
                .ok_or("native region builder is not configured")?;
            if city.edge != core.city.edge
                || city.rotation != core.city.rotation
                || city.visible != core.city.visible
            {
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
        let clipped = Rect::new(
            bounds.position.x,
            bounds.position.y,
            bounds.size.x,
            bounds.size.y,
        )
        .clip(Rect::new(
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
        let vertices: PackedVector2Array = region
            .vertices
            .iter()
            .map(|v| Vector2::new(v[0], v[1]))
            .collect();
        let uvs: PackedVector2Array = region
            .uvs
            .iter()
            .map(|v| Vector2::new(v[0], v[1]))
            .collect();
        result.set("vertices", &vertices);
        result.set("uvs", &uvs);
        result.set(
            "indices",
            &PackedInt32Array::from(region.indices.as_slice()),
        );
        let mut records = Vec::with_capacity(region.draws.len() * 16);
        let mut images = VarDictionary::new();
        for d in &region.draws {
            records.extend([
                d.id,
                d.image as i64,
                d.rect.x as i64,
                d.rect.y as i64,
                d.rect.w as i64,
                d.rect.h as i64,
                d.sprite as i64,
                i64::from(d.flip),
                d.depth,
                d.order,
                i64::from(d.ignore),
                d.reference as i64,
                d.thickness as i64,
                d.deck as i64,
                i64::from(d.requires_depth),
                0,
            ]);
            let image = self.images.entry(d.image).or_insert_with(|| {
                let s = &core.sprites.images[&d.image];
                Image::create_from_data(
                    s.w,
                    s.h,
                    false,
                    Format::RGBA8,
                    &PackedByteArray::from(s.rgba.as_slice()),
                )
                .expect("validated sprite dimensions")
            });
            // Dictionary insertion is per unique sprite, not a GDScript callback.
            if !images.contains_key(d.image as i64) {
                images.set(d.image as i64, &image.clone());
            }
        }
        result.set("records", &PackedInt64Array::from(records.as_slice()));
        result.set("images", &images);
        result.set("evicted", &PackedInt64Array::from(core.evicted.as_slice()));
        core.evicted.clear();
        result.set("builds", core.builds - before);
        result.set("total_builds", core.builds);
        result.set("cached_tiles", core.tiles.len() as i64);
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
        result.set(
            "bounds",
            Rect2i::from_components(clipped.x, clipped.y, clipped.w, clipped.h),
        );
        result
    }
}
