//! The native OpenSC2K game. It opens a window, loads the graphics pack of the
//! shared settings, and shows a city while the simulation runs on its thread.

mod audio;
mod city_view;
mod cli;
mod controls;
mod game;
mod settings;

use game::Game;
use sc2k_game::edits::{self, Selection};
use sc2k_sim::sim::geom::Vec2i;
use sc2k_sim::sim::tools::ids::group;
use sc2k_ui::controls::{Bindings, Input};
use sc2k_view::Frame;
use sc2k_view::camera::Motion;
use sc2k_view::camera::Viewport;
use sc2k_view::data_view::{MODES, TITLES};
use std::num::NonZeroU32;
use std::path::PathBuf;
use std::rc::Rc;
use std::time::Instant;
use winit::application::ApplicationHandler;
use winit::event::{ElementState, MouseButton, MouseScrollDelta, WindowEvent};
use winit::event_loop::{ActiveEventLoop, ControlFlow, EventLoop};
use winit::window::{Window, WindowId};

struct App {
    game: Game,
    window: Option<Rc<Window>>,
    surface: Option<softbuffer::Surface<Rc<Window>, Rc<Window>>>,
    last_frame: Instant,
    started: Instant,
    cursor: (f64, f64),
    dragging: Option<(f64, f64)>,
    drag_start: (f64, f64),
    /// The selected tool group and subtool.
    tool: (i64, i64),
    /// The tiles of a left-button drag, from the first.
    selection: Vec<(i32, i32)>,
    status: String,
    bindings: Bindings,
    motion: Motion,
    modifiers: winit::keyboard::ModifiersState,
    /// The speed that resumes after a pause.
    resume_speed: i64,
    /// The pinch growth since the last zoom step.
    pinch: f64,
}

/// The window icon of the game, beside the executable or in the source tree.
fn window_icon() -> Option<winit::window::Icon> {
    const ICON: &str = "assets/icons/OpenSC2K.png";
    let folder = std::env::current_exe().ok()?.parent()?.to_path_buf();
    let candidates = [
        folder.join(ICON),
        folder.join("../../../game").join(ICON),
        std::path::PathBuf::from("game").join(ICON),
    ];
    let bytes = candidates.iter().find_map(|path| std::fs::read(path).ok())?;
    let image = sc2k_formats::png::decode_rgba(&bytes).ok()?;

    winit::window::Icon::from_rgba(image.pixels, image.width, image.height).ok()
}

/// The screen direction of a camera action.
fn camera_direction(action: &str) -> Option<(f64, f64)> {
    Some(match action {
        "camera_up" => (0.0, -1.0),
        "camera_left" => (-1.0, 0.0),
        "camera_down" => (0.0, 1.0),
        "camera_right" => (1.0, 0.0),
        _ => return None,
    })
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
        game.view.clock_msec = elapsed as f64;
        let fast = if self
            .bindings
            .for_action("camera_fast")
            .iter()
            .any(|binding| binding.code == "Shift")
            && self.modifiers.shift_key()
        {
            3.0
        } else {
            1.0
        };
        let (dx, dy) = self.motion.step(delta / 1000.0, fast);
        game.view
            .camera
            .pan_screen(dx * game.view.camera.map_pixel_ratio, dy * game.view.camera.map_pixel_ratio);
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

    /// Run a key or button through the bindings: held camera keys move the
    /// camera, and press actions run.
    fn input(&mut self, input: &Input, hold_id: i64) {
        use sc2k_ui::controls::{Kind, Scope};

        const SCOPES: [Scope; 3] = [Scope::Map, Scope::Global, Scope::Anywhere];

        if let Some(action) = self.bindings.action_for(input, &[Kind::Hold], &SCOPES)
            && let Some(direction) = camera_direction(action)
        {
            if input.pressed() {
                self.motion.press(hold_id, direction);
            } else {
                self.motion.release(hold_id);
            }

            return;
        }

        if !input.pressed() {
            self.motion.release(hold_id);

            return;
        }

        if let Some(action) = self.bindings.action_for(input, &[Kind::Press], &SCOPES) {
            self.run(action);
        }
    }

    /// Run one action of the control map. Returns false for an action that
    /// this shell does not have yet.
    fn run(&mut self, action: &str) -> bool {
        use sc2k_ui::controls::{DATA_VIEW_IDS, SPEED_IDS, TOOL_IDS};

        let game = &mut self.game;
        let view = &mut game.view;

        if let Some(group) = TOOL_IDS.iter().position(|id| *id == action) {
            self.tool = (group as i64, 0);
            self.status = sc2k_sim::sim::tools::catalog::tool(self.tool.0, 0).map_or_else(String::new, |tool| tool.name.to_string());

            return true;
        }

        if let Some(index) = DATA_VIEW_IDS.iter().position(|id| *id == action) {
            view.data_mode = Some(MODES[index]);
            view.options.underground = false;
            self.status = TITLES[index].into();
            game.refresh_data_values();

            return true;
        }

        if let Some(index) = SPEED_IDS.iter().position(|id| *id == action) {
            self.set_speed(index as i64 + 1);

            return true;
        }

        match action {
            "zoom_in" => {
                view.camera.change_zoom(1, Some(self.cursor));
            }
            "zoom_out" => {
                view.camera.change_zoom(-1, Some(self.cursor));
            }
            "zoom_reset" => view.camera.reset_zoom(),
            "rotate_clockwise" => self.rotate(false),
            "rotate_counter_clockwise" => self.rotate(true),
            "speed_toggle_pause" => {
                let speed = if game.status.speed == 1 { self.resume_speed } else { 1 };
                self.set_speed(speed);
            }
            "speed_faster" | "speed_slower" => {
                let step = if action == "speed_faster" { 1 } else { -1 };
                let speed = (game.status.speed + step).clamp(1, 5);
                self.set_speed(speed);
            }
            "tool_next_subtool" | "tool_previous_subtool" => {
                let count = sc2k_sim::sim::tools::catalog::GROUPS
                    .get(self.tool.0 as usize)
                    .map_or(1, |group| group.tools.len() as i64);
                let step = if action == "tool_next_subtool" { 1 } else { -1 };
                self.tool.1 = (self.tool.1 + step).rem_euclid(count.max(1));
                self.status =
                    sc2k_sim::sim::tools::catalog::tool(self.tool.0, self.tool.1).map_or_else(String::new, |tool| tool.name.to_string());
            }
            "view_city" => {
                view.data_mode = None;
                view.options.underground = false;
                self.status = "City".into();
            }
            "view_toggle_underground" => {
                view.data_mode = None;
                view.options.underground = !view.options.underground;
            }
            "view_show_vehicles" => view.show_vehicles = !view.show_vehicles,
            "toggle_fullscreen" => {
                if let Some(window) = &self.window {
                    let fullscreen = window.fullscreen().is_none().then_some(winit::window::Fullscreen::Borderless(None));
                    window.set_fullscreen(fullscreen);
                }
            }
            "view_show_pipes" => view.options.pipes = !view.options.pipes,
            "view_show_subways" => view.options.subways = !view.options.subways,
            "view_show_water_mains" => view.options.water_mains = !view.options.water_mains,
            "view_show_tunnels" => view.options.tunnels = !view.options.tunnels,
            "undo" => {
                let undone = game.runner.call(|session| session.undo.take().map(|undo| undo.apply(session)));

                if let Some(result) = undone {
                    self.status = result.map_or_else(|error| error, |()| "Undid the last edit.".into());
                }
            }
            _ => return false,
        }

        true
    }

    fn set_speed(&mut self, speed: i64) {
        if speed > 1 {
            self.resume_speed = speed;
        }

        self.game.runner.call(move |session| session.set_speed(speed));
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

        self.game.view.show_effects(&outcome.effects, &self.game.art);

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
            .with_window_icon(window_icon())
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
            WindowEvent::ModifiersChanged(modifiers) => self.modifiers = modifiers.state(),
            WindowEvent::PinchGesture { delta, .. } => {
                // a trackpad pinch zooms one level for each quarter of growth
                self.pinch += delta;

                if self.pinch.abs() >= 0.25 {
                    self.game.view.camera.change_zoom(self.pinch.signum() as i32, Some(self.cursor));
                    self.pinch = 0.0;
                }
            }
            WindowEvent::KeyboardInput { event, .. } => {
                if let Some(input) = controls::key_input(&event, self.modifiers) {
                    self.input(&input, controls::key_id(&event));
                }
            }
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
                button: button @ (MouseButton::Right | MouseButton::Middle),
                ..
            } => {
                if state == ElementState::Pressed {
                    self.dragging = Some(self.cursor);
                    self.drag_start = self.cursor;
                } else {
                    self.dragging = None;
                    let moved = (self.cursor.0 - self.drag_start.0).abs() + (self.cursor.1 - self.drag_start.1).abs();
                    let center = button == MouseButton::Middle && self.bindings.has_mouse_button("map_center_on_tile", "Middle");

                    // a click without movement centers the map on its tile
                    if moved < 4.0
                        && center
                        && let Some((x, y)) = self.game.view.tile_at(self.cursor)
                    {
                        let edge = self.game.view.edge();
                        self.game.view.camera.center_on(sc2k_view::geometry::tile_center(edge, x, y, 0));
                    }
                }
            }
            WindowEvent::MouseInput { state, button, .. } => {
                if let Some(input) = controls::mouse_input(button, state == ElementState::Pressed, self.modifiers) {
                    self.input(&input, -20);
                }
            }
            WindowEvent::MouseWheel { delta, .. } => {
                let steps = match delta {
                    MouseScrollDelta::LineDelta(_, y) => y,
                    MouseScrollDelta::PixelDelta(position) => (position.y / 40.0) as f32,
                };

                if steps.abs() >= 1.0 {
                    self.input(&controls::wheel_input(steps > 0.0, self.modifiers), -10);
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
                drag_start: (0.0, 0.0),
                tool: (group::BULLDOZER, 0),
                selection: Vec::new(),
                status: String::new(),
                bindings: Bindings::load(&settings::Settings::load().config),
                motion: Motion::default(),
                modifiers: winit::keyboard::ModifiersState::default(),
                resume_speed: 3,
                pinch: 0.0,
            };

            sc2k_platform::console::message(&format!("OpenSC2K {} (native)", env!("CARGO_PKG_VERSION")));
            event_loop.run_app(&mut app).expect("the event loop");

            // the log of the session stays in the user folder, as the Godot build keeps its log
            let path = settings::Settings::load().root.join("logs/opensc2k.log");

            if let Err(error) = sc2k_platform::console::save(&path) {
                eprintln!("Cannot save the log: {error}");
            }
        }
    }
}
