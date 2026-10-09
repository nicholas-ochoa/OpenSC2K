//! The threads of the inspector server. The accept thread answers the
//! `/json` discovery requests of `chrome://inspect` and upgrades the target
//! path to a WebSocket. Each connection has a reader thread and a writer
//! thread. Requests with a Host header other than the loopback address are
//! refused, which stops DNS rebinding pages.

use std::io::{self, ErrorKind};
use std::net::{TcpListener, TcpStream};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{self, Receiver, Sender};
use std::time::Duration;

use super::websocket::{self, Incoming, Request};
use super::{Connection, Event, Outgoing, TARGET_ID};

// how often the accept thread checks the stop flag
const ACCEPT_WAIT: Duration = Duration::from_millis(50);
// a client must send its request head within this time
const HEAD_TIMEOUT: Duration = Duration::from_secs(5);
const LOOPBACK_HOSTS: [&str; 3] = ["127.0.0.1", "localhost", "[::1]"];

pub struct Settings {
    pub port: u16,
    pub title: String,
}

pub fn frontend_url(port: u16) -> String {
    format!("devtools://devtools/bundled/js_app.html?experiments=true&v8only=true&ws=127.0.0.1:{port}/{TARGET_ID}")
}

pub fn accept_loop(listener: TcpListener, settings: Settings, stop: Arc<AtomicBool>, events: Sender<Event>) {
    let mut next_id = 1u64;

    while !stop.load(Ordering::SeqCst) {
        match listener.accept() {
            Ok((stream, _)) => {
                if serve(stream, &settings, next_id, &events).is_ok() {
                    next_id += 1;
                }
            }
            Err(error) if error.kind() == ErrorKind::WouldBlock => std::thread::sleep(ACCEPT_WAIT),
            Err(_) => std::thread::sleep(ACCEPT_WAIT),
        }
    }
}

/// Answers one request. A WebSocket upgrade starts a connection.
fn serve(mut stream: TcpStream, settings: &Settings, id: u64, events: &Sender<Event>) -> io::Result<()> {
    // an accepted socket can keep the non-blocking mode of the listener
    stream.set_nonblocking(false)?;
    stream.set_read_timeout(Some(HEAD_TIMEOUT))?;
    let request = websocket::read_request(&mut stream)?;

    if !loopback_host(&request, settings.port) {
        return websocket::write_response(
            &mut stream,
            "403 Forbidden",
            "text/plain",
            "The inspector accepts only local hosts.",
        );
    }

    if request.is_upgrade() {
        if request.path.trim_start_matches('/') != TARGET_ID {
            return websocket::write_response(&mut stream, "404 Not Found", "text/plain", "Unknown target.");
        }

        let Some(key) = request.header("sec-websocket-key") else {
            return websocket::write_response(&mut stream, "400 Bad Request", "text/plain", "No WebSocket key.");
        };

        websocket::write_upgrade(&mut stream, key)?;
        stream.set_read_timeout(None)?;
        stream.set_nodelay(true)?;

        return start_connection(stream, id, events);
    }

    let path = request.path.split('?').next().unwrap_or_default().trim_end_matches('/');

    match (request.method.as_str(), path) {
        ("GET", "/json" | "/json/list") => websocket::write_response(&mut stream, "200 OK", "application/json", &target_list(settings)),
        ("GET", "/json/version") => websocket::write_response(&mut stream, "200 OK", "application/json", &version(settings)),
        _ => websocket::write_response(&mut stream, "404 Not Found", "text/plain", "Unknown path."),
    }
}

/// True when the Host header names the loopback interface and this port.
fn loopback_host(request: &Request, port: u16) -> bool {
    let Some(host) = request.header("host") else {
        return false;
    };

    LOOPBACK_HOSTS.iter().any(|name| host == *name || host == format!("{name}:{port}"))
}

fn start_connection(stream: TcpStream, id: u64, events: &Sender<Event>) -> io::Result<()> {
    let (sender, receiver) = mpsc::channel();
    let writer = stream.try_clone()?;
    let reader = stream.try_clone()?;
    std::thread::Builder::new()
        .name("script-inspector-writer".to_string())
        .spawn(move || write_loop(writer, receiver))?;

    let reader_events = events.clone();
    let pongs = sender.clone();
    std::thread::Builder::new()
        .name("script-inspector-reader".to_string())
        .spawn(move || read_loop(reader, id, reader_events, pongs))?;

    let _ = events.send(Event::Connected(Connection { id, sender, stream }));

    Ok(())
}

fn read_loop(mut stream: TcpStream, id: u64, events: Sender<Event>, pongs: Sender<Outgoing>) {
    loop {
        match websocket::read_message(&mut stream) {
            Ok(Incoming::Text(text)) => {
                if events.send(Event::Message(id, text)).is_err() {
                    break;
                }
            }
            Ok(Incoming::Ping(payload)) => {
                let _ = pongs.send(Outgoing::Pong(payload));
            }
            Ok(Incoming::Close) | Err(_) => break,
        }
    }

    let _ = pongs.send(Outgoing::Close);
    let _ = events.send(Event::Disconnected(id));
}

/// Ends after a close, or when every sender is gone.
fn write_loop(mut stream: TcpStream, messages: Receiver<Outgoing>) {
    while let Ok(message) = messages.recv() {
        let written = match message {
            Outgoing::Text(text) => websocket::write_text(&mut stream, &text),
            Outgoing::Pong(payload) => websocket::write_pong(&mut stream, &payload),
            Outgoing::Close => {
                let _ = websocket::write_close(&mut stream);
                break;
            }
        };

        if written.is_err() {
            break;
        }
    }

    let _ = stream.shutdown(std::net::Shutdown::Both);
}

fn target_list(settings: &Settings) -> String {
    let port = settings.port;
    let title = json_string(&settings.title);
    let frontend = json_string(&frontend_url(port));

    format!(
        "[{{\"description\":\"OpenSC2K script runtime\",\"devtoolsFrontendUrl\":{frontend},\"devtoolsFrontendUrlCompat\":{frontend},\
\"faviconUrl\":\"\",\"id\":\"{TARGET_ID}\",\"title\":{title},\"type\":\"node\",\"url\":\"file://\",\
\"webSocketDebuggerUrl\":\"ws://127.0.0.1:{port}/{TARGET_ID}\"}}]"
    )
}

fn version(settings: &Settings) -> String {
    format!("{{\"Browser\":{},\"Protocol-Version\":\"1.3\"}}", json_string(&settings.title))
}

/// A JSON string literal.
pub fn json_string(text: &str) -> String {
    let mut result = String::with_capacity(text.len() + 2);
    result.push('"');

    for character in text.chars() {
        match character {
            '"' => result.push_str("\\\""),
            '\\' => result.push_str("\\\\"),
            '\n' => result.push_str("\\n"),
            '\r' => result.push_str("\\r"),
            '\t' => result.push_str("\\t"),
            control if (control as u32) < 0x20 => result.push_str(&format!("\\u{:04x}", control as u32)),
            other => result.push(other),
        }
    }

    result.push('"');

    result
}
