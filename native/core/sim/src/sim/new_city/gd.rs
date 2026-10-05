//! The number rules of the Godot scripts that made new-city terrain. A vector
//! holds two 32-bit floats and computes in 32 bits. Other numbers are 64-bit
//! floats. A 64-bit value that a vector stores becomes a 32-bit float.
//!
//! The terrain must stay equal to the terrain of the scripts, so each function
//! here repeats the operation order of the Godot function that it replaces.

use std::ops::{Add, Div, Mul, Sub};

/// Godot `Math::CMP_EPSILON`.
const CMP_EPSILON: f64 = 0.00001;

/// Godot `Vector2` with 32-bit components.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Vector2 {
    pub x: f32,
    pub y: f32,
}

impl Vector2 {
    pub const ZERO: Self = Self { x: 0.0, y: 0.0 };

    /// `Vector2(x, y)` from script floats.
    pub fn new(x: f64, y: f64) -> Self {
        Self { x: x as f32, y: y as f32 }
    }

    /// `Vector2(x, y)` from script integers.
    pub fn from_ints(x: i64, y: i64) -> Self {
        Self { x: x as f32, y: y as f32 }
    }

    /// `vector * scalar`: the scalar becomes a 32-bit float first.
    pub fn scaled(self, scalar: f64) -> Self {
        let scalar = scalar as f32;

        Self {
            x: self.x * scalar,
            y: self.y * scalar,
        }
    }

    /// `vector / scalar`: the scalar becomes a 32-bit float first.
    pub fn divided(self, scalar: f64) -> Self {
        let scalar = scalar as f32;

        Self {
            x: self.x / scalar,
            y: self.y / scalar,
        }
    }

    pub fn rotated(self, angle: f64) -> Self {
        let angle = angle as f32;
        let sine = angle.sin();
        let cosine = angle.cos();

        Self {
            x: self.x * cosine - self.y * sine,
            y: self.x * sine + self.y * cosine,
        }
    }

    pub fn length(self) -> f32 {
        (self.x * self.x + self.y * self.y).sqrt()
    }

    pub fn length_squared(self) -> f32 {
        self.x * self.x + self.y * self.y
    }

    pub fn angle(self) -> f32 {
        self.y.atan2(self.x)
    }

    pub fn normalized(self) -> Self {
        let mut length = self.x * self.x + self.y * self.y;

        if length == 0.0 {
            return self;
        }

        length = length.sqrt();

        Self {
            x: self.x / length,
            y: self.y / length,
        }
    }

    pub fn orthogonal(self) -> Self {
        Self { x: self.y, y: -self.x }
    }

    pub fn dot(self, other: Self) -> f32 {
        self.x * other.x + self.y * other.y
    }

    pub fn lerp(self, to: Self, weight: f64) -> Self {
        let weight = weight as f32;

        Self {
            x: self.x + (to.x - self.x) * weight,
            y: self.y + (to.y - self.y) * weight,
        }
    }

    pub fn distance_to(self, to: Self) -> f32 {
        ((self.x - to.x) * (self.x - to.x) + (self.y - to.y) * (self.y - to.y)).sqrt()
    }

    pub fn distance_squared_to(self, to: Self) -> f32 {
        (self.x - to.x) * (self.x - to.x) + (self.y - to.y) * (self.y - to.y)
    }

    /// `x` as a script float.
    pub fn fx(self) -> f64 {
        f64::from(self.x)
    }

    /// `y` as a script float.
    pub fn fy(self) -> f64 {
        f64::from(self.y)
    }
}

impl Add for Vector2 {
    type Output = Self;

    fn add(self, other: Self) -> Self {
        Self {
            x: self.x + other.x,
            y: self.y + other.y,
        }
    }
}

impl Sub for Vector2 {
    type Output = Self;

    fn sub(self, other: Self) -> Self {
        Self {
            x: self.x - other.x,
            y: self.y - other.y,
        }
    }
}

impl Mul for Vector2 {
    type Output = Self;

    fn mul(self, other: Self) -> Self {
        Self {
            x: self.x * other.x,
            y: self.y * other.y,
        }
    }
}

impl Div for Vector2 {
    type Output = Self;

    fn div(self, other: Self) -> Self {
        Self {
            x: self.x / other.x,
            y: self.y / other.y,
        }
    }
}

/// `Geometry2D.get_closest_point_to_segment`.
pub fn closest_point_to_segment(point: Vector2, a: Vector2, b: Vector2) -> Vector2 {
    let offset = point - a;
    let direction = b - a;
    let length = direction.length_squared();

    if length < 1e-20 {
        return a;
    }

    let along = direction.dot(offset) / length;

    if along <= 0.0 {
        a
    } else if along >= 1.0 {
        b
    } else {
        a + Vector2 {
            x: direction.x * along,
            y: direction.y * along,
        }
    }
}

pub fn lerpf(from: f64, to: f64, weight: f64) -> f64 {
    from + (to - from) * weight
}

pub fn is_equal_approx(a: f64, b: f64) -> bool {
    if a == b {
        return true;
    }

    let tolerance = (CMP_EPSILON * a.abs()).max(CMP_EPSILON);

    (a - b).abs() < tolerance
}

pub fn smoothstep(from: f64, to: f64, value: f64) -> f64 {
    if is_equal_approx(from, to) {
        return if from <= to {
            if value <= from { 0.0 } else { 1.0 }
        } else if value <= to {
            1.0
        } else {
            0.0
        };
    }

    let s = ((value - from) / (to - from)).clamp(0.0, 1.0);

    s * s * (3.0 - 2.0 * s)
}

/// `signf`: -1, 0 or 1.
pub fn signf(value: f64) -> f64 {
    if value > 0.0 {
        1.0
    } else if value < 0.0 {
        -1.0
    } else {
        0.0
    }
}

/// `minf`, which keeps the first value unless the second one is less.
pub fn minf(a: f64, b: f64) -> f64 {
    if a < b { a } else { b }
}

pub fn maxf(a: f64, b: f64) -> f64 {
    if a > b { a } else { b }
}

/// `roundi`: half away from zero.
pub fn roundi(value: f64) -> i64 {
    value.round() as i64
}
