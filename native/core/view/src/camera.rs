//! The map camera: a center in source pixels, a zoom factor, and the screen
//! pixels of each source pixel at 100%. This is CityMapCamera of the scripts.

use super::geometry::{SIDE_MARGIN, TOP_MARGIN, VIEW_LARGE, view_size};

pub const ZOOM_LEVELS: [f64; 7] = [0.1, 0.25, 0.5, 1.0, 2.0, 3.0, 4.0];
pub const DEFAULT_ZOOM_INDEX: usize = 3;
/// A large map adds levels below the first, each half the one above, until the
/// whole map fits the view.
const MAXIMUM_FIT_ZOOM_LEVELS: usize = 4;
/// The zoom percent at which each graphics size choice applies.
pub const GRAPHICS_ZOOMS: [i64; 6] = [25, 50, 100, 200, 300, 400];
pub const DEFAULT_ZOOM_GRAPHICS: [usize; 6] = [0, 1, 2, 2, 2, 2];

/// A screen rectangle in pixels.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Viewport {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

impl Viewport {
    pub fn center(&self) -> (f64, f64) {
        (self.x + self.width / 2.0, self.y + self.height / 2.0)
    }

    pub fn contains(&self, point: (f64, f64)) -> bool {
        point.0 >= self.x && point.1 >= self.y && point.0 < self.x + self.width && point.1 < self.y + self.height
    }
}

#[derive(Clone, Debug)]
pub struct Camera {
    pub edge: i32,
    pub center: (f64, f64),
    pub zoom: f64,
    /// Whole screen pixels for each source pixel at 100% zoom.
    pub map_pixel_ratio: f64,
    pub viewport: Viewport,
    /// The graphics size for each zoom of `GRAPHICS_ZOOMS`.
    pub zoom_graphics: [usize; 6],
    /// The graphics size at 10% zoom.
    pub overview_graphics: usize,
}

impl Camera {
    pub fn new(edge: i32) -> Self {
        let (width, height) = view_size(VIEW_LARGE, edge);

        Self {
            edge,
            center: (f64::from(width) / 2.0, f64::from(height) / 2.0),
            zoom: ZOOM_LEVELS[DEFAULT_ZOOM_INDEX],
            map_pixel_ratio: 1.0,
            viewport: Viewport::default(),
            zoom_graphics: DEFAULT_ZOOM_GRAPHICS,
            overview_graphics: 0,
        }
    }

    pub fn scale(&self) -> f64 {
        self.zoom * self.map_pixel_ratio
    }

    pub fn zoom_percent(&self) -> i64 {
        (self.zoom * 100.0).round() as i64
    }

    /// The source rectangle that the camera may show: the map with side padding
    /// that matches the top margin.
    fn bounds(&self) -> (f64, f64, f64, f64) {
        let padding = f64::from(TOP_MARGIN - SIDE_MARGIN);
        let (width, height) = view_size(VIEW_LARGE, self.edge);

        (-padding, 0.0, f64::from(width) + padding * 2.0, f64::from(height))
    }

    /// The screen position of source point (0, 0).
    pub fn draw_offset(&self) -> (f64, f64) {
        let (cx, cy) = self.viewport.center();
        let scale = self.scale();

        ((cx - self.center.0 * scale).round(), (cy - self.center.1 * scale).round())
    }

    pub fn screen_to_source(&self, point: (f64, f64)) -> (f64, f64) {
        let (ox, oy) = self.draw_offset();
        let scale = self.scale();

        ((point.0 - ox) / scale, (point.1 - oy) / scale)
    }

    pub fn source_to_screen(&self, point: (f64, f64)) -> (f64, f64) {
        let (ox, oy) = self.draw_offset();
        let scale = self.scale();

        (point.0 * scale + ox, point.1 * scale + oy)
    }

    /// The zoom levels of this map and viewport.
    pub fn zoom_levels(&self) -> Vec<f64> {
        let mut levels = ZOOM_LEVELS.to_vec();
        let (_, _, width, height) = self.bounds();

        for _ in 0..MAXIMUM_FIT_ZOOM_LEVELS {
            let shown = (width * levels[0] * self.map_pixel_ratio, height * levels[0] * self.map_pixel_ratio);

            if shown.0 <= self.viewport.width && shown.1 <= self.viewport.height {
                break;
            }

            levels.insert(0, levels[0] / 2.0);
        }

        levels
    }

    fn zoom_index(&self, levels: &[f64]) -> usize {
        let mut closest = 0;

        for index in 1..levels.len() {
            if (self.zoom - levels[index]).abs() < (self.zoom - levels[closest]).abs() {
                closest = index;
            }
        }

        closest
    }

    /// Step the zoom by `direction` levels about the screen `anchor`, or the
    /// viewport center. Returns false at the first or last level.
    pub fn change_zoom(&mut self, direction: i32, anchor: Option<(f64, f64)>) -> bool {
        let levels = self.zoom_levels();
        let old = self.zoom_index(&levels);
        let new = (old as i32 + direction).clamp(0, levels.len() as i32 - 1) as usize;

        if new == old {
            return false;
        }

        let anchor = anchor.unwrap_or_else(|| self.viewport.center());
        let source = self.screen_to_source(anchor);
        self.zoom = levels[new];
        let (cx, cy) = self.viewport.center();
        let scale = self.scale();
        self.center = (source.0 + (cx - anchor.0) / scale, source.1 + (cy - anchor.1) / scale);
        self.clamp();

        true
    }

    pub fn reset_zoom(&mut self) {
        let levels = self.zoom_levels();
        let target = levels
            .iter()
            .position(|level| *level == ZOOM_LEVELS[DEFAULT_ZOOM_INDEX])
            .unwrap_or(0);
        let current = self.zoom_index(&levels);
        self.change_zoom(target as i32 - current as i32, None);
    }

    pub fn pan_screen(&mut self, dx: f64, dy: f64) {
        let scale = self.scale();
        self.center = (self.center.0 + dx / scale, self.center.1 + dy / scale);
        self.clamp();
    }

    pub fn center_on(&mut self, source: (f64, f64)) {
        self.center = source;
        self.clamp();
    }

    pub fn clamp(&mut self) {
        let (x, y, width, height) = self.bounds();
        let scale = self.scale();
        let half = (self.viewport.width / (scale * 2.0), self.viewport.height / (scale * 2.0));
        let clamp_axis = |value: f64, start: f64, size: f64, half: f64| {
            if half >= size / 2.0 {
                start + size / 2.0
            } else {
                value.clamp(start + half, start + size - half)
            }
        };

        self.center = (
            clamp_axis(self.center.0, x, width, half.0),
            clamp_axis(self.center.1, y, height, half.1),
        );
    }

    /// The graphics size that this zoom draws with.
    pub fn graphics_view(&self) -> usize {
        let percent = self.zoom_percent();

        if percent < 10 {
            return 0;
        }

        if percent <= 10 {
            return self.overview_graphics.min(2);
        }

        GRAPHICS_ZOOMS
            .iter()
            .position(|zoom| percent <= *zoom)
            .map_or(self.zoom_graphics[5], |index| self.zoom_graphics[index])
    }

    /// The source rectangle on screen: x, y, width, height.
    pub fn visible_source(&self) -> (f64, f64, f64, f64) {
        let (x, y) = self.screen_to_source((self.viewport.x, self.viewport.y));
        let scale = self.scale();

        (x, y, self.viewport.width / scale, self.viewport.height / scale)
    }
}

#[cfg(test)]
mod tests {
    use super::{Camera, Viewport};

    fn camera() -> Camera {
        let mut camera = Camera::new(128);
        camera.viewport = Viewport {
            x: 0.0,
            y: 0.0,
            width: 1280.0,
            height: 800.0,
        };
        camera.clamp();
        camera
    }

    #[test]
    fn zoom_keeps_the_anchor_point() {
        let mut camera = camera();
        let anchor = (300.0, 200.0);
        let before = camera.screen_to_source(anchor);
        assert!(camera.change_zoom(1, Some(anchor)));
        let after = camera.screen_to_source(anchor);
        assert!((before.0 - after.0).abs() < 1.0 && (before.1 - after.1).abs() < 1.0);
        assert_eq!(camera.zoom_percent(), 200);
        assert_eq!(camera.graphics_view(), 2);
        camera.change_zoom(-3, None);
        assert_eq!((camera.zoom_percent(), camera.graphics_view()), (25, 0));
    }

    #[test]
    fn a_large_map_adds_fit_levels() {
        let mut camera = Camera::new(1024);
        camera.viewport = Viewport {
            x: 0.0,
            y: 0.0,
            width: 1280.0,
            height: 800.0,
        };
        assert!(camera.zoom_levels()[0] < 0.1);
    }
}
