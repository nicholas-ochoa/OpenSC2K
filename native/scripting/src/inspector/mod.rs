//! The DevTools inspector: an HTTP and WebSocket server on the loopback
//! interface that Chrome DevTools connects to. Threads only move message
//! text. The main thread polls the events and gives each message to
//! `inspector.js`, which speaks the Chrome DevTools Protocol.
//!
//! `chrome://inspect` finds the target through `/json/list`. One DevTools
//! window can connect at a time; a new connection replaces the old one.

mod base64;
mod server;
mod sha1;
mod websocket;

use std::io;
use std::net::{Shutdown, TcpListener, TcpStream};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{self, Receiver, Sender};
use std::thread::JoinHandle;

// the WebSocket path of the target. It stays the same, thus DevTools can reconnect
pub const TARGET_ID: &str = "opensc2k";

/// What the server threads tell the main thread.
pub enum Event {
    Connected(Connection),
    Message(u64, String),
    Disconnected(u64),
}

/// The activity that `poll` reports to the main thread.
#[derive(Debug, PartialEq)]
pub enum Activity {
    Attached,
    Message(String),
    Detached,
}

/// What the main thread or the reader sends on a connection.
pub enum Outgoing {
    Text(String),
    Pong(Vec<u8>),
    Close,
}

/// One DevTools connection. Dropping it does not close it; `close` does.
pub struct Connection {
    pub id: u64,
    pub sender: Sender<Outgoing>,
    stream: TcpStream,
}

impl Connection {
    pub fn close(&self) {
        let _ = self.sender.send(Outgoing::Close);
        let _ = self.stream.shutdown(Shutdown::Both);
    }
}

pub fn websocket_url(port: u16) -> String {
    format!("ws://127.0.0.1:{port}/{TARGET_ID}")
}

/// The DevTools page that connects to the target on this port.
pub fn frontend_url(port: u16) -> String {
    server::frontend_url(port)
}

pub struct Inspector {
    port: u16,
    stop: Arc<AtomicBool>,
    events: Receiver<Event>,
    accept_thread: Option<JoinHandle<()>>,
    connection: Option<Connection>,
}

impl Inspector {
    /// Listens on 127.0.0.1. Port 0 selects a free port.
    pub fn start(port: u16, title: &str) -> io::Result<Inspector> {
        let listener = TcpListener::bind(("127.0.0.1", port))?;
        listener.set_nonblocking(true)?;
        let port = listener.local_addr()?.port();
        let stop = Arc::new(AtomicBool::new(false));
        let (events_sender, events) = mpsc::channel();
        let settings = server::Settings {
            port,
            title: title.to_string(),
        };
        let thread_stop = stop.clone();
        let accept_thread = std::thread::Builder::new()
            .name("script-inspector".to_string())
            .spawn(move || server::accept_loop(listener, settings, thread_stop, events_sender))?;

        Ok(Inspector {
            port,
            stop,
            events,
            accept_thread: Some(accept_thread),
            connection: None,
        })
    }

    pub fn port(&self) -> u16 {
        self.port
    }

    pub fn connected(&self) -> bool {
        self.connection.is_some()
    }

    /// The activity since the last call. A new connection replaces the
    /// active one, and the events of a replaced connection are dropped.
    pub fn poll(&mut self) -> Vec<Activity> {
        let mut result = Vec::new();

        while let Ok(event) = self.events.try_recv() {
            match event {
                Event::Connected(connection) => {
                    if let Some(old) = self.connection.replace(connection) {
                        old.close();
                        result.push(Activity::Detached);
                    }

                    result.push(Activity::Attached);
                }
                Event::Message(id, text) if self.active(id) => result.push(Activity::Message(text)),
                Event::Disconnected(id) if self.active(id) => {
                    self.connection = None;
                    result.push(Activity::Detached);
                }
                _ => {}
            }
        }

        result
    }

    fn active(&self, id: u64) -> bool {
        self.connection.as_ref().is_some_and(|connection| connection.id == id)
    }

    /// The sender of the active connection.
    pub fn sender(&self) -> Option<Sender<Outgoing>> {
        self.connection.as_ref().map(|connection| connection.sender.clone())
    }
}

impl Drop for Inspector {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::SeqCst);

        if let Some(connection) = self.connection.take() {
            connection.close();
        }

        if let Some(thread) = self.accept_thread.take() {
            let _ = thread.join();
        }
    }
}

#[cfg(test)]
pub mod tests;
