//! The game loop of OpenSC2K without engine types. `engine` runs the days,
//! disasters, moving objects and player answers of one city; `speed` runs
//! the engine on frame time at the game speed. A front end keeps the state
//! between calls and presents the results.
//!
//! This replaced SimulationEngine, SimulationClock, SimulationDaySchedule and
//! GameSpeedController of the scripts.

pub mod clock;
pub mod engine;
pub mod results;
pub mod speed;
pub mod state;
pub mod values;
