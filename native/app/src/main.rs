//! The native OpenSC2K game. It opens a window, loads the graphics pack of the
//! shared settings, and shows a city with the simulation running.

mod audio;
mod city_view;
mod settings;

use city_view::CityView;
use sc2k_assets::packs::graphics::GraphicsPack;
use sc2k_game::edits::{self, Selection};
use sc2k_game::session::Session;
use sc2k_sim::sim::geom::Vec2i;
use sc2k_sim::sim::tools::ids::group;
use sc2k_view::Frame;
use sc2k_view::art::CityArt;
use sc2k_view::camera::Viewport;
use std::num::NonZeroU32;
use std::path::PathBuf;
use std::rc::Rc;
use std::time::Instant;
use winit::application::ApplicationHandler;
use winit::event::{ElementState, MouseButton, MouseScrollDelta, WindowEvent};
use winit::event_loop::{ActiveEventLoop, ControlFlow, EventLoop};
use winit::keyboard::{Key, NamedKey};
use winit::window::{Window, WindowId};

const WINDOW_WIDTH: f64 = 1280.0;
const WINDOW_HEIGHT: f64 = 800.0;
const KEY_PAN_PIXELS: f64 = 64.0;

struct Game {
    audio: audio::Audio,
    art: CityArt,
    session: Session,
    view: CityView,
}

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
        let tick = self.game.session.advance(delta, elapsed, false);

        if !tick.error.is_empty() {
            eprintln!("simulation: {}", tick.error);
        }

        let game = &mut self.game;
        game.audio.advance(delta);
        game.audio
            .play_sound_events(&tick.sound_events, game.view.camera.graphics_view() as i64);

        for track in &tick.music_track_requests {
            if game.session.city.music_enabled() {
                game.audio.play_music_track(i64::from(*track), true);
            }
        }

        game.session.engine.day.midi_playback_active = game.audio.music_active();

        self.game.view.advance_palette(delta);
        self.game.view.animation_phase = elapsed / 100;
        let size = window.inner_size();
        let (width, height) = (size.width.max(1), size.height.max(1));
        let _ = surface.resize(
            NonZeroU32::new(width).unwrap(),
            NonZeroU32::new(height).unwrap(),
        );
        self.game.view.set_viewport(Viewport {
            x: 0.0,
            y: 0.0,
            width: f64::from(width),
            height: f64::from(height),
        });
        self.game.view.camera.map_pixel_ratio = window.scale_factor().round().max(1.0);

        let Ok(mut buffer) = surface.buffer_mut() else {
            return;
        };

        let mut frame = Frame {
            width: width as usize,
            height: height as usize,
            pixels: &mut buffer,
        };

        self.game
            .view
            .draw(&mut frame, &self.game.session, &self.game.art);
        let _ = buffer.present();
        window.set_title(&format!(
            "OpenSC2K — {} — day {} — ${} — speed {} — {}",
            self.game.session.city_name(),
            self.game.session.city.age_in_days(),
            edits::funds(&self.game.session),
            self.game.session.speed.speed,
            self.status
        ));
        window.request_redraw();
    }

    fn key(&mut self, key: Key) {
        let view = &mut self.game.view;

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
                "u" => {
                    view.options.underground = !view.options.underground;
                    view.invalidate();
                }
                "p" => view.options.pipes = !view.options.pipes,
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
                    if let Some(undo) = self.game.session.undo.take() {
                        self.status = match undo.apply(&mut self.game.session) {
                            Ok(()) => "Undid the last edit.".into(),
                            Err(error) => error,
                        };
                    }
                }
                digit @ ("1" | "2" | "3" | "4" | "5") => {
                    self.game.session.set_speed(digit.parse().unwrap_or(1));
                }
                _ => {}
            },
            _ => {}
        }
    }
}

impl App {
    fn apply_tool(&mut self) {
        let path = std::mem::take(&mut self.selection);
        let (Some(first), Some(last)) = (path.first(), path.last()) else {
            return;
        };

        let point = |tile: &(i32, i32)| Vec2i::new(i64::from(tile.0), i64::from(tile.1));
        let mut selection = Selection::new(self.tool.0, self.tool.1, point(first), point(last));
        selection.path = path.iter().map(point).collect();
        selection.underground = self.game.view.options.underground;

        // a bridge or connection that the route asks for takes the first choice
        selection.bridge = 0;
        selection.connection = 0;
        selection.confirmation = 1;
        let outcome = edits::apply(&mut self.game.session, &selection);

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
            .with_inner_size(winit::dpi::LogicalSize::new(WINDOW_WIDTH, WINDOW_HEIGHT));
        let window = Rc::new(event_loop.create_window(attributes).expect("a window"));
        let context = softbuffer::Context::new(window.clone()).expect("a drawing context");
        self.surface =
            Some(softbuffer::Surface::new(&context, window.clone()).expect("a window surface"));
        window.request_redraw();
        self.window = Some(window);
    }

    fn window_event(&mut self, event_loop: &ActiveEventLoop, _: WindowId, event: WindowEvent) {
        match event {
            WindowEvent::CloseRequested => event_loop.exit(),
            WindowEvent::Focused(focused) => self.game.audio.set_focus(focused),
            WindowEvent::RedrawRequested => self.redraw(),
            WindowEvent::KeyboardInput { event, .. } if event.state == ElementState::Pressed => {
                self.key(event.logical_key)
            }
            WindowEvent::CursorMoved { position, .. } => {
                let point = (position.x, position.y);
                let tile = self.game.view.tile_at(&self.game.session, point);

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
                    self.game
                        .view
                        .camera
                        .pan_screen(last.0 - point.0, last.1 - point.1);
                    self.dragging = Some(point);
                }

                self.cursor = point;
            }
            WindowEvent::MouseInput {
                state,
                button: MouseButton::Right | MouseButton::Middle,
                ..
            } => {
                self.dragging = (state == ElementState::Pressed).then_some(self.cursor);
            }
            WindowEvent::MouseInput {
                state,
                button: MouseButton::Left,
                ..
            } => {
                if state == ElementState::Pressed {
                    self.selection = self
                        .game
                        .view
                        .tile_at(&self.game.session, self.cursor)
                        .into_iter()
                        .collect();
                } else {
                    self.apply_tool();
                }
            }
            WindowEvent::MouseWheel { delta, .. } => {
                let steps = match delta {
                    MouseScrollDelta::LineDelta(_, y) => y,
                    MouseScrollDelta::PixelDelta(position) => (position.y / 40.0) as f32,
                };

                if steps.abs() >= 1.0 {
                    self.game
                        .view
                        .camera
                        .change_zoom(steps.signum() as i32, Some(self.cursor));
                }
            }
            _ => {}
        }
    }
}

fn load_game(city_path: PathBuf) -> Result<Game, String> {
    let settings = settings::Settings::load();
    let folder = settings
        .graphics_folder()
        .ok_or("No graphics pack is set. Import the game assets first.")?;
    let pack = GraphicsPack::load(&folder.to_string_lossy())?;
    let art = CityArt::new(&pack);
    let seed = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_or(1, |time| time.as_millis() as i64);
    let session = Session::open(&city_path, seed)?;
    let view = CityView::new(&session);
    let config = &settings.config;
    let mut audio = audio::Audio::new(&audio::AudioSettings {
        music_volume: config.float("audio", "music_volume", 0.8) as f32,
        effects_volume: config.float("audio", "effects_volume", 0.8) as f32,
        shuffle: config.bool("audio", "shuffle_music", false),
        sound_pack: settings.path("audio", "sound_pack_folder"),
        music_pack: settings.path("audio", "music_pack_folder"),
        soundfont_choice: config.string("audio", "music_soundfont", "system"),
        soundfont_path: config.string("audio", "music_soundfont_path", ""),
    });

    if session.city.music_enabled() {
        let track = audio.next_general_track();
        audio.play_music_track(track, true);
    }

    if !audio.notice.is_empty() {
        eprintln!("{}", audio.notice);
    }

    Ok(Game {
        audio,
        art,
        session,
        view,
    })
}

/// Render one frame of `game` to a PNG file, without a window.
fn snapshot(game: &mut Game, path: &str, width: usize, height: usize) -> Result<(), String> {
    let mut pixels = vec![0_u32; width * height];
    game.view.set_viewport(Viewport {
        x: 0.0,
        y: 0.0,
        width: width as f64,
        height: height as f64,
    });
    let mut frame = Frame {
        width,
        height,
        pixels: &mut pixels,
    };
    game.view.draw(&mut frame, &game.session, &game.art);
    let rgba: Vec<u8> = pixels
        .iter()
        .flat_map(|pixel| [(pixel >> 16) as u8, (pixel >> 8) as u8, *pixel as u8, 255])
        .collect();
    let bytes = sc2k_formats::png::encode_rgba(width as u32, height as u32, &rgba)?;

    std::fs::write(path, bytes).map_err(|error| error.to_string())
}

fn main() {
    let arguments: Vec<String> = std::env::args().skip(1).collect();

    let Some(city_path) = arguments.first().map(PathBuf::from) else {
        eprintln!("usage: opensc2k <city file> [--snapshot out.png [zoom steps]]");
        std::process::exit(2);
    };

    let mut game = match load_game(city_path) {
        Ok(game) => game,
        Err(error) => {
            eprintln!("{error}");
            std::process::exit(1);
        }
    };

    if arguments.get(1).map(String::as_str) == Some("--snapshot") {
        let path = arguments
            .get(2)
            .cloned()
            .unwrap_or_else(|| "snapshot.png".into());
        let steps: i32 = arguments
            .get(3)
            .and_then(|text| text.parse().ok())
            .unwrap_or(0);
        game.view.set_viewport(Viewport {
            x: 0.0,
            y: 0.0,
            width: WINDOW_WIDTH,
            height: WINDOW_HEIGHT,
        });
        game.view.camera.change_zoom(steps, None);

        if let Err(error) = snapshot(
            &mut game,
            &path,
            WINDOW_WIDTH as usize,
            WINDOW_HEIGHT as usize,
        ) {
            eprintln!("{error}");
            std::process::exit(1);
        }

        return;
    }

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
