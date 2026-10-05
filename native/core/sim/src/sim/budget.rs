//! Frame-granted work leases for the simulation worker, as SimulationSliceBudget.
//!
//! A worker parks at checkpoints until the next rendered frame grants time.
//! Only the worker calls `checkpoint` and `finish`. The main thread calls
//! `grant` and `cancel`. The bridge installs the budget of a call as the
//! current budget of the worker thread, so simulation loops call `checkpoint()`.

use std::cell::RefCell;
use std::sync::atomic::{AtomicBool, AtomicI64, Ordering};
use std::sync::{Arc, Condvar, Mutex, OnceLock};
use std::time::Instant;

/// Microseconds since the library started. Only differences are meaningful.
pub fn now_usec() -> i64 {
    static START: OnceLock<Instant> = OnceLock::new();

    START.get_or_init(Instant::now).elapsed().as_micros() as i64
}

#[derive(Default)]
struct State {
    parked_usec: i64,
    created_usec: i64,
    elapsed_usec: i64,
    waiting: bool,
    cancelled: bool,
    grant_deadline: i64,
    started: i64,
    slices: i64,
    max_slice_usec: i64,
    resume_permits: i64,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Metrics {
    pub slices: i64,
    pub max_slice_usec: i64,
    pub waiting: bool,
    pub cancelled: bool,
    pub elapsed_usec: i64,
    pub parked_usec: i64,
}

pub struct SliceBudget {
    state: Mutex<State>,
    resume: Condvar,
    // Read without the lock on the fast path of each checkpoint.
    deadline: AtomicI64,
    stopped: AtomicBool,
    parked: AtomicI64,
}

impl Default for SliceBudget {
    fn default() -> Self {
        Self::new()
    }
}

impl SliceBudget {
    pub fn new() -> Self {
        Self {
            state: Mutex::new(State {
                created_usec: now_usec(),
                ..Default::default()
            }),
            resume: Condvar::new(),
            deadline: AtomicI64::new(0),
            stopped: AtomicBool::new(false),
            parked: AtomicI64::new(0),
        }
    }

    fn record_slice(state: &mut State) {
        if state.started > 0 {
            state.max_slice_usec = state.max_slice_usec.max(now_usec() - state.started);
            state.started = 0;
        }
    }

    fn start_slice(&self, state: &mut State) {
        state.started = now_usec();
        self.deadline.store(state.grant_deadline, Ordering::Release);
        state.slices += 1;
    }

    pub fn checkpoint(&self) {
        if self.stopped.load(Ordering::Acquire) || now_usec() < self.deadline.load(Ordering::Acquire) {
            return;
        }

        let mut state = self.state.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
        Self::record_slice(&mut state);

        if state.cancelled {
            self.stopped.store(true, Ordering::Release);
            return;
        }

        // A new frame replaces the current lease, even while the worker runs.
        // Unused time expires instead of accumulating.
        if now_usec() < state.grant_deadline {
            self.start_slice(&mut state);
            return;
        }

        state.waiting = true;
        let wait_started = now_usec();

        while state.resume_permits == 0 {
            state = self.resume.wait(state).unwrap_or_else(|poisoned| poisoned.into_inner());
        }

        state.resume_permits -= 1;
        state.parked_usec += now_usec() - wait_started;
        self.parked.store(state.parked_usec, Ordering::Release);

        if state.cancelled {
            self.stopped.store(true, Ordering::Release);
        } else {
            self.start_slice(&mut state);
        }
    }

    pub fn grant(&self, usec: i64) {
        let mut state = self.state.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
        let wake = state.waiting && !state.cancelled;

        if !state.cancelled {
            state.grant_deadline = now_usec() + usec.max(100);
        }

        if wake {
            state.waiting = false;
            state.resume_permits += 1;
            self.resume.notify_one();
        }
    }

    pub fn cancel(&self) {
        let mut state = self.state.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
        let wake = !state.cancelled;
        state.cancelled = true;

        if wake {
            state.resume_permits += 1;
            self.resume.notify_one();
        }
    }

    pub fn finish(&self) {
        let mut state = self.state.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
        Self::record_slice(&mut state);
        state.elapsed_usec = now_usec() - state.created_usec;
    }

    pub fn metrics(&self) -> Metrics {
        let state = self.state.lock().unwrap_or_else(|poisoned| poisoned.into_inner());

        Metrics {
            slices: state.slices,
            max_slice_usec: state.max_slice_usec,
            waiting: state.waiting,
            cancelled: state.cancelled,
            elapsed_usec: state.elapsed_usec,
            parked_usec: state.parked_usec,
        }
    }

    pub fn parked_usec(&self) -> i64 {
        self.parked.load(Ordering::Acquire)
    }
}

thread_local! {
    static CURRENT: RefCell<Option<Arc<SliceBudget>>> = const { RefCell::new(None) };
}

/// Run `work` with `budget` as the current budget of this thread.
pub fn with_budget<T>(budget: Option<Arc<SliceBudget>>, work: impl FnOnce() -> T) -> T {
    let previous = CURRENT.with(|current| current.replace(budget));
    let result = work();
    CURRENT.with(|current| current.replace(previous));
    result
}

/// Park at a frame boundary when the current lease has expired.
#[inline]
pub fn checkpoint() {
    CURRENT.with(|current| {
        if let Some(budget) = current.borrow().as_ref() {
            budget.checkpoint();
        }
    });
}

/// Frame waits of the current budget. Timings exclude them.
pub fn parked_usec() -> i64 {
    CURRENT.with(|current| current.borrow().as_ref().map_or(0, |budget| budget.parked_usec()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_grant_admits_work_and_a_cancel_releases_a_parked_worker() {
        let budget = Arc::new(SliceBudget::new());
        budget.grant(20_000);
        budget.checkpoint();
        assert_eq!(budget.metrics().slices, 1);

        let worker = {
            let budget = budget.clone();
            std::thread::spawn(move || {
                std::thread::sleep(std::time::Duration::from_millis(30));
                budget.checkpoint();
            })
        };

        while !budget.metrics().waiting {
            std::thread::yield_now();
        }

        budget.cancel();
        worker.join().unwrap();
        assert!(budget.metrics().cancelled);
    }
}
