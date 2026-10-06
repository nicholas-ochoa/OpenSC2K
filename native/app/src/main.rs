//! The native OpenSC2K game. It opens a window, loads the graphics pack of the
//! shared settings, and shows a city while the simulation runs on its thread.

mod audio;
mod city_view;
mod cli;
mod game;
mod settings;

use game::Game;
use sc2k_game::edits::{self, Selection};
use sc2k_sim::sim::geom::Vec2i;
use sc2k_sim::sim::tools::ids::group;
use sc2k_view::Frame;
use sc2k_view::camera::Viewport;
use sc2k_view::data_view::{MODES, TITLES};
use std::num::NonZeroU32;
use std::path::PathBuf;
use std::rc::Rc;
use std::time::Instant;
use winit::application::ApplicationHandler;
use winit::event::{ElementState, MouseButton, MouseScrollDelta, WindowEvent};
use winit::event_loop::{ActiveEventLoop, ControlFlow, EventLoop};
use winit::keyboard::{Key, NamedKey};
use winit::window::{Window, WindowId};

const KEY_PAN_PIXELS: f64 = 64.0;

struct App {
    game: Game,
    window: Option<Rc<Window>>,
    surface: Option<softbuffer::Surface<Rc<Window>, Rc<Window>>>,
    last_frame: Instant,
    started: Instant,
    cursor: (f64, f64),
    dragging: Option<(f64, f64)>,
    /// The selected tool group and subtool.
    tool: (i64, i64),
    /// The tiles of a left-button drag, from the first.
    selection: Vec<(i32, i32)>,
    status: String,
}

impl App {
    fn redraw(&mut self) {
        let (Some(window), Some(surface)) = (&self.window, &mut self.surface) else {
            return;
        };

        let now = Instant::now();
        let delta = now.duration_since(self.last_frame).as_secs_f64() * 1000.0;
        self.last_frame = now;
        let elapsed = now.duration_since(self.started).as_millis() as i64;
        let game = &mut self.game;
        game.runner.advance(delta, elapsed, false);
        game.receive();
        game.audio.advance(delta);
        game.view.advance_palette(delta);
        game.view.animation_phase = elapsed / 100;
        let size = window.inner_size();
        let (width, height) = (size.width.max(1), size.height.max(1));
        let _ = surface.resize(NonZeroU32::new(width).unwrap(), NonZeroU32::new(height).unwrap());
        game.view.set_viewport(Viewport {
            x: 0.0,
            y: 0.0,
            width: f64::from(width),
            height: f64::from(height),
        });
        game.view.camera.map_pixel_ratio = window.scale_factor().round().max(1.0);

        let Ok(mut buffer) = surface.buffer_mut() else {
            return;
        };

        let mut frame = Frame {
            width: width as usize,
            height: height as usize,
            pixels: &mut buffer,
        };
        game.view.draw(&mut frame, &game.art);
        let _ = buffer.present();
        let status = &game.status;
        window.set_title(&format!(
            "OpenSC2K — {} — day {} — ${} — speed {} — {}",
            status.city_name, status.days, status.funds, status.speed, self.status
        ));
        window.request_redraw();
    }

    fn key(&mut self, key: Key) {
        let game = &mut self.game;
        let view = &mut game.view;

        match key {
            Key::Named(NamedKey::ArrowLeft) => view.camera.pan_screen(-KEY_PAN_PIXELS, 0.0),
            Key::Named(NamedKey::ArrowRight) => view.camera.pan_screen(KEY_PAN_PIXELS, 0.0),
            Key::Named(NamedKey::ArrowUp) => view.camera.pan_screen(0.0, -KEY_PAN_PIXELS),
            Key::Named(NamedKey::ArrowDown) => view.camera.pan_screen(0.0, KEY_PAN_PIXELS),
            Key::Character(text) => match text.as_str() {
                "+" | "=" => {
                    view.camera.change_zoom(1, None);
                }
                "-" => {
                    view.camera.change_zoom(-1, None);
                }
                "0" => view.camera.reset_zoom(),
                "u" => view.options.underground = !view.options.underground,
                "p" => view.options.pipes = !view.options.pipes,
                "v" => {
                    let next = match view.data_mode {
                        None => Some(0),
                        Some(mode) => MODES
                            .iter()
                            .position(|known| *known == mode)
                            .map(|index| index + 1)
                            .filter(|index| *index < MODES.len()),
                    };

                    view.data_mode = next.map(|index| MODES[index]);
                    self.status = next.map_or_else(|| "City".into(), |index| TITLES[index].into());
                    game.refresh_data_values();
                }
                "[" | "]" => self.rotate(text.as_str() == "["),
                "b" => self.tool = (group::BULLDOZER, 0),
                "x" => self.tool = (group::ROADS, 0),
                "w" => self.tool = (group::POWER, 0),
                "z" => self.tool = (group::RESIDENTIAL, 0),
                "c" => self.tool = (group::COMMERCIAL, 0),
                "i" => self.tool = (group::INDUSTRIAL, 0),
                "t" => self.tool = (group::LANDSCAPE, 0),
                "k" => self.tool = (group::POWER, 2),
                "q" => self.tool = (group::QUERY, 0),
                "y" => {
                    let undone = game.runner.call(|session| session.undo.take().map(|undo| undo.apply(session)));

                    if let Some(result) = undone {
                        self.status = result.map_or_else(|error| error, |()| "Undid the last edit.".into());
                    }
                }
                digit @ ("1" | "2" | "3" | "4" | "5") => {
                    let speed: i64 = digit.parse().unwrap_or(1);
                    game.runner.call(move |session| session.set_speed(speed));
                }
                _ => {}
            },
            _ => {}
        }
    }

    fn rotate(&mut self, counter_clockwise: bool) {
        let game = &mut self.game;
        let edge = game.view.edge();
        let center = game.view.tile_at(game.view.camera.viewport.center());

        match game.runner.call(move |session| session.rotate(counter_clockwise)) {
            Ok(()) => {
                // the rotated maps arrive with the next update
                game.receive();

                if let Some((x, y)) = center {
                    let (x, y) = if counter_clockwise { (y, edge - 1 - x) } else { (edge - 1 - y, x) };
                    game.view.camera.center_on(sc2k_view::geometry::tile_center(edge, x, y, 0));
                }

                self.status = if counter_clockwise {
                    "Rotated counterclockwise".into()
                } else {
                    "Rotated clockwise".into()
                };
            }
            Err(error) => self.status = format!("Cannot rotate city: {error}"),
        }
    }

    fn apply_tool(&mut self) {
        let path = std::mem::take(&mut self.selection);
        let (Some(first), Some(last)) = (path.first().copied(), path.last().copied()) else {
            return;
        };

        let point = |tile: (i32, i32)| Vec2i::new(i64::from(tile.0), i64::from(tile.1));
        let mut selection = Selection::new(self.tool.0, self.tool.1, point(first), point(last));
        selection.path = path.into_iter().map(point).collect();
        selection.underground = self.game.view.options.underground;

        // a bridge or connection that the route asks for takes the first choice
        selection.bridge = 0;
        selection.connection = 0;
        selection.confirmation = 1;
        let outcome = self.game.runner.call(move |session| edits::apply(session, &selection));

        for sound in &outcome.sounds {
            self.game.audio.play_sound(*sound, false, false);
        }

        if outcome.music_track >= 0 {
            self.game.audio.play_music_track(outcome.music_track, false);
        }

        self.status = match outcome.view_action {
            Some(action) => format!("{action} at {}, {}", last.0, last.1),
            None => outcome.message,
        };
    }
}

impl ApplicationHandler for App {
    fn resumed(&mut self, event_loop: &ActiveEventLoop) {
        if self.window.is_some() {
            return;
        }

        let attributes = Window::default_attributes()
            .with_title("OpenSC2K")
            .with_inner_size(winit::dpi::LogicalSize::new(cli::WIDTH, cli::HEIGHT));
        let window = Rc::new(event_loop.create_window(attributes).expect("a window"));
        let context = softbuffer::Context::new(window.clone()).expect("a drawing context");
        self.surface = Some(softbuffer::Surface::new(&context, window.clone()).expect("a window surface"));
        window.request_redraw();
        self.window = Some(window);
    }

    fn window_event(&mut self, event_loop: &ActiveEventLoop, _: WindowId, event: WindowEvent) {
        match event {
            WindowEvent::CloseRequested => event_loop.exit(),
            WindowEvent::Focused(focused) => self.game.audio.set_focus(focused),
            WindowEvent::RedrawRequested => self.redraw(),
            WindowEvent::KeyboardInput { event, .. } if event.state == ElementState::Pressed => self.key(event.logical_key),
            WindowEvent::CursorMoved { position, .. } => {
                let point = (position.x, position.y);
                let tile = self.game.view.tile_at(point);

                if let Some(tile) = tile
                    && !self.selection.is_empty()
                    && self.selection.last() != Some(&tile)
                {
                    self.selection.push(tile);
                }

                self.game.view.highlight = if self.selection.is_empty() {
                    tile.into_iter().collect()
                } else {
                    self.selection.clone()
                };

                if let Some(last) = self.dragging {
                    self.game.view.camera.pan_screen(last.0 - point.0, last.1 - point.1);
                    self.dragging = Some(point);
                }

                self.cursor = point;
            }
            WindowEvent::MouseInput {
                state,
                button: MouseButton::Left,
                ..
            } => {
                if state == ElementState::Pressed {
                    self.selection = self.game.view.tile_at(self.cursor).into_iter().collect();
                } else {
                    self.apply_tool();
                }
            }
            WindowEvent::MouseInput {
                state,
                button: MouseButton::Right | MouseButton::Middle,
                ..
            } => {
                self.dragging = (state == ElementState::Pressed).then_some(self.cursor);
            }
            WindowEvent::MouseWheel { delta, .. } => {
                let steps = match delta {
                    MouseScrollDelta::LineDelta(_, y) => y,
                    MouseScrollDelta::PixelDelta(position) => (position.y / 40.0) as f32,
                };

                if steps.abs() >= 1.0 {
                    self.game.view.camera.change_zoom(steps.signum() as i32, Some(self.cursor));
                }
            }
            _ => {}
        }
    }
}

fn exit_with(error: String) -> ! {
    eprintln!("{error}");
    std::process::exit(1);
}

fn main() {
    let arguments: Vec<String> = std::env::args().skip(1).collect();

    let Some(city_path) = arguments.first().map(PathBuf::from) else {
        eprintln!(
            "usage: opensc2k <city file> [--snapshot out.png [zoom steps] | --render out.png [view] [underground] | --benchmark [frames] [speed]]"
        );
        std::process::exit(2);
    };

    if arguments.get(1).map(String::as_str) == Some("--render") {
        let settings = settings::Settings::load();
        let folder = settings.graphics_folder().unwrap_or_default();
        let pack = sc2k_assets::packs::graphics::GraphicsPack::load(&folder.to_string_lossy()).unwrap_or_else(|error| exit_with(error));
        let art = sc2k_view::art::CityArt::new(&pack);
        let session = sc2k_game::session::Session::open(&city_path, 1).unwrap_or_else(|error| exit_with(error));
        let path = arguments.get(2).cloned().unwrap_or_else(|| "city.png".into());
        let view: usize = arguments.get(3).and_then(|text| text.parse().ok()).unwrap_or(2);
        let underground = arguments.get(4).map(String::as_str) == Some("underground");
        cli::render_city(&session, &art, &path, view, underground).unwrap_or_else(|error| exit_with(error));

        return;
    }

    let mut game = Game::load(&city_path).unwrap_or_else(|error| exit_with(error));

    match arguments.get(1).map(String::as_str) {
        Some("--snapshot") => {
            let path = arguments.get(2).cloned().unwrap_or_else(|| "snapshot.png".into());
            let steps: i32 = arguments.get(3).and_then(|text| text.parse().ok()).unwrap_or(0);
            cli::snapshot(&mut game, &path, steps).unwrap_or_else(|error| exit_with(error));
        }
        Some("--benchmark") => {
            let frames: usize = arguments.get(2).and_then(|text| text.parse().ok()).unwrap_or(300);
            let speed: i64 = arguments.get(3).and_then(|text| text.parse().ok()).unwrap_or(5);
            cli::benchmark(&mut game, frames, speed);
        }
        _ => {
            let event_loop = EventLoop::new().expect("an event loop");
            event_loop.set_control_flow(ControlFlow::Poll);
            let mut app = App {
                game,
                window: None,
                surface: None,
                last_frame: Instant::now(),
                started: Instant::now(),
                cursor: (0.0, 0.0),
                dragging: None,
                tool: (group::BULLDOZER, 0),
                selection: Vec::new(),
                status: String::new(),
            };

            event_loop.run_app(&mut app).expect("the event loop");
        }
    }
}
