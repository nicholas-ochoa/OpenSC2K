//! The power scan, as PowerPhase.

use super::{TraceQueue, building_indices, flags_without, queue_neighbors};
use crate::gd_phase_result;
use crate::sim::city::City;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::ordinance_ids;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::phase::{PhaseResultLike, TimingSpan};
use crate::sim::random::SimRandom;

const FLAG_MARK: i64 = flag_bits::MARK;
const FLAG_POWERED: i64 = flag_bits::POWERED;
const FLAG_POWERABLE: i64 = flag_bits::POWERABLE;

gd_phase_result! {
    pub struct PowerResult as "PowerPhase.Result" {
        pub generation: i64 = 0,
        pub consumers: i64 = 0,
        pub supplied_consumers: i64 = 0,
        pub usage_percent: i64 = 0,
    }
}

#[derive(Default)]
struct Component {
    size: usize,
    capacity: i64,
    consumers: i64,
}

fn is_plant(building: i64) -> bool {
    (tiles::HYDRO_POWER_1..=tiles::COAL_POWER).contains(&building)
}

fn plant_capacity(city: &City, building: i64, x: i64, y: i64, random: &mut SimRandom) -> i64 {
    match building {
        tiles::HYDRO_POWER_1 | tiles::HYDRO_POWER_2 => 40,
        tiles::WIND_POWER => {
            let wind = city.misc_u32(misc_layout::WEATHER_WIND) & 0xff;

            (city.land_altitude(x, y) + random.next_u15() % (wind / 8 + 1)) / 2
        }
        tiles::GAS_POWER => 11,
        tiles::OIL_POWER => 48,
        tiles::NUCLEAR_POWER => 111,
        tiles::SOLAR_POWER => {
            let rain = city.misc_u32(misc_layout::WEATHER_RAIN) & 0xff;
            let sunlight_range = ((100 - rain) / 10).max(1);

            random.next_u15() % sunlight_range + 5
        }
        tiles::MICROWAVE_POWER => 355,
        tiles::FUSION_POWER => 555,
        tiles::COAL_POWER => 44,
        _ => 0,
    }
}

/// PowerPhase.run.
pub fn run(city: &mut City, random: &mut SimRandom) -> PowerResult {
    let mut span = TimingSpan::new();
    span.mark("clear power and scan marks");
    let mut flags = flags_without(&city.xbit.data, FLAG_MARK | FLAG_POWERED);
    let mut total_generation = 0;
    let mut supplied_consumers = 0;
    let mut total_consumers = 0;
    // SC2X cities trace without the original queue limit.
    let bounded_queue = !city.is_extended();
    let mut queue = if bounded_queue { Vec::new() } else { vec![0i64; flags.len()] };
    span.mark("find power sources");
    let plant_ids: Vec<i64> = (tiles::HYDRO_POWER_1..=tiles::COAL_POWER).collect();
    let plants = building_indices(&city.xbld.data, &plant_ids);

    for index in plants {
        if flags[index as usize] as i64 & FLAG_POWERED != 0 {
            continue;
        }

        span.mark("network traversal and generation");
        let component = if bounded_queue {
            trace_bounded_component(city, &mut flags, index, random)
        } else {
            trace_component(city, &mut flags, &mut queue, index, random)
        };

        span.mark("capacity and ordinance totals");
        let mut capacity = component.capacity;
        let consumers = component.consumers;
        total_generation += capacity;
        total_consumers += consumers;

        if city.misc_u32(misc_layout::ORDINANCES) & ordinance_ids::ENERGY_CONSERVATION_MASK != 0 {
            capacity += capacity / 12;
        }

        supplied_consumers += capacity.min(consumers);
        span.mark("distribute power");

        if bounded_queue {
            distribute_bounded(city, &mut flags, index, capacity);
            span.mark("find power sources");
            continue;
        }

        // Power goes to the tiles in trace order until the capacity is used.
        for &tile in &queue[..component.size] {
            let tile = tile as usize;

            if capacity != 0 {
                if city.xbld.data[tile] as i64 >= tiles::DEVELOPED_FIRST {
                    capacity -= 1;
                }

                flags[tile] = (flags[tile] as i64 | FLAG_POWERED) as u8;
            }

            flags[tile] = (flags[tile] as i64 & !FLAG_MARK & 0xff) as u8;
        }

        span.mark("find power sources");
    }

    span.mark("store powered tiles");
    city.xbit.replace(flags);
    span.mark("utilization");
    let usage_percent = if total_generation != 0 {
        ((supplied_consumers * 100) / total_generation).min(100)
    } else {
        100
    };
    let mut result = PowerResult {
        generation: total_generation,
        consumers: total_consumers,
        supplied_consumers,
        usage_percent,
        ..Default::default()
    };
    result.base_mut().ok = true;
    result.base_mut().timing = span.finish();
    result
}

/// The original marks a tile when the tile leaves the queue, and skips the
/// later copies of the tile. A mark when the tile enters the queue visits the
/// same tiles in the same order, with a queue no larger than the map.
fn trace_component(city: &City, flags: &mut [u8], queue: &mut [i64], start: i64, random: &mut SimRandom) -> Component {
    let mut result = Component::default();
    let carries = |flag: u8| flag as i64 & (FLAG_MARK | FLAG_POWERABLE) == FLAG_POWERABLE;

    if !carries(flags[start as usize]) {
        return result;
    }

    let map_edge = city.map_size;
    let last_y = map_edge - 1;
    let tile_count = flags.len() as i64;
    let buildings = &city.xbld.data;
    let mut head = 0;
    let mut tail = 1;
    flags[start as usize] = (flags[start as usize] as i64 | FLAG_MARK) as u8;
    queue[0] = start;

    while head < tail {
        if head & 127 == 0 {
            crate::sim::budget::checkpoint();
        }

        let index = queue[head];
        head += 1;
        let y = index % map_edge;
        let building = buildings[index as usize] as i64;

        if is_plant(building) {
            result.capacity += plant_capacity(city, building, index / map_edge, y, random);
        } else if building >= tiles::DEVELOPED_FIRST {
            result.consumers += 1;
        }

        // Neighbors in the original order: y - 1, x - 1, y + 1, x + 1.
        for (valid, neighbor) in [
            (y > 0, index - 1),
            (index - map_edge >= 0, index - map_edge),
            (y < last_y, index + 1),
            (index + map_edge < tile_count, index + map_edge),
        ] {
            if valid && carries(flags[neighbor as usize]) {
                flags[neighbor as usize] = (flags[neighbor as usize] as i64 | FLAG_MARK) as u8;
                queue[tail] = neighbor;
                tail += 1;
            }
        }
    }

    result.size = tail;
    result
}

/// The original first pass. It queues only unmarked neighbors, including tiles
/// that do not carry power.
fn trace_bounded_component(city: &City, flags: &mut [u8], start: i64, random: &mut SimRandom) -> Component {
    let map_edge = city.map_size;
    let mut queue = TraceQueue::new(start);
    let mut result = Component::default();

    let mut visited = 0;

    while !queue.is_empty() {
        if visited & 127 == 0 {
            crate::sim::budget::checkpoint();
        }

        visited += 1;
        let index = queue.pop();
        let flag = flags[index as usize] as i64;

        if flag & FLAG_MARK != 0 || flag & FLAG_POWERABLE == 0 {
            continue;
        }

        flags[index as usize] = (flag | FLAG_MARK) as u8;
        let x = index / map_edge;
        let y = index % map_edge;
        let building = city.xbld.data[index as usize] as i64;

        if is_plant(building) {
            result.capacity += plant_capacity(city, building, x, y, random);
        } else if building >= tiles::DEVELOPED_FIRST {
            result.consumers += 1;
        }

        queue_neighbors(flags, &mut queue, x, y, 0, map_edge);
    }

    result
}

/// The original second pass walks the marked tiles again from the plant. A
/// marked tile that the queue drops keeps its mark and gets no power.
fn distribute_bounded(city: &City, flags: &mut [u8], start: i64, mut capacity: i64) {
    let map_edge = city.map_size;
    let mut queue = TraceQueue::new(start);

    let mut visited = 0;

    while !queue.is_empty() {
        if visited & 127 == 0 {
            crate::sim::budget::checkpoint();
        }

        visited += 1;
        let index = queue.pop();
        let i = index as usize;

        if flags[i] as i64 & FLAG_MARK == 0 {
            continue;
        }

        if capacity != 0 {
            if city.xbld.data[i] as i64 >= tiles::DEVELOPED_FIRST {
                capacity -= 1;
            }

            flags[i] = (flags[i] as i64 | FLAG_POWERED) as u8;
        }

        flags[i] = (flags[i] as i64 & !FLAG_MARK & 0xff) as u8;
        queue_neighbors(flags, &mut queue, index / map_edge, index % map_edge, FLAG_MARK, map_edge);
    }
}
