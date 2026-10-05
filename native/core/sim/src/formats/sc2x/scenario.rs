//! SCEN schema 2 and the matching TMPL descriptors.
//!
//! SCEN schema 2 is 64 bytes at every map size. It widens the disaster
//! coordinates to u16 and the two building tile counts to u32. The legacy
//! 52-byte layout has no life-expectancy or education goals; they become zero.

use super::wire::{Reader, put_i32, put_u16, put_u32};

pub const MARKER: u32 = 0x8000_0000;
pub const LEGACY_SIZE: usize = 52;
pub const EXTENDED_SIZE: usize = 56;
pub const SCHEMA2_SIZE: usize = 64;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Scenario {
    pub disaster_type: u16,
    pub disaster_x: u16,
    pub disaster_y: u16,
    pub time_limit_months: u16,
    pub city_size_goal: u32,
    pub residential_goal: i32,
    pub commercial_goal: i32,
    pub industrial_goal: i32,
    pub cash_goal: i32,
    pub land_value_goal: i32,
    pub life_expectancy_goal: u16,
    pub education_goal: u16,
    pub pollution_limit: u32,
    pub crime_limit: u32,
    pub traffic_limit: u32,
    pub first_building_id: u8,
    pub second_building_id: u8,
    pub first_building_tile_count: u32,
    pub second_building_tile_count: u32,
    pub reserved: u16,
}

impl Scenario {
    /// Read a 52-byte or 56-byte original SCEN payload.
    pub fn from_legacy(data: &[u8]) -> Result<Self, String> {
        if data.len() != LEGACY_SIZE && data.len() != EXTENDED_SIZE {
            return Err(format!("SCEN has {} bytes; expected 52 or 56", data.len()));
        }

        let mut reader = Reader::new(data);

        if reader.u32()? != MARKER {
            return Err("SCEN header is not 0x80000000".into());
        }

        let mut scenario = Scenario {
            disaster_type: reader.u16()?,
            disaster_x: reader.u8()? as u16,
            disaster_y: reader.u8()? as u16,
            time_limit_months: reader.u16()?,
            city_size_goal: reader.u32()?,
            residential_goal: reader.i32()?,
            commercial_goal: reader.i32()?,
            industrial_goal: reader.i32()?,
            cash_goal: reader.i32()?,
            land_value_goal: reader.i32()?,
            ..Default::default()
        };

        if data.len() == EXTENDED_SIZE {
            scenario.life_expectancy_goal = reader.u16()?;
            scenario.education_goal = reader.u16()?;
        }

        scenario.pollution_limit = reader.u32()?;
        scenario.crime_limit = reader.u32()?;
        scenario.traffic_limit = reader.u32()?;
        scenario.first_building_id = reader.u8()?;
        scenario.second_building_id = reader.u8()?;
        scenario.first_building_tile_count = reader.u16()? as u32;
        scenario.second_building_tile_count = reader.u16()? as u32;

        Ok(scenario)
    }

    pub fn from_schema2(data: &[u8], edge: usize) -> Result<Self, String> {
        if data.len() != SCHEMA2_SIZE {
            return Err(format!("SCEN schema 2 has {} bytes; expected 64", data.len()));
        }

        let mut reader = Reader::new(data);

        if reader.u32()? != MARKER {
            return Err("SCEN header is not 0x80000000".into());
        }

        let scenario = Scenario {
            disaster_type: reader.u16()?,
            disaster_x: reader.u16()?,
            disaster_y: reader.u16()?,
            time_limit_months: reader.u16()?,
            city_size_goal: reader.u32()?,
            residential_goal: reader.i32()?,
            commercial_goal: reader.i32()?,
            industrial_goal: reader.i32()?,
            cash_goal: reader.i32()?,
            land_value_goal: reader.i32()?,
            life_expectancy_goal: reader.u16()?,
            education_goal: reader.u16()?,
            pollution_limit: reader.u32()?,
            crime_limit: reader.u32()?,
            traffic_limit: reader.u32()?,
            first_building_id: reader.u8()?,
            second_building_id: reader.u8()?,
            first_building_tile_count: reader.u32()?,
            second_building_tile_count: reader.u32()?,
            reserved: reader.u16()?,
        };

        if scenario.disaster_x as usize >= edge || scenario.disaster_y as usize >= edge {
            return Err("SCEN disaster coordinates are outside the map".into());
        }

        Ok(scenario)
    }

    pub fn to_schema2(&self) -> Vec<u8> {
        let mut output = Vec::with_capacity(SCHEMA2_SIZE);
        put_u32(&mut output, MARKER);
        put_u16(&mut output, self.disaster_type);
        put_u16(&mut output, self.disaster_x);
        put_u16(&mut output, self.disaster_y);
        put_u16(&mut output, self.time_limit_months);
        put_u32(&mut output, self.city_size_goal);
        put_i32(&mut output, self.residential_goal);
        put_i32(&mut output, self.commercial_goal);
        put_i32(&mut output, self.industrial_goal);
        put_i32(&mut output, self.cash_goal);
        put_i32(&mut output, self.land_value_goal);
        put_u16(&mut output, self.life_expectancy_goal);
        put_u16(&mut output, self.education_goal);
        put_u32(&mut output, self.pollution_limit);
        put_u32(&mut output, self.crime_limit);
        put_u32(&mut output, self.traffic_limit);
        // the two u32 counts are deliberately unaligned in the serialized bytes
        output.push(self.first_building_id);
        output.push(self.second_building_id);
        put_u32(&mut output, self.first_building_tile_count);
        put_u32(&mut output, self.second_building_tile_count);
        put_u16(&mut output, self.reserved);

        output
    }
}

/// One TMPL descriptor: a field name and its DBYT, DWRD, or DLNG type code.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Descriptor {
    pub name: Vec<u8>,
    pub type_code: [u8; 4],
}

const DBYT: [u8; 4] = *b"DBYT";
const DWRD: [u8; 4] = *b"DWRD";
const DLNG: [u8; 4] = *b"DLNG";

/// The descriptors of the original 52-byte SCEN layout, in order.
const LEGACY_TEMPLATE: [(&str, [u8; 4]); 17] = [
    ("Disaster Type", DWRD),
    ("Disaster XLoc", DBYT),
    ("Disaster YLoc", DBYT),
    ("Time Limit (Months)", DWRD),
    ("City Size Goal", DLNG),
    ("Residential Goal", DLNG),
    ("Commercial Goal", DLNG),
    ("Industrial Goal", DLNG),
    ("Cash Goal Funds-Bonds", DLNG),
    ("Land Value Goal", DLNG),
    ("Pollution Limit", DLNG),
    ("Crime Limit", DLNG),
    ("Traffic Limit", DLNG),
    ("Build Item One", DBYT),
    ("Build Item Two", DBYT),
    ("Item One Tiles", DWRD),
    ("Item Two Tiles", DWRD),
];

/// The descriptors of SCEN schema 2, in order.
pub const SCHEMA2_TEMPLATE: [(&str, [u8; 4]); 20] = [
    ("Disaster Type", DWRD),
    ("Disaster XLoc", DWRD),
    ("Disaster YLoc", DWRD),
    ("Time Limit (Months)", DWRD),
    ("City Size Goal", DLNG),
    ("Residential Goal", DLNG),
    ("Commercial Goal", DLNG),
    ("Industrial Goal", DLNG),
    ("Cash Goal Funds-Bonds", DLNG),
    ("Land Value Goal", DLNG),
    ("Life Expectancy Goal", DWRD),
    ("Education Goal", DWRD),
    ("Pollution Limit", DLNG),
    ("Crime Limit", DLNG),
    ("Traffic Limit", DLNG),
    ("Build Item One", DBYT),
    ("Build Item Two", DBYT),
    ("Item One Tiles", DLNG),
    ("Item Two Tiles", DLNG),
    ("Reserved", DWRD),
];

pub fn parse_template(data: &[u8]) -> Result<Vec<Descriptor>, String> {
    let mut reader = Reader::new(data);

    if reader.u32()? != MARKER {
        return Err("TMPL header is not 0x80000000".into());
    }

    let mut result = Vec::new();

    while reader.remaining() > 0 {
        let length = reader.u8()? as usize;

        if length == 0 {
            return Err("TMPL descriptor has an empty name".into());
        }

        let name = reader.bytes(length)?.to_vec();
        let code = reader.bytes(4)?;
        result.push(Descriptor {
            name,
            type_code: [code[0], code[1], code[2], code[3]],
        });
    }

    Ok(result)
}

pub fn encode_template(descriptors: &[Descriptor]) -> Vec<u8> {
    let mut output = Vec::new();
    put_u32(&mut output, MARKER);

    for descriptor in descriptors {
        output.push(descriptor.name.len() as u8);
        output.extend_from_slice(&descriptor.name);
        output.extend_from_slice(&descriptor.type_code);
    }

    output
}

pub fn schema2_template() -> Vec<u8> {
    let descriptors: Vec<Descriptor> = SCHEMA2_TEMPLATE
        .iter()
        .map(|(name, code)| Descriptor {
            name: name.as_bytes().to_vec(),
            type_code: *code,
        })
        .collect();

    encode_template(&descriptors)
}

/// The SCEN size that a template describes, including the 4-byte marker.
pub fn template_scenario_size(descriptors: &[Descriptor]) -> Option<usize> {
    let mut size = 4;

    for descriptor in descriptors {
        size += match descriptor.type_code {
            DBYT => 1,
            DWRD => 2,
            DLNG => 4,
            _ => return None,
        };
    }

    Some(size)
}

/// Upgrade a template of the original layout to SCEN schema 2. `None` means the
/// template has other descriptors; keep it only as superseded preserved data.
pub fn upgrade_template(data: &[u8]) -> Option<Vec<u8>> {
    let descriptors = parse_template(data).ok()?;

    if descriptors.len() != LEGACY_TEMPLATE.len() {
        return None;
    }

    for (descriptor, (name, code)) in descriptors.iter().zip(LEGACY_TEMPLATE.iter()) {
        if descriptor.name != name.as_bytes() || descriptor.type_code != *code {
            return None;
        }
    }

    Some(schema2_template())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn legacy(size: usize) -> Vec<u8> {
        let mut data = Vec::new();
        put_u32(&mut data, MARKER);
        put_u16(&mut data, 3);
        data.extend_from_slice(&[100, 27]);
        put_u16(&mut data, 60);
        put_u32(&mut data, 30000);

        for value in [1, -2, 3, 4000, 90] {
            put_i32(&mut data, value);
        }

        if size == EXTENDED_SIZE {
            put_u16(&mut data, 71);
            put_u16(&mut data, 88);
        }

        for value in [10, 20, 30] {
            put_u32(&mut data, value);
        }

        data.extend_from_slice(&[0xd2, 0xe0]);
        put_u16(&mut data, 12);
        put_u16(&mut data, 65535);
        assert_eq!(data.len(), size);

        data
    }

    #[test]
    fn both_legacy_sizes_convert_to_schema_2() {
        let short = Scenario::from_legacy(&legacy(LEGACY_SIZE)).unwrap();
        assert_eq!(
            (short.disaster_x, short.disaster_y, short.life_expectancy_goal, short.education_goal),
            (100, 27, 0, 0)
        );
        assert_eq!(short.residential_goal, 1);
        assert_eq!(short.commercial_goal, -2);
        assert_eq!(short.second_building_tile_count, 65535);

        let long = Scenario::from_legacy(&legacy(EXTENDED_SIZE)).unwrap();
        assert_eq!((long.life_expectancy_goal, long.education_goal), (71, 88));
        assert_eq!(long.traffic_limit, 30);

        let bytes = long.to_schema2();
        assert_eq!(bytes.len(), SCHEMA2_SIZE);
        assert_eq!(Scenario::from_schema2(&bytes, 128).unwrap(), long);
    }

    #[test]
    fn schema_2_holds_large_coordinates_and_counts() {
        let scenario = Scenario {
            disaster_x: 1000,
            disaster_y: 300,
            first_building_tile_count: 70000,
            second_building_tile_count: 1 << 31,
            ..Default::default()
        };
        let bytes = scenario.to_schema2();
        assert_eq!(&bytes[6..10], &[0x03, 0xe8, 0x01, 0x2c]);
        assert_eq!(&bytes[54..58], &70000u32.to_be_bytes());
        assert_eq!(Scenario::from_schema2(&bytes, 1024).unwrap(), scenario);
        assert!(Scenario::from_schema2(&bytes, 512).is_err(), "coordinates must be inside the map");
        assert!(Scenario::from_legacy(&bytes).is_err());
    }

    #[test]
    fn templates_upgrade_only_when_they_describe_the_original_layout() {
        let descriptors: Vec<Descriptor> = LEGACY_TEMPLATE
            .iter()
            .map(|(name, code)| Descriptor {
                name: name.as_bytes().to_vec(),
                type_code: *code,
            })
            .collect();
        let original = encode_template(&descriptors);
        assert_eq!(template_scenario_size(&descriptors), Some(LEGACY_SIZE));

        let upgraded = upgrade_template(&original).unwrap();
        let parsed = parse_template(&upgraded).unwrap();
        assert_eq!(template_scenario_size(&parsed), Some(SCHEMA2_SIZE));
        assert_eq!(parsed[1].type_code, DWRD);
        assert_eq!(parsed[17].type_code, DLNG);

        let mut unknown = descriptors.clone();
        unknown.push(Descriptor {
            name: b"Custom".to_vec(),
            type_code: DBYT,
        });
        assert!(upgrade_template(&encode_template(&unknown)).is_none());
    }
}
