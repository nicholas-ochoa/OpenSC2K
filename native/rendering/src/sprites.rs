use super::Rect;
use std::collections::HashMap;

#[derive(Clone)]
pub struct Sprite {
    pub w: i32,
    pub h: i32,
    pub rgba: Vec<u8>,
    pub la: Vec<u8>,
}
pub struct Sprites {
    pub images: HashMap<u64, Sprite>,
    target: [u8; 4],
}
impl Sprites {
    pub fn new(images: HashMap<u64, Sprite>, target: [u8; 4]) -> Self {
        Self { images, target }
    }
    pub fn get(&mut self, id: i32, flip: bool) -> Result<u64, String> {
        let key = (id as u64) * 2 + u64::from(flip);
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
        let key = (1_u64 << 32) | (traffic << 16) | surface;
        if !self.images.contains_key(&key) {
            let mut copy = self.images[&traffic].clone();
            let base = &self.images[&surface];
            let offset = base.h - copy.h;
            for y in 0..copy.h {
                for x in 0..copy.w {
                    let sy = y + offset;
                    let keep = x < base.w
                        && sy >= 0
                        && sy < base.h
                        && base.rgba[((sy * base.w + x) * 4) as usize..((sy * base.w + x) * 4 + 4) as usize] == self.target;
                    if !keep {
                        let p = (y * copy.w + x) as usize;
                        copy.rgba[p * 4 + 3] = 0;
                        copy.la[p * 2 + 1] = 0;
                    }
                }
            }
            self.images.insert(key, copy);
        }
        key
    }
}
pub struct Atlas {
    pub edge: i32,
    pub revision: i64,
    pub data: Vec<u8>,
    pub slots: HashMap<u64, Rect>,
    x: i32,
    y: i32,
    row: i32,
}
impl Atlas {
    pub fn new(edge: i32) -> Self {
        Self {
            edge,
            revision: 0,
            data: vec![0; edge as usize * edge as usize * 2],
            slots: HashMap::new(),
            x: 0,
            y: 0,
            row: 0,
        }
    }
    fn grow(&mut self) -> Result<(), String> {
        if self.edge >= 8192 {
            return Err("GPU sprite atlas is full".into());
        }
        let old = self.edge as usize;
        let mut data = vec![0; old * old * 8];
        for y in 0..old {
            data[y * old * 4..y * old * 4 + old * 2].copy_from_slice(&self.data[y * old * 2..(y + 1) * old * 2]);
        }
        self.data = data;
        self.edge *= 2;
        self.revision += 1;
        Ok(())
    }
    pub fn slot(&mut self, key: u64, sprite: &Sprite) -> Result<Rect, String> {
        if let Some(rect) = self.slots.get(&key) {
            return Ok(*rect);
        }
        if sprite.w + 2 > 8192 || sprite.h + 2 > 8192 {
            return Err("Sprite exceeds GPU atlas dimensions".into());
        }
        while sprite.w + 2 > self.edge || sprite.h + 2 > self.edge {
            self.grow()?;
        }
        if self.x + sprite.w + 2 > self.edge {
            self.x = 0;
            self.y += self.row;
            self.row = 0;
        }
        while self.y + sprite.h + 2 > self.edge {
            self.grow()?;
        }
        let rect = Rect::new(self.x + 1, self.y + 1, sprite.w, sprite.h);
        for y in 0..sprite.h {
            let src = (y * sprite.w * 2) as usize;
            let dst = ((rect.y + y) * self.edge * 2 + rect.x * 2) as usize;
            self.data[dst..dst + sprite.w as usize * 2].copy_from_slice(&sprite.la[src..src + sprite.w as usize * 2]);
        }
        self.x += sprite.w + 2;
        self.row = self.row.max(sprite.h + 2);
        self.revision += 1;
        self.slots.insert(key, rect);
        Ok(rect)
    }
}
