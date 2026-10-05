use std::io::{Read, Write};
use std::net::TcpStream;
use std::time::{Duration, Instant};

use super::websocket::{self, Incoming, TEXT_OPCODE};
use super::{Activity, Inspector, Outgoing, TARGET_ID};

const WAIT: Duration = Duration::from_secs(5);

fn http_get(port: u16, path: &str, host: &str) -> String {
    let mut stream = TcpStream::connect(("127.0.0.1", port)).unwrap();
    write!(stream, "GET {path} HTTP/1.1\r\nHost: {host}\r\n\r\n").unwrap();
    let mut response = String::new();
    stream.read_to_string(&mut response).unwrap();

    response
}

/// A WebSocket client of the target, after the upgrade.
pub fn connect(port: u16) -> TcpStream {
    let mut stream = TcpStream::connect(("127.0.0.1", port)).unwrap();
    write!(
        stream,
        "GET /{TARGET_ID} HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n"
    )
    .unwrap();
    let mut head = Vec::new();
    let mut byte = [0u8; 1];

    while !head.ends_with(b"\r\n\r\n") {
        stream.read_exact(&mut byte).unwrap();
        head.push(byte[0]);
    }

    let head = String::from_utf8(head).unwrap();
    assert!(head.starts_with("HTTP/1.1 101"), "{head}");
    assert!(head.contains("Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo="), "{head}");
    stream.set_read_timeout(Some(WAIT)).unwrap();

    stream
}

pub fn send(stream: &mut TcpStream, text: &str) {
    websocket::write_frame(stream, TEXT_OPCODE, text.as_bytes(), Some([3, 1, 4, 1])).unwrap();
}

pub fn receive(stream: &mut TcpStream) -> String {
    match websocket::read_message(stream).unwrap() {
        Incoming::Text(text) => text,
        other => panic!("expected text, got {other:?}"),
    }
}

/// Polls until the inspector reports activity.
fn wait_for(inspector: &mut Inspector) -> Vec<Activity> {
    let started = Instant::now();

    loop {
        let activity = inspector.poll();

        if !activity.is_empty() || started.elapsed() > WAIT {
            return activity;
        }

        std::thread::sleep(Duration::from_millis(5));
    }
}

#[test]
fn chrome_finds_the_target_on_the_loopback_host_only() {
    let inspector = Inspector::start(0, "OpenSC2K").unwrap();
    let port = inspector.port();

    let list = http_get(port, "/json/list", &format!("127.0.0.1:{port}"));
    assert!(list.starts_with("HTTP/1.1 200"), "{list}");
    assert!(
        list.contains(&format!("\"webSocketDebuggerUrl\":\"ws://127.0.0.1:{port}/{TARGET_ID}\"")),
        "{list}"
    );
    assert!(list.contains("\"type\":\"node\""));
    assert!(http_get(port, "/json/version", "localhost").contains("\"Protocol-Version\":\"1.3\""));
    assert!(http_get(port, "/json", "evil.example:80").starts_with("HTTP/1.1 403"));
    assert!(http_get(port, "/other", "localhost").starts_with("HTTP/1.1 404"));
    assert_eq!(super::websocket_url(port), format!("ws://127.0.0.1:{port}/{TARGET_ID}"));
}

#[test]
fn messages_pass_both_ways_and_a_new_client_replaces_the_old() {
    let mut inspector = Inspector::start(0, "OpenSC2K").unwrap();
    let mut client = connect(inspector.port());

    assert_eq!(wait_for(&mut inspector), vec![Activity::Attached]);
    assert!(inspector.connected());

    send(&mut client, "{\"id\":1}");
    assert_eq!(wait_for(&mut inspector), vec![Activity::Message("{\"id\":1}".to_string())]);

    inspector
        .sender()
        .unwrap()
        .send(Outgoing::Text("{\"id\":1,\"result\":{}}".to_string()))
        .unwrap();
    assert_eq!(receive(&mut client), "{\"id\":1,\"result\":{}}");

    // a ping gets a pong from the reader thread
    websocket::write_frame(&mut client, 0x9, b"beat", Some([1, 1, 1, 1])).unwrap();
    let mut pong = [0u8; 6];
    client.read_exact(&mut pong).unwrap();
    assert_eq!(pong, [0x8a, 4, b'b', b'e', b'a', b't']);

    let mut second = connect(inspector.port());
    assert_eq!(wait_for(&mut inspector), vec![Activity::Detached, Activity::Attached]);
    send(&mut second, "second");
    assert_eq!(wait_for(&mut inspector), vec![Activity::Message("second".to_string())]);

    websocket::write_frame(&mut second, 0x8, &[], Some([0, 0, 0, 0])).unwrap();
    assert_eq!(wait_for(&mut inspector), vec![Activity::Detached]);
    assert!(!inspector.connected());
}
