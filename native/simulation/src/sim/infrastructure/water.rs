//! The water scan, as WaterPhase.

use super::{TraceQueue, building_indices, flags_without, queue_neighbors};
use crate::gd_phase_result;
use crate::sim::city::City;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::phase::{PhaseResultLike, TimingSpan};

const FLAG_MARK: i64 = flag_bits::MARK;
const FLAG_WATERED: i64 = flag_bits::WATERED;
const FLAG_PIPED: i64 = flag_bits::PIPED;
const FLAG_POWERED: i64 = flag_bits::POWERED;

gd_phase_result! {
    pub struct WaterResult as "WaterPhase.Result" {
        pub supply: i64 = 0,
        pub consumers: i64 = 0,
        pub watered_consumers: i64 = 0,
        pub usage_percent: i64 = 0,
        pub treatment_capacity: i64 = 0,
        pub treatment_sufficient: bool = false,
    }
}

#[derive(Default)]
struct Component {
    size: usize,
    supply: i64,
    consumers: i64,
    tower_capacity: i64,
}

/// Water that a component still has to give out in its second pass.
struct Distribution {
    served: i64,
    towers_to_fill: i64,
}

/// WaterPhase.run.
pub fn run(city: &mut City) -> WaterResult {
    let map_edge = city.map_size;
    let mut span = TimingSpan::new();
    span.mark("clear water and scan marks");
    let mut flags = flags_without(&city.xbit.data, FLAG_MARK | FLAG_WATERED);

    // A water tower keeps its stored water.
    for index in building_indices(&city.xbld.data, &[tiles::WATER_TOWER]) {
        let i = index as usize;
        flags[i] = (flags[i] as i64 | (city.xbit.data[i] as i64 & FLAG_WATERED)) as u8;
    }

    let mut total_supply = 0;
    let mut total_consumers = 0;
    let mut watered_consumers = 0;
    let pump_base_supply =
        (city.misc_u32(misc_layout::WEATHER_RAIN) & 0xff) / 2 + city.misc_u32(misc_layout::WATER_LEVEL) * 5;
    // SC2X cities trace without the original queue limit.
    let bounded_queue = !city.is_extended();
    let mut queue = if bounded_queue { Vec::new() } else { vec![0i64; flags.len()] };
    span.mark("find water sources");
    let sources = sources_in_scan_order(city, city.compass_rotation());

    for index in sources {
        let i = index as usize;

        if flags[i] as i64 & FLAG_WATERED != 0 || flags[i] as i64 & FLAG_POWERED == 0 {
            continue;
        }

        span.mark("network traversal and supply");
        let component = if bounded_queue {
            trace_bounded_component(city, &mut flags, index, pump_base_supply)
        } else {
            trace_component(&city.xbld.data, &mut flags, &mut queue, index, pump_base_supply, map_edge)
        };

        span.mark("capacity and tower allocation");
        let served = component.supply.min(component.consumers);
        let stored_units = (component.supply - served).min(component.tower_capacity);
        let mut distribution = Distribution { served, towers_to_fill: (stored_units + 50) / 100 };
        total_supply += component.supply;
        total_consumers += component.consumers;
        watered_consumers += served;
        span.mark("distribute water and fill towers");

        if bounded_queue {
            distribute_bounded(city, &mut flags, index, &mut distribution);
            span.mark("find water sources");
            continue;
        }

        for &tile in &queue[..component.size] {
            water_tile(&city.xbld.data, &mut flags, tile, &mut distribution);
            flags[tile as usize] = (flags[tile as usize] as i64 & !FLAG_MARK & 0xff) as u8;
        }

        span.mark("find water sources");
    }

    span.mark("store watered tiles");
    city.xbit.replace(flags);
    span.mark("utilization and treatment capacity");
    let usage_percent = if total_supply != 0 { (watered_consumers * 100) / total_supply } else { 100 };
    let mut treatment_tiles = city.misc_u32(misc_layout::TILE_COUNTS + tiles::WATER_TREATMENT * 4);

    if !city.is_extended() {
        treatment_tiles &= 0xffff;

        if treatment_tiles >= 0x8000 {
            treatment_tiles -= 0x10000;
        }
    }

    let treatment_capacity = (treatment_tiles / 4) * 2000;
    let treatment_sufficient = watered_consumers <= treatment_capacity;
    city.set_misc_u32(misc_layout::TREATMENT_SUFFICIENT, treatment_sufficient as i64);

    let mut result = WaterResult {
        supply: total_supply,
        consumers: total_consumers,
        watered_consumers,
        usage_percent,
        treatment_capacity,
        treatment_sufficient,
        ..Default::default()
    };
    result.base_mut().ok = true;
    result.base_mut().timing = span.finish();
    result
}

fn trace_component(
    buildings: &[u8],
    flags: &mut [u8],
    queue: &mut [i64],
    start: i64,
    pump_base_supply: i64,
    map_edge: i64,
) -> Component {
    let mut result = Component::default();

    if flags[start as usize] as i64 & FLAG_PIPED == 0 {
        return result;
    }

    let last_y = map_edge - 1;
    let tile_count = flags.len() as i64;
    let carries = |flag: u8| flag as i64 & (FLAG_MARK | FLAG_PIPED) == FLAG_PIPED;
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
        count_tile(buildings, flags, index, index / map_edge, y, pump_base_supply, map_edge, &mut result);

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

/// The original first pass. It uses the 512-entry trace queue of the power
/// scan and queues only unmarked neighbors, including tiles without pipes.
fn trace_bounded_component(city: &City, flags: &mut [u8], start: i64, pump_base_supply: i64) -> Component {
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

        if flag & FLAG_MARK != 0 || flag & FLAG_PIPED == 0 {
            continue;
        }

        let x = index / map_edge;
        let y = index % map_edge;
        count_tile(&city.xbld.data, flags, index, x, y, pump_base_supply, map_edge, &mut result);
        flags[index as usize] = (flags[index as usize] as i64 | FLAG_MARK) as u8;
        queue_neighbors(flags, &mut queue, x, y, 0, map_edge);
    }

    result
}

/// The original second pass walks the marked tiles again from the source. A
/// marked tile that the queue drops keeps its mark and gets no water.
fn distribute_bounded(city: &City, flags: &mut [u8], start: i64, distribution: &mut Distribution) {
    let map_edge = city.map_size;
    let mut queue = TraceQueue::new(start);

    let mut visited = 0;

    while !queue.is_empty() {
        if visited & 127 == 0 {
            crate::sim::budget::checkpoint();
        }

        visited += 1;
        let index = queue.pop();

        if flags[index as usize] as i64 & FLAG_MARK == 0 {
            continue;
        }

        water_tile(&city.xbld.data, flags, index, distribution);
        flags[index as usize] = (flags[index as usize] as i64 & !FLAG_MARK & 0xff) as u8;
        queue_neighbors(flags, &mut queue, index / map_edge, index % map_edge, FLAG_MARK, map_edge);
    }
}

/// Add one traced tile to the component supply, consumers, and tower capacity.
#[allow(clippy::too_many_arguments)]
fn count_tile(
    buildings: &[u8],
    flags: &mut [u8],
    index: i64,
    x: i64,
    y: i64,
    pump_base_supply: i64,
    map_edge: i64,
    component: &mut Component,
) {
    let i = index as usize;
    let building = buildings[i] as i64;

    if building < tiles::DEVELOPED_FIRST {
        return;
    }

    let flag = flags[i] as i64;

    if building == tiles::WATER_PUMP {
        if flag & FLAG_POWERED != 0 {
            component.supply += neighbor_supply(flags, x, y, map_edge, flag_bits::WATER, 10) + pump_base_supply;
        }
    } else if building == tiles::WATER_TOWER {
        component.tower_capacity += 100;

        if flag & FLAG_WATERED != 0 {
            component.supply += 100;
        }

        flags[i] = (flag & !FLAG_WATERED & 0xff) as u8;
    } else if building == tiles::DESALINIZATION {
        if flag & FLAG_POWERED != 0 {
            component.supply += neighbor_supply(flags, x, y, map_edge, flag_bits::SALT_WATER | flag_bits::WATER, 20);
        }
    } else if building != tiles::WATER_TREATMENT {
        component.consumers += 1;
    }
}

/// Supply from the 3 by 3 area whose water bits equal `wanted`.
fn neighbor_supply(flags: &[u8], x: i64, y: i64, map_edge: i64, wanted: i64, amount: i64) -> i64 {
    let mut supply = 0;

    for near_x in (x - 1).max(0)..(x + 2).min(map_edge) {
        for near_y in (y - 1).max(0)..(y + 2).min(map_edge) {
            let bits = flags[(near_x * map_edge + near_y) as usize] as i64 & (flag_bits::SALT_WATER | flag_bits::WATER);

            if bits == wanted {
                supply += amount;
            }
        }
    }

    supply
}

/// Second-pass water for one tile of a component.
fn water_tile(buildings: &[u8], flags: &mut [u8], tile: i64, distribution: &mut Distribution) {
    let i = tile as usize;
    let building = buildings[i] as i64;
    let flag = flags[i] as i64;

    if building < tiles::DEVELOPED_FIRST {
        if distribution.served != 0 {
            flags[i] = (flag | FLAG_WATERED) as u8;
        }
    } else if building == tiles::WATER_PUMP || building == tiles::WATER_TREATMENT || building == tiles::DESALINIZATION {
        if flag & FLAG_POWERED != 0 {
            flags[i] = (flag | FLAG_WATERED) as u8;
        }
    } else if building == tiles::WATER_TOWER {
        if flag & FLAG_POWERED != 0 && distribution.towers_to_fill != 0 {
            flags[i] = (flag | FLAG_WATERED) as u8;
            distribution.towers_to_fill -= 1;
        }
    } else if distribution.served != 0 {
        flags[i] = (flag | FLAG_WATERED) as u8;
        distribution.served -= 1;
    }
}

/// Pumps and desalination plants in the order of the original scan for the
/// compass rotation. Each rotation scans from a different corner.
fn sources_in_scan_order(city: &City, rotation: i64) -> Vec<i64> {
    let edge = city.map_size;
    let last = edge - 1;
    let tile_count = edge * edge;
    let mut ranked: Vec<i64> = building_indices(&city.xbld.data, &[tiles::WATER_PUMP, tiles::DESALINIZATION])
        .into_iter()
        .map(|index| {
            let x = index / edge;
            let y = index % edge;
            let rank = match rotation & 3 {
                0 => y * edge + x,
                1 => x * edge + last - y,
                2 => (last - y) * edge + last - x,
                _ => (last - x) * edge + y,
            };
            rank * tile_count + index
        })
        .collect();
    ranked.sort_unstable();

    ranked.into_iter().map(|value| value % tile_count).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::geom::Vec2i;
    use crate::sim::ids::building_tile_ids as tiles;
    use crate::sim::testing::{empty_city, empty_full_resolution_city};

    /// Water sources follow the scan order of each view rotation.
    #[test]
    fn sources_follow_the_rotated_scan_order() {
        for (edge, full) in [(128i64, false), (128, true), (256, false), (384, false), (512, true)] {
            let mut city = if full { empty_full_resolution_city(edge) } else { empty_city(edge) };
            let last = edge - 1;

            for point in [Vec2i::new(0, 0), Vec2i::new(3, last), Vec2i::new(last, 2), Vec2i::new(7, 7), Vec2i::new(7, 9), Vec2i::new(9, 7), Vec2i::new(last, last)] {
                let tile = if point.x == 7 { tiles::DESALINIZATION } else { tiles::WATER_PUMP };
                city.xbld.data[(point.x * edge + point.y) as usize] = tile as u8;
            }

            for rotation in 0..4 {
                let mut expected = Vec::new();

                for major in 0..edge {
                    for minor in 0..edge {
                        let x = [minor, major, last - minor, last - major][rotation as usize];
                        let y = [major, last - minor, last - major, minor][rotation as usize];
                        let building = city.xbld.data[(x * edge + y) as usize] as i64;

                        if building == tiles::WATER_PUMP || building == tiles::DESALINIZATION {
                            expected.push(x * edge + y);
                        }
                    }
                }

                assert_eq!(sources_in_scan_order(&city, rotation), expected, "rotation {rotation}");
            }
        }
    }
}
