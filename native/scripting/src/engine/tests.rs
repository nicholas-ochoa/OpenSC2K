use std::cell::RefCell;
use std::rc::{Rc, Weak};
use std::time::Duration;

use super::Engine;
use crate::value::JsData;

type Calls = Rc<RefCell<Vec<(String, Vec<JsData>)>>>;

/// An engine whose host records each call. `add` returns the sum of two
/// integers and `fail` returns an error.
fn engine_with_host() -> (Engine, Calls) {
    let engine = Engine::new().expect("engine");
    let calls: Calls = Rc::new(RefCell::new(Vec::new()));
    let record = calls.clone();

    engine.set_host(Some(Rc::new(move |name: &str, arguments: Vec<JsData>| {
        record.borrow_mut().push((name.to_string(), arguments.clone()));

        match (name, arguments.as_slice()) {
            ("add", [JsData::Int(first), JsData::Int(second)]) => Ok(JsData::Int(first + second)),
            ("fail", _) => Err("the host refused".to_string()),
            _ => Ok(JsData::Undefined),
        }
    })));

    (engine, calls)
}

fn console_lines(calls: &Calls, level: &str) -> Vec<String> {
    calls
        .borrow()
        .iter()
        .filter(|(name, _)| name == "console")
        .filter_map(|(_, arguments)| match arguments.as_slice() {
            [JsData::String(kind), JsData::String(text)] if kind == level => Some(text.clone()),
            _ => None,
        })
        .collect()
}

#[test]
fn console_input_shows_inspected_values() {
    let (engine, _) = engine_with_host();

    assert_eq!(engine.eval_console("1 + 2"), Ok(Some("3".to_string())));
    assert_eq!(engine.eval_console("'a' + 'b'"), Ok(Some("\"ab\"".to_string())));
    assert_eq!(
        engine.eval_console("({ a: 1, list: [1, 2] })"),
        Ok(Some("{ a: 1, list: [ 1, 2 ] }".to_string()))
    );
    assert_eq!(engine.eval_console("undefined"), Ok(None));
}

#[test]
fn console_declarations_persist_between_inputs() {
    let (engine, _) = engine_with_host();

    assert_eq!(engine.eval_console("var counter = 5"), Ok(None));
    assert_eq!(engine.eval_console("let doubled = counter * 2"), Ok(None));
    assert_eq!(engine.eval_console("function triple(value) { return value * 3 }"), Ok(None));
    assert_eq!(engine.eval_console("triple(doubled)"), Ok(Some("30".to_string())));
}

#[test]
fn console_input_can_await() {
    let (engine, _) = engine_with_host();

    assert_eq!(engine.eval_console("await Promise.resolve(7)"), Ok(Some("7".to_string())));
}

#[test]
fn errors_include_the_type_message_and_stack() {
    let (engine, _) = engine_with_host();

    let syntax = engine.eval_console("1 +").unwrap_err();
    assert!(syntax.starts_with("SyntaxError"), "{syntax}");

    let thrown = engine
        .eval_console("function explode() { throw new RangeError('too far') }\nexplode()")
        .unwrap_err();
    assert!(thrown.starts_with("RangeError: too far"), "{thrown}");
    assert!(thrown.contains("explode"), "{thrown}");
}

#[test]
fn host_functions_return_values_and_throw_errors() {
    let (engine, calls) = engine_with_host();

    assert_eq!(engine.eval_console("__runtime.host('add', 2, 3)"), Ok(Some("5".to_string())));
    assert_eq!(
        engine.eval_console("try { __runtime.host('fail') } catch (error) { error.message }"),
        Ok(Some("\"the host refused\"".to_string()))
    );
    assert!(calls.borrow().iter().any(|(name, _)| name == "fail"));
}

#[test]
fn host_global_is_hidden_from_scripts() {
    let (engine, _) = engine_with_host();

    assert_eq!(engine.eval_console("typeof __host"), Ok(Some("\"undefined\"".to_string())));
}

#[test]
fn console_methods_send_levels_and_text_to_the_host() {
    let (engine, calls) = engine_with_host();

    engine
        .eval_console("console.log('city', { funds: 20000 }); console.warn('low funds'); console.error(new Error('broke'))")
        .unwrap();

    assert_eq!(console_lines(&calls, "log"), vec!["city { funds: 20000 }".to_string()]);
    assert_eq!(console_lines(&calls, "warn"), vec!["low funds".to_string()]);
    assert!(console_lines(&calls, "error")[0].starts_with("Error: broke"));
}

#[test]
fn dispatch_calls_listeners_and_returns_the_cancelled_event() {
    let (engine, calls) = engine_with_host();

    engine
        .run_script(
            "globalThis.seen = [];\n\
             __runtime.events.on('tool.beforeApply', (event) => { seen.push(event.tool); if (event.tool === 'Bulldozer') event.cancel(); });\n\
             __runtime.events.on('*', (event) => seen.push('*' + event.type));",
            "listeners.js",
        )
        .unwrap();

    let detail = JsData::object(vec![("tool", JsData::String("Bulldozer".to_string()))]);
    let event = engine
        .call(
            "__runtime.dispatch",
            &[JsData::String("tool.beforeApply".to_string()), detail, JsData::Bool(true)],
        )
        .unwrap();

    assert_eq!(event.get("cancelled"), Some(&JsData::Bool(true)));
    assert_eq!(event.get("tool"), Some(&JsData::String("Bulldozer".to_string())));
    assert_eq!(
        engine.eval_console("seen.join()"),
        Ok(Some("\"Bulldozer,*tool.beforeApply\"".to_string()))
    );

    let notices: Vec<Vec<JsData>> = calls
        .borrow()
        .iter()
        .filter(|(name, _)| name == "listeners")
        .map(|(_, arguments)| arguments.clone())
        .collect();
    assert_eq!(notices[0], vec![JsData::String("tool.beforeApply".to_string()), JsData::Int(1)]);
    assert_eq!(notices[1], vec![JsData::String("*".to_string()), JsData::Int(1)]);
}

#[test]
fn a_listener_error_does_not_stop_the_other_listeners() {
    let (engine, calls) = engine_with_host();

    engine
        .run_script(
            "globalThis.ran = 0;\n\
             __runtime.events.on('sim.day', () => { throw new Error('bad listener') });\n\
             __runtime.events.on('sim.day', () => { ran += 1 });\n\
             __runtime.events.once('sim.day', () => { ran += 10 });",
            "errors.js",
        )
        .unwrap();

    for _ in 0..2 {
        engine
            .call(
                "__runtime.dispatch",
                &[JsData::String("sim.day".to_string()), JsData::Null, JsData::Bool(false)],
            )
            .unwrap();
    }

    assert_eq!(engine.eval_console("ran"), Ok(Some("12".to_string())));
    assert_eq!(console_lines(&calls, "error").len(), 2);
    assert!(console_lines(&calls, "error")[0].contains("bad listener"));
}

#[test]
fn timers_run_when_due() {
    let (engine, calls) = engine_with_host();

    engine.run_script("globalThis.fired = []; setTimeout((name) => fired.push(name), 0, 'once'); const id = setInterval(() => fired.push('again'), 1); setTimeout(() => clearInterval(id), 3);", "timers.js").unwrap();
    std::thread::sleep(Duration::from_millis(5));

    assert_eq!(engine.call("__runtime.tick", &[]), Ok(JsData::Int(0)));
    assert_eq!(engine.eval_console("fired.join()"), Ok(Some("\"once,again\"".to_string())));

    let timer_notices: Vec<Vec<JsData>> = calls
        .borrow()
        .iter()
        .filter(|(name, _)| name == "timers")
        .map(|(_, arguments)| arguments.clone())
        .collect();
    assert_eq!(timer_notices, vec![vec![JsData::Int(1)], vec![JsData::Int(0)]]);
}

#[test]
fn the_time_limit_stops_a_runaway_script() {
    let (engine, _) = engine_with_host();
    engine.set_time_limit(Duration::from_millis(50));

    let error = engine.eval_console("while (true) {}").unwrap_err();
    assert!(error.contains("interrupted"), "{error}");

    // the engine runs again after the interruption
    assert_eq!(engine.eval_console("2 * 21"), Ok(Some("42".to_string())));
}

#[test]
fn modules_import_files_by_relative_path() {
    let folder = std::env::temp_dir().join(format!("opensc2k_scripting_modules_{}", std::process::id()));
    std::fs::create_dir_all(folder.join("lib")).unwrap();
    std::fs::write(folder.join("lib/helper.js"), "export const tax = (funds) => funds / 10;").unwrap();
    let main = folder.join("main.js");
    std::fs::write(&main, "import { tax } from './lib/helper.js';\n__runtime.host('add', tax(50), 1);").unwrap();
    let source = std::fs::read_to_string(&main).unwrap();
    let (engine, calls) = engine_with_host();

    let path = main.to_string_lossy().replace('\\', "/");
    engine.run_script(&source, &path).unwrap();

    assert!(
        calls
            .borrow()
            .iter()
            .any(|(name, arguments)| name == "add" && arguments == &vec![JsData::Int(5), JsData::Int(1)])
    );

    let missing = engine.run_script("import { gone } from './missing.js';", &path).unwrap_err();
    assert!(missing.contains("missing.js"), "{missing}");

    // an .mjs file is a module without an import or export
    let bare = engine.run_script(
        "import './lib/helper.js';",
        &folder.join("bare.mjs").to_string_lossy().replace('\\', "/"),
    );
    assert_eq!(bare, Ok(()));
    std::fs::remove_dir_all(&folder).unwrap();
}

#[test]
fn unhandled_rejections_are_reported() {
    let (engine, calls) = engine_with_host();

    engine
        .run_script(
            "Promise.reject(new TypeError('no handler')); Promise.reject(1).catch(() => {});",
            "rejections.js",
        )
        .unwrap();

    let errors = console_lines(&calls, "error");
    assert_eq!(errors.len(), 1, "{errors:?}");
    assert!(
        errors[0].starts_with("Uncaught (in promise) TypeError: no handler"),
        "{}",
        errors[0]
    );
}

#[test]
fn values_copy_between_javascript_and_rust() {
    let (engine, _) = engine_with_host();
    engine
        .run_script(
            "globalThis.echo = (value) => ({ value, half: 1.5, big: 2 ** 40, method() {}, list: [true, null, 'text'] });",
            "echo.js",
        )
        .unwrap();

    let input = JsData::object(vec![("x", JsData::Int(3)), ("name", JsData::String("Bulldozer".to_string()))]);
    let output = engine.call("echo", std::slice::from_ref(&input)).unwrap();

    assert_eq!(output.get("value"), Some(&input));
    assert_eq!(output.get("half"), Some(&JsData::Float(1.5)));
    assert_eq!(output.get("big"), Some(&JsData::Int(1 << 40)));
    assert_eq!(output.get("method"), None);
    assert_eq!(
        output.get("list"),
        Some(&JsData::Array(vec![
            JsData::Bool(true),
            JsData::Null,
            JsData::String("text".to_string())
        ]))
    );
}

#[test]
fn script_commands_register_with_the_host_and_return_text() {
    let (engine, calls) = engine_with_host();

    engine
        .run_script(
            "__runtime.command('greet', 'Greets the mayor.', (name) => `Hello, ${name}`);",
            "commands.js",
        )
        .unwrap();

    assert!(calls.borrow().iter().any(|(name, arguments)| name == "command"
        && arguments == &vec![JsData::String("greet".to_string()), JsData::String("Greets the mayor.".to_string())]));
    assert_eq!(
        engine.call(
            "__runtime.runCommand",
            &[
                JsData::String("greet".to_string()),
                JsData::Array(vec![JsData::String("Ada".to_string())])
            ]
        ),
        Ok(JsData::String("Hello, Ada".to_string()))
    );
}

#[test]
fn a_host_function_can_call_into_the_engine_again() {
    let engine = Rc::new(Engine::new().unwrap());
    let weak: Weak<Engine> = Rc::downgrade(&engine);

    engine.set_host(Some(Rc::new(move |name: &str, _arguments: Vec<JsData>| {
        if name != "apply" {
            return Ok(JsData::Undefined);
        }

        // as a tool action does: the host dispatches an event during the call
        let engine = weak.upgrade().unwrap();
        let event = engine.call(
            "__runtime.dispatch",
            &[JsData::String("tool.applied".to_string()), JsData::Null, JsData::Bool(false)],
        )?;

        Ok(event.get("type").cloned().unwrap_or(JsData::Undefined))
    })));

    engine
        .run_script(
            "globalThis.applied = 0; __runtime.events.on('tool.applied', () => applied++);",
            "reentry.js",
        )
        .unwrap();

    assert_eq!(
        engine.eval_console("__runtime.host('apply') + ' ' + applied"),
        Ok(Some("\"tool.applied 1\"".to_string()))
    );
}

#[test]
fn memory_usage_reports_the_heap() {
    let (engine, _) = engine_with_host();

    let usage = engine.memory_usage();

    assert!(matches!(usage.get("memory_used"), Some(JsData::Int(bytes)) if *bytes > 0));
    assert!(matches!(usage.get("memory_limit"), Some(JsData::Int(bytes)) if *bytes > 0));
    assert!(!Engine::version().is_empty());
}
