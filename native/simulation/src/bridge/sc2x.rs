//! SC2X version 4 entry points for the sign table and the map profiles. The
//! documents themselves are in `document.rs`.

use godot::prelude::*;

use super::convert;
use sc2k_sim::formats::sc2x::xsgn::{Sign, Xsgn};
use sc2k_sim::formats::sc2x::{collection, limits};

#[derive(GodotClass)]
#[class(no_init, base = Object)]
pub struct NativeSc2x {}

fn failure(error: &str) -> VarDictionary {
    let mut result = VarDictionary::new();
    result.set("ok", false);
    result.set("error", error);
    result
}

fn success() -> VarDictionary {
    let mut result = VarDictionary::new();
    result.set("ok", true);
    result.set("error", "");
    result
}

fn packed(bytes: &[u8]) -> PackedByteArray {
    PackedByteArray::from(bytes)
}

fn signs_value(xsgn: &Xsgn) -> VarDictionary {
    let mut result = success();
    let active: Vec<&Sign> = xsgn.signs.iter().collect();
    result.set("capacity", xsgn.signs.len() as i64);
    result.set(
        "ids",
        &PackedInt64Array::from(active.iter().map(|sign| sign.id as i64).collect::<Vec<_>>().as_slice()),
    );
    result.set(
        "xs",
        &PackedInt32Array::from(active.iter().map(|sign| sign.x as i32).collect::<Vec<_>>().as_slice()),
    );
    result.set(
        "ys",
        &PackedInt32Array::from(active.iter().map(|sign| sign.y as i32).collect::<Vec<_>>().as_slice()),
    );
    result.set(
        "texts",
        &active
            .iter()
            .map(|sign| GString::from(sign.text.as_str()))
            .collect::<PackedStringArray>(),
    );
    result.set("extension", &packed(&collection::encode_extension(&xsgn.extension)));
    result
}

fn signs_from(request: &VarDictionary) -> Result<Xsgn, String> {
    let ids = convert::ints64(request, "ids");
    let xs = convert::ints32(request, "xs");
    let ys = convert::ints32(request, "ys");
    let texts = convert::strings(request, "texts");

    if xs.len() != ids.len() || ys.len() != ids.len() || texts.len() != ids.len() {
        return Err("Sign arrays have different lengths".into());
    }

    let mut signs = Vec::with_capacity(ids.len());

    for index in 0..ids.len() {
        let id = u32::try_from(ids[index]).map_err(|_| "A sign ID is outside the u32 range".to_string())?;

        if id == 0 {
            signs.push(Sign::default());
            continue;
        }

        let x = u16::try_from(xs[index]).map_err(|_| "A sign coordinate is outside the map".to_string())?;
        let y = u16::try_from(ys[index]).map_err(|_| "A sign coordinate is outside the map".to_string())?;
        signs.push(Sign {
            id,
            x,
            y,
            flags: 0,
            reserved: 0,
            text: texts[index].clone(),
        });
    }

    let extension = collection::decode_extension(&convert::bytes(request, "extension"), "XSGN")?;

    Ok(Xsgn { signs, extension })
}

#[godot_api]
impl NativeSc2x {
    /// `{ok, error, data}`: XSGN.bin from `{ids, xs, ys, texts, extension}`. A zero ID is an empty slot.
    #[func]
    fn encode_signs(request: VarDictionary, edge: i64) -> VarDictionary {
        let result = signs_from(&request).and_then(|xsgn| xsgn.encode(edge.max(0) as usize));

        match result {
            Ok(data) => {
                let mut value = success();
                value.set("data", &packed(&data));
                value
            }
            Err(error) => failure(&error),
        }
    }

    /// `{ok, error, capacity, ids, xs, ys, texts, extension}` for every slot.
    #[func]
    fn decode_signs(data: PackedByteArray, edge: i64) -> VarDictionary {
        match Xsgn::decode(data.as_slice(), edge.max(0) as usize) {
            Ok(xsgn) => signs_value(&xsgn),
            Err(error) => failure(&error),
        }
    }

    /// The error of one record-owned name, or an empty string.
    #[func]
    fn name_error(text: GString) -> GString {
        match collection::check_name(&text.to_string()) {
            Ok(()) => GString::new(),
            Err(error) => GString::from(error.as_str()),
        }
    }

    /// `{edge, facilities, signs, things, airplanes, helicopters, ships, sailboats, trains}`,
    /// or an empty dictionary for an edge without a profile.
    #[func]
    fn profile(edge: i64) -> VarDictionary {
        let mut result = VarDictionary::new();

        if let Some(profile) = limits::profile_for(edge.max(0) as usize) {
            result.set("edge", profile.edge as i64);
            result.set("facilities", profile.facilities as i64);
            result.set("signs", profile.signs as i64);
            result.set("things", profile.things as i64);
            result.set("airplanes", profile.airplanes as i64);
            result.set("helicopters", profile.helicopters as i64);
            result.set("ships", profile.ships as i64);
            result.set("sailboats", profile.sailboats as i64);
            result.set("trains", profile.trains as i64);
        }

        result
    }
}
