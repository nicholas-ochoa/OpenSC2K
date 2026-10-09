//! XSGN.bin: independent signs with a persistent ID, tile coordinates, and text.
//!
//! File order: common header, C fixed cores, C text indexes, UTF-8 text,
//! extension section. There is no reserved slot.

use super::collection::{self, ExtensionBlock, HEADER_SIZE, Header, TEXT_INDEX_SIZE};
use super::wire::{Reader, put_u16, put_u32};

pub const CORE_SIZE: usize = 12;

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Sign {
    /// Nonzero for an active sign. Zero marks an empty slot.
    pub id: u32,
    pub x: u16,
    pub y: u16,
    pub flags: u16,
    pub reserved: u16,
    pub text: String,
}

impl Sign {
    pub fn is_active(&self) -> bool {
        self.id != 0
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Xsgn {
    pub signs: Vec<Sign>,
    pub extension: Vec<ExtensionBlock>,
}

impl Xsgn {
    pub fn active_records(&self) -> usize {
        self.signs.iter().filter(|sign| sign.is_active()).count()
    }

    pub fn encode(&self, edge: usize) -> Result<Vec<u8>, String> {
        self.validate(edge)?;

        let names: Vec<String> = self.signs.iter().map(|sign| sign.text.clone()).collect();
        let (index, text) = collection::encode_texts(&names).map_err(|error| format!("XSGN {}", error))?;
        let extension = collection::encode_extension(&self.extension);
        let header = Header {
            schema_version: collection::SCHEMA_VERSION,
            capacity: self.signs.len() as u32,
            active_records: self.active_records() as u32,
            record_stride: CORE_SIZE as u32,
            text_bytes: text.len() as u32,
            extension_bytes: extension.len() as u32,
        };
        let mut output = Vec::with_capacity(HEADER_SIZE + self.signs.len() * (CORE_SIZE + TEXT_INDEX_SIZE) + text.len() + extension.len());
        header.write(&mut output);

        for sign in &self.signs {
            put_u32(&mut output, sign.id);
            put_u16(&mut output, sign.x);
            put_u16(&mut output, sign.y);
            put_u16(&mut output, sign.flags);
            put_u16(&mut output, sign.reserved);
        }

        output.extend_from_slice(&index);
        output.extend_from_slice(&text);
        output.extend_from_slice(&extension);

        Ok(output)
    }

    pub fn decode(bytes: &[u8], edge: usize) -> Result<Self, String> {
        let mut reader = Reader::new(bytes);
        let header = Header::read(&mut reader, CORE_SIZE as u32, "XSGN")?;
        let count = header.capacity as usize;
        collection::require(&reader, count, CORE_SIZE + TEXT_INDEX_SIZE, "XSGN")?;
        let mut signs = Vec::with_capacity(count);

        for _ in 0..count {
            signs.push(Sign {
                id: reader.u32()?,
                x: reader.u16()?,
                y: reader.u16()?,
                flags: reader.u16()?,
                reserved: reader.u16()?,
                text: String::new(),
            });
        }

        let (texts, extension) = collection::read_tail(&mut reader, &header, "XSGN")?;

        for (sign, text) in signs.iter_mut().zip(texts) {
            sign.text = text;
        }

        let result = Self { signs, extension };

        if result.active_records() != header.active_records as usize {
            return Err("XSGN active record count does not match its records".into());
        }

        result.validate(edge)?;

        Ok(result)
    }

    /// Check text, coordinates, one sign per tile, and unique IDs.
    pub fn validate(&self, edge: usize) -> Result<(), String> {
        let mut tiles = std::collections::HashSet::new();
        let mut identities = std::collections::HashSet::new();

        for (slot, sign) in self.signs.iter().enumerate() {
            if !sign.is_active() {
                if sign.x != 0 || sign.y != 0 || sign.flags != 0 || sign.reserved != 0 || !sign.text.is_empty() {
                    return Err(format!("XSGN slot {} is empty but keeps data", slot));
                }

                continue;
            }

            if sign.text.is_empty() {
                return Err(format!("XSGN sign {} has no text", sign.id));
            }

            if sign.x as usize >= edge || sign.y as usize >= edge {
                return Err(format!("XSGN sign {} is outside the map", sign.id));
            }

            if sign.flags != 0 {
                return Err(format!("XSGN sign {} uses undefined flags", sign.id));
            }

            if !tiles.insert((sign.x, sign.y)) {
                return Err(format!("XSGN has two signs at ({}, {})", sign.x, sign.y));
            }

            if !identities.insert(sign.id) {
                return Err(format!("XSGN sign ID {} is repeated", sign.id));
            }
        }

        Ok(())
    }

    /// Give the sign at (`x`, `y`) the text `text`. Empty text removes the
    /// sign. A new sign takes `next_id` and the first empty slot while fewer
    /// than `budget` signs are active. Returns the ID of the sign, or 0 for a
    /// removed sign.
    pub fn set_text(&mut self, x: u16, y: u16, text: &str, next_id: u32, budget: usize) -> Result<u32, String> {
        collection::check_name(text)?;

        let free = self.signs.iter().position(|sign| !sign.is_active());
        let found = self.signs.iter().rposition(|sign| sign.is_active() && sign.x == x && sign.y == y);

        match (text.is_empty(), found) {
            (true, None) => Err("this tile does not have a sign".into()),
            (true, Some(slot)) => {
                self.signs[slot] = Sign::default();

                Ok(0)
            }
            (false, Some(slot)) => {
                self.signs[slot].text = text.to_string();

                Ok(self.signs[slot].id)
            }
            (false, None) => match free {
                Some(slot) if self.active_records() < budget => {
                    self.signs[slot] = Sign {
                        id: next_id,
                        x,
                        y,
                        text: text.to_string(),
                        ..Sign::default()
                    };

                    Ok(next_id)
                }
                _ => Err("all sign slots are in use".into()),
            },
        }
    }

    /// The largest sign ID in use.
    pub fn max_id(&self) -> u32 {
        self.signs.iter().map(|sign| sign.id).max().unwrap_or(0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sign(id: u32, x: u16, y: u16, text: &str) -> Sign {
        Sign {
            id,
            x,
            y,
            text: text.into(),
            ..Default::default()
        }
    }

    #[test]
    fn set_text_adds_renames_and_removes_signs() {
        let mut table = Xsgn {
            signs: vec![sign(3, 1, 2, "Old"), Sign::default(), Sign::default()],
            extension: vec![],
        };
        assert_eq!(table.set_text(1, 2, "New", 9, 3), Ok(3));
        assert_eq!(table.signs[0].text, "New");
        assert_eq!(table.set_text(4, 4, "Park", 9, 3), Ok(9));
        assert_eq!(table.signs[1], sign(9, 4, 4, "Park"));
        assert_eq!(table.set_text(5, 5, "Full", 10, 2), Err("all sign slots are in use".into()));
        assert_eq!(table.set_text(1, 2, "", 10, 3), Ok(0));
        assert_eq!(table.signs[0], Sign::default());
        assert_eq!(table.set_text(1, 2, "", 10, 3), Err("this tile does not have a sign".into()));
        assert!(
            table.set_text(6, 6, &"x".repeat(300), 10, 3).is_err(),
            "a name over 256 bytes is refused"
        );
    }

    #[test]
    fn signs_round_trip_with_sizes_from_the_formula() {
        let xsgn = Xsgn {
            signs: vec![sign(3, 1, 2, "Downtown"), Sign::default(), sign(9, 15, 15, "\u{1F999}")],
            extension: vec![],
        };
        let bytes = xsgn.encode(16).unwrap();
        assert_eq!(bytes.len(), 24 + 20 * 3 + "Downtown".len() + 4);
        assert_eq!(Xsgn::decode(&bytes, 16).unwrap(), xsgn);
        assert_eq!(
            Xsgn {
                signs: vec![Sign::default(); 16],
                extension: vec![]
            }
            .encode(16)
            .unwrap()
            .len(),
            24 + 20 * 16
        );
    }

    #[test]
    fn sign_text_limits_are_0_1_64_and_65_code_points() {
        let check = |text: &str| {
            Xsgn {
                signs: vec![sign(1, 0, 0, text)],
                extension: vec![],
            }
            .encode(16)
        };
        assert!(check("").is_err(), "an active sign needs text");
        assert!(check("a").is_ok());
        assert!(check(&"\u{1F600}".repeat(64)).is_ok());
        assert!(check(&"\u{1F600}".repeat(65)).is_err());
    }

    #[test]
    fn validation_enforces_one_sign_per_tile_ids_and_bounds() {
        let same_tile = Xsgn {
            signs: vec![sign(1, 4, 4, "A"), sign(2, 4, 4, "B")],
            extension: vec![],
        };
        assert!(same_tile.encode(16).is_err());

        let same_id = Xsgn {
            signs: vec![sign(1, 4, 4, "A"), sign(1, 5, 4, "B")],
            extension: vec![],
        };
        assert!(same_id.encode(16).is_err());

        let outside = Xsgn {
            signs: vec![sign(1, 16, 0, "A")],
            extension: vec![],
        };
        assert!(outside.encode(16).is_err());

        let stale = Xsgn {
            signs: vec![Sign {
                x: 1,
                ..Default::default()
            }],
            extension: vec![],
        };
        assert!(stale.encode(16).is_err());
    }
}
