//! The city view of the native shell: the camera, the painted regions over the
//! published scene, the moving draws, the data views, and the palette clock.

use sc2k_assets::palette;
use sc2k_game::speed::BASE_TICK_MSEC;
use sc2k_render::City as PainterCity;
use sc2k_view::Frame;
use sc2k_view::art::CityArt;
use sc2k_view::camera::{Camera, Viewport};
use sc2k_view::data_view::{self, Mode};
use sc2k_view::moving::{Thing, moving_draws};
use sc2k_view::present::{cycled_colors, dark_underground, draw_map, outline_tile};
use sc2k_view::regions::{Options, Regions};
use sc2k_view::scene;

/// The clear color of the window, as the Godot build: (0.035, 0.047, 0.059).
pub const BACKGROUND: u32 = 0x00090c0f;
const UNDERGROUND_BACKGROUND: u32 = 0x00ffffff;
const HIGHLIGHT: u32 = 0x00ffff40;

pub struct CityView {
    pub camera: Camera,
    pub options: Options,
    /// The maps while no regions hold them.
    city: Option<PainterCity>,
    regions: Option<Regions>,
    things: Vec<Thing>,
    markers: Vec<(usize, i64)>,
    pub revision: u64,
    pub map_revision: u64,
    pub cycle_ticks: i64,
    cycle_msec: f64,
    /// The display clock of moving sprites, in tenths of a second.
    pub animation_phase: i64,
    pub show_vehicles: bool,
    /// The dark colors of the underground view, a display setting.
    pub dark_underground: bool,
    /// Show the art of the HD sprite pack, when one is loaded.
    pub hd: bool,
    /// The data view that replaces the city, and its tile values.
    pub data_mode: Option<Mode>,
    pub data_values: Vec<i32>,
    data_mesh: Option<(u64, Mode, sc2k_render::data_view::DataMesh)>,
    /// The tiles that the selection outlines.
    pub highlight: Vec<(i32, i32)>,
    moving_key: (u64, i64, usize, bool),
    pub effects: sc2k_view::effects::Effects,
    /// The milliseconds of the view clock, for the effects.
    pub clock_msec: f64,
}

impl CityView {
    /// A view of the first whole scene update, centered on tile `center`.
    pub fn new(first: &scene::Update, center: (i32, i32)) -> Self {
        let mut city = PainterCity::default();
        scene::apply(&mut city, first);
        let mut camera = Camera::new(city.edge);
        let edge = city.edge;
        let (x, y) = (center.0.clamp(0, edge - 1), center.1.clamp(0, edge - 1));
        camera.center = sc2k_view::geometry::tile_center(edge, x, y, city.altitude.get((x * edge + y) as usize).map_or(0, |a| a & 31));

        Self {
            camera,
            options: Options::default(),
            city: Some(city),
            regions: None,
            things: first.things.clone(),
            markers: first.markers.clone().unwrap_or_default(),
            revision: first.revision,
            map_revision: first.map_revision,
            cycle_ticks: 0,
            cycle_msec: 0.0,
            animation_phase: 0,
            show_vehicles: true,
            hd: true,
            dark_underground: false,
            data_mode: None,
            data_values: Vec::new(),
            data_mesh: None,
            highlight: Vec::new(),
            moving_key: (u64::MAX, -1, usize::MAX, true),
            effects: sc2k_view::effects::Effects::default(),
            clock_msec: 0.0,
        }
    }

    /// Start the effects of a tick or an edit.
    pub fn show_effects(&mut self, values: &[sc2k_sim::sim::value::Value], art: &CityArt) {
        let events = sc2k_view::effects::events_of(values);

        if events.is_empty() {
            return;
        }

        let view = self.camera.graphics_view();
        let painter = match &self.regions {
            Some(regions) => regions.city(),
            None => self.city.as_ref().expect("the view holds its maps"),
        };
        self.effects.show(&events, self.clock_msec, painter, &art.views[view], view);
    }

    fn painter(&self) -> &PainterCity {
        match &self.regions {
            Some(regions) => regions.city(),
            None => self.city.as_ref().expect("the view holds its maps"),
        }
    }

    pub fn edge(&self) -> i32 {
        self.painter().edge
    }

    /// Apply a scene update from the simulation.
    pub fn apply(&mut self, update: &scene::Update) {
        match &mut self.regions {
            Some(regions) => regions.apply(update),
            None => {
                if let Some(city) = &mut self.city {
                    scene::apply(city, update);
                }
            }
        }

        self.things.clone_from(&update.things);

        if let Some(markers) = &update.markers {
            self.markers.clone_from(markers);
        }

        self.revision = update.revision;
        self.map_revision = update.map_revision;
    }

    pub fn advance_palette(&mut self, delta_msec: f64) {
        self.cycle_msec += delta_msec.max(0.0);
        let ticks = (self.cycle_msec / BASE_TICK_MSEC) as i64;
        self.cycle_msec -= ticks as f64 * BASE_TICK_MSEC;
        self.cycle_ticks += ticks;
    }

    pub fn set_viewport(&mut self, viewport: Viewport) {
        self.camera.viewport = viewport;
        self.camera.clamp();
    }

    /// Paint again on the next frame, as after a change of display options.
    pub fn invalidate(&mut self) {
        if let Some(regions) = self.regions.take() {
            self.city = Some(regions.into_city());
        }
    }

    /// The tile under a screen point.
    pub fn tile_at(&self, point: (f64, f64)) -> Option<(i32, i32)> {
        sc2k_view::picking::tile_at(self.painter(), self.camera.screen_to_source(point))
    }

    pub fn draw(&mut self, frame: &mut Frame, art: &CityArt) {
        let view = self.camera.graphics_view();

        if self
            .regions
            .as_ref()
            .is_some_and(|regions| regions.view != view || regions.options != self.options)
        {
            self.invalidate();
        }

        if self.regions.is_none() {
            let city = self.city.take().expect("the view holds its maps");

            let regions = if art.hd.is_some() && self.hd {
                Regions::new_hd(city.clone(), art, view, self.options)
            } else {
                Regions::new(city.clone(), art, view, self.options)
            };

            match regions {
                Ok(regions) => {
                    self.regions = Some(regions);
                    self.moving_key = (u64::MAX, -1, usize::MAX, true);
                }
                Err(error) => {
                    sc2k_platform::console::error(&format!("Cannot paint the city: {error}"));
                    self.city = Some(city);

                    return;
                }
            }
        }

        if !self.options.underground {
            let key = (self.revision, self.animation_phase, view, self.show_vehicles);

            if key != self.moving_key {
                let regions = self.regions.as_mut().expect("regions exist");
                let draws = moving_draws(
                    regions.city(),
                    &self.things,
                    &art.views[view],
                    &self.markers,
                    view,
                    self.animation_phase,
                    32,
                    self.show_vehicles,
                );
                regions.set_moving(draws);
                self.moving_key = key;
            }
        }

        if let Some(mode) = self.data_mode {
            self.draw_data(frame, mode);

            return;
        }

        let mut colors = cycled_colors(&art.palette, &palette::index_map(self.cycle_ticks));
        let mut background = if self.options.underground {
            UNDERGROUND_BACKGROUND
        } else {
            BACKGROUND
        };

        if self.options.underground && self.dark_underground {
            colors = dark_underground(&colors);
            background = dark_underground(&[UNDERGROUND_BACKGROUND; 256])[0];
        }
        let regions = self.regions.as_mut().expect("regions exist");
        draw_map(frame, &self.camera, regions, &colors, background);

        for tile in &self.highlight {
            outline_tile(frame, &self.camera, regions.city(), *tile, HIGHLIGHT);
        }
    }

    fn draw_data(&mut self, frame: &mut Frame, mode: Mode) {
        let stale = self
            .data_mesh
            .as_ref()
            .is_none_or(|(revision, cached, _)| *revision != self.map_revision || *cached != mode);

        if stale && let Some(mesh) = data_view::mesh(self.painter(), mode) {
            self.data_mesh = Some((self.map_revision, mode, mesh));
        }

        frame.pixels.fill(BACKGROUND);

        if let Some((_, _, mesh)) = &self.data_mesh {
            data_view::draw(frame, &self.camera, mesh, &self.data_values, self.edge() as usize, mode);
        }

        for tile in &self.highlight {
            outline_tile(frame, &self.camera, self.painter(), *tile, HIGHLIGHT);
        }
    }
}
