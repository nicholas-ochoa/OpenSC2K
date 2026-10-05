use super::{Draw, Rect};
use std::collections::{BTreeSet, HashMap};

/// The image key of the placeholder of a missing sprite.
pub const PLACEHOLDER: u64 = u64::MAX - 1;

/// Image keys at and above this bit are derived images, such as masked traffic.
pub const TRAFFIC_KEY: u64 = 1 << 32;

/// Atlas key bits of the images that are not indexed sprites.
pub const ARTWORK_SLOT: u64 = 1 << 63;
const MASK_SLOT: u64 = 1 << 62;
const RECORD_SLOT: u64 = 1 << 61;

/// The palette indices that the palette animation changes.
const ANIMATED_COLORS: [std::ops::RangeInclusive<u8>; 3] = [171..=198, 200..=219, 224..=239];

/// The largest GPU atlas edge, and the largest padded image in it.
pub const ATLAS_LIMIT: i32 = 8192;

/// Empty texels around full-color art, and repeated rows above and below each
/// animation frame. The shader reads up to two texels outside a sample.
pub const ARTWORK_PADDING: i32 = 2;

#[derive(Clone)]
pub struct Sprite {
    pub w: i32,
    pub h: i32,
    pub rgba: Vec<u8>,
    pub la: Vec<u8>,
}

/// A full-color image that replaces the look of one indexed sprite.
///
/// `image` holds RGBA pixels at any density. It covers the logical width of
/// the sprite and `height` logical rows that end at the bottom of the sprite.
/// An animation stacks `frames` equal frames from top to bottom.
#[derive(Clone)]
pub struct Artwork {
    pub image: Sprite,
    pub height: i32,
    pub frames: u8,
    pub fps: u8,
}

pub struct Sprites {
    pub images: HashMap<u64, Sprite>,
    /// Full-color art of unflipped sprite keys. Indexed pixels still give the
    /// draw geometry, the masks and the silhouettes.
    pub artwork: HashMap<u64, Artwork>,
    /// The road pixels of each masked traffic key, as alpha in logical pixels.
    pub traffic_masks: HashMap<u64, Sprite>,
    /// Whether each image has palette indices that animate.
    animated: HashMap<u64, bool>,
    target: [u8; 4],
    /// While set, a missing sprite paints as a transparent pixel and is recorded
    /// in `missing`, so one pass finds every missing sprite.
    pub placeholders: bool,
    pub missing: BTreeSet<i32>,
}

impl Sprites {
    pub fn new(images: HashMap<u64, Sprite>, target: [u8; 4]) -> Self {
        Self {
            images,
            artwork: HashMap::new(),
            traffic_masks: HashMap::new(),
            animated: HashMap::new(),
            target,
            placeholders: false,
            missing: BTreeSet::new(),
        }
    }

    /// The unflipped key of the artwork that a draw shows, and whether the draw
    /// mirrors it. Masked traffic shows the art of its traffic sprite.
    pub fn artwork_source(&self, image: u64) -> Option<(u64, bool)> {
        let shown = if image < TRAFFIC_KEY {
            image
        } else if image < TRAFFIC_KEY << 1 {
            (image >> 16) & 0xffff
        } else {
            return None;
        };

        let source = shown & !1;
        self.artwork.contains_key(&source).then_some((source, shown & 1 != 0))
    }

    /// The screen rectangle of the artwork of a draw. Art can be taller than
    /// its indexed sprite. It keeps the bottom edge of the sprite.
    pub fn artwork_rect(&self, draw: &Draw) -> Rect {
        if draw.image & TRAFFIC_KEY != 0 {
            return draw.rect;
        }

        match self.artwork_source(draw.image) {
            Some((source, _)) => {
                let height = self.artwork[&source].height;

                Rect::new(draw.rect.x, draw.rect.y + draw.rect.h - height, draw.rect.w, height)
            }
            None => draw.rect,
        }
    }

    /// Whether the indexed pixels of `key` use the colors that the palette animates.
    pub fn has_animated_colors(&mut self, key: u64) -> bool {
        if let Some(&animated) = self.animated.get(&key) {
            return animated;
        }

        let animated = self.images.get(&key).is_some_and(|image| {
            image
                .la
                .chunks_exact(2)
                .any(|pixel| pixel[1] != 0 && ANIMATED_COLORS.iter().any(|range| range.contains(&pixel[0])))
        });
        self.animated.insert(key, animated);
        animated
    }

    pub fn get(&mut self, id: i32, flip: bool) -> Result<u64, String> {
        let key = (id as u64) * 2 + u64::from(flip);

        if !self.images.contains_key(&key) && !self.images.contains_key(&((id as u64) * 2)) && self.placeholders {
            self.missing.insert(id);

            return Ok(PLACEHOLDER);
        }

        if !self.images.contains_key(&key) {
            let Some(original) = self.images.get(&((id as u64) * 2)) else {
                return Err(format!("missing region sprite {id}"));
            };

            let mut copy = original.clone();

            for y in 0..copy.h as usize {
                for x in 0..copy.w as usize {
                    let a = y * copy.w as usize + x;
                    let b = y * copy.w as usize + copy.w as usize - 1 - x;
                    copy.rgba[a * 4..a * 4 + 4].copy_from_slice(&original.rgba[b * 4..b * 4 + 4]);
                    copy.la[a * 2..a * 2 + 2].copy_from_slice(&original.la[b * 2..b * 2 + 2]);
                }
            }

            self.images.insert(key, copy);
        }

        Ok(key)
    }

    pub fn traffic(&mut self, traffic: u64, surface: u64) -> u64 {
        let key = TRAFFIC_KEY | (traffic << 16) | surface;

        if !self.images.contains_key(&key) {
            let mut copy = self.images[&traffic].clone();
            let base = &self.images[&surface];
            let offset = base.h - copy.h;

            let with_artwork = self.artwork.contains_key(&(traffic & !1));
            let mut mask = Sprite {
                w: copy.w,
                h: copy.h,
                rgba: vec![0; (copy.w * copy.h * 4) as usize],
                la: Vec::new(),
            };

            for y in 0..copy.h {
                for x in 0..copy.w {
                    let sy = y + offset;
                    let keep = x < base.w
                        && sy >= 0
                        && sy < base.h
                        && base.rgba[((sy * base.w + x) * 4) as usize..((sy * base.w + x) * 4 + 4) as usize] == self.target;
                    let p = (y * copy.w + x) as usize;

                    if keep {
                        mask.rgba[p * 4 + 3] = 255;
                    } else {
                        copy.rgba[p * 4 + 3] = 0;
                        copy.la[p * 2 + 1] = 0;
                    }
                }
            }

            // The art of the traffic shows only on the road pixels of the surface.
            if with_artwork {
                self.traffic_masks.insert(key, mask);
            }

            self.images.insert(key, copy);
        }

        key
    }
}

/// The GPU sprite texture: RGBA texels in square power-of-two sizes.
///
/// An indexed sprite stores its palette index in red, green and blue, and its
/// alpha in alpha. Full-color art stores its own colors. Slots never move, so
/// published meshes stay valid when the atlas grows.
pub struct Atlas {
    pub edge: i32,
    pub revision: i64,
    pub data: Vec<u8>,
    pub slots: HashMap<u64, Rect>,
    free: Vec<Rect>,
}

impl Atlas {
    pub fn new(edge: i32) -> Self {
        Self {
            edge,
            revision: 0,
            data: vec![0; edge as usize * edge as usize * 4],
            slots: HashMap::new(),
            free: vec![Rect::new(0, 0, edge, edge)],
        }
    }

    fn grow(&mut self) -> Result<(), String> {
        if self.edge >= ATLAS_LIMIT {
            return Err("GPU sprite atlas is full".into());
        }

        let old = self.edge as usize;
        let mut data = vec![0; old * old * 16];

        for y in 0..old {
            data[y * old * 8..y * old * 8 + old * 4].copy_from_slice(&self.data[y * old * 4..(y + 1) * old * 4]);
        }

        self.data = data;
        self.edge *= 2;

        // Free rectangles at the old border continue into the new space.
        for rect in &mut self.free {
            if rect.x + rect.w == old as i32 {
                rect.w += old as i32;
            }

            if rect.y + rect.h == old as i32 {
                rect.h += old as i32;
            }
        }

        self.free.push(Rect::new(old as i32, 0, old as i32, self.edge));
        self.free.push(Rect::new(0, old as i32, self.edge, old as i32));
        self.prune_free();
        self.revision += 1;
        Ok(())
    }

    /// Removes each free rectangle that another free rectangle contains.
    fn prune_free(&mut self) {
        let contained = |a: Rect, b: Rect| a.x >= b.x && a.y >= b.y && a.x + a.w <= b.x + b.w && a.y + a.h <= b.y + b.h;
        let mut index = 0;

        while index < self.free.len() {
            let covered = (0..self.free.len()).any(|other| {
                other != index && contained(self.free[index], self.free[other]) && (self.free[index] != self.free[other] || other < index)
            });

            if covered {
                self.free.remove(index);
            } else {
                index += 1;
            }
        }
    }

    /// A free area of `width` x `height`. The atlas grows when no area fits.
    fn reserve(&mut self, width: i32, height: i32) -> Result<Rect, String> {
        loop {
            // Best short side fit: tall strips and narrow sprites leave less unusable space.
            let choice = self
                .free
                .iter()
                .filter(|rect| rect.w >= width && rect.h >= height)
                .min_by_key(|rect| {
                    let (w, h) = (rect.w - width, rect.h - height);
                    (w.min(h), w.max(h), rect.y, rect.x)
                })
                .copied();

            let Some(space) = choice else {
                self.grow()?;
                continue;
            };

            let used = Rect::new(space.x, space.y, width, height);
            let mut remaining = Vec::new();

            for free in self.free.drain(..) {
                if !free.clip(used).area() {
                    remaining.push(free);
                    continue;
                }

                if used.x > free.x {
                    remaining.push(Rect::new(free.x, free.y, used.x - free.x, free.h));
                }

                if used.x + used.w < free.x + free.w {
                    remaining.push(Rect::new(used.x + used.w, free.y, free.x + free.w - used.x - used.w, free.h));
                }

                if used.y > free.y {
                    remaining.push(Rect::new(free.x, free.y, free.w, used.y - free.y));
                }

                if used.y + used.h < free.y + free.h {
                    remaining.push(Rect::new(free.x, used.y + used.h, free.w, free.y + free.h - used.y - used.h));
                }
            }

            self.free = remaining;
            self.prune_free();
            return Ok(used);
        }
    }

    /// The slot of an indexed sprite.
    pub fn slot(&mut self, key: u64, sprite: &Sprite) -> Result<Rect, String> {
        if let Some(rect) = self.slots.get(&key) {
            return Ok(*rect);
        }

        let indexed: Vec<u8> = sprite.la.chunks_exact(2).flat_map(|p| [p[0], p[0], p[0], p[1]]).collect();
        self.insert(key, sprite.w, sprite.h, &indexed, 1)
    }

    /// The slot of full-color art. Each animation frame repeats its top and
    /// bottom rows `ARTWORK_PADDING` times above and below it, so filtered
    /// samples at a frame edge never read the next frame.
    pub fn artwork_slot(&mut self, key: u64, artwork: &Artwork) -> Result<Rect, String> {
        let key = key | ARTWORK_SLOT;

        if let Some(rect) = self.slots.get(&key) {
            return Ok(*rect);
        }

        let image = &artwork.image;

        if artwork.frames <= 1 {
            return self.insert(key, image.w, image.h, &image.rgba, ARTWORK_PADDING);
        }

        let frames = i32::from(artwork.frames);
        let frame_height = image.h / frames;
        let stride = frame_height + ARTWORK_PADDING * 2;
        let row_bytes = image.w as usize * 4;
        let mut rgba = vec![0; row_bytes * (stride * frames) as usize];

        for frame in 0..frames {
            for row in 0..stride {
                let source_row = (row - ARTWORK_PADDING).clamp(0, frame_height - 1);
                let source = ((frame * frame_height + source_row) * image.w * 4) as usize;
                let target = ((frame * stride + row) * image.w * 4) as usize;
                rgba[target..target + row_bytes].copy_from_slice(&image.rgba[source..source + row_bytes]);
            }
        }

        // The repeated rows are the padding above and below the strip.
        self.insert(key, image.w, stride * frames, &rgba, ARTWORK_PADDING)
    }

    /// The slot of the road mask of a masked traffic key.
    pub fn mask_slot(&mut self, key: u64, mask: &Sprite) -> Result<Rect, String> {
        self.insert(key | MASK_SLOT, mask.w, mask.h, &mask.rgba, 1)
    }

    /// The slot of a texel record of a masked traffic key. Each texel holds two
    /// 16-bit words, high byte first.
    pub fn record_slot(&mut self, key: u64, words: &[i32]) -> Result<Rect, String> {
        let texels: Vec<u8> = words.iter().flat_map(|&word| (word as u16).to_be_bytes()).collect();
        self.insert(key | RECORD_SLOT, texels.len() as i32 / 4, 1, &texels, 1)
    }

    /// Copies RGBA pixels into a new slot with `padding` empty texels on each side.
    fn insert(&mut self, key: u64, width: i32, height: i32, rgba: &[u8], padding: i32) -> Result<Rect, String> {
        if let Some(rect) = self.slots.get(&key) {
            return Ok(*rect);
        }

        if width + padding * 2 > ATLAS_LIMIT || height + padding * 2 > ATLAS_LIMIT {
            return Err("Sprite exceeds GPU atlas dimensions".into());
        }

        let padded = self.reserve(width + padding * 2, height + padding * 2)?;
        let rect = Rect::new(padded.x + padding, padded.y + padding, width, height);
        let row_bytes = width as usize * 4;

        for y in 0..height {
            let source = y as usize * row_bytes;
            let target = ((rect.y + y) * self.edge * 4 + rect.x * 4) as usize;
            self.data[target..target + row_bytes].copy_from_slice(&rgba[source..source + row_bytes]);
        }

        self.revision += 1;
        self.slots.insert(key, rect);
        Ok(rect)
    }

    /// Whether the atlas has the art of `key`.
    pub fn has_artwork(&self, key: u64) -> bool {
        self.slots.contains_key(&(key | ARTWORK_SLOT))
    }
}
