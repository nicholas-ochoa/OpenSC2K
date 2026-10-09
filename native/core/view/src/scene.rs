//! What the city view draws, apart from the simulation: the painter maps, the
//! moving objects, and the disaster markers. A publisher on the simulation
//! thread compares its shadow maps with the city and sends only the changes.

use super::moving::{Thing, marker_cells, things_of};
use super::snapshot::painter_city;
use super::sync;
use sc2k_render::City as PainterCity;
use sc2k_sim::sim::city::City;
use std::collections::HashMap;

/// The painter values of one map cell.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Cell {
    pub terrain: u8,
    pub building: u8,
    pub zone: u8,
    pub flags: u8,
    pub underground: u8,
    pub altitude: i32,
}

/// The changes since the last update.
#[derive(Clone, Debug, Default)]
pub struct Update {
    pub revision: u64,
    pub map_revision: u64,
    /// A whole new map, after a change of most cells.
    pub full: Option<Box<PainterCity>>,
    pub cells: Vec<(usize, Cell)>,
    pub traffic: Option<Vec<u8>>,
    pub dispatch: Option<HashMap<usize, i32>>,
    pub things: Vec<Thing>,
    pub markers: Option<Vec<(usize, i64)>>,
}

/// Set the changed cells of `update` in `city`. Returns the changed cells.
pub fn apply(city: &mut PainterCity, update: &Update) -> Vec<usize> {
    if let Some(full) = &update.full {
        *city = (**full).clone();

        return (0..city.altitude.len()).collect();
    }

    let mut changed: Vec<usize> = update.cells.iter().map(|(cell, _)| *cell).collect();

    for &(cell, value) in &update.cells {
        city.terrain[cell] = value.terrain;
        city.buildings[cell] = value.building;
        city.zones[cell] = value.zone;
        city.flags[cell] = value.flags;
        city.underground[cell] = value.underground;
        city.altitude[cell] = value.altitude;
    }

    if let Some(traffic) = &update.traffic {
        city.traffic = traffic.clone();
    }

    if let Some(dispatch) = &update.dispatch {
        changed.extend(
            city.dispatch
                .keys()
                .chain(dispatch.keys())
                .filter(|cell| city.dispatch.get(cell) != dispatch.get(cell)),
        );
        city.dispatch = dispatch.clone();
    }

    changed
}

/// The simulation side: shadow maps and the revisions that it published.
pub struct Publisher {
    shadow: PainterCity,
    altitude_bytes: Vec<u8>,
    map_revision: u64,
}

impl Publisher {
    /// A publisher and the first whole update of `city`.
    pub fn new(city: &City, revision: u64, map_revision: u64) -> (Self, Update) {
        let mut publisher = Self {
            shadow: painter_city(city, 32),
            altitude_bytes: Vec::new(),
            map_revision,
        };

        // the first sync fills the byte cache; the shadow is already current
        sync::sync(&mut publisher.shadow, city, &mut publisher.altitude_bytes);
        let update = Update {
            revision,
            map_revision,
            full: Some(Box::new(publisher.shadow.clone())),
            things: things_of(city),
            markers: Some(marker_cells(city)),
            ..Update::default()
        };

        (publisher, update)
    }

    /// The changes since the last call. Maps compare only after a map change.
    pub fn update(&mut self, city: &City, revision: u64, map_revision: u64) -> Update {
        let mut update = Update {
            revision,
            map_revision,
            things: things_of(city),
            ..Update::default()
        };

        if map_revision == self.map_revision {
            return update;
        }

        self.map_revision = map_revision;

        // a rotation turns every cell
        if self.shadow.rotation != city.compass_rotation() as usize {
            self.shadow = painter_city(city, 32);
            self.altitude_bytes.clear();
            sync::sync(&mut self.shadow, city, &mut self.altitude_bytes);
            update.full = Some(Box::new(self.shadow.clone()));
            update.markers = Some(marker_cells(city));

            return update;
        }

        let traffic = self.shadow.traffic.clone();
        let dispatch = self.shadow.dispatch.clone();
        let mut changed = sync::sync(&mut self.shadow, city, &mut self.altitude_bytes);
        changed.sort_unstable();
        changed.dedup();

        if changed.len() > self.shadow.altitude.len() / 8 {
            update.full = Some(Box::new(self.shadow.clone()));
        } else {
            let shadow = &self.shadow;
            update.cells = changed
                .into_iter()
                .map(|cell| {
                    let value = Cell {
                        terrain: shadow.terrain[cell],
                        building: shadow.buildings[cell],
                        zone: shadow.zones[cell],
                        flags: shadow.flags[cell],
                        underground: shadow.underground[cell],
                        altitude: shadow.altitude[cell],
                    };

                    (cell, value)
                })
                .collect();

            if shadow.traffic != traffic {
                update.traffic = Some(shadow.traffic.clone());
            }

            if shadow.dispatch != dispatch {
                update.dispatch = Some(shadow.dispatch.clone());
            }
        }

        update.markers = Some(marker_cells(city));

        update
    }
}
