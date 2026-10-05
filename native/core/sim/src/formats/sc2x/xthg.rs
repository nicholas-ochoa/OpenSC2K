//! XTHG.bin: moving-object records with a 32-byte fixed core and optional names.
//!
//! File order: common header, C fixed cores, C text indexes, UTF-8 text,
//! extension section.

use super::collection::{self, ExtensionBlock, HEADER_SIZE, Header, TEXT_INDEX_SIZE};
use super::wire::{Reader, put_u16, put_u32};

pub const CORE_SIZE: usize = 32;
pub const TYPE_NONE: u8 = 0;
pub const TYPE_SHIP: u8 = 3;
pub const TYPE_TRAIN_ENGINE: u8 = 10;
pub const TYPE_TRAIN_CAR: u8 = 11;
pub const TYPE_SUBWAY_ENGINE: u8 = 12;
pub const TYPE_SUBWAY_CAR: u8 = 13;
pub const TYPE_LAST: u8 = 16;

/// Flag bit 0: the object occupies its tile in the runtime tile index.
pub const FLAG_OCCUPANT: u16 = 0x0001;
/// Flag bits 8 through 15: the stacking depth of an occupant. Zero is the
/// bottom object of a tile.
pub const FLAG_DEPTH_SHIFT: u16 = 8;
pub const FLAG_DEPTH_MASK: u16 = 0xff00;
/// Flag bits that this schema defines.
pub const DEFINED_FLAGS: u16 = FLAG_OCCUPANT | FLAG_DEPTH_MASK;

/// Extension block of working records that the core cannot express: slot u32,
/// then 12 low-plane and 12 high-plane bytes.
pub const WORKING_RECORD_TAG: [u8; 4] = *b"LREC";
pub const WORKING_RECORD_ENTRY: usize = 4 + 24;
/// Extension block of occupants whose occupied tile differs from their
/// position: slot u32, tile X u16, tile Y u16.
pub const OCCUPIED_TILE_TAG: [u8; 4] = *b"LOCC";
pub const OCCUPIED_TILE_ENTRY: usize = 8;
/// Extension block of working tile links that no structure describes, such as
/// a link to a free record or to a sign without text: tile index u32, link
/// u16, reserved u16. A load writes each link back to its tile.
pub const LINK_TAG: [u8; 4] = *b"LLNK";
pub const LINK_ENTRY: usize = 8;

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Thing {
    pub kind: u8,
    pub direction: u8,
    pub state: u16,
    pub x: u16,
    pub y: u16,
    pub z: u16,
    pub px: u16,
    pub py: u16,
    pub dx: u16,
    pub dy: u16,
    pub reserved: u16,
    pub goal: u16,
    /// Ship home coordinate plus one. Zero means no stored home.
    pub home_x1: u16,
    pub home_y1: u16,
    pub flags: u16,
    pub object_id: u32,
    pub name: String,
}

impl Thing {
    pub fn is_active(&self) -> bool {
        self.kind != TYPE_NONE
    }

    pub fn is_occupant(&self) -> bool {
        self.flags & FLAG_OCCUPANT != 0
    }

    pub fn depth(&self) -> u16 {
        (self.flags & FLAG_DEPTH_MASK) >> FLAG_DEPTH_SHIFT
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Xthg {
    pub things: Vec<Thing>,
    pub extension: Vec<ExtensionBlock>,
}

impl Xthg {
    pub fn active_records(&self) -> usize {
        self.things.iter().filter(|thing| thing.is_active()).count()
    }

    pub fn encode(&self) -> Result<Vec<u8>, String> {
        self.validate()?;

        let names: Vec<String> = self.things.iter().map(|thing| thing.name.clone()).collect();
        let (index, text) = collection::encode_texts(&names).map_err(|error| format!("XTHG {}", error))?;
        let extension = collection::encode_extension(&self.extension);
        let header = Header {
            schema_version: collection::SCHEMA_VERSION,
            capacity: self.things.len() as u32,
            active_records: self.active_records() as u32,
            record_stride: CORE_SIZE as u32,
            text_bytes: text.len() as u32,
            extension_bytes: extension.len() as u32,
        };
        let mut output = Vec::with_capacity(HEADER_SIZE + self.things.len() * (CORE_SIZE + TEXT_INDEX_SIZE) + text.len() + extension.len());
        header.write(&mut output);

        for thing in &self.things {
            output.push(thing.kind);
            output.push(thing.direction);

            for value in [
                thing.state,
                thing.x,
                thing.y,
                thing.z,
                thing.px,
                thing.py,
                thing.dx,
                thing.dy,
                thing.reserved,
                thing.goal,
                thing.home_x1,
                thing.home_y1,
                thing.flags,
            ] {
                put_u16(&mut output, value);
            }

            put_u32(&mut output, thing.object_id);
        }

        output.extend_from_slice(&index);
        output.extend_from_slice(&text);
        output.extend_from_slice(&extension);

        Ok(output)
    }

    pub fn decode(bytes: &[u8]) -> Result<Self, String> {
        let mut reader = Reader::new(bytes);
        let header = Header::read(&mut reader, CORE_SIZE as u32, "XTHG")?;
        let count = header.capacity as usize;
        collection::require(&reader, count, CORE_SIZE + TEXT_INDEX_SIZE, "XTHG")?;
        let mut things = Vec::with_capacity(count);

        for _ in 0..count {
            things.push(Thing {
                kind: reader.u8()?,
                direction: reader.u8()?,
                state: reader.u16()?,
                x: reader.u16()?,
                y: reader.u16()?,
                z: reader.u16()?,
                px: reader.u16()?,
                py: reader.u16()?,
                dx: reader.u16()?,
                dy: reader.u16()?,
                reserved: reader.u16()?,
                goal: reader.u16()?,
                home_x1: reader.u16()?,
                home_y1: reader.u16()?,
                flags: reader.u16()?,
                object_id: reader.u32()?,
                name: String::new(),
            });
        }

        let (names, extension) = collection::read_tail(&mut reader, &header, "XTHG")?;

        for (thing, name) in things.iter_mut().zip(names) {
            thing.name = name;
        }

        let result = Self { things, extension };

        if result.active_records() != header.active_records as usize {
            return Err("XTHG active record count does not match its records".into());
        }

        result.validate()?;

        Ok(result)
    }

    /// Check types, identities, names, flags, the reserved field, and train chains.
    pub fn validate(&self) -> Result<(), String> {
        let broken = broken_trains(self.things.len(), |slot| {
            let thing = &self.things[slot];
            (thing.kind, thing.state as usize)
        });

        if let Some(slot) = broken.iter().position(|broken| *broken) {
            return Err(format!("XTHG slot {} is part of an incomplete train", slot));
        }

        let mut identities = std::collections::HashSet::new();

        for (slot, thing) in self.things.iter().enumerate() {
            if thing.kind > TYPE_LAST {
                return Err(format!("XTHG slot {} has unknown type {}", slot, thing.kind));
            }

            if thing.reserved != 0 {
                return Err(format!("XTHG slot {} reserved field is not zero", slot));
            }

            if thing.flags & !DEFINED_FLAGS != 0 {
                return Err(format!(
                    "XTHG slot {} uses undefined flags 0x{:04x}",
                    slot,
                    thing.flags & !DEFINED_FLAGS
                ));
            }

            if !thing.is_active() {
                if thing.object_id != 0 || !thing.name.is_empty() || thing.flags != 0 {
                    return Err(format!("XTHG slot {} is free but keeps an identity, name, or flags", slot));
                }

                continue;
            }

            if thing.object_id == 0 {
                return Err(format!("XTHG slot {} is active without an object ID", slot));
            }

            if !identities.insert(thing.object_id) {
                return Err(format!("XTHG object ID {} is repeated", thing.object_id));
            }

            if !thing.is_occupant() && thing.depth() != 0 {
                return Err(format!("XTHG slot {} has a depth without occupying a tile", slot));
            }
        }

        Ok(())
    }

    /// The first extension block with `tag`.
    pub fn block(&self, tag: [u8; 4]) -> Option<&ExtensionBlock> {
        self.extension.iter().find(|block| block.tag == tag)
    }
}

/// The members of broken trains. A train is an engine whose state field names
/// its first car, and a first car whose state field names the second car. The
/// cars are two different active cars, rail or subway, of no other engine.
/// Slot 0 is never a car. `record(slot)` gives the type and the state field.
pub fn broken_trains(count: usize, record: impl Fn(usize) -> (u8, usize)) -> Vec<bool> {
    let is_engine = |kind: u8| kind == TYPE_TRAIN_ENGINE || kind == TYPE_SUBWAY_ENGINE;
    let is_car = |kind: u8| kind == TYPE_TRAIN_CAR || kind == TYPE_SUBWAY_CAR;
    let mut broken = vec![false; count];
    let mut owned = vec![false; count];

    for (slot, flag) in broken.iter_mut().enumerate().skip(1) {
        let (kind, first) = record(slot);

        if !is_engine(kind) {
            continue;
        }

        let free_car = |car: usize, owned: &[bool]| car > 0 && car < count && !owned[car] && is_car(record(car).0);
        let second = if free_car(first, &owned) { record(first).1 } else { 0 };

        if free_car(first, &owned) && free_car(second, &owned) && second != first {
            owned[first] = true;
            owned[second] = true;
        } else {
            *flag = true;
        }
    }

    for (slot, flag) in broken.iter_mut().enumerate().skip(1) {
        if is_car(record(slot).0) && !owned[slot] {
            *flag = true;
        }
    }

    broken
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample() -> Xthg {
        let mut things = vec![Thing::default(); 5];
        things[0] = Thing {
            kind: 4,
            object_id: 1,
            ..Default::default()
        };
        things[1] = Thing {
            kind: TYPE_SHIP,
            direction: 3,
            state: 0x0102,
            x: 700,
            y: 12,
            z: 4,
            px: 5,
            py: 6,
            dx: 900,
            dy: 901,
            goal: 3,
            home_x1: 701,
            home_y1: 13,
            flags: FLAG_OCCUPANT,
            object_id: 7,
            name: "Queen Mary".into(),
            ..Default::default()
        };
        things[3] = Thing {
            kind: 7,
            flags: FLAG_OCCUPANT | (1 << FLAG_DEPTH_SHIFT),
            object_id: 8,
            ..Default::default()
        };

        Xthg {
            things,
            extension: vec![ExtensionBlock {
                tag: WORKING_RECORD_TAG,
                data: vec![0; WORKING_RECORD_ENTRY],
            }],
        }
    }

    #[test]
    fn records_round_trip_with_sizes_from_the_formula() {
        let xthg = sample();
        let bytes = xthg.encode().unwrap();
        assert_eq!(bytes.len(), 24 + 40 * 5 + "Queen Mary".len() + 8 + WORKING_RECORD_ENTRY);
        assert_eq!(Xthg::decode(&bytes).unwrap(), xthg);
        assert_eq!(
            Xthg {
                things: vec![Thing::default(); 16],
                extension: vec![]
            }
            .encode()
            .unwrap()
            .len(),
            24 + 40 * 16
        );
    }

    #[test]
    fn validation_enforces_identity_and_free_slot_rules() {
        let mut repeated = sample();
        repeated.things[3].object_id = 7;
        assert!(repeated.encode().is_err());

        let mut missing = sample();
        missing.things[3].object_id = 0;
        assert!(missing.encode().is_err());

        let mut free_name = sample();
        free_name.things[2].name = "Ghost".into();
        assert!(free_name.encode().is_err());

        let mut reserved = sample();
        reserved.things[1].reserved = 1;
        assert!(reserved.encode().is_err());

        let mut unknown = sample();
        unknown.things[1].kind = 17;
        assert!(unknown.encode().is_err());

        let mut flags = sample();
        flags.things[1].flags |= 0x0002;
        assert!(flags.encode().is_err());
    }
}
