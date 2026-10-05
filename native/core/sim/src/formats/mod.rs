//! City file codecs. They have no Godot types.

pub mod document;
pub mod rle;
pub mod sc2;
pub mod sc2kfix;
pub mod sc2x;
pub mod store;

#[cfg(test)]
mod corpus_tests;
