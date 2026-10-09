//! A list of EffectEvent values as one integer array. A large demolition
//! returns an effect for each tile, and one Godot dictionary for each effect
//! is slow to build and to read.

use super::value::Value;

/// The GDScript class of a packed list.
pub const PACKED_CLASS: &str = "EffectEventList";

/// The integers of one effect: the type index, point x and y, sprite ID,
/// screen offset x and y, flip, frame, altitude, frames, frame time,
/// distance, and depth point x and y.
pub const STRIDE: usize = 14;

/// The EffectEvent fields in the order of `gd_object!`.
const FIELDS: [&str; 11] = [
    "type",
    "point",
    "sprite_id",
    "screen_offset",
    "flip",
    "frame",
    "altitude",
    "frames",
    "frame_msec",
    "distance",
    "depth_point",
];

/// The packed integers and the distinct type names that they index.
#[derive(Debug, Default, PartialEq)]
pub struct PackedEffects {
    pub values: Vec<i64>,
    pub types: Vec<String>,
}

/// The packed form of `items`, or None when an item is not an EffectEvent.
pub fn pack(items: &[Value]) -> Option<PackedEffects> {
    if items.is_empty() || !items.iter().all(is_effect) {
        return None;
    }

    let mut packed = PackedEffects {
        values: Vec::with_capacity(items.len() * STRIDE),
        types: Vec::new(),
    };

    for item in items {
        let Value::Object(_, fields) = item else {
            return None;
        };

        let type_index = match &fields[0].1 {
            Value::Str(name) => type_index(&mut packed.types, name),
            _ => return None,
        };

        let (point, offset, depth) = (vec2(&fields[1].1)?, vec2(&fields[3].1)?, vec2(&fields[10].1)?);
        let flip = matches!(fields[4].1, Value::Bool(true)) as i64;

        packed.values.extend([
            type_index,
            point.0,
            point.1,
            int(&fields[2].1)?,
            offset.0,
            offset.1,
            flip,
            int(&fields[5].1)?,
            int(&fields[6].1)?,
            int(&fields[7].1)?,
            int(&fields[8].1)?,
            int(&fields[9].1)?,
            depth.0,
            depth.1,
        ]);
    }

    Some(packed)
}

fn is_effect(item: &Value) -> bool {
    match item {
        Value::Object(class, fields) => {
            *class == "EffectEvent"
                && fields.len() == FIELDS.len()
                && fields.iter().zip(FIELDS).all(|((name, _), expected)| *name == expected)
        }
        _ => false,
    }
}

// Most effects have no type. A list holds only a few names.
fn type_index(types: &mut Vec<String>, name: &str) -> i64 {
    if let Some(index) = types.iter().position(|known| known == name) {
        return index as i64;
    }

    types.push(name.to_string());
    types.len() as i64 - 1
}

fn vec2(value: &Value) -> Option<(i64, i64)> {
    match value {
        Value::Vec2i(point) => Some((point.x, point.y)),
        _ => None,
    }
}

fn int(value: &Value) -> Option<i64> {
    match value {
        Value::Int(number) => Some(*number),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::events::EffectEvent;
    use crate::sim::geom::Vec2i;
    use crate::sim::value::ToValue;

    #[test]
    fn effect_lists_pack_every_field_and_share_type_names() {
        let mut dust = EffectEvent::new(Vec2i::new(3, 4), 1393, Vec2i::new(-2, 5), true, 7, 2);
        dust.depth_point = Vec2i::new(9, 8);
        let events = vec![
            dust,
            EffectEvent::earthquake(),
            EffectEvent::new(Vec2i::new(1, 2), 1392, Vec2i::ZERO, false, 0, -1),
        ];
        let Value::Array(items) = events.to_value() else {
            panic!("an effect list is an array");
        };

        let packed = pack(&items).expect("effect lists pack");
        assert_eq!(packed.types, vec!["".to_string(), "earthquake".to_string()]);
        assert_eq!(packed.values.len(), 3 * STRIDE);
        assert_eq!(&packed.values[..STRIDE], &[0, 3, 4, 1393, -2, 5, 1, 7, 2, 24, 5, 4, 9, 8]);
        assert_eq!(packed.values[STRIDE], 1);
        assert_eq!(packed.values[2 * STRIDE], 0);
    }

    #[test]
    fn other_lists_stay_arrays() {
        assert_eq!(pack(&[]), None);
        assert_eq!(pack(&[Value::Int(1)]), None);
        assert_eq!(pack(&[EffectEvent::earthquake().to_value(), Value::Nil]), None);
    }
}
