//! Integer points and rectangles with Godot Vector2i and Rect2i rules.

use std::ops::{Add, Sub};

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct Vec2i {
    pub x: i64,
    pub y: i64,
}

impl Vec2i {
    pub const ZERO: Vec2i = Vec2i { x: 0, y: 0 };
    pub const NONE: Vec2i = Vec2i { x: -1, y: -1 };

    #[inline]
    pub const fn new(x: i64, y: i64) -> Self {
        Self { x, y }
    }
}

impl Add for Vec2i {
    type Output = Vec2i;

    #[inline]
    fn add(self, other: Vec2i) -> Vec2i {
        Vec2i::new(self.x + other.x, self.y + other.y)
    }
}

impl Sub for Vec2i {
    type Output = Vec2i;

    #[inline]
    fn sub(self, other: Vec2i) -> Vec2i {
        Vec2i::new(self.x - other.x, self.y - other.y)
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Rect2i {
    pub position: Vec2i,
    pub size: Vec2i,
}

impl Rect2i {
    pub const fn new(x: i64, y: i64, width: i64, height: i64) -> Self {
        Self {
            position: Vec2i::new(x, y),
            size: Vec2i::new(width, height),
        }
    }

    pub const fn from(position: Vec2i, size: Vec2i) -> Self {
        Self { position, size }
    }

    pub fn end(&self) -> Vec2i {
        self.position + self.size
    }

    pub fn has_area(&self) -> bool {
        self.size.x > 0 && self.size.y > 0
    }

    /// Rect2i.encloses: the other rectangle is inside this one.
    pub fn encloses(&self, other: &Rect2i) -> bool {
        other.position.x >= self.position.x
            && other.position.y >= self.position.y
            && other.position.x + other.size.x <= self.position.x + self.size.x
            && other.position.y + other.size.y <= self.position.y + self.size.y
    }

    /// Rect2i.intersects: the rectangles share at least one cell.
    pub fn intersects(&self, other: &Rect2i) -> bool {
        self.position.x < other.end().x
            && other.position.x < self.end().x
            && self.position.y < other.end().y
            && other.position.y < self.end().y
    }

    /// Rect2i.has_point: the end edges are outside.
    pub fn has_point(&self, point: Vec2i) -> bool {
        point.x >= self.position.x
            && point.y >= self.position.y
            && point.x < self.position.x + self.size.x
            && point.y < self.position.y + self.size.y
    }
}
