//! The saved city chunks that the simulation reads and writes.
//!
//! The GDScript CityState keeps mirror arrays of some chunks. The simulation
//! keeps each mirror equal to its chunk, so this model keeps only the chunks.
//! A chunk that the simulation writes is marked `written`, as Sc2Chunk.mark_mutated
//! does. The bridge then stores it in the GDScript document.

use super::bytes::{read_u32_be, write_u32_be};
use super::ids::{sc2altitude_layout as altitude, sc2microsim_layout, sc2misc_layout as misc};
use super::ids::{sc2overlay_layout, sc2tile_flags as flags, sc2zone_layout as zone};

#[derive(Clone, Debug, Default)]
pub struct Chunk {
    pub present: bool,
    pub data: Vec<u8>,
    pub written: bool,
}

impl Chunk {
    pub fn new(data: Vec<u8>) -> Self {
        Self {
            present: true,
            data,
            written: false,
        }
    }

    /// Mutable access marks the chunk as written, as each GDScript write does.
    #[inline]
    pub fn mutate(&mut self) -> &mut Vec<u8> {
        self.written = true;

        &mut self.data
    }

    /// Replace the payload, as Sc2Chunk.set_decoded_payload does after its size check.
    pub fn replace(&mut self, value: Vec<u8>) {
        self.data = value;
        self.written = true;
    }

    /// Mark the chunk written when its content differs from `original`.
    /// Growth and other copy-then-commit phases write only changed chunks.
    pub fn commit_if_changed(&mut self, original: &[u8]) -> bool {
        let changed = self.data.as_slice() != original;
        self.written |= changed;

        changed
    }
}

/// Chunk identifiers that the simulation uses. Other chunks stay in GDScript.
pub const CHUNK_IDS: [&str; 25] = [
    "CNAM", "MISC", "ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XLAB", "XMIC", "XTHG", "XBIT", "XTRF", "XPLT", "XVAL", "XCRM", "XPLC",
    "XFIR", "XPOP", "XROG", "XGRP", "SCEN", "TEXT", "PICT", "TMPL",
];

#[derive(Clone, Debug, Default)]
pub struct City {
    pub map_size: i64,
    pub large_version: i64,
    pub cnam: Chunk,
    pub misc: Chunk,
    pub altm: Chunk,
    pub xter: Chunk,
    pub xbld: Chunk,
    pub xzon: Chunk,
    pub xund: Chunk,
    pub xtxt: Chunk,
    pub xlab: Chunk,
    pub xmic: Chunk,
    pub xthg: Chunk,
    pub xbit: Chunk,
    pub xtrf: Chunk,
    pub xplt: Chunk,
    pub xval: Chunk,
    pub xcrm: Chunk,
    pub xplc: Chunk,
    pub xfir: Chunk,
    pub xpop: Chunk,
    pub xrog: Chunk,
    pub xgrp: Chunk,
    pub scen: Chunk,
    pub text: Chunk,
    pub pict: Chunk,
    pub tmpl: Chunk,
    /// Runtime only. The most important building class that disaster damage reached.
    pub disaster_damage_class: i64,
}

impl City {
    pub fn new(map_size: i64, large_version: i64) -> Self {
        Self {
            map_size,
            large_version,
            disaster_damage_class: -1,
            ..Default::default()
        }
    }

    pub fn chunk(&self, id: &str) -> Option<&Chunk> {
        let chunk = match id {
            "CNAM" => &self.cnam,
            "MISC" => &self.misc,
            "ALTM" => &self.altm,
            "XTER" => &self.xter,
            "XBLD" => &self.xbld,
            "XZON" => &self.xzon,
            "XUND" => &self.xund,
            "XTXT" => &self.xtxt,
            "XLAB" => &self.xlab,
            "XMIC" => &self.xmic,
            "XTHG" => &self.xthg,
            "XBIT" => &self.xbit,
            "XTRF" => &self.xtrf,
            "XPLT" => &self.xplt,
            "XVAL" => &self.xval,
            "XCRM" => &self.xcrm,
            "XPLC" => &self.xplc,
            "XFIR" => &self.xfir,
            "XPOP" => &self.xpop,
            "XROG" => &self.xrog,
            "XGRP" => &self.xgrp,
            "SCEN" => &self.scen,
            "TEXT" => &self.text,
            "PICT" => &self.pict,
            "TMPL" => &self.tmpl,
            _ => return None,
        };

        chunk.present.then_some(chunk)
    }

    pub fn chunk_mut(&mut self, id: &str) -> Option<&mut Chunk> {
        let chunk = match id {
            "CNAM" => &mut self.cnam,
            "MISC" => &mut self.misc,
            "ALTM" => &mut self.altm,
            "XTER" => &mut self.xter,
            "XBLD" => &mut self.xbld,
            "XZON" => &mut self.xzon,
            "XUND" => &mut self.xund,
            "XTXT" => &mut self.xtxt,
            "XLAB" => &mut self.xlab,
            "XMIC" => &mut self.xmic,
            "XTHG" => &mut self.xthg,
            "XBIT" => &mut self.xbit,
            "XTRF" => &mut self.xtrf,
            "XPLT" => &mut self.xplt,
            "XVAL" => &mut self.xval,
            "XCRM" => &mut self.xcrm,
            "XPLC" => &mut self.xplc,
            "XFIR" => &mut self.xfir,
            "XPOP" => &mut self.xpop,
            "XROG" => &mut self.xrog,
            "XGRP" => &mut self.xgrp,
            "SCEN" => &mut self.scen,
            "TEXT" => &mut self.text,
            "PICT" => &mut self.pict,
            "TMPL" => &mut self.tmpl,
            _ => return None,
        };

        if chunk.present { Some(chunk) } else { None }
    }

    /// The first missing chunk of `ids`, or None when all are present with the
    /// decoded size of the document.
    pub fn missing_or_resized(&self, ids: &[&str]) -> Option<String> {
        for id in ids {
            match self.chunk(id) {
                Some(chunk) if chunk.data.len() as i64 == self.decoded_size(id) => {}
                _ => return Some(id.to_string()),
            }
        }

        None
    }

    pub fn tile_count(&self) -> i64 {
        self.map_size * self.map_size
    }

    /// Sc2File.full_resolution_maps. SCLG version 3 and SC2X version 4 use per-tile data maps.
    pub fn full_resolution_maps(&self) -> bool {
        self.large_version >= 3
    }

    /// An SC2X version 4 working document. Its tile index has two planes at
    /// every map size, and its record tables have per-document capacities.
    pub fn is_sc2x_working(&self) -> bool {
        self.large_version >= 4
    }

    /// Sc2File.is_extended.
    pub fn is_extended(&self) -> bool {
        self.map_size != 128 || self.full_resolution_maps()
    }

    /// Sc2File.decoded_size.
    pub fn decoded_size(&self, id: &str) -> i64 {
        let edge = self.map_size;

        // a working document keeps the record capacities of its file
        if self.is_sc2x_working() {
            match id {
                // the layered tile index
                "XTXT" => return edge * edge * super::overlay::LAYERED_PLANES,
                "XMIC" | "XTHG" | "XLAB" => return self.chunk(id).map_or(-1, |chunk| chunk.data.len() as i64),
                _ => {}
            }
        }

        crate::formats::sc2::decoded_size(id, edge, self.large_version)
    }

    #[inline]
    pub fn index_of(&self, x: i64, y: i64) -> i64 {
        if x < 0 || x >= self.map_size || y < 0 || y >= self.map_size {
            return -1;
        }

        x * self.map_size + y
    }

    #[inline]
    pub fn altitude_word(&self, index: i64) -> i64 {
        let offset = index as usize * 2;

        ((self.altm.data[offset] as i64) << 8) | self.altm.data[offset + 1] as i64
    }

    pub fn land_altitude(&self, x: i64, y: i64) -> i64 {
        let index = self.index_of(x, y);

        if index < 0 {
            0
        } else {
            self.altitude_word(index) & altitude::LAND_MASK
        }
    }

    pub fn water_altitude(&self, x: i64, y: i64) -> i64 {
        let index = self.index_of(x, y);

        if index < 0 {
            0
        } else {
            (self.altitude_word(index) >> altitude::WATER_SHIFT) & altitude::LEVEL_MASK
        }
    }

    pub fn tunnel_levels(&self, x: i64, y: i64) -> i64 {
        let index = self.index_of(x, y);

        if index < 0 {
            0
        } else {
            (self.altitude_word(index) >> altitude::TUNNEL_SHIFT) & altitude::TUNNEL_FIELD_VALUE_MASK
        }
    }

    #[inline]
    fn byte_at(data: &[u8], index: i64) -> i64 {
        if index < 0 { 0 } else { data[index as usize] as i64 }
    }

    pub fn terrain_id(&self, x: i64, y: i64) -> i64 {
        Self::byte_at(&self.xter.data, self.index_of(x, y))
    }

    pub fn building_id(&self, x: i64, y: i64) -> i64 {
        Self::byte_at(&self.xbld.data, self.index_of(x, y))
    }

    pub fn zone_id(&self, x: i64, y: i64) -> i64 {
        Self::byte_at(&self.xzon.data, self.index_of(x, y)) & zone::TYPE_MASK
    }

    pub fn building_corners(&self, x: i64, y: i64) -> i64 {
        Self::byte_at(&self.xzon.data, self.index_of(x, y)) & zone::CORNERS_MASK
    }

    pub fn underground_id(&self, x: i64, y: i64) -> i64 {
        Self::byte_at(&self.xund.data, self.index_of(x, y))
    }

    pub fn text_overlay_id(&self, x: i64, y: i64) -> i64 {
        let index = self.index_of(x, y);

        if index < 0 {
            0
        } else {
            super::overlay::read(&self.xtxt.data, index)
        }
    }

    fn flag(&self, x: i64, y: i64, mask: i64) -> bool {
        Self::byte_at(&self.xbit.data, self.index_of(x, y)) & mask != 0
    }

    pub fn is_salt_water(&self, x: i64, y: i64) -> bool {
        self.flag(x, y, flags::SALT_WATER)
    }

    pub fn is_flipped(&self, x: i64, y: i64) -> bool {
        self.flag(x, y, flags::FLIPPED)
    }

    pub fn is_water(&self, x: i64, y: i64) -> bool {
        self.flag(x, y, flags::WATER)
    }

    pub fn is_watered(&self, x: i64, y: i64) -> bool {
        self.flag(x, y, flags::WATERED)
    }

    pub fn is_piped(&self, x: i64, y: i64) -> bool {
        self.flag(x, y, flags::PIPED)
    }

    pub fn is_powered(&self, x: i64, y: i64) -> bool {
        self.flag(x, y, flags::POWERED)
    }

    pub fn is_powerable(&self, x: i64, y: i64) -> bool {
        self.flag(x, y, flags::POWERABLE)
    }

    /// CityTileEdits.set_building_id without the range check.
    pub fn set_building_id(&mut self, x: i64, y: i64, value: i64) -> bool {
        let index = self.index_of(x, y);

        if !(0..=0xff).contains(&value) || index < 0 || self.xbld.data.len() as i64 != self.tile_count() {
            return false;
        }

        self.xbld.mutate()[index as usize] = value as u8;

        true
    }

    pub fn set_terrain_id(&mut self, x: i64, y: i64, value: i64) -> bool {
        let index = self.index_of(x, y);

        if !(0..=0xff).contains(&value) || index < 0 || self.xter.data.len() as i64 != self.tile_count() {
            return false;
        }

        self.xter.mutate()[index as usize] = value as u8;

        true
    }

    pub fn set_underground_id(&mut self, x: i64, y: i64, value: i64) -> bool {
        let index = self.index_of(x, y);

        if !(0..=0xff).contains(&value) || index < 0 || self.xund.data.len() as i64 != self.tile_count() {
            return false;
        }

        self.xund.mutate()[index as usize] = value as u8;

        true
    }

    /// CityTileEdits.set_zone_id: keep the corner bits of the stored byte.
    pub fn set_zone_id(&mut self, x: i64, y: i64, value: i64) -> bool {
        let index = self.index_of(x, y);

        if !(0..=zone::TYPE_MASK).contains(&value) || index < 0 || self.xzon.data.len() as i64 != self.tile_count() {
            return false;
        }

        let data = self.xzon.mutate();
        data[index as usize] = ((data[index as usize] as i64 & zone::CORNERS_MASK) | value) as u8;

        true
    }

    /// CityTileEdits.set_building_corners: keep the zone bits of the stored byte.
    pub fn set_building_corners(&mut self, x: i64, y: i64, value: i64) -> bool {
        let index = self.index_of(x, y);

        if !(0..=zone::CORNERS_MASK).contains(&value)
            || value & zone::TYPE_MASK != 0
            || index < 0
            || self.xzon.data.len() as i64 != self.tile_count()
        {
            return false;
        }

        let data = self.xzon.mutate();
        data[index as usize] = (value | (data[index as usize] as i64 & zone::TYPE_MASK)) as u8;

        true
    }

    /// CityTileEdits.set_text_overlay_id.
    pub fn set_text_overlay_id(&mut self, x: i64, y: i64, value: i64) -> bool {
        let limit = if self.map_size <= 128 { 0xff } else { 0xffff };
        let index = self.index_of(x, y);
        let size = self.xtxt.data.len() as i64;

        if value < 0 || value > limit || index < 0 || index >= size || !self.xtxt.present {
            return false;
        }

        let cells = super::overlay::cells_for(size);

        if index >= cells || (cells < size && cells + index >= size) {
            return false;
        }

        super::overlay::write(self.xtxt.mutate(), index, value);

        true
    }

    /// CityTileEdits.set_tile_flag.
    pub fn set_tile_flag(&mut self, x: i64, y: i64, mask: i64, enabled: bool) -> bool {
        let index = self.index_of(x, y);

        if !(0..=0xff).contains(&mask) || index < 0 || self.xbit.data.len() as i64 != self.tile_count() {
            return false;
        }

        let data = self.xbit.mutate();
        let current = data[index as usize] as i64;
        data[index as usize] = if enabled { current | mask } else { current & !mask & 0xff } as u8;

        true
    }

    /// CityTileEdits._set_altitude_word.
    pub fn set_altitude_word(&mut self, x: i64, y: i64, value: i64) -> bool {
        let index = self.index_of(x, y);

        if index < 0 || self.altm.data.len() as i64 != self.tile_count() * 2 {
            return false;
        }

        let word = value & 0xffff;
        let data = self.altm.mutate();
        data[index as usize * 2] = (word >> 8) as u8;
        data[index as usize * 2 + 1] = word as u8;

        true
    }

    pub fn set_land_altitude(&mut self, x: i64, y: i64, value: i64) -> bool {
        let index = self.index_of(x, y);

        if !(0..=altitude::LEVEL_MASK).contains(&value) || index < 0 {
            return false;
        }

        let word = (self.altitude_word(index) & !altitude::LEVEL_MASK) | value;
        self.set_altitude_word(x, y, word)
    }

    pub fn set_water_altitude(&mut self, x: i64, y: i64, value: i64) -> bool {
        let index = self.index_of(x, y);

        if !(0..=altitude::LEVEL_MASK).contains(&value) || index < 0 {
            return false;
        }

        let word = (self.altitude_word(index) & !altitude::WATER_MASK) | (value << altitude::WATER_SHIFT);
        self.set_altitude_word(x, y, word)
    }

    pub fn set_tunnel_levels(&mut self, x: i64, y: i64, value: i64) -> bool {
        let index = self.index_of(x, y);

        if !(0..=altitude::TUNNEL_FIELD_VALUE_MASK).contains(&value) || index < 0 {
            return false;
        }

        let word = (self.altitude_word(index) & !altitude::TUNNEL_FIELD_MASK) | (value << altitude::TUNNEL_SHIFT);
        self.set_altitude_word(x, y, word)
    }

    /// Sc2File.misc_u32: 0 when MISC is missing or the field is outside it.
    pub fn misc_u32(&self, offset: i64) -> i64 {
        if !self.misc.present || offset < 0 || offset + 4 > self.misc.data.len() as i64 {
            return 0;
        }

        read_u32_be(&self.misc.data, offset)
    }

    pub fn misc_i32(&self, offset: i64) -> i64 {
        let value = self.misc_u32(offset);

        if value >= 0x8000_0000 { value - 0x1_0000_0000 } else { value }
    }

    /// Sc2File.set_misc_u32. Each call marks MISC written.
    pub fn set_misc_u32(&mut self, offset: i64, value: i64) -> bool {
        if !self.misc.present || offset < 0 || offset + 4 > self.misc.data.len() as i64 {
            return false;
        }

        write_u32_be(self.misc.mutate(), offset, value & 0xffff_ffff);

        true
    }

    pub fn set_misc_i32(&mut self, offset: i64, value: i64) -> bool {
        self.set_misc_u32(offset, value)
    }

    pub fn city_mode(&self) -> i64 {
        self.misc_u32(misc::CITY_MODE)
    }

    pub fn difficulty(&self) -> i64 {
        self.misc_u32(misc::DIFFICULTY)
    }

    pub fn city_status(&self) -> i64 {
        self.misc_u32(misc::PROGRESSION)
    }

    pub fn weather_type(&self) -> i64 {
        self.misc_u32(misc::WEATHER_TREND)
    }

    pub fn disaster_type(&self) -> i64 {
        self.misc_u32(misc::DISASTER_TYPE)
    }

    pub fn funds(&self) -> i64 {
        self.misc_i32(misc::FUNDS)
    }

    pub fn set_funds(&mut self, value: i64) -> bool {
        self.set_misc_i32(misc::FUNDS, value)
    }

    pub fn founding_year(&self) -> i64 {
        self.misc_u32(misc::START_YEAR)
    }

    pub fn compass_rotation(&self) -> i64 {
        self.misc_u32(misc::COMPASS) & 0x03
    }

    pub fn age_in_days(&self) -> i64 {
        self.misc_u32(misc::CITY_DAYS)
    }

    pub fn set_age_in_days(&mut self, value: i64) -> bool {
        if value < 0 {
            return false;
        }

        self.set_misc_u32(misc::CITY_DAYS, value)
    }

    pub fn simulation_speed(&self) -> i64 {
        self.misc_u32(misc::SIMULATION_SPEED)
    }

    pub fn set_simulation_speed(&mut self, value: i64) -> bool {
        if !(1..=5).contains(&value) {
            return false;
        }

        self.set_misc_u32(misc::SIMULATION_SPEED, value)
    }

    pub fn auto_budget_enabled(&self) -> bool {
        self.misc_u32(misc::AUTO_BUDGET) != 0
    }

    pub fn newspaper_subscription_enabled(&self) -> bool {
        self.misc_u32(misc::NEWSPAPER_SUBSCRIPTION) != 0
    }

    pub fn newspaper_extras_enabled(&self) -> bool {
        self.misc_u32(misc::NEWSPAPER_EXTRAS) != 0
    }

    pub fn auto_goto_enabled(&self) -> bool {
        self.misc_u32(misc::AUTO_GOTO) != 0
    }

    pub fn music_enabled(&self) -> bool {
        self.misc_u32(misc::MUSIC) != 0
    }

    pub fn no_disasters_enabled(&self) -> bool {
        self.misc_u32(misc::NO_DISASTERS) != 0
    }

    pub fn current_year(&self) -> i64 {
        self.founding_year() + self.age_in_days() / super::ids::city_calendar::DAYS_PER_YEAR
    }

    pub fn current_month(&self) -> i64 {
        use super::ids::city_calendar::{DAYS_PER_MONTH, DAYS_PER_YEAR};

        (self.age_in_days() % DAYS_PER_YEAR) / DAYS_PER_MONTH + 1
    }

    pub fn population(&self) -> i64 {
        self.misc_u32(misc::ARCOLOGY_POPULATION) + self.misc_u32(misc::NORMAL_POPULATION)
    }

    /// The traffic density near a tile, as CityState.traffic_density reads it.
    pub fn traffic_density(&self, x: i64, y: i64) -> i64 {
        if self.index_of(x, y) < 0 || !self.xtrf.present || self.xtrf.data.len() as i64 != self.decoded_size("XTRF") {
            return 0;
        }

        let index = super::grid::index(&self.xtrf.data, self.map_size, x, y);

        self.xtrf.data[index as usize] as i64
    }

    /// Thing records in XTHG.
    pub fn thing_count(&self) -> i64 {
        super::things::count(&self.xthg.data)
    }

    /// Chunk identifiers written by the simulation, in CHUNK_IDS order.
    pub fn written_ids(&self) -> Vec<&'static str> {
        CHUNK_IDS
            .iter()
            .copied()
            .filter(|id| self.chunk(id).is_some_and(|chunk| chunk.written))
            .collect()
    }
}

/// Sc2OverlayLayout.facility_capacity.
pub fn facility_capacity(factor: i64) -> i64 {
    (sc2microsim_layout::ORIGINAL_COUNT * factor)
        .min(sc2microsim_layout::ORIGINAL_COUNT + sc2overlay_layout::EXTRA_SIGN - sc2overlay_layout::EXTRA_FACILITY)
}
