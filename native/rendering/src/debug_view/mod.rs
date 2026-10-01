//! Debug map layers. The debug tile layer tints a window of tile tops over the
//! city view. Each tile reads one byte of a value texture, and a 256-color
//! table gives the tint. These modules make the geometry, the derived values,
//! the network components, the tile differences and the moving thing rows.
//! They read display arrays only and do not change the city.

pub mod geometry;
pub mod networks;
pub mod snapshot;
pub mod things;
pub mod values;
