//! The moving-thing tick result, as MovingThingResult.

use crate::gd_object;
use crate::gd_phase_result;
use crate::sim::events::SoundEvent;
use crate::sim::geom::Vec2i;
use crate::sim::things;

gd_object! {
    pub struct ConnectionChange as "MovingThingResult.ConnectionChange" {
        pub kind: String = String::new(),
        pub delta: i64 = 0,
        pub point: Vec2i = Vec2i::ZERO,
    }
}

gd_object! {
    pub struct DisasterRequest as "MovingThingResult.DisasterRequest" {
        pub type_: i64 = 0,
        pub point: Vec2i = Vec2i::ZERO,
    }
}

gd_phase_result! {
    pub struct MovingThingResult as "MovingThingResult" {
        pub scanned_records: i64 = 0,
        pub active_airplanes: i64 = 0,
        pub active_helicopters: i64 = 0,
        pub active_ships: i64 = 0,
        pub active_monsters: i64 = 0,
        pub active_explosions: i64 = 0,
        pub active_sailboats: i64 = 0,
        pub active_trains: i64 = 0,
        pub active_tornadoes: i64 = 0,
        pub active_maxis_men: i64 = 0,
        pub moved_helicopters: i64 = 0,
        pub moved_airplanes: i64 = 0,
        pub moved_ships: i64 = 0,
        pub moved_monsters: i64 = 0,
        pub moved_sailboats: i64 = 0,
        pub moved_trains: i64 = 0,
        pub moved_tornadoes: i64 = 0,
        pub moved_maxis_men: i64 = 0,
        pub turned_sailboats: i64 = 0,
        pub turned_trains: i64 = 0,
        pub paused_trains: i64 = 0,
        pub reversed_trains: i64 = 0,
        pub distressed_sailboats: i64 = 0,
        pub removed_sailboats: i64 = 0,
        pub removed_trains: i64 = 0,
        pub removed_helicopters: i64 = 0,
        pub crashed_helicopters: i64 = 0,
        pub removed_airplanes: i64 = 0,
        pub crashed_airplanes: i64 = 0,
        pub landed_airplanes: i64 = 0,
        pub removed_ships: i64 = 0,
        pub crashed_ships: i64 = 0,
        pub docked_ships: i64 = 0,
        pub departing_ships: i64 = 0,
        pub removed_explosions: i64 = 0,
        pub removed_tornadoes: i64 = 0,
        pub removed_maxis_men: i64 = 0,
        pub removed_monsters: i64 = 0,
        pub monster_damage_hits: i64 = 0,
        pub monster_forced_airplanes: i64 = 0,
        pub monster_forced_helicopters: i64 = 0,
        pub monster_military_collisions: i64 = 0,
        pub tornado_demolitions: i64 = 0,
        pub maxis_man_extinguished_fires: i64 = 0,
        pub maxis_man_destroyed_targets: i64 = 0,
        pub maxis_man_explosions: i64 = 0,
        pub spread_explosion_fires: i64 = 0,
        pub rubble_explosion_hits: i64 = 0,
        pub damaged_facilities: i64 = 0,
        pub deferred_facility_explosion_hits: i64 = 0,
        pub malformed_records: i64 = 0,
        pub traffic_news_checks: i64 = 0,
        pub traffic_news_time_msec: i64 = 0,
        pub traffic_news_deadline_msec: i64 = 0,
        pub connection_count_changes: Vec<ConnectionChange> = Vec::new(),
        pub created_train_crash_explosions: i64 = 0,
        pub disaster_start_requests: Vec<DisasterRequest> = Vec::new(),
        pub sailboats_complete: bool = false,
        pub train_routes_complete: bool = false,
        pub helicopters_save_visible_complete: bool = false,
        pub ships_save_visible_complete: bool = false,
        pub airplanes_save_visible_complete: bool = false,
        pub explosion_records_complete: bool = false,
        pub tornadoes_save_visible_complete: bool = false,
        pub maxis_man_save_visible_complete: bool = false,
        pub monsters_save_visible_complete: bool = false,
        pub explosion_map_damage_complete: bool = false,
    }
}

/// The record position, from fields 3 and 4.
#[inline]
pub fn record_point(data: &[u8], record: i64) -> Vec2i {
    let offset = record * things::RECORD_SIZE;

    Vec2i::new(things::read(data, offset + 3), things::read(data, offset + 4))
}

/// A sound from a moving thing, with its type, record, and position.
pub fn queue_thing_sound(counters: &mut MovingThingResult, sound_id: i64, data: &[u8], record: i64) {
    let thing_type = things::read(data, record * things::RECORD_SIZE);
    let point = record_point(data, record);
    counters
        .base
        .sound_events
        .push(SoundEvent::for_thing(sound_id, thing_type, record, point));
}

/// A record index read that ignores records past the end, as a failed
/// GDScript packed-array read does.
#[inline]
pub fn record_type(data: &[u8], record: i64) -> i64 {
    let offset = record * things::RECORD_SIZE;

    if offset < 0 || offset as usize >= data.len() {
        return 0;
    }

    things::read(data, offset)
}

/// A spawned explosion record, as the MaxisManThingTick, TrainThingTick, and
/// DisasterMapState _spawn_explosion helpers.
#[allow(clippy::too_many_arguments)]
pub fn spawn_explosion(
    text: &mut [u8],
    data: &mut [u8],
    point: Vec2i,
    height: i64,
    state: i64,
    goal: i64,
    map_edge: i64,
    caps: &super::spawner::VehicleCaps,
) -> bool {
    crate::sim::disasters::map::spawn_explosion(text, data, point, height, state, goal, map_edge, caps)
}
