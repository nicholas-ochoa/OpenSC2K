//! The city view of the native shell: the camera, the painted regions, and the
//! palette clock over one session.

use sc2k_assets::palette;
use sc2k_game::session::Session;
use sc2k_game::speed::BASE_TICK_MSEC;
use sc2k_view::Frame;
use sc2k_view::art::CityArt;
use sc2k_view::camera::{Camera, Viewport};
use sc2k_view::moving::{marker_cells, moving_draws};
use sc2k_view::present::{cycled_colors, draw_map, outline_tile};
use sc2k_view::regions::{Options, Regions};
use sc2k_view::snapshot::painter_city;

/// The clear color of the window, as the Godot build: (0.035, 0.047, 0.059).
pub const BACKGROUND: u32 = 0x00090c0f;
const UNDERGROUND_BACKGROUND: u32 = 0x00ffffff;
const HIGHLIGHT: u32 = 0x00ffff40;

pub struct CityView {
    pub camera: Camera,
    pub options: Options,
    regions: Option<Regions>,
    revision: u64,
    pub cycle_ticks: i64,
    cycle_msec: f64,
    /// The display clock of moving sprites, in tenths of a second.
    pub animation_phase: i64,
    pub show_vehicles: bool,
    /// The data view that replaces the city, or none.
    pub data_mode: Option<sc2k_view::data_view::Mode>,
    data_cache: Option<(
        u64,
        sc2k_view::data_view::Mode,
        sc2k_render::data_view::DataMesh,
        Vec<i32>,
    )>,
    /// The tiles that the selection outlines.
    pub highlight: Vec<(i32, i32)>,
    markers: Vec<(usize, i64)>,
    moving_key: (u64, i64, usize),
}

impl CityView {
    pub fn new(session: &Session) -> Self {
        let mut camera = Camera::new(session.city.map_size as i32);
        let edge = session.city.map_size as i32;
        let x = session
            .city
            .misc_u32(sc2k_sim::sim::ids::sc2misc_layout::CITY_CENTER_X)
            .clamp(0, i64::from(edge) - 1) as i32;
        let y = session
            .city
            .misc_u32(sc2k_sim::sim::ids::sc2misc_layout::CITY_CENTER_Y)
            .clamp(0, i64::from(edge) - 1) as i32;
        let altitude = session.city.land_altitude(i64::from(x), i64::from(y)) as i32;
        camera.center = sc2k_view::geometry::tile_center(edge, x, y, altitude);

        Self {
            camera,
            options: Options::default(),
            regions: None,
            revision: u64::MAX,
            cycle_ticks: 0,
            cycle_msec: 0.0,
            animation_phase: 0,
            show_vehicles: true,
            highlight: Vec::new(),
            data_mode: None,
            data_cache: None,
            markers: Vec::new(),
            moving_key: (u64::MAX, -1, usize::MAX),
        }
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
        self.regions = None;
    }

    pub fn draw(&mut self, frame: &mut Frame, session: &Session, art: &CityArt) {
        let view = self.camera.graphics_view();
        let rebuild = match &self.regions {
            Some(regions) => regions.view != view || regions.options != self.options,
            None => true,
        };

        if rebuild {
            match Regions::new(painter_city(&session.city, 32), art, view, self.options) {
                Ok(regions) => {
                    self.regions = Some(regions);
                    self.moving_key = (u64::MAX, -1, usize::MAX);
                }
                Err(error) => {
                    eprintln!("Cannot paint the city: {error}");
                    return;
                }
            }

            self.revision = session.revision;
        } else if self.revision != session.revision {
            if let Some(regions) = &mut self.regions {
                regions.update(painter_city(&session.city, 32));
            }

            self.revision = session.revision;
        }

        if self.regions.is_some() && !self.options.underground {
            let key = (session.revision, self.animation_phase, view);

            if key != self.moving_key {
                if key.0 != self.moving_key.0 || self.moving_key.2 != view {
                    self.markers = marker_cells(&session.city);
                }

                let draws = moving_draws(
                    &session.city,
                    &art.views[view],
                    &self.markers,
                    view,
                    self.animation_phase,
                    32,
                    self.show_vehicles,
                );

                if let Some(regions) = &mut self.regions {
                    regions.set_moving(draws);
                }

                self.moving_key = key;
            }
        }

        let colors = cycled_colors(&art.palette, &palette::index_map(self.cycle_ticks));
        let background = if self.options.underground {
            UNDERGROUND_BACKGROUND
        } else {
            BACKGROUND
        };

        if let Some(mode) = self.data_mode {
            self.draw_data(frame, session, mode);

            return;
        }

        if let Some(regions) = &mut self.regions {
            draw_map(frame, &self.camera, regions, &colors, background);

            for tile in &self.highlight {
                outline_tile(frame, &self.camera, regions.city(), *tile, HIGHLIGHT);
            }
        }
    }
}

impl CityView {
    fn draw_data(
        &mut self,
        frame: &mut Frame,
        session: &Session,
        mode: sc2k_view::data_view::Mode,
    ) {
        use sc2k_view::data_view;

        let stale = self
            .data_cache
            .as_ref()
            .is_none_or(|(revision, cached, _, _)| {
                *revision != session.map_revision || *cached != mode
            });

        if stale {
            let painter = painter_city(&session.city, 32);

            if let Some(mesh) = data_view::mesh(&painter, mode) {
                self.data_cache = Some((
                    session.map_revision,
                    mode,
                    mesh,
                    data_view::values(&session.city, mode),
                ));
            }
        }

        frame.pixels.fill(BACKGROUND);

        if let Some((_, _, mesh, values)) = &self.data_cache {
            data_view::draw(
                frame,
                &self.camera,
                mesh,
                values,
                session.city.map_size as usize,
                mode,
            );
        }

        for tile in &self.highlight {
            if let Some(regions) = &self.regions {
                outline_tile(frame, &self.camera, regions.city(), *tile, HIGHLIGHT);
            }
        }
    }

    /// The tile under a screen point.
    pub fn tile_at(&self, session: &Session, point: (f64, f64)) -> Option<(i32, i32)> {
        let source = self.camera.screen_to_source(point);

        match &self.regions {
            Some(regions) => sc2k_view::picking::tile_at(regions.city(), source),
            None => sc2k_view::picking::tile_at(&painter_city(&session.city, 32), source),
        }
    }
}
