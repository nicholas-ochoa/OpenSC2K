//! The data views: each tile top and exposed wall in the color of the tile's
//! value, with dark grid edges, as CityDataView and its grid shader.

use super::Frame;
use super::camera::Camera;
use sc2k_render::data_view::{self, DataCity, DataMesh};
use sc2k_sim::sim::city::City;

/// The data views, in the order of CityViewMode.DATA_MODES.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Mode {
    Density,
    Growth,
    Traffic,
    Pollution,
    Crime,
    PolicePower,
    FirePower,
    LandValue,
    Water,
    Power,
    Height,
}

pub const MODES: [Mode; 11] = [
    Mode::Density,
    Mode::Growth,
    Mode::Traffic,
    Mode::Pollution,
    Mode::Crime,
    Mode::PolicePower,
    Mode::FirePower,
    Mode::LandValue,
    Mode::Water,
    Mode::Power,
    Mode::Height,
];

pub const TITLES: [&str; 11] = [
    "Density",
    "Rate of Growth",
    "Traffic",
    "Pollution",
    "Crime",
    "Police Power",
    "Fire Power",
    "Land Value",
    "Water Supply",
    "Power Supply",
    "Heightmap",
];

type Rgb = [f32; 3];

const fn rgb(value: u32) -> Rgb {
    [
        ((value >> 16) & 0xff) as f32 / 255.0,
        ((value >> 8) & 0xff) as f32 / 255.0,
        (value & 0xff) as f32 / 255.0,
    ]
}

const NO_VALUE: Rgb = rgb(0x535b67);
const DEFAULT_GRADIENT: [Rgb; 2] = [rgb(0x2b5260), rgb(0xff694c)];
const LAND_HEIGHT: [Rgb; 8] = [
    rgb(0x004400),
    rgb(0x008800),
    rgb(0x00cc00),
    rgb(0x00ff00),
    rgb(0x44cc00),
    rgb(0x969600),
    rgb(0xcc4400),
    rgb(0xff0011),
];
const UNDERWATER: [Rgb; 3] = [rgb(0x1100ff), rgb(0x0000cc), rgb(0x000078)];
const GROWTH_COLORS: [Rgb; 3] = [rgb(0xe2453c), rgb(0x2a2a2e), rgb(0x35d16a)];
const GROWTH_DECLINE: i32 = 0x7d;
const GROWTH_INCREASE: i32 = 0x83;
const GROWTH_FULL_DISTANCE: f32 = 32.0;
const UNDERWATER_BASE: i32 = 32;
const MAX_LEVEL: f32 = 31.0;
const MAX_SHOWN_DEPTH: f32 = 15.0;
/// The darkest shade of a grid edge, and where the shade starts and ends.
const EDGE_SHADE: f32 = 0.28;
const EDGE_START: f32 = 0.45;
const EDGE_END: f32 = 0.95;
/// Power and water flags in XBIT: supplied and connected.
const POWER_FLAGS: (u8, u8) = (0x40, 0x80);
const WATER_FLAGS: (u8, u8) = (0x10, 0x20);

impl Mode {
    fn chunk(self) -> Option<&'static str> {
        Some(match self {
            Mode::Density => "XPOP",
            Mode::Growth => "XROG",
            Mode::Traffic => "XTRF",
            Mode::Pollution => "XPLT",
            Mode::Crime => "XCRM",
            Mode::PolicePower => "XPLC",
            Mode::FirePower => "XFIR",
            Mode::LandValue => "XVAL",
            _ => return None,
        })
    }

    fn gradient(self) -> ([Rgb; 2], f32) {
        match self {
            Mode::Density => ([rgb(0x1f2d3f), rgb(0xffd166)], 1.0),
            Mode::Traffic => ([rgb(0x38c8ff), rgb(0xc8102e)], 1.0),
            Mode::Pollution => ([rgb(0x2a2a2e), rgb(0xb84dff)], 0.5),
            Mode::Crime => ([rgb(0x0a5468), rgb(0xff2d55)], 1.0),
            Mode::PolicePower => ([rgb(0x101c4c), rgb(0x2f6bff)], 1.0),
            Mode::FirePower => ([rgb(0x4a1010), rgb(0xff3326)], 1.0),
            Mode::LandValue => ([rgb(0x2a2a2e), rgb(0x2fbf4f)], 2.0),
            _ => (DEFAULT_GRADIENT, 1.0),
        }
    }
}

fn lerp(a: Rgb, b: Rgb, amount: f32) -> Rgb {
    [
        a[0] + (b[0] - a[0]) * amount,
        a[1] + (b[1] - a[1]) * amount,
        a[2] + (b[2] - a[2]) * amount,
    ]
}

fn ramp(stops: &[Rgb], amount: f32) -> Rgb {
    let position = amount.clamp(0.0, 1.0) * (stops.len() - 1) as f32;
    let first = (position.floor() as usize).min(stops.len() - 2);

    lerp(stops[first], stops[first + 1], position - first as f32)
}

/// Rate of growth reads as decline, steady, or growth around its middle band.
pub fn growth_state(value: i32) -> usize {
    if value < GROWTH_DECLINE {
        0
    } else if value < GROWTH_INCREASE {
        1
    } else {
        2
    }
}

/// The color of a tile value in `mode`. A negative value has no data.
pub fn color(value: i32, mode: Mode) -> Rgb {
    if value < 0 {
        return NO_VALUE;
    }

    match mode {
        Mode::Height if value >= UNDERWATER_BASE => ramp(&UNDERWATER, (value - UNDERWATER_BASE) as f32 / MAX_SHOWN_DEPTH),
        Mode::Height => ramp(&LAND_HEIGHT, value as f32 / MAX_LEVEL),
        Mode::Water | Mode::Power => {
            let supplied = if mode == Mode::Water { rgb(0x42bde8) } else { rgb(0xf4d35e) };

            [rgb(0x687381), rgb(0xe25c46), supplied][value.clamp(0, 2) as usize]
        }
        Mode::Growth => {
            let state = growth_state(value);

            if state == 1 {
                return GROWTH_COLORS[1];
            }

            let distance = if state == 0 {
                GROWTH_DECLINE - value
            } else {
                value - GROWTH_INCREASE + 1
            };

            lerp(
                GROWTH_COLORS[1],
                GROWTH_COLORS[state],
                (distance as f32 / GROWTH_FULL_DISTANCE).clamp(0.0, 1.0).sqrt(),
            )
        }
        Mode::Traffic if value == 0 => rgb(0x2a2a2e),
        _ => {
            let (stops, curve) = mode.gradient();

            ramp(&stops, (value as f32 / 255.0).clamp(0.0, 1.0).powf(curve))
        }
    }
}

/// The value of each tile in `mode`, by map cell.
pub fn values(city: &City, mode: Mode) -> Vec<i32> {
    let edge = city.map_size as usize;
    let cells = edge * edge;
    let flags = city.chunk("XBIT").map(|chunk| chunk.data.as_slice()).unwrap_or_default();

    if let Some(id) = mode.chunk() {
        let data = city.chunk(id).map(|chunk| chunk.data.as_slice()).unwrap_or_default();
        let grid = [edge, edge / 2, edge / 4]
            .into_iter()
            .find(|grid| *grid > 0 && data.len() == grid * grid);

        let Some(grid) = grid else {
            return vec![-1; cells];
        };

        let scale = edge / grid;

        return (0..cells)
            .map(|cell| i32::from(data[(cell / edge / scale) * grid + (cell % edge) / scale]))
            .collect();
    }

    if flags.len() != cells {
        return vec![-1; cells];
    }

    let bytes = match mode {
        Mode::Height => {
            let altitude: Vec<i32> = city
                .chunk("ALTM")
                .map(|chunk| {
                    chunk
                        .data
                        .chunks_exact(2)
                        .map(|word| i32::from(u16::from_be_bytes([word[0], word[1]])))
                        .collect()
                })
                .unwrap_or_default();

            if altitude.len() != cells {
                return vec![-1; cells];
            }

            data_view::height_values(&altitude, flags)
        }
        Mode::Power => data_view::utility_values(flags, POWER_FLAGS.0, POWER_FLAGS.1),
        _ => data_view::utility_values(flags, WATER_FLAGS.0, WATER_FLAGS.1),
    };

    bytes.into_iter().map(i32::from).collect()
}

/// The overlay mesh of a city, in source pixels.
pub fn mesh(city: &sc2k_render::City, mode: Mode) -> Option<DataMesh> {
    let data = DataCity {
        edge: city.edge as usize,
        visible: city.visible,
        altitude: &city.altitude,
        terrain: &city.terrain,
        flags: &city.flags,
    };

    data.validate().ok()?;

    Some(data_view::build(&data, mode == Mode::Height))
}

fn smoothstep(low: f32, high: f32, value: f32) -> f32 {
    let t = ((value - low) / (high - low)).clamp(0.0, 1.0);

    t * t * (3.0 - 2.0 * t)
}

/// Draw the mesh into the viewport of `frame`, over what is there.
pub fn draw(frame: &mut Frame, camera: &Camera, mesh: &DataMesh, values: &[i32], edge: usize, mode: Mode) {
    let colors: Vec<Rgb> = (0..256).map(|value| color(value, mode)).collect();
    let viewport = camera.viewport;
    let clip = (
        viewport.x.max(0.0),
        viewport.y.max(0.0),
        (viewport.x + viewport.width).min(frame.width as f64),
        (viewport.y + viewport.height).min(frame.height as f64),
    );

    for triangle in mesh.indices.chunks_exact(3) {
        let corner = |index: i32| {
            let index = index as usize;
            let point = camera.source_to_screen((f64::from(mesh.vertices[index][0]), f64::from(mesh.vertices[index][1])));

            (point, mesh.uvs[index], mesh.colors[index][2])
        };
        let (a, b, c) = (corner(triangle[0]), corner(triangle[1]), corner(triangle[2]));
        let tile = ((a.1[1] / 2.0).floor() as usize, (a.1[0] / 2.0).floor() as usize);
        let value = values.get(tile.0 * edge + tile.1).copied().unwrap_or(-1);
        let base = if value < 0 { NO_VALUE } else { colors[value.min(255) as usize] };
        let shade = a.2;
        fill_triangle(
            frame,
            clip,
            [a, b, c],
            |uv| [uv[0] - (uv[0] / 2.0).floor() * 2.0, uv[1] - (uv[1] / 2.0).floor() * 2.0],
            base,
            shade,
        );
    }
}

type Corner = ((f64, f64), [f32; 2], f32);

/// Fill a screen triangle. Each pixel takes `base` times `shade`, darkened
/// toward the edges of its tile in UV space as the grid shader does.
fn fill_triangle(
    frame: &mut Frame,
    clip: (f64, f64, f64, f64),
    corners: [Corner; 3],
    local: impl Fn([f32; 2]) -> [f32; 2],
    base: Rgb,
    shade: f32,
) {
    let [(p0, t0, _), (p1, t1, _), (p2, t2, _)] = corners;
    let area = (p1.0 - p0.0) * (p2.1 - p0.1) - (p2.0 - p0.0) * (p1.1 - p0.1);

    if area.abs() < 1e-9 {
        return;
    }

    // the UV change for each screen pixel, constant over the triangle
    let du = [
        ((t1[0] - t0[0]) as f64 * (p2.1 - p0.1) - (t2[0] - t0[0]) as f64 * (p1.1 - p0.1)) / area,
        ((t2[0] - t0[0]) as f64 * (p1.0 - p0.0) - (t1[0] - t0[0]) as f64 * (p2.0 - p0.0)) / area,
    ];
    let dv = [
        ((t1[1] - t0[1]) as f64 * (p2.1 - p0.1) - (t2[1] - t0[1]) as f64 * (p1.1 - p0.1)) / area,
        ((t2[1] - t0[1]) as f64 * (p1.0 - p0.0) - (t1[1] - t0[1]) as f64 * (p2.0 - p0.0)) / area,
    ];
    let width = [
        (du[0].abs() + du[1].abs()).max(1e-5) as f32,
        (dv[0].abs() + dv[1].abs()).max(1e-5) as f32,
    ];
    let left = p0.0.min(p1.0).min(p2.0).max(clip.0).floor() as i64;
    let right = p0.0.max(p1.0).max(p2.0).min(clip.2 - 1.0).ceil() as i64;
    let top = p0.1.min(p1.1).min(p2.1).max(clip.1).floor() as i64;
    let bottom = p0.1.max(p1.1).max(p2.1).min(clip.3 - 1.0).ceil() as i64;
    let edge = |a: (f64, f64), b: (f64, f64), p: (f64, f64)| (b.0 - a.0) * (p.1 - a.1) - (b.1 - a.1) * (p.0 - a.0);

    for y in top.max(0)..=bottom {
        for x in left.max(0)..=right {
            let p = (x as f64 + 0.5, y as f64 + 0.5);
            let (w0, w1, w2) = (edge(p1, p2, p), edge(p2, p0, p), edge(p0, p1, p));
            let inside = if area > 0.0 {
                w0 >= 0.0 && w1 >= 0.0 && w2 >= 0.0
            } else {
                w0 <= 0.0 && w1 <= 0.0 && w2 <= 0.0
            };

            if !inside || x as usize >= frame.width || y as usize >= frame.height {
                continue;
            }

            let (b0, b1, b2) = (w0 / area, w1 / area, w2 / area);
            let uv = [
                (b0 * t0[0] as f64 + b1 * t1[0] as f64 + b2 * t2[0] as f64) as f32,
                (b0 * t0[1] as f64 + b1 * t1[1] as f64 + b2 * t2[1] as f64) as f32,
            ];
            let local = local(uv);
            let distance = ((local[0].min(1.0 - local[0])) / width[0]).min((local[1].min(1.0 - local[1])) / width[1]);
            let factor = shade * (EDGE_SHADE + (1.0 - EDGE_SHADE) * smoothstep(EDGE_START, EDGE_END, distance));
            let channel = |value: f32| ((value * factor).clamp(0.0, 1.0) * 255.0).round() as u32;
            frame.pixels[y as usize * frame.width + x as usize] = (channel(base[0]) << 16) | (channel(base[1]) << 8) | channel(base[2]);
        }
    }
}
