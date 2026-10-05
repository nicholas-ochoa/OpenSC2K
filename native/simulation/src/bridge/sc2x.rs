//! SC2X version 4 entry points for `Sc2xDocument`. GDScript reads and writes
//! the ZIP archive and the metadata; these calls encode, decode, and check the
//! binary entries and convert between them and the working chunks.

use godot::prelude::*;

use super::convert;
use sc2k_sim::formats::sc2x::framing::{self, PreservedChunk, TextOccurrence};
use sc2k_sim::formats::sc2x::project::{self, SplitOptions, Working};
use sc2k_sim::formats::sc2x::scenario::{self, Scenario};
use sc2k_sim::formats::sc2x::xmic::Xmic;
use sc2k_sim::formats::sc2x::xsgn::{Sign, Xsgn};
use sc2k_sim::formats::sc2x::xthg::Xthg;
use sc2k_sim::formats::sc2x::{collection, labels, limits};

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

fn strings(values: &[String]) -> PackedStringArray {
    values.iter().map(GString::from).collect()
}

fn usize_of(dictionary: &VarDictionary, key: &str) -> usize {
    usize::try_from(convert::int(dictionary, key, 0)).unwrap_or(0)
}

fn u32_of(dictionary: &VarDictionary, key: &str) -> u32 {
    u32::try_from(convert::int(dictionary, key, 0)).unwrap_or(0)
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

    /// Check one binary entry of a map with `edge` tiles. Returns an error or an empty string.
    #[func]
    fn validate_entry(name: GString, data: PackedByteArray, edge: i64) -> GString {
        let edge = edge.max(0) as usize;
        let bytes = data.as_slice();
        let result = match name.to_string().as_str() {
            "XMIC" => Xmic::decode(bytes, edge).map(|_| ()),
            "XTHG" => Xthg::decode(bytes).map(|_| ()),
            "XSGN" => Xsgn::decode(bytes, edge).map(|_| ()),
            "TEXT" => framing::decode_text(bytes).map(|_| ()),
            "CUNK" => framing::decode_chunks(bytes).map(|_| ()),
            "SCEN" => Scenario::from_schema2(bytes, edge).map(|_| ()),
            "TMPL" => scenario::parse_template(bytes).and_then(|descriptors| {
                if scenario::template_scenario_size(&descriptors) == Some(scenario::SCHEMA2_SIZE) {
                    Ok(())
                } else {
                    Err("TMPL does not describe SCEN schema 2".into())
                }
            }),
            _ => Ok(()),
        };

        match result {
            Ok(()) => GString::new(),
            Err(error) => GString::from(error.as_str()),
        }
    }

    /// `{ok, error, data}`: SCEN schema 2 from a 52-byte or 56-byte original payload.
    #[func]
    fn upgrade_scenario(data: PackedByteArray) -> VarDictionary {
        match Scenario::from_legacy(data.as_slice()) {
            Ok(scenario) => {
                let mut value = success();
                value.set("data", &packed(&scenario.to_schema2()));
                value
            }
            Err(error) => failure(&error),
        }
    }

    /// The schema 2 template, or an empty array when `data` has other descriptors.
    #[func]
    fn upgrade_template(data: PackedByteArray) -> PackedByteArray {
        scenario::upgrade_template(data.as_slice())
            .map(|bytes| packed(&bytes))
            .unwrap_or_default()
    }

    /// TEXT.bin from `[{source_order, source_occurrence, payload}]`.
    #[func]
    fn encode_text(occurrences: VarArray) -> PackedByteArray {
        let values: Vec<TextOccurrence> = occurrences
            .iter_shared()
            .filter_map(|value| value.try_to::<VarDictionary>().ok())
            .map(|entry| TextOccurrence {
                source_order: u32_of(&entry, "source_order"),
                source_occurrence: u32_of(&entry, "source_occurrence"),
                payload: convert::bytes(&entry, "payload"),
            })
            .collect();

        packed(&framing::encode_text(&values))
    }

    /// `{ok, error, occurrences: [{source_order, source_occurrence, payload}]}`.
    #[func]
    fn decode_text(data: PackedByteArray) -> VarDictionary {
        match framing::decode_text(data.as_slice()) {
            Ok(values) => {
                let mut list = VarArray::new();

                for occurrence in values {
                    let mut entry = VarDictionary::new();
                    entry.set("source_order", occurrence.source_order as i64);
                    entry.set("source_occurrence", occurrence.source_occurrence as i64);
                    entry.set("payload", &packed(&occurrence.payload));
                    list.push(&entry.to_variant());
                }

                let mut value = success();
                value.set("occurrences", &list);
                value
            }
            Err(error) => failure(&error),
        }
    }

    /// CUNK.bin from `[{chunk_id, occurrence, source_order, flags, payload}]`.
    #[func]
    fn encode_chunks(chunks: VarArray) -> VarDictionary {
        let mut values = Vec::new();

        for value in chunks.iter_shared() {
            let Ok(entry) = value.try_to::<VarDictionary>() else {
                return failure("A preserved chunk is not a dictionary");
            };
            let id = convert::string(&entry, "chunk_id").into_bytes();

            if id.len() != 4 {
                return failure("A preserved chunk ID is not four bytes");
            }

            values.push(PreservedChunk {
                chunk_id: [id[0], id[1], id[2], id[3]],
                occurrence: u32_of(&entry, "occurrence"),
                source_order: u32_of(&entry, "source_order"),
                flags: u32_of(&entry, "flags"),
                payload: convert::bytes(&entry, "payload"),
            });
        }

        let data = framing::encode_chunks(&values);

        match framing::decode_chunks(&data) {
            Ok(_) => {
                let mut value = success();
                value.set("data", &packed(&data));
                value
            }
            Err(error) => failure(&error),
        }
    }

    /// `{ok, error, chunks: [{chunk_id, occurrence, source_order, flags, payload}]}`.
    #[func]
    fn decode_chunks(data: PackedByteArray) -> VarDictionary {
        match framing::decode_chunks(data.as_slice()) {
            Ok(values) => {
                let mut list = VarArray::new();

                for chunk in values {
                    let mut entry = VarDictionary::new();
                    entry.set("chunk_id", String::from_utf8_lossy(&chunk.chunk_id).as_ref());
                    entry.set("occurrence", chunk.occurrence as i64);
                    entry.set("source_order", chunk.source_order as i64);
                    entry.set("flags", chunk.flags as i64);
                    entry.set("payload", &packed(&chunk.payload));
                    list.push(&entry.to_variant());
                }

                let mut value = success();
                value.set("chunks", &list);
                value
            }
            Err(error) => failure(&error),
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

    /// Save working or legacy chunks as version 4 entries. The request has `edge`,
    /// `xtxt`, `xmic`, `xthg`, `labels`, `wide_labels`, optional `signs` (XSGN.bin
    /// of a working document), `object_ids`, `object_names`, `next_sign_id`,
    /// `next_object_id`, the least `facility_capacity`, `thing_capacity`, and
    /// `sign_capacity`, `trim_free_tail` for a new city, and the encoded unowned
    /// `xmic_extension` and `xthg_extension` blocks from `join`. The result has `entries` (`XTXT`, `XMIC`, `XTHG`, `XSGN`),
    /// `mayor_name`, `team_names`, `residual_labels`, the next IDs, and `issues`.
    #[func]
    fn split(request: VarDictionary) -> VarDictionary {
        let edge = usize_of(&request, "edge");
        let xtxt = convert::bytes(&request, "xtxt");
        let xmic = convert::bytes(&request, "xmic");
        let xthg = convert::bytes(&request, "xthg");
        let label_table = convert::bytes(&request, "labels");
        let signs = convert::bytes(&request, "signs");
        let signs = if request.contains_key("signs") {
            match Xsgn::decode(&signs, edge) {
                Ok(xsgn) => Some(xsgn),
                Err(error) => return failure(&error),
            }
        } else {
            None
        };
        let options = SplitOptions {
            signs,
            object_ids: convert::ints64(&request, "object_ids")
                .iter()
                .map(|id| u32::try_from(*id).unwrap_or(0))
                .collect(),
            object_names: convert::strings(&request, "object_names"),
            next_sign_id: u32_of(&request, "next_sign_id"),
            next_object_id: u32_of(&request, "next_object_id"),
            facility_capacity: usize_of(&request, "facility_capacity"),
            thing_capacity: usize_of(&request, "thing_capacity"),
            sign_capacity: usize_of(&request, "sign_capacity"),
            trim_free_tail: convert::boolean(&request, "trim_free_tail", false),
            xmic_extension: match collection::decode_extension(&convert::bytes(&request, "xmic_extension"), "XMIC") {
                Ok(blocks) => blocks,
                Err(error) => return failure(&error),
            },
            xthg_extension: match collection::decode_extension(&convert::bytes(&request, "xthg_extension"), "XTHG") {
                Ok(blocks) => blocks,
                Err(error) => return failure(&error),
            },
        };
        let working = Working {
            edge,
            xtxt: &xtxt,
            xmic: &xmic,
            xthg: &xthg,
            labels: &label_table,
            wide_labels: convert::boolean(&request, "wide_labels", false),
        };
        let split = match project::split(&working, options) {
            Ok(split) => split,
            Err(error) => return failure(&error),
        };
        let mut entries = VarDictionary::new();
        entries.set("XTXT", &packed(&split.markers));

        for (name, data) in [
            ("XMIC", split.xmic.encode(edge)),
            ("XTHG", split.xthg.encode()),
            ("XSGN", split.xsgn.encode(edge)),
        ] {
            match data {
                Ok(data) => entries.set(name, &packed(&data)),
                Err(error) => return failure(&error),
            }
        }

        let mut result = success();
        result.set("entries", &entries);
        result.set("mayor_name", split.mayor_name.as_str());
        result.set("team_names", &strings(&split.team_names));
        result.set("residual_labels", &packed(&split.residual_labels));
        result.set("next_sign_id", split.next_sign_id as i64);
        result.set("next_object_id", split.next_object_id as i64);
        result.set("issues", &strings(&split.issues));
        result.set(
            "object_ids",
            &PackedInt64Array::from(
                split
                    .xthg
                    .things
                    .iter()
                    .map(|thing| thing.object_id as i64)
                    .collect::<Vec<_>>()
                    .as_slice(),
            ),
        );
        result
    }

    /// Rebuild working chunks from `{edge, XTXT, XMIC, XTHG, mayor_name, team_names}`.
    /// The result has `xtxt`, `xmic`, `xthg`, `labels`, `object_ids`, `object_names`,
    /// and the encoded extension blocks that the application does not own,
    /// `xmic_extension` and `xthg_extension`, for the next `split`.
    #[func]
    fn join(request: VarDictionary) -> VarDictionary {
        let edge = usize_of(&request, "edge");
        let xmic = match Xmic::decode(&convert::bytes(&request, "XMIC"), edge) {
            Ok(xmic) => xmic,
            Err(error) => return failure(&error),
        };
        let xthg = match Xthg::decode(&convert::bytes(&request, "XTHG")) {
            Ok(xthg) => xthg,
            Err(error) => return failure(&error),
        };
        let markers = convert::bytes(&request, "XTXT");
        let mayor = convert::string(&request, "mayor_name");
        let teams = convert::strings(&request, "team_names");

        match project::join(edge, &markers, &xmic, &xthg, &mayor, &teams) {
            Ok(joined) => {
                let mut result = success();
                result.set("xtxt", &packed(&joined.xtxt));
                result.set("xmic", &packed(&joined.xmic));
                result.set("xthg", &packed(&joined.xthg));
                result.set("labels", &packed(&joined.labels));
                result.set(
                    "object_ids",
                    &PackedInt64Array::from(joined.object_ids.iter().map(|id| *id as i64).collect::<Vec<_>>().as_slice()),
                );
                result.set("object_names", &strings(&joined.object_names));
                result.set("xmic_extension", &packed(&collection::encode_extension(&joined.xmic_extension)));
                result.set("xthg_extension", &packed(&collection::encode_extension(&joined.xthg_extension)));
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// The runtime label record size of a wide or legacy table.
    #[func]
    fn label_record_size(wide: bool) -> i64 {
        labels::record_size(wide) as i64
    }
}
