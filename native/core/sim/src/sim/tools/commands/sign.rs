//! User signs of original and SCLG cities, as SignCommand: XLAB holds the
//! text and XTXT links the tile. An SC2X version 4 city keeps its signs in
//! XSGN instead; see `formats::sc2x::xsgn::Xsgn::set_text`.

use crate::sim::city::City;
use crate::sim::geom::Vec2i;
use crate::sim::ids::sc2label_layout as layout;
use crate::sim::ids::sc2overlay_layout as overlay_layout;
use crate::sim::overlay;
use crate::sim::value::{Bytes, ToValue, Value};

const RECORD_SIZE: usize = layout::RECORD_SIZE as usize;
const MAX_TEXT_BYTES: usize = layout::MAX_TEXT_BYTES as usize;

/// The edit of one sign: the overlay and the label record before and after it.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct SignEdit {
    pub point: Vec2i,
    pub tile_index: i64,
    pub label_id: i64,
    pub old_overlay: i64,
    pub new_overlay: i64,
    pub old_record: Vec<u8>,
    pub new_record: Vec<u8>,
    /// The stored text: at most 23 characters.
    pub text: String,
}

/// The SignEditResult of a successful edit.
impl ToValue for SignEdit {
    fn to_value(&self) -> Value {
        Value::Object(
            "SignEditResult",
            vec![
                ("ok", Value::Bool(true)),
                ("command_type", Value::Str("sign".into())),
                ("point", Value::Vec2i(self.point)),
                ("tile_index", Value::Int(self.tile_index)),
                ("label_id", Value::Int(self.label_id)),
                ("old_overlay", Value::Int(self.old_overlay)),
                ("new_overlay", Value::Int(self.new_overlay)),
                ("old_record", Bytes(self.old_record.clone()).to_value()),
                ("new_record", Bytes(self.new_record.clone()).to_value()),
                ("text", Value::Str(self.text.clone())),
            ],
        )
    }
}

/// A failed sign edit as a SignEditResult.
pub fn rejected(message: &str) -> Value {
    Value::Object(
        "SignEditResult",
        vec![("ok", Value::Bool(false)), ("error", Value::Str(message.to_string()))],
    )
}

/// The label IDs that user signs can take in a label table of `label_bytes`.
fn sign_ids(label_bytes: usize) -> impl Iterator<Item = i64> {
    let extra = overlay::EXTRA_SIGN..(label_bytes / RECORD_SIZE) as i64;

    (overlay_layout::ORIGINAL_SIGN_FIRST..=overlay_layout::ORIGINAL_SIGN_LAST).chain(extra)
}

/// The text of a legacy label, as Latin-1 up to its terminator.
fn label(labels: &[u8], label_id: i64) -> String {
    let offset = label_id as usize * RECORD_SIZE;

    match labels.get(offset..offset + RECORD_SIZE) {
        Some(record) => {
            let declared = usize::from(record[layout::LENGTH_OFFSET as usize]).min(MAX_TEXT_BYTES);
            let text = &record[layout::TEXT_OFFSET as usize..layout::TEXT_OFFSET as usize + declared];

            text.iter().take_while(|&&byte| byte != 0).map(|&byte| char::from(byte)).collect()
        }
        None => String::new(),
    }
}

/// Store `text` in a legacy label: 23 ASCII bytes and a terminator. Other
/// characters become spaces. The bytes after the terminator stay, as the label
/// editor of the original keeps them.
fn write_label(labels: &mut [u8], label_id: i64, text: &str) -> bool {
    let offset = label_id as usize * RECORD_SIZE;

    let Some(record) = labels.get_mut(offset..offset + RECORD_SIZE) else {
        return false;
    };

    let ascii: Vec<u8> = text
        .chars()
        .map(|character| if character.is_ascii() { character as u8 } else { b' ' })
        .take(MAX_TEXT_BYTES)
        .collect();
    let start = layout::TEXT_OFFSET as usize;
    record[layout::LENGTH_OFFSET as usize] = ascii.len() as u8;
    record[start..start + ascii.len()].copy_from_slice(&ascii);
    record[start + ascii.len()] = 0;

    true
}

/// Add, change, or remove (with empty text) the sign at `point`.
pub fn set_sign(city: &mut City, point: Vec2i, text: &str) -> Result<SignEdit, String> {
    let tile_index = city.index_of(point.x, point.y);

    if tile_index < 0 {
        return Err("sign position is outside the city".into());
    }

    let old_overlay = overlay::read(&city.xtxt.data, tile_index);

    if old_overlay != 0 && !overlay::is_sign(old_overlay) {
        return Err("this tile has a protected simulation label".into());
    }

    let labels_valid = city
        .chunk("XLAB")
        .is_some_and(|chunk| chunk.data.len() as i64 == city.decoded_size("XLAB"));
    let mut label_id = old_overlay;

    if label_id == 0 && !text.is_empty() {
        let label_bytes = city.decoded_size("XLAB").max(0) as usize;
        let labels = &city.xlab.data;
        label_id = sign_ids(label_bytes)
            .find(|&id| !labels_valid || label(labels, id).is_empty())
            .ok_or("all user sign labels are in use")?;
    }

    if label_id == 0 {
        return Err("this tile does not have a sign".into());
    }

    if city.chunk("XLAB").is_none() {
        return Err("XLAB data is missing".into());
    }

    let offset = label_id as usize * RECORD_SIZE;
    let record = |labels: &[u8]| labels.get(offset..offset + RECORD_SIZE).map(<[u8]>::to_vec).unwrap_or_default();
    let old_record = record(&city.xlab.data);
    let mut labels = city.xlab.data.clone();

    if !labels_valid || !write_label(&mut labels, label_id, text) {
        return Err("cannot store the sign text".into());
    }

    let new_record = record(&labels);
    let new_overlay = if text.is_empty() { 0 } else { label_id };
    let mut overlays = city.xtxt.data.clone();
    overlay::write(&mut overlays, tile_index, new_overlay);
    city.xlab.replace(labels);
    city.xtxt.replace(overlays);

    Ok(SignEdit {
        point,
        tile_index,
        label_id,
        old_overlay,
        new_overlay,
        old_record,
        new_record,
        text: text.chars().take(MAX_TEXT_BYTES).collect(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::testing::empty_city;

    #[test]
    fn a_sign_takes_the_first_free_label_and_keeps_its_tail() {
        let mut city = empty_city(128);
        let first = overlay_layout::ORIGINAL_SIGN_FIRST;
        let mut labels = city.xlab.data.clone();
        assert!(write_label(&mut labels, first, "Taken"));
        city.xlab.replace(labels);

        let edit = set_sign(&mut city, Vec2i::new(3, 4), "Pier é").expect("a free label");
        assert_eq!(edit.label_id, first + 1);
        assert_eq!(overlay::read(&city.xtxt.data, edit.tile_index), first + 1);
        assert_eq!(label(&city.xlab.data, first + 1), "Pier  ", "non-ASCII characters become spaces");

        let renamed = set_sign(&mut city, Vec2i::new(3, 4), "P").unwrap();
        assert_eq!(&renamed.new_record[..4], &[1, b'P', 0, b'e'], "the bytes after the terminator stay");

        let removed = set_sign(&mut city, Vec2i::new(3, 4), "").unwrap();
        assert_eq!((removed.old_overlay, removed.new_overlay), (first + 1, 0));
        assert_eq!(
            set_sign(&mut city, Vec2i::new(3, 4), ""),
            Err("this tile does not have a sign".into())
        );
        assert!(set_sign(&mut city, Vec2i::new(128, 0), "x").is_err());
    }

    #[test]
    fn simulation_labels_are_protected() {
        let mut city = empty_city(128);
        let mut overlays = city.xtxt.data.clone();
        overlay::write(&mut overlays, 5, overlay_layout::ORIGINAL_FACILITY_FIRST);
        city.xtxt.replace(overlays);

        let error = set_sign(&mut city, Vec2i::new(0, 5), "x").unwrap_err();
        assert_eq!(error, "this tile has a protected simulation label");
    }
}
