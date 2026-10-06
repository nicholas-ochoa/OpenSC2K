//! The command line modes without a window: a snapshot of the view, a render
//! of the whole city, and a frame benchmark.

use crate::game::Game;
use sc2k_game::session::Session;
use sc2k_view::Frame;
use sc2k_view::art::CityArt;
use sc2k_view::camera::Viewport;
use std::time::Instant;

pub const WIDTH: f64 = 1280.0;
pub const HEIGHT: f64 = 800.0;

fn write_png(path: &str, width: usize, height: usize, pixels: &[u32]) -> Result<(), String> {
    let rgba: Vec<u8> = pixels
        .iter()
        .flat_map(|pixel| [(pixel >> 16) as u8, (pixel >> 8) as u8, *pixel as u8, 255])
        .collect();
    let bytes = sc2k_formats::png::encode_rgba(width as u32, height as u32, &rgba)?;

    std::fs::write(path, bytes).map_err(|error| error.to_string())
}

/// Render one frame of the view, zoomed by `steps` levels, to a PNG file.
pub fn snapshot(game: &mut Game, path: &str, steps: i32) -> Result<(), String> {
    let (width, height) = (WIDTH as usize, HEIGHT as usize);
    let mut pixels = vec![0_u32; width * height];
    game.view.set_viewport(Viewport {
        x: 0.0,
        y: 0.0,
        width: WIDTH,
        height: HEIGHT,
    });
    game.view.camera.change_zoom(steps, None);
    let mut frame = Frame {
        width,
        height,
        pixels: &mut pixels,
    };
    game.view.draw(&mut frame, &game.art);

    write_png(path, width, height, &pixels)
}

/// Render the whole city in graphics size `view` to a PNG file, as the CPU
/// painter of the Godot build exports it: moving objects and disaster markers
/// at phase 0, over the export background.
pub fn render_city(
    session: &Session,
    art: &CityArt,
    path: &str,
    view: usize,
    underground: bool,
) -> Result<(), String> {
    use sc2k_view::moving::{marker_cells, moving_draws, things_of};
    use sc2k_view::present::{cycled_colors, whole_city};
    use sc2k_view::regions::{Options, Regions};
    use sc2k_view::snapshot::painter_city;

    const EXPORT_BACKGROUND: u32 = 0x0018242c;
    const UNDERGROUND_INDEX: usize = 0xff;
    let city = &session.city;
    let options = Options {
        underground,
        ..Options::default()
    };
    let painter = painter_city(city, 32);
    let mut regions = Regions::new(painter.clone(), art, view, options)?;

    if !underground {
        regions.set_moving(moving_draws(
            &painter,
            &things_of(city),
            &art.views[view],
            &marker_cells(city),
            view,
            0,
            32,
            true,
        ));
    }

    let identity: Vec<i32> = (0..256).collect();
    let colors = cycled_colors(&art.palette, &identity);
    let background = if underground {
        colors[UNDERGROUND_INDEX]
    } else {
        EXPORT_BACKGROUND
    };
    let (width, height, rgba) = whole_city(&mut regions, &colors, background);
    let bytes = sc2k_formats::png::encode_rgba(width as u32, height as u32, &rgba)?;

    std::fs::write(path, bytes).map_err(|error| error.to_string())
}

/// Time `frames` frames of 1280 by 800 pixels at 60 frames each second, while
/// the camera pans and the simulation thread runs at `speed`.
pub fn benchmark(game: &mut Game, frames: usize, speed: i64) {
    const FRAME_MSEC: f64 = 1000.0 / 60.0;
    let (width, height) = (WIDTH as usize, HEIGHT as usize);
    let mut pixels = vec![0_u32; width * height];
    game.view.set_viewport(Viewport {
        x: 0.0,
        y: 0.0,
        width: WIDTH,
        height: HEIGHT,
    });
    game.runner.call(move |session| session.set_speed(speed));
    let mut frame_msec = Vec::with_capacity(frames);
    let started = Instant::now();
    let first_day = game.status.days;

    for frame_index in 0..frames {
        let frame_start = Instant::now();
        let now = started.elapsed().as_millis() as i64;
        game.runner.advance(FRAME_MSEC, now, false);
        game.receive();
        game.view.advance_palette(FRAME_MSEC);
        game.view.animation_phase = now / 100;
        game.view.camera.pan_screen(
            if (frame_index / 120) % 2 == 0 {
                4.0
            } else {
                -4.0
            },
            1.0,
        );
        let mut frame = Frame {
            width,
            height,
            pixels: &mut pixels,
        };
        game.view.draw(&mut frame, &game.art);
        frame_msec.push(frame_start.elapsed().as_secs_f64() * 1000.0);

        // keep the pace of a 60 Hz display, as a window would
        let remaining = FRAME_MSEC - frame_start.elapsed().as_secs_f64() * 1000.0;

        if remaining > 0.0 {
            std::thread::sleep(std::time::Duration::from_secs_f64(remaining / 1000.0));
        }
    }

    frame_msec.sort_by(f64::total_cmp);
    let average = frame_msec.iter().sum::<f64>() / frames.max(1) as f64;
    println!(
        "{frames} frames: frame work average {average:.2} ms, median {:.2} ms, 95th {:.2} ms, worst {:.2} ms; {:.1} s; days {} to {}",
        frame_msec[frames / 2],
        frame_msec[frames * 95 / 100],
        frame_msec[frames - 1],
        started.elapsed().as_secs_f64(),
        first_day,
        game.status.days
    );
}
