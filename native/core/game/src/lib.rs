//! The game loop of OpenSC2K without engine types. `engine` runs the days,
//! disasters, moving objects and player answers of one city; `speed` runs
//! the engine on frame time at the game speed. A front end keeps the state
//! between calls and presents the results.
//!
//! This replaced SimulationEngine, SimulationClock, SimulationDaySchedule and
//! GameSpeedController of the scripts. `newspaper` writes the story text.

pub mod checkpoint;
pub mod clock;
pub mod edits;
pub mod engine;
pub mod newspaper;
pub mod results;
pub mod session;
pub mod speed;
pub mod state;
pub mod values;
