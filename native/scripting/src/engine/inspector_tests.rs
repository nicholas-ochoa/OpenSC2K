//! The DevTools protocol of inspector.js, through a WebSocket client.

use std::net::TcpStream;
use std::sync::mpsc::{self, Receiver};
use std::time::{Duration, Instant};

use super::Engine;
use super::tests::engine_with_host;
use crate::inspector::tests::{connect, receive, send};

const WAIT: Duration = Duration::from_secs(5);

/// A DevTools client. A thread reads the messages of the server.
struct Client {
    stream: TcpStream,
    messages: Receiver<String>,
    next_id: u64,
}

impl Client {
    fn attach(engine: &Engine) -> Client {
        let port = engine.start_inspector(0, "OpenSC2K").unwrap();
        let stream = connect(port);
        let mut reader = stream.try_clone().unwrap();
        reader.set_read_timeout(None).unwrap();
        let (sender, messages) = mpsc::channel();
        std::thread::spawn(move || {
            while let Ok(text) = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| receive(&mut reader))) {
                if sender.send(text).is_err() {
                    break;
                }
            }
        });

        let started = Instant::now();

        while !engine.inspector_connected() && started.elapsed() < WAIT {
            engine.poll_inspector();
        }

        Client {
            stream,
            messages,
            next_id: 1,
        }
    }

    /// Sends a request and polls the engine until its answer. Returns the
    /// answer and the events before it.
    fn request(&mut self, engine: &Engine, method: &str, params: &str) -> (String, Vec<String>) {
        let id = self.next_id;
        self.next_id += 1;
        send(
            &mut self.stream,
            &format!("{{\"id\":{id},\"method\":\"{method}\",\"params\":{params}}}"),
        );
        let marker = format!("{{\"id\":{id},");
        let mut events = Vec::new();
        let started = Instant::now();

        while started.elapsed() < WAIT {
            engine.poll_inspector();

            while let Ok(message) = self.messages.recv_timeout(Duration::from_millis(5)) {
                if message.starts_with(&marker) {
                    return (message, events);
                }

                events.push(message);
            }
        }

        panic!("no answer to {method}; events: {events:?}");
    }

    /// The events that arrive while the engine polls for a moment.
    fn events(&mut self, engine: &Engine) -> Vec<String> {
        let mut events = Vec::new();
        let started = Instant::now();

        while started.elapsed() < Duration::from_millis(100) {
            engine.poll_inspector();

            while let Ok(message) = self.messages.recv_timeout(Duration::from_millis(5)) {
                events.push(message);
            }
        }

        events
    }
}

/// The value of `"key":` in a JSON text, up to the next comma or brace.
fn field<'a>(json: &'a str, key: &str) -> &'a str {
    let marker = format!("\"{key}\":");
    let start = json.find(&marker).unwrap_or_else(|| panic!("no {key} in {json}")) + marker.len();
    let rest = &json[start..];
    let end = match rest.strip_prefix('"') {
        Some(text) => text.find('"').unwrap() + 2,
        None => rest.find([',', '}']).unwrap(),
    };

    &rest[..end]
}

#[test]
fn the_console_evaluates_and_inspects_values() {
    let (engine, _) = engine_with_host();
    let mut client = Client::attach(&engine);

    let (_, events) = client.request(&engine, "Runtime.enable", "{}");
    assert!(
        events.iter().any(|event| event.contains("Runtime.executionContextCreated")),
        "{events:?}"
    );

    engine
        .run_script("globalThis.mayor = { name: 'Ada', funds: 5 };", "/tmp/mayor.js")
        .unwrap();
    let (answer, _) = client.request(&engine, "Runtime.evaluate", "{\"expression\":\"mayor.funds * 2\"}");
    assert!(
        answer.contains("\"result\":{\"result\":{\"type\":\"number\",\"value\":10"),
        "{answer}"
    );

    let (answer, _) = client.request(&engine, "Runtime.evaluate", "{\"expression\":\"await Promise.resolve('later')\"}");
    assert!(answer.contains("\"value\":\"later\""), "{answer}");

    let (answer, _) = client.request(&engine, "Runtime.evaluate", "{\"expression\":\"mayor\",\"generatePreview\":true}");
    assert!(
        answer.contains("\"preview\"") && answer.contains("{\"name\":\"funds\",\"type\":\"number\",\"value\":\"5\"}"),
        "{answer}"
    );
    let object_id = field(&answer, "objectId").to_string();

    let (answer, _) = client.request(
        &engine,
        "Runtime.getProperties",
        &format!("{{\"objectId\":{object_id},\"ownProperties\":true}}"),
    );
    assert!(answer.contains("\"name\":\"name\"") && answer.contains("[[Prototype]]"), "{answer}");

    let call = format!(
        "{{\"objectId\":{object_id},\"functionDeclaration\":\"function () {{ return Object.keys(this) }}\",\"returnByValue\":true}}"
    );
    let (answer, _) = client.request(&engine, "Runtime.callFunctionOn", &call);
    assert!(answer.contains("\"value\":[\"name\",\"funds\"]"), "{answer}");

    let (answer, _) = client.request(&engine, "Runtime.evaluate", "{\"expression\":\"missing.value\"}");
    assert!(
        answer.contains("\"exceptionDetails\"") && answer.contains("ReferenceError"),
        "{answer}"
    );
}

#[test]
fn eager_evaluation_cannot_change_the_game() {
    let (engine, _) = engine_with_host();
    let mut client = Client::attach(&engine);
    client.request(&engine, "Runtime.enable", "{}");
    engine.run_script("globalThis.city = { funds: 5 };", "/tmp/city.js").unwrap();

    let (answer, _) = client.request(
        &engine,
        "Runtime.evaluate",
        "{\"expression\":\"city.funds = 0\",\"throwOnSideEffect\":true}",
    );
    assert!(answer.contains("Possible side-effect"), "{answer}");
    let (answer, _) = client.request(
        &engine,
        "Runtime.evaluate",
        "{\"expression\":\"city.funds\",\"throwOnSideEffect\":true}",
    );
    assert!(answer.contains("\"value\":5"), "eager evaluation reads properties: {answer}");
}

#[test]
fn console_calls_and_uncaught_errors_reach_devtools() {
    let (engine, _) = engine_with_host();
    let mut client = Client::attach(&engine);
    client.request(&engine, "Runtime.enable", "{}");

    engine
        .run_script("console.warn('low funds', { funds: 1 });", "/tmp/warn.js")
        .unwrap();
    let events = client.events(&engine);
    let warning = events
        .iter()
        .find(|event| event.contains("Runtime.consoleAPICalled"))
        .expect("console event");
    assert!(
        warning.contains("\"type\":\"warning\"") && warning.contains("\"value\":\"low funds\""),
        "{warning}"
    );
    assert!(warning.contains("\"url\":\"file:///tmp/warn.js\",\"lineNumber\":0"), "{warning}");

    engine
        .run_script(
            "__runtime.events.on('sim.day', () => { throw new TypeError('bad mod') });",
            "/tmp/bad.js",
        )
        .unwrap();
    engine
        .call("__runtime.dispatch", &[crate::value::JsData::String("sim.day".to_string())])
        .unwrap();
    let events = client.events(&engine);
    let thrown = events
        .iter()
        .find(|event| event.contains("Runtime.exceptionThrown"))
        .expect("exception event");
    assert!(
        thrown.contains("TypeError: bad mod") && thrown.contains("file:///tmp/bad.js"),
        "{thrown}"
    );

    engine.inspector_game_log("error", "The simulation stopped.");
    let events = client.events(&engine);
    assert!(
        events
            .iter()
            .any(|event| event.contains("\"type\":\"error\"") && event.contains("The simulation stopped.")),
        "{events:?}"
    );
}

#[test]
fn the_sources_panel_lists_scripts_and_modules() {
    let folder = std::env::temp_dir().join(format!("opensc2k_inspector_sources_{}", std::process::id()));
    std::fs::create_dir_all(&folder).unwrap();
    std::fs::write(folder.join("helper.js"), "export const value = 42;").unwrap();
    let main = folder.join("main.js").to_string_lossy().replace('\\', "/");
    let (engine, _) = engine_with_host();
    engine
        .run_script("import { value } from './helper.js'; globalThis.loaded = value;", &main)
        .unwrap();
    let mut client = Client::attach(&engine);

    let (answer, events) = client.request(&engine, "Debugger.enable", "{}");
    assert!(answer.contains("debuggerId"), "{answer}");
    let parsed: Vec<&String> = events.iter().filter(|event| event.contains("Debugger.scriptParsed")).collect();
    assert_eq!(parsed.len(), 2, "{events:?}");
    assert!(
        parsed
            .iter()
            .any(|event| event.contains("helper.js") && event.contains("\"isModule\":true"))
    );

    let script_id = field(parsed[0], "scriptId").to_string();
    let (answer, _) = client.request(&engine, "Debugger.getScriptSource", &format!("{{\"scriptId\":{script_id}}}"));
    assert!(answer.contains("globalThis.loaded = value"), "{answer}");

    // a script that runs later is announced
    engine.run_script("globalThis.later = 1;", "/tmp/later.js").unwrap();
    assert!(
        client
            .events(&engine)
            .iter()
            .any(|event| event.contains("Debugger.scriptParsed") && event.contains("later.js"))
    );

    let (answer, _) = client.request(
        &engine,
        "Debugger.setBreakpointByUrl",
        "{\"lineNumber\":1,\"url\":\"file:///tmp/later.js\"}",
    );
    assert!(answer.contains("\"error\"") && answer.contains("full debugger"), "{answer}");
    let (answer, _) = client.request(&engine, "No.suchMethod", "{}");
    assert!(answer.contains("-32601"), "{answer}");
    std::fs::remove_dir_all(&folder).unwrap();
}

#[test]
fn a_runaway_evaluation_answers_with_the_time_limit_error() {
    let (engine, _) = engine_with_host();
    engine.set_time_limit(Duration::from_millis(50));
    let mut client = Client::attach(&engine);

    let (answer, _) = client.request(&engine, "Runtime.evaluate", "{\"expression\":\"for (;;) {}\"}");
    assert!(answer.contains("\"error\"") && answer.contains("interrupted"), "{answer}");

    let (answer, _) = client.request(&engine, "Runtime.evaluate", "{\"expression\":\"6 * 7\"}");
    assert!(answer.contains("\"value\":42"), "{answer}");
}

#[test]
fn stopping_the_inspector_detaches_devtools() {
    let (engine, _) = engine_with_host();
    let _client = Client::attach(&engine);
    assert!(engine.inspector_connected());

    engine.stop_inspector();
    assert!(!engine.inspector_connected() && engine.inspector_port().is_none());
}
