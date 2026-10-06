//! The city maps of the painter, from the chunks of a simulation city.

use sc2k_render::City as PainterCity;
use sc2k_sim::sim::city::City;
use std::collections::HashMap;

/// The decoded payload of a chunk, or an empty one.
fn chunk(city: &City, id: &str) -> Vec<u8> {
    city.chunk(id).map(|chunk| chunk.data.clone()).unwrap_or_default()
}

/// The painter city. `visible` is the number of altitude levels that show, 32 for all.
pub fn painter_city(city: &City, visible: i32) -> PainterCity {
    let edge = city.map_size as i32;
    let cells = (edge * edge) as usize;
    let altitude: Vec<i32> = chunk(city, "ALTM")
        .chunks_exact(2)
        .map(|word| i32::from(u16::from_be_bytes([word[0], word[1]])))
        .collect();
    let traffic = chunk(city, "XTRF");
    let traffic_size = city.decoded_size("XTRF");
    let resized = |data: Vec<u8>| {
        if data.len() == cells { data } else { vec![0; cells] }
    };
    let mut painter = PainterCity {
        edge,
        visible,
        rotation: city.compass_rotation() as usize,
        altitude: if altitude.len() == cells { altitude } else { vec![0; cells] },
        terrain: resized(chunk(city, "XTER")),
        buildings: resized(chunk(city, "XBLD")),
        zones: resized(chunk(city, "XZON")),
        flags: resized(chunk(city, "XBIT")),
        overlays: chunk(city, "XTXT"),
        underground: resized(chunk(city, "XUND")),
        ground: Vec::new(),
        objects: Vec::new(),
        traffic: if traffic.len() as i64 == traffic_size {
            traffic
        } else {
            Vec::new()
        },
        dispatch: HashMap::new(),
    };

    painter.set_dispatch(&chunk(city, "XTHG"));

    painter
}
