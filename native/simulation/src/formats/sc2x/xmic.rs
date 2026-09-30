//! XMIC.bin: facility records with their statistics, owned footprint, and name.
//!
//! File order: common header, `position_bytes: u32`, C fixed cores, C text
//! indexes, position section, UTF-8 text, extension section.

use super::collection::{self, ExtensionBlock, HEADER_SIZE, Header, TEXT_INDEX_SIZE};
use super::wire::{Reader, put_len, put_u16};

pub const CORE_SIZE: usize = 24;
pub const POSITION_SIZE: usize = 4;
/// Shared facility categories use slots 1 through 9. Individual records start at 10.
pub const SHARED_FIRST: usize = 1;
pub const SHARED_LAST: usize = 9;
pub const INDIVIDUAL_FIRST: usize = 10;
/// Extension block of active individual records that own no tile: slot u32,
/// the 8-byte working record, a u16 name length, and the UTF-8 name.
pub const ORPHAN_RECORD_TAG: [u8; 4] = *b"ORPH";

/// The tiles that one record owns.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub enum Footprint {
    /// No owned tiles. A free slot, the reserved slot, or an unplaced shared category.
    #[default]
    None,
    /// Every tile of a complete rectangle.
    Rect { x: u16, y: u16, width: u16, height: u16 },
    /// An explicit column-major list of tile coordinates, for shared, irregular,
    /// or fragmented footprints.
    Tiles(Vec<(u16, u16)>),
}

impl Footprint {
    /// Build the smallest description of the tiles at `indices`, which are
    /// column-major tile indices in ascending order.
    pub fn from_indices(indices: &[usize], edge: usize) -> Self {
        if indices.is_empty() {
            return Footprint::None;
        }

        let points: Vec<(u16, u16)> = indices.iter().map(|index| ((index / edge) as u16, (index % edge) as u16)).collect();
        let (x, y, width, height) = bounds(&points);

        if width as usize * height as usize == points.len() {
            Footprint::Rect { x, y, width, height }
        } else {
            Footprint::Tiles(points)
        }
    }

    /// The owned column-major tile indices in ascending order.
    pub fn indices(&self, edge: usize) -> Vec<usize> {
        match self {
            Footprint::None => Vec::new(),
            Footprint::Rect { x, y, width, height } => {
                let mut result = Vec::with_capacity(*width as usize * *height as usize);

                for column in *x as usize..(*x + *width) as usize {
                    for row in *y as usize..(*y + *height) as usize {
                        result.push(column * edge + row);
                    }
                }

                result
            }
            Footprint::Tiles(points) => points.iter().map(|(x, y)| *x as usize * edge + *y as usize).collect(),
        }
    }

    pub fn bounds(&self) -> (u16, u16, u16, u16) {
        match self {
            Footprint::None => (0, 0, 0, 0),
            Footprint::Rect { x, y, width, height } => (*x, *y, *width, *height),
            Footprint::Tiles(points) => bounds(points),
        }
    }

    pub fn is_empty(&self) -> bool {
        matches!(self, Footprint::None)
    }
}

fn bounds(points: &[(u16, u16)]) -> (u16, u16, u16, u16) {
    let min_x = points.iter().map(|point| point.0).min().unwrap_or(0);
    let max_x = points.iter().map(|point| point.0).max().unwrap_or(0);
    let min_y = points.iter().map(|point| point.1).min().unwrap_or(0);
    let max_y = points.iter().map(|point| point.1).max().unwrap_or(0);

    (min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
}

/// One facility slot. `stats` holds core bytes 1 through 7 unchanged: statistic 0
/// (u8) and statistics 1 through 3 (big-endian u16), with facility-specific meanings.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Facility {
    pub tile_id: u8,
    pub stats: [u8; 7],
    pub footprint: Footprint,
    pub name: String,
}

impl Facility {
    /// The 8-byte legacy record: tile ID, then the statistic bytes.
    pub fn legacy_record(&self) -> [u8; 8] {
        let mut record = [0u8; 8];
        record[0] = self.tile_id;
        record[1..].copy_from_slice(&self.stats);

        record
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Xmic {
    pub facilities: Vec<Facility>,
    pub extension: Vec<ExtensionBlock>,
}

impl Xmic {
    pub fn block(&self, tag: [u8; 4]) -> Option<&ExtensionBlock> {
        self.extension.iter().find(|block| block.tag == tag)
    }

    pub fn active_records(&self) -> usize {
        self.facilities.iter().filter(|facility| facility.tile_id != 0).count()
    }

    pub fn encode(&self, edge: usize) -> Result<Vec<u8>, String> {
        self.validate(edge)?;

        let names: Vec<String> = self.facilities.iter().map(|facility| facility.name.clone()).collect();
        let (index, text) = collection::encode_texts(&names).map_err(|error| format!("XMIC {}", error))?;
        let extension = collection::encode_extension(&self.extension);
        let mut positions = Vec::new();
        let mut cores = Vec::with_capacity(self.facilities.len() * CORE_SIZE);

        for facility in &self.facilities {
            let (x, y, width, height) = facility.footprint.bounds();
            cores.push(facility.tile_id);
            cores.extend_from_slice(&facility.stats);
            put_u16(&mut cores, x);
            put_u16(&mut cores, y);
            put_u16(&mut cores, width);
            put_u16(&mut cores, height);

            match &facility.footprint {
                Footprint::Tiles(points) => {
                    put_len(&mut cores, positions.len());
                    put_len(&mut cores, points.len());

                    for (point_x, point_y) in points {
                        put_u16(&mut positions, *point_x);
                        put_u16(&mut positions, *point_y);
                    }
                }
                _ => {
                    put_len(&mut cores, 0);
                    put_len(&mut cores, 0);
                }
            }
        }

        let header = Header {
            schema_version: collection::SCHEMA_VERSION,
            capacity: self.facilities.len() as u32,
            active_records: self.active_records() as u32,
            record_stride: CORE_SIZE as u32,
            text_bytes: text.len() as u32,
            extension_bytes: extension.len() as u32,
        };
        let mut output = Vec::with_capacity(HEADER_SIZE + 4 + cores.len() + index.len() + positions.len() + text.len() + extension.len());
        header.write(&mut output);
        put_len(&mut output, positions.len());
        output.extend_from_slice(&cores);
        output.extend_from_slice(&index);
        output.extend_from_slice(&positions);
        output.extend_from_slice(&text);
        output.extend_from_slice(&extension);

        Ok(output)
    }

    pub fn decode(bytes: &[u8], edge: usize) -> Result<Self, String> {
        let mut reader = Reader::new(bytes);
        let header = Header::read(&mut reader, CORE_SIZE as u32, "XMIC")?;
        let position_bytes = reader.u32()? as usize;
        let count = header.capacity as usize;
        collection::require(&reader, count, CORE_SIZE + TEXT_INDEX_SIZE, "XMIC")?;

        if !position_bytes.is_multiple_of(POSITION_SIZE) {
            return Err("XMIC position section is not a whole number of coordinate pairs".into());
        }

        let cores = reader.bytes(count * CORE_SIZE)?;
        let index = reader.bytes(count * TEXT_INDEX_SIZE)?;
        let positions = reader.bytes(position_bytes)?;
        let text = reader.bytes(header.text_bytes as usize)?;
        let names = collection::decode_texts(index, text, count, "XMIC")?;
        let extension = collection::decode_extension(reader.bytes(header.extension_bytes as usize)?, "XMIC")?;

        if reader.remaining() != 0 {
            return Err(format!("XMIC has {} bytes after its extension section", reader.remaining()));
        }

        let mut facilities = Vec::with_capacity(count);
        let mut packed = 0usize;

        for (slot, name) in names.into_iter().enumerate() {
            let mut core = Reader::new(&cores[slot * CORE_SIZE..(slot + 1) * CORE_SIZE]);
            let tile_id = core.u8()?;
            let mut stats = [0u8; 7];
            stats.copy_from_slice(core.bytes(7)?);
            let (x, y, width, height) = (core.u16()?, core.u16()?, core.u16()?, core.u16()?);
            let position_offset = core.u32()? as usize;
            let position_count = core.u32()? as usize;

            let footprint = if position_count == 0 {
                if position_offset != 0 {
                    return Err(format!("XMIC slot {} has a position offset without positions", slot));
                }

                match (width, height) {
                    (0, 0) if x == 0 && y == 0 => Footprint::None,
                    (0, 0) => return Err(format!("XMIC slot {} has an empty footprint with a nonzero origin", slot)),
                    (0, _) | (_, 0) => return Err(format!("XMIC slot {} has a footprint with one zero dimension", slot)),
                    _ => Footprint::Rect { x, y, width, height },
                }
            } else {
                if position_offset != packed || position_offset + position_count * POSITION_SIZE > positions.len() {
                    return Err(format!("XMIC slot {} tile list is not packed by slot", slot));
                }

                let mut list = Reader::new(&positions[position_offset..position_offset + position_count * POSITION_SIZE]);
                let mut points = Vec::with_capacity(position_count);

                for _ in 0..position_count {
                    points.push((list.u16()?, list.u16()?));
                }

                packed += position_count * POSITION_SIZE;

                if bounds(&points) != (x, y, width, height) {
                    return Err(format!("XMIC slot {} bounds do not match its tile list", slot));
                }

                Footprint::Tiles(points)
            };

            facilities.push(Facility {
                tile_id,
                stats,
                footprint,
                name,
            });
        }

        if packed != positions.len() {
            return Err("XMIC position section has coordinate pairs that no record uses".into());
        }

        let result = Self { facilities, extension };

        if result.active_records() != header.active_records as usize {
            return Err("XMIC active record count does not match its records".into());
        }

        result.validate(edge)?;

        Ok(result)
    }

    /// Check geometry, ownership, and slot rules against a map of `edge` tiles.
    pub fn validate(&self, edge: usize) -> Result<(), String> {
        let mut owner = vec![u32::MAX; edge * edge];

        for (slot, facility) in self.facilities.iter().enumerate() {
            if (slot == 0 || facility.tile_id == 0) && (!facility.footprint.is_empty() || !facility.name.is_empty()) {
                return Err(format!("XMIC slot {} is free or reserved but has geometry or a name", slot));
            }

            if slot >= INDIVIDUAL_FIRST && facility.tile_id != 0 && facility.footprint.is_empty() {
                return Err(format!("XMIC individual facility {} owns no tile", slot));
            }

            match &facility.footprint {
                Footprint::None => {}
                Footprint::Rect { x, y, width, height } => {
                    if *x as usize + *width as usize > edge || *y as usize + *height as usize > edge {
                        return Err(format!("XMIC slot {} footprint extends past the map", slot));
                    }
                }
                Footprint::Tiles(points) => {
                    let mut previous: Option<usize> = None;

                    for (x, y) in points {
                        if *x as usize >= edge || *y as usize >= edge {
                            return Err(format!("XMIC slot {} tile ({}, {}) is outside the map", slot, x, y));
                        }

                        let index = *x as usize * edge + *y as usize;

                        if previous.is_some_and(|last| index <= last) {
                            return Err(format!("XMIC slot {} tile list is not in ascending column-major order", slot));
                        }

                        previous = Some(index);
                    }
                }
            }

            for index in facility.footprint.indices(edge) {
                if owner[index] != u32::MAX {
                    return Err(format!("XMIC slots {} and {} both own tile {}", owner[index], slot, index));
                }

                owner[index] = slot as u32;
            }
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn facility(tile_id: u8, footprint: Footprint, name: &str) -> Facility {
        Facility {
            tile_id,
            stats: [1, 2, 3, 4, 5, 6, 7],
            footprint,
            name: name.into(),
        }
    }

    fn sample() -> Xmic {
        let mut facilities = vec![
            Facility {
                tile_id: 0xec,
                ..Default::default()
            };
            12
        ];
        facilities[1] = facility(0xd2, Footprint::Tiles(vec![(0, 0), (0, 1), (5, 5)]), "Bus Depots");
        facilities[2] = facility(0xd3, Footprint::None, "");
        facilities[10] = facility(
            0xe0,
            Footprint::Rect {
                x: 2,
                y: 3,
                width: 3,
                height: 2,
            },
            "City Hall \u{00e9}",
        );
        facilities[11] = facility(0, Footprint::None, "");

        Xmic {
            facilities,
            extension: vec![],
        }
    }

    #[test]
    fn records_round_trip_with_sizes_from_the_formula() {
        let xmic = sample();
        let bytes = xmic.encode(16).unwrap();
        let text = "Bus Depots".len() + "City Hall \u{00e9}".len();
        assert_eq!(bytes.len(), 28 + 32 * 12 + 4 * 3 + text);
        assert_eq!(Xmic::decode(&bytes, 16).unwrap(), xmic);
    }

    #[test]
    fn minimum_size_is_28_plus_32_per_slot() {
        let xmic = Xmic {
            facilities: vec![Facility::default(); 64],
            extension: vec![],
        };
        assert_eq!(xmic.encode(16).unwrap().len(), 28 + 32 * 64);
    }

    #[test]
    fn footprints_choose_rectangles_only_when_complete() {
        assert_eq!(
            Footprint::from_indices(&[17, 18, 33, 34], 16),
            Footprint::Rect {
                x: 1,
                y: 1,
                width: 2,
                height: 2
            }
        );
        assert_eq!(Footprint::from_indices(&[17, 34], 16), Footprint::Tiles(vec![(1, 1), (2, 2)]));
        assert_eq!(Footprint::from_indices(&[], 16), Footprint::None);
        let edge_clipped = Footprint::from_indices(&[14 * 16 + 15, 15 * 16 + 15], 16);
        assert_eq!(
            edge_clipped,
            Footprint::Rect {
                x: 14,
                y: 15,
                width: 2,
                height: 1
            }
        );
        assert_eq!(edge_clipped.indices(16), vec![14 * 16 + 15, 15 * 16 + 15]);
    }

    #[test]
    fn validation_rejects_overlap_order_bounds_and_reserved_geometry() {
        let mut overlap = sample();
        overlap.facilities[11] = facility(
            0xe1,
            Footprint::Rect {
                x: 8,
                y: 8,
                width: 1,
                height: 1,
            },
            "",
        );
        assert!(overlap.encode(16).is_ok());
        overlap.facilities[11] = facility(
            0xe1,
            Footprint::Rect {
                x: 4,
                y: 4,
                width: 2,
                height: 2,
            },
            "",
        );
        assert!(overlap.encode(16).is_err(), "rectangle overlaps slot 10");

        let mut unsorted = sample();
        unsorted.facilities[1].footprint = Footprint::Tiles(vec![(5, 5), (0, 0)]);
        assert!(unsorted.encode(16).is_err());

        let mut outside = sample();
        outside.facilities[10].footprint = Footprint::Rect {
            x: 15,
            y: 0,
            width: 2,
            height: 1,
        };
        assert!(outside.encode(16).is_err());

        let mut reserved = sample();
        reserved.facilities[0].name = "Reserved".into();
        assert!(reserved.encode(16).is_err());

        let mut free = sample();
        free.facilities[11].footprint = Footprint::Rect {
            x: 9,
            y: 9,
            width: 1,
            height: 1,
        };
        assert!(free.encode(16).is_err());
    }

    #[test]
    fn decoding_rejects_inconsistent_framing() {
        let bytes = sample().encode(16).unwrap();
        assert!(Xmic::decode(&bytes[..bytes.len() - 1], 16).is_err());

        let mut extra = bytes.clone();
        extra.push(0);
        assert!(Xmic::decode(&extra, 16).is_err());

        let mut active = bytes.clone();
        active[11] ^= 1;
        assert!(Xmic::decode(&active, 16).is_err());

        let mut bounds = bytes.clone();
        // slot 1 width follows its tile ID, statistics, X, and Y
        let width = 28 + CORE_SIZE + 12;
        bounds[width + 1] += 1;
        assert!(Xmic::decode(&bounds, 16).is_err());
    }
}
