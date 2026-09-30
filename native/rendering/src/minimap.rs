//! City Map window images: one palette index per tile, and the RGBA image of
//! those indices. Maps larger than 1024 tiles sample every second or fourth tile,
//! since the Map window never shows more than 1024 pixels.

pub const MAX_IMAGE_EDGE: usize = 1024;

const WATER: u8 = 0x04;
const WATERED: u8 = 0x10;
const PIPED: u8 = 0x20;
const POWERED: u8 = 0x40;
const POWERABLE: u8 = 0x80;
const ZONE_COLORS: [u8; 16] = [0, 59, 59, 92, 92, 50, 50, 0, 0, 0, 0, 0, 0, 0, 0, 0];
const TREES_1: u8 = 0x06;
const SMALL_PARK: u8 = 0x0d;
const POLICE_STATION: u8 = 0xd2;
const FIRE_STATION: u8 = 0xd3;
const SCHOOL: u8 = 0xd6;
const COLLEGE: u8 = 0xd9;
// Underground pipes through the subway entrance.
const PIPE_FIRST: u8 = 0x10;
const PIPE_LAST: u8 = 0x23;

/// The data maps of the Map window. Each mode names the chunk it reads.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Mode {
    Structures,
    Zones,
    Roads,
    Rail,
    Traffic,
    Power,
    Water,
    Density,
    Growth,
    Crime,
    PolicePower,
    PoliceStations,
    Pollution,
    LandValue,
    FirePower,
    FireStations,
    Schools,
    Colleges,
}
impl Mode {
    /// Unknown names draw the structures map.
    pub fn from_name(name: &str) -> Self {
        match name {
            "zones" => Self::Zones,
            "roads" => Self::Roads,
            "rail" => Self::Rail,
            "traffic" => Self::Traffic,
            "power" => Self::Power,
            "water" => Self::Water,
            "density" => Self::Density,
            "growth" => Self::Growth,
            "crime" => Self::Crime,
            "police_power" => Self::PolicePower,
            "police_stations" => Self::PoliceStations,
            "pollution" => Self::Pollution,
            "land_value" => Self::LandValue,
            "fire_power" => Self::FirePower,
            "fire_stations" => Self::FireStations,
            "schools" => Self::Schools,
            "colleges" => Self::Colleges,
            _ => Self::Structures,
        }
    }
    /// The data chunk that the mode reads, if any.
    pub fn chunk(self) -> Option<&'static str> {
        Some(match self {
            Self::Traffic => "XTRF",
            Self::Density => "XPOP",
            Self::Growth => "XROG",
            Self::Crime => "XCRM",
            Self::PolicePower => "XPLC",
            Self::Pollution => "XPLT",
            Self::LandValue => "XVAL",
            Self::FirePower => "XFIR",
            _ => return None,
        })
    }
}

pub struct MinimapCity<'a> {
    pub edge: usize,
    pub buildings: &'a [u8],
    pub zones: &'a [u8],
    pub flags: &'a [u8],
    pub underground: &'a [u8],
    pub altitude: &'a [i32],
    /// The mode's data map at full, half or quarter resolution, or empty.
    pub data: &'a [u8],
}
impl MinimapCity<'_> {
    pub fn validate(&self) -> Result<(), String> {
        let cells = self.edge * self.edge;
        if self.edge == 0
            || [
                self.buildings.len(),
                self.zones.len(),
                self.flags.len(),
                self.underground.len(),
                self.altitude.len(),
            ]
            .iter()
            .any(|n| *n != cells)
        {
            return Err("invalid city map arrays".into());
        }
        Ok(())
    }
    // A legacy coarse grid covers two or four tiles per cell.
    fn data_value(&self, x: usize, y: usize) -> u8 {
        let edge = self.edge;
        let grid = [edge, edge / 2, edge / 4]
            .into_iter()
            .find(|g| *g > 0 && self.data.len() == g * g)
            .unwrap_or(0);
        if grid == 0 {
            return 0;
        }
        let scale = edge / grid;
        self.data[(x / scale) * grid + y / scale]
    }
    fn base(&self, i: usize, building: u8) -> u8 {
        if building == 0 {
            if self.flags[i] & WATER != 0 {
                return 0x62;
            }
            let altitude = (self.altitude[i] & 0x1f).min(0x10);
            return (0x80 - altitude * 3 / 4) as u8;
        }
        if building < TREES_1 {
            return 0x35;
        }
        if building < SMALL_PARK {
            return 0x43;
        }
        0
    }
    fn gradient_or(&self, x: usize, y: usize, base: u8) -> u8 {
        let gradient = self.data_value(x, y) >> 4;
        if gradient != 0 { gradient + 0x9b } else { base }
    }
    /// The palette index of one tile. Tiles outside the map are 0.
    pub fn color_index(&self, x: usize, y: usize, mode: Mode) -> u8 {
        if x >= self.edge || y >= self.edge {
            return 0;
        }
        let i = x * self.edge + y;
        let b = self.buildings[i];
        let base = self.base(i, b);
        let flags = self.flags[i];
        let marked = |hit: bool| if hit { 0xff } else { base };
        match mode {
            Mode::Structures => base,
            Mode::Zones => {
                let zone = self.zones[i] & 0x0f;
                if zone != 0 { ZONE_COLORS[zone as usize] } else { base }
            }
            Mode::Roads => marked(is_road(b)),
            Mode::Rail => marked(is_rail(b)),
            Mode::Traffic => {
                let traffic = self.data_value(x, y) >> 4;
                if traffic != 0 {
                    traffic + 0x9b
                } else {
                    marked(is_traffic_network(b))
                }
            }
            Mode::Power => {
                if is_power_line(b) {
                    0xff
                } else if flags & POWERED != 0 {
                    0x32
                } else if flags & POWERABLE != 0 {
                    0x1d
                } else {
                    base
                }
            }
            Mode::Water => {
                if (PIPE_FIRST..=PIPE_LAST).contains(&self.underground[i]) {
                    0xff
                } else if flags & WATERED != 0 {
                    0x32
                } else if flags & PIPED != 0 {
                    0x1d
                } else {
                    base
                }
            }
            Mode::Growth => match self.data_value(x, y) {
                g if g < 0x7d => 0x1d,
                g if g >= 0x83 => 0x43,
                _ => base,
            },
            Mode::Density | Mode::Crime | Mode::PolicePower | Mode::Pollution | Mode::LandValue | Mode::FirePower => {
                self.gradient_or(x, y, base)
            }
            Mode::PoliceStations => marked(b == POLICE_STATION),
            Mode::FireStations => marked(b == FIRE_STATION),
            Mode::Schools => marked(b == SCHOOL),
            Mode::Colleges => marked(b == COLLEGE),
        }
    }
}

/// The image edge of a map: one pixel per tile up to 1024 tiles.
pub fn image_edge(edge: usize) -> usize {
    edge / (edge / MAX_IMAGE_EDGE).max(1)
}

/// Palette indices in image rows: the pixel at column x and row y shows tile
/// (x * step, y * step).
pub fn indices(city: &MinimapCity, mode: Mode) -> Vec<u8> {
    let size = image_edge(city.edge);
    let step = (city.edge / MAX_IMAGE_EDGE).max(1);
    let mut out = vec![0; size * size];
    for y in 0..size {
        for x in 0..size {
            out[y * size + x] = city.color_index(x * step, y * step, mode);
        }
    }
    out
}

/// RGBA8 pixels of the indices through a 256-entry RGBA palette.
pub fn colorize(indices: &[u8], palette: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(indices.len() * 4);
    for &index in indices {
        let at = usize::from(index) * 4;
        out.extend_from_slice(palette.get(at..at + 4).unwrap_or(&[0, 0, 0, 0]));
    }
    out
}

fn is_road(b: u8) -> bool {
    matches!(b, 0x1d..=0x2b | 0x3f..=0x46 | 0x49..=0x59 | 0x5d..=0x6b)
}
fn is_rail(b: u8) -> bool {
    matches!(b, 0x2c..=0x3e | 0x45..=0x48 | 0x6c..=0x6f | 0x4d | 0x4e | 0x5a | 0x5b)
}
fn is_traffic_network(b: u8) -> bool {
    matches!(b, 0x1d..=0x3e | 0x3f..=0x48 | 0x49..=0x50 | 0x5d..=0x6f)
}
fn is_power_line(b: u8) -> bool {
    matches!(b, 0x0e..=0x1c | 0x43 | 0x44 | 0x47 | 0x48 | 0x5c)
}

#[cfg(test)]
mod tests {
    use super::*;

    struct Arrays {
        edge: usize,
        buildings: Vec<u8>,
        zones: Vec<u8>,
        flags: Vec<u8>,
        underground: Vec<u8>,
        altitude: Vec<i32>,
        data: Vec<u8>,
    }
    impl Arrays {
        fn new(edge: usize) -> Self {
            let cells = edge * edge;
            Self {
                edge,
                buildings: vec![0; cells],
                zones: vec![0; cells],
                flags: vec![0; cells],
                underground: vec![0; cells],
                altitude: vec![0; cells],
                data: Vec::new(),
            }
        }
        fn city(&self) -> MinimapCity<'_> {
            MinimapCity {
                edge: self.edge,
                buildings: &self.buildings,
                zones: &self.zones,
                flags: &self.flags,
                underground: &self.underground,
                altitude: &self.altitude,
                data: &self.data,
            }
        }
    }

    #[test]
    fn base_colors_follow_ground_trees_and_water() {
        let mut a = Arrays::new(8);
        a.altitude[0] = 8;
        a.flags[1] = WATER;
        a.buildings[2] = 0x03;
        a.buildings[3] = TREES_1;
        a.buildings[4] = 0x70;
        let c = a.city();
        assert_eq!(c.color_index(0, 0, Mode::Structures), 0x80 - 6);
        assert_eq!(c.color_index(0, 1, Mode::Structures), 0x62);
        assert_eq!(c.color_index(0, 2, Mode::Structures), 0x35);
        assert_eq!(c.color_index(0, 3, Mode::Structures), 0x43);
        assert_eq!(c.color_index(0, 4, Mode::Structures), 0);
        assert_eq!(c.color_index(8, 0, Mode::Structures), 0);
    }

    #[test]
    fn layers_mark_networks_utilities_and_services() {
        let mut a = Arrays::new(4);
        a.buildings[0] = 0x1d;
        a.buildings[1] = 0x2c;
        a.buildings[2] = 0x0e;
        a.buildings[3] = POLICE_STATION;
        a.flags[4] = POWERED;
        a.flags[5] = POWERABLE;
        a.underground[6] = PIPE_FIRST;
        a.flags[7] = WATERED;
        a.zones[8] = 0x13;
        let c = a.city();
        assert_eq!(c.color_index(0, 0, Mode::Roads), 0xff);
        assert_eq!(c.color_index(0, 1, Mode::Rail), 0xff);
        assert_eq!(c.color_index(0, 2, Mode::Power), 0xff);
        assert_eq!(c.color_index(0, 3, Mode::PoliceStations), 0xff);
        assert_eq!(c.color_index(1, 0, Mode::Power), 0x32);
        assert_eq!(c.color_index(1, 1, Mode::Power), 0x1d);
        assert_eq!(c.color_index(1, 2, Mode::Water), 0xff);
        assert_eq!(c.color_index(1, 3, Mode::Water), 0x32);
        assert_eq!(c.color_index(2, 0, Mode::Zones), 92);
    }

    #[test]
    fn coarse_and_native_data_maps() {
        let mut a = Arrays::new(8);
        a.data = vec![0; 16];
        a.data[4 + 2] = 0xff;
        let c = a.city();
        // cell (1, 2) of a half-resolution grid covers tiles 2..4, 4..6
        assert_eq!(c.color_index(3, 5, Mode::Pollution), 0x9b + 15);
        assert_eq!(c.color_index(3, 6, Mode::Pollution), c.color_index(3, 6, Mode::Structures));
        assert_eq!(c.color_index(3, 6, Mode::Growth), 0x1d);
        let mut full = Arrays::new(8);
        full.data = vec![0x80; 64];
        assert_eq!(
            full.city().color_index(0, 0, Mode::Growth),
            full.city().color_index(0, 0, Mode::Structures)
        );
    }

    #[test]
    fn large_maps_sample_tiles() {
        let mut a = Arrays::new(2048);
        a.buildings[2 * 2048 + 4] = POLICE_STATION;
        let pixels = indices(&a.city(), Mode::PoliceStations);
        assert_eq!(pixels.len(), 1024 * 1024);
        // tile (2, 4) is image column 1, row 2
        assert_eq!(pixels[2 * 1024 + 1], 0xff);
        let rgba = colorize(&pixels[..2], &[[1, 2, 3, 4]; 256].concat());
        assert_eq!(rgba, vec![1, 2, 3, 4, 1, 2, 3, 4]);
    }
}
