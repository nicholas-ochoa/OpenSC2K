//! The city view of the native shell: the camera, the painted regions, and the
//! palette clock over one session.

use sc2k_assets::palette;
use sc2k_game::session::Session;
use sc2k_game::speed::BASE_TICK_MSEC;
use sc2k_view::Frame;
use sc2k_view::art::CityArt;
use sc2k_view::camera::{Camera, Viewport};
use sc2k_view::present::{cycled_colors, draw_map};
use sc2k_view::regions::{Options, Regions};
use sc2k_view::snapshot::painter_city;

/// The clear color of the window, as the Godot build: (0.035, 0.047, 0.059).
pub const BACKGROUND: u32 = 0x00090c0f;
const UNDERGROUND_BACKGROUND: u32 = 0x00ffffff;

pub struct CityView {
    pub camera: Camera,
    pub options: Options,
    regions: Option<Regions>,
    revision: u64,
    pub cycle_ticks: i64,
    cycle_msec: f64,
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
                Ok(regions) => self.regions = Some(regions),
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

        let colors = cycled_colors(&art.palette, &palette::index_map(self.cycle_ticks));
        let background = if self.options.underground {
            UNDERGROUND_BACKGROUND
        } else {
            BACKGROUND
        };

        if let Some(regions) = &mut self.regions {
            draw_map(frame, &self.camera, regions, &colors, background);
        }
    }
}
