//! The simulation thread, as FrameSimulationRunner: it owns the session, runs
//! the frame time that the front end posts, and runs the calls that the front
//! end makes. After each step it publishes what `publish` makes of the
//! session, so the front end never waits for a day to finish.

use crate::results::TickResult;
use crate::session::Session;
use std::sync::mpsc::{self, Receiver, Sender};
use std::thread::JoinHandle;

type Call = Box<dyn FnOnce(&mut Session) + Send>;

enum Request {
    Advance { delta_msec: f64, now_msec: i64, suspended: bool },
    Call(Call),
    Stop,
}

/// What one step of the thread produced.
pub struct Update<P> {
    /// The result of the posted frame time, or `None` after a call.
    pub tick: Option<TickResult>,
    pub published: P,
}

pub struct Runner<P> {
    requests: Sender<Request>,
    updates: Receiver<Update<P>>,
    handle: Option<JoinHandle<Session>>,
}

impl<P: Send + 'static> Runner<P> {
    /// Start the thread. `publish` runs on it after each step.
    pub fn spawn(mut session: Session, mut publish: impl FnMut(&Session, Option<&TickResult>) -> P + Send + 'static) -> Self {
        let (requests, inbox) = mpsc::channel::<Request>();
        let (outbox, updates) = mpsc::channel();
        let handle = std::thread::Builder::new()
            .name("simulation".into())
            .spawn(move || {
                let mut pending: Option<Request> = None;

                loop {
                    let request = match pending.take() {
                        Some(request) => request,
                        None => match inbox.recv() {
                            Ok(request) => request,
                            Err(_) => break,
                        },
                    };

                    match request {
                        Request::Stop => break,
                        Request::Call(call) => {
                            call(&mut session);

                            if outbox
                                .send(Update {
                                    tick: None,
                                    published: publish(&session, None),
                                })
                                .is_err()
                            {
                                break;
                            }
                        }
                        Request::Advance {
                            mut delta_msec,
                            mut now_msec,
                            suspended,
                        } => {
                            // frames that arrived during a long step run as one step
                            while let Ok(next) = inbox.try_recv() {
                                match next {
                                    Request::Advance {
                                        delta_msec: more,
                                        now_msec: now,
                                        ..
                                    } => {
                                        delta_msec += more;
                                        now_msec = now;
                                    }
                                    other => {
                                        pending = Some(other);
                                        break;
                                    }
                                }
                            }

                            let tick = session.advance(delta_msec, now_msec, suspended);
                            let published = publish(&session, Some(&tick));

                            if outbox
                                .send(Update {
                                    tick: Some(tick),
                                    published,
                                })
                                .is_err()
                            {
                                break;
                            }
                        }
                    }
                }

                session
            })
            .expect("a simulation thread");

        Self {
            requests,
            updates,
            handle: Some(handle),
        }
    }

    /// Post frame time. The thread joins frames that arrive while it works.
    pub fn advance(&self, delta_msec: f64, now_msec: i64, suspended: bool) {
        let _ = self.requests.send(Request::Advance {
            delta_msec,
            now_msec,
            suspended,
        });
    }

    /// Run `call` on the session and wait for its value. Updates that the
    /// thread published before the call stay in the queue.
    pub fn call<T: Send + 'static>(&self, call: impl FnOnce(&mut Session) -> T + Send + 'static) -> T {
        let (reply, answer) = mpsc::channel();
        let request = Request::Call(Box::new(move |session: &mut Session| {
            let _ = reply.send(call(session));
        }));

        self.requests.send(request).expect("the simulation thread runs");

        answer.recv().expect("the simulation thread answers")
    }

    /// The updates that the thread published since the last poll.
    pub fn poll(&self) -> Vec<Update<P>> {
        self.updates.try_iter().collect()
    }

    /// Stop the thread and return the session.
    pub fn stop(mut self) -> Session {
        let _ = self.requests.send(Request::Stop);

        self.handle
            .take()
            .expect("a running thread")
            .join()
            .expect("the simulation thread ends")
    }
}

impl<P> Drop for Runner<P> {
    fn drop(&mut self) {
        if let Some(handle) = self.handle.take() {
            let _ = self.requests.send(Request::Stop);
            let _ = handle.join();
        }
    }
}
