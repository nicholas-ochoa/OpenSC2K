//! Projection between the runtime working layout and the version 4 structures.
//!
//! The simulation, the tools, and the renderer read one combined tile index:
//! XTXT holds a marker, a facility link, or the top moving object of each tile,
//! and each occupying object keeps the value below it in its label field. A
//! version 4 working document uses that index as derived runtime state only.
//! `split` saves it as marker bytes, facility footprints, and object occupancy;
//! `join` rebuilds it after a load. For a working document, `join(split(W))`
//! restores the same index, records, and names.
//!
//! A legacy city also keeps signs and names in the index and in XLAB. `split`
//! gathers them into XSGN, the owning records, and the shared names.

use std::collections::{BTreeMap, HashSet};

use super::collection::{ExtensionBlock, MAX_NAME_BYTES, MAX_NAME_CODE_POINTS, check_name};
use super::labels;
use super::xmic::{Facility, Footprint, Xmic};
use super::xsgn::{Sign, Xsgn};
use super::xthg::{self, Thing, Xthg};
use crate::sim::ids::sc2microsim_layout as microsim;
use crate::sim::ids::sc2overlay_layout as layout;
use crate::sim::ids::sc2thing_layout as thing_layout;
use crate::sim::overlay;
use crate::sim::things;

/// Tile index values from here through 255 are markers, such as fire and flood.
pub const MARKER_FIRST: i64 = layout::ORIGINAL_RESERVED_FIRST;
/// The most facility records that the tile index can link.
pub const MAX_WORKING_FACILITIES: usize = (microsim::ORIGINAL_COUNT + layout::EXTRA_SIGN - layout::EXTRA_FACILITY) as usize;
/// The most moving-object records that the tile index can link.
pub const MAX_WORKING_THINGS: usize = (thing_layout::ORIGINAL_COUNT + 0x1_0000 - layout::EXTRA_THING) as usize;
const RECORD: usize = thing_layout::RECORD_SIZE as usize;
const LEGACY_SIZE: usize = thing_layout::ORIGINAL_SIZE as usize;
const FIELD_LABEL: usize = thing_layout::FIELD_LABEL as usize;

/// The chunks of one working or legacy document.
pub struct Working<'a> {
    pub edge: usize,
    pub xtxt: &'a [u8],
    pub xmic: &'a [u8],
    pub xthg: &'a [u8],
    pub labels: &'a [u8],
    pub wide_labels: bool,
}

#[derive(Default)]
pub struct SplitOptions {
    /// The signs of a version 4 working document. `None` gathers signs from
    /// the tile index and the label table, as in a legacy city.
    pub signs: Option<Xsgn>,
    /// Object identity and names by slot. Missing identities get new IDs.
    pub object_ids: Vec<u32>,
    pub object_names: Vec<String>,
    pub next_sign_id: u32,
    pub next_object_id: u32,
    /// The least capacity of each collection, normally the map profile.
    pub facility_capacity: usize,
    pub thing_capacity: usize,
    pub sign_capacity: usize,
    /// Drop empty slots past the least capacities, as for a new city. An import
    /// keeps its larger capacity.
    pub trim_free_tail: bool,
}

#[derive(Debug, Default)]
pub struct Split {
    pub markers: Vec<u8>,
    pub xmic: Xmic,
    pub xthg: Xthg,
    pub xsgn: Xsgn,
    pub mayor_name: String,
    pub team_names: Vec<String>,
    /// The legacy label table without the names that moved. Empty for a wide table.
    pub residual_labels: Vec<u8>,
    pub next_sign_id: u32,
    pub next_object_id: u32,
    /// Links that the version 4 structures cannot hold. Each one is reported.
    pub issues: Vec<String>,
}

#[derive(Debug, Default, PartialEq, Eq)]
pub struct Joined {
    pub xtxt: Vec<u8>,
    pub xmic: Vec<u8>,
    pub xthg: Vec<u8>,
    pub labels: Vec<u8>,
    pub object_ids: Vec<u32>,
    pub object_names: Vec<String>,
}

pub fn facility_label(record: usize) -> usize {
    overlay::facility_id(record as i64) as usize
}

fn wide_field(kind: u8, field: usize) -> bool {
    let kind = kind as i64;
    let field = field as i64;

    field == thing_layout::FIELD_X
        || field == thing_layout::FIELD_Y
        || field == thing_layout::FIELD_DX
        || field == thing_layout::FIELD_DY
        || field == thing_layout::FIELD_LABEL
        || ((thing_layout::TYPE_TRAIN_ENGINE..=thing_layout::TYPE_SUBWAY_CAR).contains(&kind)
            && (field == thing_layout::FIELD_STATE || field == thing_layout::FIELD_PX || field == thing_layout::FIELD_PY))
        || (kind == thing_layout::TYPE_MAXIS_MAN && field == thing_layout::FIELD_GOAL)
}

/// One record of a split-plane table: 12 low-plane and 12 high-plane bytes.
fn working_record(data: &[u8], slot: usize) -> [u8; 24] {
    let mut record = [0u8; 24];

    if data.len() == LEGACY_SIZE {
        record[..RECORD].copy_from_slice(&data[slot * RECORD..(slot + 1) * RECORD]);
    } else {
        let half = data.len() / 2;
        record[..RECORD].copy_from_slice(&data[slot * RECORD..(slot + 1) * RECORD]);
        record[RECORD..].copy_from_slice(&data[half + slot * RECORD..half + (slot + 1) * RECORD]);
    }

    record
}

fn field_value(record: &[u8; 24], field: usize) -> u16 {
    let low = record[field] as u16;

    if wide_field(record[0], field) {
        low | ((record[RECORD + field] as u16) << 8)
    } else {
        low
    }
}

/// The core fields of a working record. Identity, name, and flags are set by the caller.
fn core_of(record: &[u8; 24]) -> Thing {
    let ship = record[0] == xthg::TYPE_SHIP;
    let high = &record[RECORD..];

    Thing {
        kind: record[0],
        direction: record[1],
        state: field_value(record, 2),
        x: field_value(record, 3),
        y: field_value(record, 4),
        z: field_value(record, 5),
        px: field_value(record, 6),
        py: field_value(record, 7),
        dx: field_value(record, 8),
        dy: field_value(record, 9),
        reserved: 0,
        goal: field_value(record, 11),
        home_x1: if ship { high[0] as u16 | ((high[1] as u16) << 8) } else { 0 },
        home_y1: if ship { high[2] as u16 | ((high[5] as u16) << 8) } else { 0 },
        ..Default::default()
    }
}

/// The working record that a core describes, with `label` in the label field.
fn record_of(thing: &Thing, label: u16) -> [u8; 24] {
    let values = [
        thing.kind as u16,
        thing.direction as u16,
        thing.state,
        thing.x,
        thing.y,
        thing.z,
        thing.px,
        thing.py,
        thing.dx,
        thing.dy,
        label,
        thing.goal,
    ];
    let mut record = [0u8; 24];

    for (field, value) in values.iter().enumerate() {
        record[field] = *value as u8;

        if wide_field(thing.kind, field) {
            record[RECORD + field] = (*value >> 8) as u8;
        }
    }

    if thing.kind == xthg::TYPE_SHIP {
        record[RECORD] = thing.home_x1 as u8;
        record[RECORD + 1] = (thing.home_x1 >> 8) as u8;
        record[RECORD + 2] = thing.home_y1 as u8;
        record[RECORD + 5] = (thing.home_y1 >> 8) as u8;
    }

    record
}

/// Check that the working layout can hold the fields of `thing`.
fn check_working_fields(slot: usize, thing: &Thing) -> Result<(), String> {
    let values = [thing.state, thing.z, thing.px, thing.py, thing.goal];
    let fields = [2, 5, 6, 7, 11];

    for (value, field) in values.iter().zip(fields) {
        if *value > 0xff && !wide_field(thing.kind, field) {
            return Err(format!("XTHG slot {} field {} is wider than this object type allows", slot, field));
        }
    }

    if thing.kind != xthg::TYPE_SHIP && (thing.home_x1 != 0 || thing.home_y1 != 0) {
        return Err(format!("XTHG slot {} has a ship home but is not a ship", slot));
    }

    Ok(())
}

fn limit_name(name: String, issues: &mut Vec<String>, owner: &str) -> String {
    if check_name(&name).is_ok() {
        return name;
    }

    issues.push(format!(
        "{} name is longer than {} characters; it was shortened",
        owner, MAX_NAME_CODE_POINTS
    ));
    let mut text = String::new();

    for character in name.chars().filter(|character| *character != '\0').take(MAX_NAME_CODE_POINTS) {
        if text.len() + character.len_utf8() > MAX_NAME_BYTES {
            break;
        }

        text.push(character);
    }

    text
}

fn point(index: usize, edge: usize) -> (usize, usize) {
    (index / edge, index % edge)
}

/// Save a working or legacy document as version 4 structures.
pub fn split(working: &Working, options: SplitOptions) -> Result<Split, String> {
    let edge = working.edge;
    let cells = edge * edge;

    if overlay::count(working.xtxt) as usize != cells {
        return Err(format!(
            "XTXT has {} bytes; it does not match a {} tile map",
            working.xtxt.len(),
            edge
        ));
    }

    if !working.xmic.len().is_multiple_of(8) {
        return Err("XMIC is not a whole number of 8-byte records".into());
    }

    let mut facility_count = working.xmic.len() / 8;
    let mut thing_count = things::count(working.xthg) as usize;

    if options.trim_free_tail {
        let used = |record: usize| working.xmic[record * 8..record * 8 + 8].iter().any(|byte| *byte != 0);
        let last = (0..facility_count)
            .rev()
            .find(|record| used(*record))
            .map_or(0, |record| record + 1);
        facility_count = facility_count.min(last.max(options.facility_capacity));
        let last = (0..thing_count)
            .rev()
            .find(|slot| working_record(working.xthg, *slot) != [0; 24])
            .map_or(0, |slot| slot + 1);
        thing_count = thing_count.min(last.max(options.thing_capacity));
    }
    let gather_signs = options.signs.is_none();
    let mut issues = Vec::new();
    let mut markers = vec![0u8; cells];
    let mut owners: Vec<Vec<usize>> = vec![Vec::new(); facility_count];
    let mut sign_tiles: Vec<(usize, usize)> = Vec::new();
    let mut occupancy: Vec<Option<(usize, u16)>> = vec![None; thing_count];
    let mut below = vec![0u16; thing_count];

    for (index, marker) in markers.iter_mut().enumerate() {
        let mut value = overlay::read(working.xtxt, index as i64);

        if value == 0 {
            continue;
        }

        let (x, y) = point(index, edge);
        let mut stack: Vec<usize> = Vec::new();
        let mut broken = false;

        while overlay::is_thing(value) {
            let record = overlay::thing_record(value);
            let valid = record >= 0 && (record as usize) < thing_count;

            if !valid
                || occupancy[record as usize].is_some()
                || stack.contains(&(record as usize))
                || working.xthg[record as usize * RECORD] == 0
            {
                issues.push(format!(
                    "Tile ({}, {}) links to object record {}, which is free, missing, or linked twice",
                    x, y, record
                ));
                broken = true;
                break;
            }

            stack.push(record as usize);
            value = things::field(working.xthg, record, FIELD_LABEL as i64);
        }

        let base = if broken {
            0
        } else if overlay::is_sign(value) {
            if gather_signs {
                sign_tiles.push((index, value as usize));
            } else {
                issues.push(format!("Tile ({}, {}) links to sign {} in the working tile index", x, y, value));
            }

            0
        } else if overlay::is_facility(value) {
            let record = overlay::facility_record(value);

            if record > 0 && (record as usize) < facility_count && working.xmic[record as usize * 8] != 0 {
                owners[record as usize].push(index);
                value
            } else {
                issues.push(format!(
                    "Tile ({}, {}) links to facility record {}, which is free or reserved",
                    x, y, record
                ));
                0
            }
        } else if (MARKER_FIRST..=0xff).contains(&value) {
            *marker = value as u8;
            value
        } else if value != 0 {
            issues.push(format!(
                "Tile ({}, {}) holds tile index value {}, which is not a link or a marker",
                x, y, value
            ));
            0
        } else {
            0
        };

        for (position, record) in stack.iter().enumerate() {
            occupancy[*record] = Some((index, (stack.len() - 1 - position) as u16));
            below[*record] = if position + 1 < stack.len() {
                overlay::thing_id(stack[position + 1] as i64) as u16
            } else {
                base as u16
            };
        }
    }

    let mut migrated: HashSet<usize> = HashSet::new();
    let label = |id: usize| labels::read(working.labels, id, working.wide_labels).unwrap_or_default();

    // Facilities keep their slots. Slot 0 is reserved and keeps no name.
    let facility_capacity = facility_count.max(options.facility_capacity);
    let mut facilities = Vec::with_capacity(facility_capacity);

    for record in 0..facility_capacity {
        let mut facility = Facility::default();

        if record < facility_count {
            facility.tile_id = working.xmic[record * 8];
            facility.stats.copy_from_slice(&working.xmic[record * 8 + 1..record * 8 + 8]);
        }

        if record != 0 && facility.tile_id != 0 {
            facility.footprint = Footprint::from_indices(owners.get(record).map_or(&[], Vec::as_slice), edge);
            facility.name = limit_name(label(facility_label(record)), &mut issues, &format!("Facility {}", record));
            migrated.insert(facility_label(record));
        }

        facilities.push(facility);
    }

    // Moving objects keep their slots, fields, and occupancy.
    let thing_capacity = thing_count.max(options.thing_capacity);
    let mut next_object_id = options.next_object_id.max(1);
    let mut used_ids: HashSet<u32> = HashSet::new();
    let mut thing_records = Vec::with_capacity(thing_capacity);
    let mut overrides = Vec::new();
    let mut occupied_tiles = Vec::new();

    for slot in 0..thing_capacity {
        if slot >= thing_count {
            thing_records.push(Thing::default());
            continue;
        }

        let mut target = working_record(working.xthg, slot);
        let mut thing = core_of(&target);

        if thing.kind > xthg::TYPE_LAST {
            return Err(format!("XTHG slot {} has unknown type {}", slot, thing.kind));
        }

        let mut label_value = 0u16;

        if thing.is_active() {
            let supplied = options.object_ids.get(slot).copied().unwrap_or(0);

            thing.object_id = if supplied != 0 && !used_ids.contains(&supplied) {
                supplied
            } else {
                while used_ids.contains(&next_object_id) || next_object_id == 0 {
                    next_object_id = next_object_id.wrapping_add(1);
                }

                next_object_id
            };

            used_ids.insert(thing.object_id);
            next_object_id = next_object_id.max(thing.object_id.wrapping_add(1)).max(1);

            let name = match options.object_names.get(slot) {
                Some(name) => name.clone(),
                None if !working.wide_labels && slot < thing_layout::ORIGINAL_COUNT as usize => {
                    let id = overlay::thing_id(slot as i64) as usize;
                    migrated.insert(id);
                    label(id)
                }
                None => String::new(),
            };
            thing.name = limit_name(name, &mut issues, &format!("Object {}", slot));

            if let Some((tile, depth)) = occupancy[slot] {
                thing.flags = xthg::FLAG_OCCUPANT | (depth << xthg::FLAG_DEPTH_SHIFT);
                label_value = below[slot];
                target[FIELD_LABEL] = label_value as u8;
                target[RECORD + FIELD_LABEL] = (label_value >> 8) as u8;
                let (x, y) = point(tile, edge);

                if (x, y) != (thing.x as usize, thing.y as usize) {
                    occupied_tiles.push((slot, x as u16, y as u16));
                }
            }
        }

        if record_of(&thing, label_value) != target {
            overrides.push((slot, target));
        }

        thing_records.push(thing);
    }

    let mut thing_extension = Vec::new();

    if !overrides.is_empty() {
        let mut data = Vec::with_capacity(overrides.len() * xthg::WORKING_RECORD_ENTRY);

        for (slot, record) in &overrides {
            data.extend_from_slice(&(*slot as u32).to_be_bytes());
            data.extend_from_slice(record);
        }

        thing_extension.push(ExtensionBlock {
            tag: xthg::WORKING_RECORD_TAG,
            data,
        });
    }

    if !occupied_tiles.is_empty() {
        let mut data = Vec::with_capacity(occupied_tiles.len() * xthg::OCCUPIED_TILE_ENTRY);

        for (slot, x, y) in &occupied_tiles {
            data.extend_from_slice(&(*slot as u32).to_be_bytes());
            data.extend_from_slice(&x.to_be_bytes());
            data.extend_from_slice(&y.to_be_bytes());
        }

        thing_extension.push(ExtensionBlock {
            tag: xthg::OCCUPIED_TILE_TAG,
            data,
        });
    }

    // Signs: one record per tile. A legacy sign keeps its text but gets a new ID.
    let mut next_sign_id = options.next_sign_id.max(1);
    let xsgn = match options.signs {
        Some(signs) => {
            next_sign_id = next_sign_id.max(signs.max_id().wrapping_add(1)).max(1);
            signs
        }
        None => {
            let mut signs = Vec::new();

            for (index, id) in sign_tiles {
                let (x, y) = point(index, edge);
                let text = limit_name(label(id), &mut issues, &format!("Sign at ({}, {})", x, y));
                migrated.insert(id);

                if text.is_empty() {
                    issues.push(format!("Sign {} at ({}, {}) has no text; it was not kept", id, x, y));
                    continue;
                }

                signs.push(Sign {
                    id: next_sign_id,
                    x: x as u16,
                    y: y as u16,
                    flags: 0,
                    reserved: 0,
                    text,
                });
                next_sign_id += 1;
            }

            let capacity = signs.len().max(options.sign_capacity);
            signs.resize(capacity, Sign::default());

            Xsgn {
                signs,
                extension: Vec::new(),
            }
        }
    };

    let mayor_name = limit_name(label(labels::MAYOR_LABEL), &mut issues, "Mayor");
    let team_names: Vec<String> = (0..labels::TEAM_COUNT)
        .map(|team| {
            limit_name(
                label(labels::TEAM_LABEL_FIRST + team),
                &mut issues,
                &format!("Stadium team {}", team + 1),
            )
        })
        .collect();
    migrated.insert(labels::MAYOR_LABEL);
    migrated.extend(labels::TEAM_LABEL_FIRST..labels::TEAM_LABEL_FIRST + labels::TEAM_COUNT);

    let residual_labels = if working.wide_labels {
        Vec::new()
    } else {
        let mut residual = working.labels.to_vec();

        for id in migrated {
            labels::erase(&mut residual, id, false);
        }

        residual
    };

    let xmic = Xmic {
        facilities,
        extension: Vec::new(),
    };
    xmic.validate(edge)?;
    let xthg = Xthg {
        things: thing_records,
        extension: thing_extension,
    };
    xthg.validate()?;
    xsgn.validate(edge)?;

    Ok(Split {
        markers,
        xmic,
        xthg,
        xsgn,
        mayor_name,
        team_names,
        residual_labels,
        next_sign_id,
        next_object_id,
        issues,
    })
}

fn decode_entries<const N: usize>(block: Option<&ExtensionBlock>, name: &str) -> Result<Vec<(usize, [u8; N])>, String> {
    let Some(block) = block else {
        return Ok(Vec::new());
    };
    let entry = 4 + N;

    if !block.data.len().is_multiple_of(entry) {
        return Err(format!("XTHG {} block is not a whole number of entries", name));
    }

    let mut result: Vec<(usize, [u8; N])> = Vec::with_capacity(block.data.len() / entry);

    for chunk in block.data.chunks(entry) {
        let slot = u32::from_be_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]) as usize;

        if result.last().is_some_and(|(last, _)| *last >= slot) {
            return Err(format!("XTHG {} entries are not in ascending slot order", name));
        }

        let mut value = [0u8; N];
        value.copy_from_slice(&chunk[4..]);
        result.push((slot, value));
    }

    Ok(result)
}

/// Rebuild a version 4 working document from its saved structures.
pub fn join(edge: usize, markers: &[u8], xmic: &Xmic, xthg: &Xthg, mayor_name: &str, team_names: &[String]) -> Result<Joined, String> {
    let cells = edge * edge;
    let mut xtxt = vec![0u8; cells * 2];

    if overlay::count(&xtxt) as usize != cells {
        return Err(format!("The {} tile map size has no working tile index", edge));
    }

    if markers.len() != cells {
        return Err(format!("XTXT has {} bytes; expected {}", markers.len(), cells));
    }

    xmic.validate(edge)?;
    xthg.validate()?;

    if xmic.facilities.len() > MAX_WORKING_FACILITIES {
        return Err(format!(
            "XMIC has {} slots; this version links at most {}",
            xmic.facilities.len(),
            MAX_WORKING_FACILITIES
        ));
    }

    let thing_capacity = xthg.things.len();

    if thing_capacity > MAX_WORKING_THINGS || thing_capacity * 24 == LEGACY_SIZE {
        return Err(format!("XTHG capacity {} is not supported by this version", thing_capacity));
    }

    for (index, marker) in markers.iter().enumerate() {
        if *marker != 0 && (*marker as i64) < MARKER_FIRST {
            let (x, y) = point(index, edge);
            return Err(format!("XTXT tile ({}, {}) holds reserved value {}", x, y, marker));
        }

        overlay::write(&mut xtxt, index as i64, *marker as i64);
    }

    let mut facility_bytes = vec![0u8; xmic.facilities.len() * 8];
    let last_label = facility_label(xmic.facilities.len().saturating_sub(1));
    let mut label_table = labels::wide_table(last_label);
    labels::write_wide(&mut label_table, labels::MAYOR_LABEL, mayor_name);

    for (team, name) in team_names.iter().take(labels::TEAM_COUNT).enumerate() {
        labels::write_wide(&mut label_table, labels::TEAM_LABEL_FIRST + team, name);
    }

    for (record, facility) in xmic.facilities.iter().enumerate() {
        facility_bytes[record * 8..record * 8 + 8].copy_from_slice(&facility.legacy_record());

        if !facility.name.is_empty() {
            labels::write_wide(&mut label_table, facility_label(record), &facility.name);
        }

        for index in facility.footprint.indices(edge) {
            if overlay::read(&xtxt, index as i64) != 0 {
                let (x, y) = point(index, edge);
                return Err(format!(
                    "XTXT tile ({}, {}) has a marker and facility {}; this version cannot link both",
                    x, y, record
                ));
            }

            overlay::write(&mut xtxt, index as i64, overlay::facility_id(record as i64));
        }
    }

    let occupied: Vec<(usize, [u8; 4])> = decode_entries(xthg.block(xthg::OCCUPIED_TILE_TAG), "LOCC")?;
    let overrides: Vec<(usize, [u8; 24])> = decode_entries(xthg.block(xthg::WORKING_RECORD_TAG), "LREC")?;
    let occupied: BTreeMap<usize, (usize, usize)> = occupied
        .into_iter()
        .map(|(slot, tile)| {
            (
                slot,
                (
                    u16::from_be_bytes([tile[0], tile[1]]) as usize,
                    u16::from_be_bytes([tile[2], tile[3]]) as usize,
                ),
            )
        })
        .collect();
    let mut stacks: BTreeMap<usize, Vec<(u16, usize)>> = BTreeMap::new();

    for (slot, thing) in xthg.things.iter().enumerate() {
        check_working_fields(slot, thing)?;

        if occupied.contains_key(&slot) && !thing.is_occupant() {
            return Err(format!("XTHG slot {} has an occupied tile but does not occupy one", slot));
        }

        if thing.is_occupant() {
            let (x, y) = occupied.get(&slot).copied().unwrap_or((thing.x as usize, thing.y as usize));

            if x >= edge || y >= edge {
                return Err(format!("XTHG slot {} occupies a tile outside the map", slot));
            }

            stacks.entry(x * edge + y).or_default().push((thing.depth(), slot));
        }
    }

    let mut thing_labels = vec![0u16; thing_capacity];

    for (index, mut stack) in stacks {
        stack.sort_unstable();

        for (position, (depth, _)) in stack.iter().enumerate() {
            if *depth as usize != position {
                let (x, y) = point(index, edge);
                return Err(format!(
                    "XTHG occupants of tile ({}, {}) do not have depths 0 through {}",
                    x,
                    y,
                    stack.len() - 1
                ));
            }
        }

        for (_, slot) in stack {
            thing_labels[slot] = overlay::read(&xtxt, index as i64) as u16;
            overlay::write(&mut xtxt, index as i64, overlay::thing_id(slot as i64));
        }
    }

    let half = thing_capacity * RECORD;
    let mut thing_bytes = vec![0u8; half * 2];
    let mut write_record = |slot: usize, record: &[u8; 24]| {
        thing_bytes[slot * RECORD..(slot + 1) * RECORD].copy_from_slice(&record[..RECORD]);
        thing_bytes[half + slot * RECORD..half + (slot + 1) * RECORD].copy_from_slice(&record[RECORD..]);
    };

    for (slot, thing) in xthg.things.iter().enumerate() {
        write_record(slot, &record_of(thing, thing_labels[slot]));
    }

    for (slot, record) in overrides {
        if slot >= thing_capacity {
            return Err(format!("XTHG LREC entry names slot {} outside the table", slot));
        }

        write_record(slot, &record);
    }

    Ok(Joined {
        xtxt,
        xmic: facility_bytes,
        xthg: thing_bytes,
        labels: label_table,
        object_ids: xthg.things.iter().map(|thing| thing.object_id).collect(),
        object_names: xthg.things.iter().map(|thing| thing.name.clone()).collect(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    const EDGE: usize = 16;

    /// A small working document: a shared facility in two places, a 2 by 2
    /// facility, a fire marker, a stacked pair of objects, and a ship.
    fn working() -> (Vec<u8>, Vec<u8>, Vec<u8>, Vec<u8>) {
        let cells = EDGE * EDGE;
        let mut xtxt = vec![0u8; cells * 2];
        let mut xmic = vec![0u8; 64 * 8];
        let mut xthg = vec![0u8; 16 * 24];
        let mut label_table = labels::wide_table(facility_label(63));
        let half = xthg.len() / 2;

        xmic[0] = 0xec;
        xmic[8] = 0xd2;
        xmic[10 * 8] = 0xe0;
        xmic[10 * 8 + 7] = 9;
        labels::write_wide(&mut label_table, facility_label(1), "Bus Depots");
        labels::write_wide(&mut label_table, facility_label(10), "City Hall \u{1F3DB}");
        labels::write_wide(&mut label_table, 0, "Mayor Ada");
        labels::write_wide(&mut label_table, labels::TEAM_LABEL_FIRST + 2, "Llamas");

        for index in [0, 1, 5 * EDGE + 5] {
            overlay::write(&mut xtxt, index as i64, overlay::facility_id(1));
        }

        for (x, y) in [(2, 3), (2, 4), (3, 3), (3, 4)] {
            overlay::write(&mut xtxt, (x * EDGE + y) as i64, overlay::facility_id(10));
        }

        overlay::write(&mut xtxt, (9 * EDGE + 9) as i64, 0xff);

        // slot 0 keeps the original bulldozer placeholder with a stale label
        xthg[0] = 4;
        xthg[FIELD_LABEL] = 205;

        // slots 2 and 3 stack on the city hall tile (3, 4); slot 3 is on top
        for slot in [2usize, 3] {
            let offset = slot * RECORD;
            xthg[offset] = 10;
            xthg[offset + 3] = 3;
            xthg[offset + 4] = 4;
            xthg[offset + 2] = 0x34;
            xthg[half + offset + 2] = 0x01;
        }

        xthg[2 * RECORD + FIELD_LABEL] = overlay::facility_id(10) as u8;
        xthg[half + 2 * RECORD + FIELD_LABEL] = (overlay::facility_id(10) >> 8) as u8;
        xthg[3 * RECORD + FIELD_LABEL] = overlay::thing_id(2) as u8;
        overlay::write(&mut xtxt, (3 * EDGE + 4) as i64, overlay::thing_id(3));

        // slot 5 is a ship with a saved home at (12, 1); its link sits one tile away
        let ship = 5 * RECORD;
        xthg[ship] = 3;
        xthg[ship + 3] = 12;
        xthg[ship + 4] = 2;
        xthg[half + ship] = 13;
        xthg[half + ship + 2] = 2;
        overlay::write(&mut xtxt, (12 * EDGE + 3) as i64, overlay::thing_id(5));

        (xtxt, xmic, xthg, label_table)
    }

    fn working_view<'a>(parts: &'a (Vec<u8>, Vec<u8>, Vec<u8>, Vec<u8>), wide: bool) -> Working<'a> {
        Working {
            edge: EDGE,
            xtxt: &parts.0,
            xmic: &parts.1,
            xthg: &parts.2,
            labels: &parts.3,
            wide_labels: wide,
        }
    }

    fn signs() -> Xsgn {
        Xsgn {
            signs: vec![
                Sign {
                    id: 4,
                    x: 3,
                    y: 4,
                    text: "Over city hall".into(),
                    ..Default::default()
                },
                Sign::default(),
            ],
            extension: Vec::new(),
        }
    }

    #[test]
    fn split_saves_markers_geometry_occupancy_and_names() {
        let parts = working();
        let split = split(
            &working_view(&parts, true),
            SplitOptions {
                signs: Some(signs()),
                next_object_id: 1,
                ..Default::default()
            },
        )
        .unwrap();
        assert!(split.issues.is_empty(), "{:?}", split.issues);
        assert_eq!(split.markers[9 * EDGE + 9], 0xff);
        assert_eq!(split.markers.iter().filter(|marker| **marker != 0).count(), 1);
        assert_eq!(split.xmic.facilities[1].footprint, Footprint::Tiles(vec![(0, 0), (0, 1), (5, 5)]));
        assert_eq!(
            split.xmic.facilities[10].footprint,
            Footprint::Rect {
                x: 2,
                y: 3,
                width: 2,
                height: 2
            }
        );
        assert_eq!(split.xmic.facilities[10].name, "City Hall \u{1F3DB}");
        assert_eq!(split.xmic.facilities[10].stats[6], 9);
        assert!(split.xmic.facilities[0].name.is_empty() && split.xmic.facilities[0].footprint.is_empty());
        assert_eq!(split.mayor_name, "Mayor Ada");
        assert_eq!(split.team_names[2], "Llamas");

        let things = &split.xthg.things;
        assert_eq!((things[2].is_occupant(), things[2].depth()), (true, 0));
        assert_eq!((things[3].is_occupant(), things[3].depth()), (true, 1));
        assert_eq!(things[2].state, 0x134, "train state is a wide field");
        assert_eq!((things[5].home_x1, things[5].home_y1), (13, 2));
        assert!(!things[0].is_occupant());
        let ids: HashSet<u32> = things
            .iter()
            .filter(|thing| thing.is_active())
            .map(|thing| thing.object_id)
            .collect();
        assert_eq!(ids.len(), 4);
        assert!(split.xthg.block(xthg::WORKING_RECORD_TAG).is_some(), "slot 0 keeps its stale label");
        assert!(
            split.xthg.block(xthg::OCCUPIED_TILE_TAG).is_some(),
            "the ship link is one tile away"
        );
    }

    #[test]
    fn join_restores_the_working_document() {
        let parts = working();
        let split = split(
            &working_view(&parts, true),
            SplitOptions {
                signs: Some(signs()),
                next_object_id: 1,
                ..Default::default()
            },
        )
        .unwrap();
        let joined = join(EDGE, &split.markers, &split.xmic, &split.xthg, &split.mayor_name, &split.team_names).unwrap();
        assert_eq!(joined.xtxt, parts.0);
        assert_eq!(joined.xmic, parts.1);
        assert_eq!(joined.xthg, parts.2);

        for id in 0..parts.3.len() / labels::WIDE_RECORD_SIZE {
            assert_eq!(
                labels::read(&joined.labels, id, true),
                labels::read(&parts.3, id, true),
                "label {}",
                id
            );
        }

        // a second save keeps identities and produces the same structures
        let again = split_with_ids(&joined, &split);
        assert_eq!(again.xmic, split.xmic);
        assert_eq!(again.xthg, split.xthg);
        assert_eq!(again.markers, split.markers);
    }

    fn split_with_ids(joined: &Joined, first: &Split) -> Split {
        let parts = (joined.xtxt.clone(), joined.xmic.clone(), joined.xthg.clone(), joined.labels.clone());
        split(
            &working_view(&parts, true),
            SplitOptions {
                signs: Some(first.xsgn.clone()),
                object_ids: joined.object_ids.clone(),
                object_names: joined.object_names.clone(),
                next_object_id: first.next_object_id,
                next_sign_id: first.next_sign_id,
                ..Default::default()
            },
        )
        .unwrap()
    }

    #[test]
    fn legacy_split_gathers_signs_names_and_covered_links() {
        let cells = 128 * 128;
        let mut xtxt = vec![0u8; cells];
        let mut xmic = vec![0u8; 150 * 8];
        let mut xthg = vec![0u8; LEGACY_SIZE];
        let mut table = vec![0u8; labels::LEGACY_RECORD_SIZE * 256];
        let mut put = |id: usize, text: &[u8]| {
            table[id * 25] = text.len() as u8;
            table[id * 25 + 1..id * 25 + 1 + text.len()].copy_from_slice(text);
        };

        put(0, b"Mayor");
        put(3, b"Hidden sign");
        put(7, b"Plain sign");
        put(12, b"Unused label");
        put(51 + 20, b"Hospital");
        put(0xfb, b"Llamas");
        xmic[20 * 8] = 0xd5;
        xtxt[10 * 128 + 10] = 51 + 20;
        xtxt[4 * 128 + 4] = 7;
        xtxt[40 * 128 + 40] = 0xfc;

        // a train engine at (6, 6) covers sign 3
        xthg[RECORD] = 10;
        xthg[RECORD + 3] = 6;
        xthg[RECORD + 4] = 6;
        xthg[RECORD + FIELD_LABEL] = 3;
        xtxt[6 * 128 + 6] = overlay::thing_id(1) as u8;

        let parts = (xtxt, xmic, xthg, table);
        let split = split(
            &Working {
                edge: 128,
                xtxt: &parts.0,
                xmic: &parts.1,
                xthg: &parts.2,
                labels: &parts.3,
                wide_labels: false,
            },
            SplitOptions {
                next_sign_id: 1,
                next_object_id: 1,
                facility_capacity: 256,
                thing_capacity: 128,
                sign_capacity: 128,
                ..Default::default()
            },
        )
        .unwrap();
        assert!(split.issues.is_empty(), "{:?}", split.issues);
        let active: Vec<(u16, u16, &str)> = split
            .xsgn
            .signs
            .iter()
            .filter(|sign| sign.is_active())
            .map(|sign| (sign.x, sign.y, sign.text.as_str()))
            .collect();
        assert_eq!(active, vec![(4, 4, "Plain sign"), (6, 6, "Hidden sign")]);
        assert_eq!(split.xsgn.signs.len(), 128);
        assert_eq!(split.xmic.facilities.len(), 256);
        assert_eq!(split.xthg.things.len(), 128);
        assert_eq!(split.xmic.facilities[20].name, "Hospital");
        assert_eq!(
            split.xmic.facilities[20].footprint,
            Footprint::Rect {
                x: 10,
                y: 10,
                width: 1,
                height: 1
            }
        );
        assert_eq!(split.markers[40 * 128 + 40], 0xfc);
        assert_eq!(split.mayor_name, "Mayor");
        assert_eq!(split.team_names[0], "Llamas");
        assert_eq!(
            labels::read(&split.residual_labels, 12, false).unwrap(),
            "Unused label",
            "unrecognized labels stay"
        );

        for id in [0, 3, 7, 71, 0xfb] {
            assert_eq!(labels::read(&split.residual_labels, id, false).unwrap(), "", "label {} moved", id);
        }

        // the covered sign is gone from the working index; the engine now covers nothing
        let joined = join(128, &split.markers, &split.xmic, &split.xthg, &split.mayor_name, &split.team_names).unwrap();
        assert_eq!(overlay::read(&joined.xtxt, 6 * 128 + 6), overlay::thing_id(1));
        assert_eq!(things::field(&joined.xthg, 1, FIELD_LABEL as i64), 0);
        assert_eq!(overlay::read(&joined.xtxt, 4 * 128 + 4), 0);
        assert_eq!(overlay::read(&joined.xtxt, 10 * 128 + 10), overlay::facility_id(20));
    }

    #[test]
    fn a_new_city_trims_empty_slots_but_an_import_keeps_them() {
        let parts = (vec![0u8; 128 * 128], vec![0u8; 150 * 8], vec![0u8; LEGACY_SIZE], vec![0u8; 6400]);
        let view = Working {
            edge: 128,
            xtxt: &parts.0,
            xmic: &parts.1,
            xthg: &parts.2,
            labels: &parts.3,
            wide_labels: false,
        };
        let options = |trim| SplitOptions {
            facility_capacity: 64,
            thing_capacity: 16,
            sign_capacity: 16,
            trim_free_tail: trim,
            ..Default::default()
        };
        let fresh = split(&view, options(true)).unwrap();
        assert_eq!((fresh.xmic.facilities.len(), fresh.xthg.things.len()), (64, 16));
        let import = split(&view, options(false)).unwrap();
        assert_eq!((import.xmic.facilities.len(), import.xthg.things.len()), (150, 40));

        let mut used = parts.clone();
        used.1[100 * 8] = 0xd2;
        let view = Working {
            edge: 128,
            xtxt: &used.0,
            xmic: &used.1,
            xthg: &used.2,
            labels: &used.3,
            wide_labels: false,
        };
        assert_eq!(
            split(&view, options(true)).unwrap().xmic.facilities.len(),
            101,
            "a used slot is never dropped"
        );
    }

    #[test]
    fn broken_links_are_reported_instead_of_saved() {
        let mut parts = working();
        overlay::write(&mut parts.0, 7, overlay::facility_id(30));
        overlay::write(&mut parts.0, 8, overlay::thing_id(9));
        overlay::write(&mut parts.0, 9, 3);
        let split = split(
            &working_view(&parts, true),
            SplitOptions {
                signs: Some(signs()),
                ..Default::default()
            },
        )
        .unwrap();
        assert_eq!(split.issues.len(), 3, "{:?}", split.issues);
    }

    #[test]
    fn join_rejects_conflicts_that_the_index_cannot_hold() {
        let parts = working();
        let split = split(
            &working_view(&parts, true),
            SplitOptions {
                signs: Some(signs()),
                ..Default::default()
            },
        )
        .unwrap();

        let mut markers = split.markers.clone();
        markers[2 * EDGE + 3] = 0xfd;
        assert!(
            join(EDGE, &markers, &split.xmic, &split.xthg, "", &[]).is_err(),
            "marker on a facility tile"
        );

        let mut reserved = split.markers.clone();
        reserved[0] = 60;
        assert!(
            join(EDGE, &reserved, &split.xmic, &split.xthg, "", &[]).is_err(),
            "reference values are not markers"
        );

        let mut depths = split.xthg.clone();
        depths.things[3].flags = xthg::FLAG_OCCUPANT | (4 << xthg::FLAG_DEPTH_SHIFT);
        assert!(join(EDGE, &split.markers, &split.xmic, &depths, "", &[]).is_err());

        let mut wide_z = split.xthg.clone();
        wide_z.things[5].z = 300;
        assert!(join(EDGE, &split.markers, &split.xmic, &wide_z, "", &[]).is_err());

        let twenty = Xthg {
            things: vec![Thing::default(); 20],
            extension: Vec::new(),
        };
        assert!(join(EDGE, &split.markers, &split.xmic, &twenty, "", &[]).is_err());
        assert!(join(2048, &vec![0; 2048 * 2048], &Xmic::default(), &Xthg::default(), "", &[]).is_err());
    }
}
