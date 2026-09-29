//! Operation dispatch.
//!
//! A request has these fields:
//! - `op`: the operation name.
//! - `city`: `{map_size, large_version, disaster_damage_class, chunks: {id: bytes}}`.
//! - `randoms`: the SimRandom, SimLfsrRandom, and GameLcgRandom states.
//! - `args`: operation arguments.
//!
//! A response has `ok`, `error`, `written` (`{id: bytes}`), `randoms`,
//! `disaster_damage_class`, and `result`.

use godot::prelude::*;

use super::convert;
use crate::sim::city::City;
use crate::sim::random::Randoms;
use crate::sim::growth;
use crate::sim::value::{ToValue, Value};

pub const OPERATIONS: &[&str] = &["echo", "growth"];

pub struct Outcome {
    pub error: String,
    pub result: Value,
}

impl Outcome {
    pub fn value(result: Value) -> Self {
        Self { error: String::new(), result }
    }

    pub fn failure(message: impl Into<String>) -> Self {
        Self { error: message.into(), result: Value::Nil }
    }
}

pub fn run(request: &VarDictionary) -> VarDictionary {
    let op = convert::string(request, "op");
    let args = convert::dictionary(request, "args");
    let mut city = convert::city(request);
    let mut randoms = convert::randoms(request);
    let outcome = dispatch(&op, &args, &mut city, &mut randoms);
    let mut response = VarDictionary::new();
    response.set("ok", outcome.error.is_empty());
    response.set("error", outcome.error.as_str());
    response.set("written", &convert::written_chunks(&city));
    response.set("randoms", &convert::randoms_value(&randoms));
    response.set("disaster_damage_class", city.disaster_damage_class);
    response.set("result", &convert::variant(&outcome.result));
    response
}

fn dispatch(op: &str, args: &VarDictionary, city: &mut City, randoms: &mut Randoms) -> Outcome {
    match op {
        "growth" => {
            let step = convert::int(args, "step", -1);
            let substep = convert::int(args, "substep", -1);
            let detailed = convert::boolean(args, "detailed", false);
            Outcome::value(growth::run(city, randoms, step, substep, detailed).to_value())
        }
        "echo" => Outcome::value(Value::Int(convert::int(args, "value", 0) + city.map_size)),
        _ => Outcome::failure(format!("unknown native simulation operation: {op}")),
    }
}
