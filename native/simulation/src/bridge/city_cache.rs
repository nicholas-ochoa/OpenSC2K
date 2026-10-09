//! Native city copies by handle. A cache keeps the chunks of one city between
//! simulation and tool calls, so a call copies only the chunks that changed.
//!
//! Each stored chunk has a revision. Every revision is unique in the process:
//! `next_revision` numbers the GDScript chunk writes, and a native call numbers
//! the chunks that it writes. Equal revisions therefore mean equal bytes.
//!
//! The simulation worker and the main thread can share a cache. A call that
//! finds the cache busy builds a private city instead of waiting, because the
//! worker can wait for the main thread at a frame boundary.

use std::collections::HashMap;
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::{Arc, Mutex, MutexGuard, OnceLock, TryLockError};

use sc2k_sim::sim::city::{CHUNK_IDS, City};

/// The chunks of the last call and the revision of each chunk.
#[derive(Default)]
pub struct Cached {
    pub city: Option<City>,
    pub revisions: HashMap<&'static str, i64>,
}

type Shared = Arc<Mutex<Cached>>;

fn registry() -> &'static Mutex<HashMap<i64, Shared>> {
    static REGISTRY: OnceLock<Mutex<HashMap<i64, Shared>>> = OnceLock::new();

    REGISTRY.get_or_init(|| Mutex::new(HashMap::new()))
}

fn lock_registry() -> MutexGuard<'static, HashMap<i64, Shared>> {
    registry().lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}

/// A new revision. Revision 0 means unknown, so the first one is 1.
pub fn next_revision() -> i64 {
    static NEXT: AtomicI64 = AtomicI64::new(1);

    NEXT.fetch_add(1, Ordering::Relaxed)
}

pub fn create() -> i64 {
    static NEXT: AtomicI64 = AtomicI64::new(1);
    let handle = NEXT.fetch_add(1, Ordering::Relaxed);
    lock_registry().insert(handle, Arc::new(Mutex::new(Cached::default())));

    handle
}

pub fn free(handle: i64) {
    lock_registry().remove(&handle);
}

pub fn get(handle: i64) -> Option<Shared> {
    lock_registry().get(&handle).cloned()
}

/// The cache when no other call uses it.
pub fn try_lock(shared: &Shared) -> Option<MutexGuard<'_, Cached>> {
    match shared.try_lock() {
        Ok(guard) => Some(guard),
        Err(TryLockError::Poisoned(poisoned)) => Some(poisoned.into_inner()),
        Err(TryLockError::WouldBlock) => None,
    }
}

/// One chunk of a call: its bytes, or `None` when the document has no such
/// chunk, and its revision. Revision 0 is unknown.
pub struct Incoming<'a> {
    pub id: &'static str,
    pub bytes: Option<&'a [u8]>,
    pub revision: i64,
}

/// The city of a call, from the cached city of the last call. Only chunks whose
/// revision differs from the cached revision are copied. A chunk with revision
/// 0 has no known revision and is always copied.
pub fn sync<'a>(cache: &mut Cached, map_size: i64, large_version: i64, chunks: impl Iterator<Item = Incoming<'a>>) -> City {
    let mut city = match cache.city.take() {
        Some(city) if city.map_size == map_size && city.large_version == large_version => city,
        _ => {
            cache.revisions.clear();
            City::new(map_size, large_version)
        }
    };

    for chunk in chunks {
        let known = cache.revisions.get(chunk.id).copied();
        let slot = city.chunk_slot_mut(chunk.id).expect("every chunk id has a slot");
        slot.written = false;

        let Some(bytes) = chunk.bytes else {
            slot.present = false;
            slot.data.clear();
            cache.revisions.remove(chunk.id);

            continue;
        };

        if chunk.revision == 0 || !slot.present || known != Some(chunk.revision) {
            slot.present = true;
            slot.data = bytes.to_vec();

            if chunk.revision == 0 {
                cache.revisions.remove(chunk.id);
            } else {
                cache.revisions.insert(chunk.id, chunk.revision);
            }
        }
    }

    city
}

/// The revision of each chunk id after a call. Written chunks get new revisions.
pub fn store_written(cached: &mut Cached, city: &City) -> Vec<(&'static str, i64)> {
    let mut written = Vec::new();

    for id in CHUNK_IDS {
        if city.chunk(id).is_some_and(|chunk| chunk.written) {
            let revision = next_revision();
            cached.revisions.insert(id, revision);
            written.push((id, revision));
        }
    }

    written
}

#[cfg(test)]
mod tests {
    use super::*;

    fn incoming<'a>(id: &'static str, bytes: &'a [u8], revision: i64) -> Incoming<'a> {
        Incoming {
            id,
            bytes: Some(bytes),
            revision,
        }
    }

    #[test]
    fn only_changed_revisions_are_copied() {
        let mut cache = Cached::default();
        let city = sync(
            &mut cache,
            16,
            2,
            [incoming("XTER", &[1, 2], 5), incoming("XBLD", &[3], 0)].into_iter(),
        );
        cache.city = Some(city);

        // the cached bytes stay while the revision is the same, even if the
        // sender's bytes differ; a new revision copies them
        let city = sync(
            &mut cache,
            16,
            2,
            [incoming("XTER", &[9, 9], 5), incoming("XBLD", &[4], 0)].into_iter(),
        );
        assert_eq!(city.chunk("XTER").unwrap().data, [1, 2]);
        assert_eq!(city.chunk("XBLD").unwrap().data, [4]);
        cache.city = Some(city);

        let city = sync(&mut cache, 16, 2, [incoming("XTER", &[7, 7], 6)].into_iter());
        assert_eq!(city.chunk("XTER").unwrap().data, [7, 7]);
    }

    #[test]
    fn a_missing_chunk_or_a_new_layout_drops_the_cached_bytes() {
        let mut cache = Cached::default();
        cache.city = Some(sync(&mut cache, 16, 2, [incoming("XTER", &[1], 5)].into_iter()));

        let none = Incoming {
            id: "XTER",
            bytes: None,
            revision: 0,
        };
        let city = sync(&mut cache, 16, 2, [none].into_iter());
        assert!(city.chunk("XTER").is_none());
        cache.city = Some(city);

        cache.city = Some(sync(&mut cache, 16, 2, [incoming("XTER", &[1], 5)].into_iter()));
        let city = sync(&mut cache, 32, 2, [incoming("XTER", &[2], 5)].into_iter());
        assert_eq!(city.chunk("XTER").unwrap().data, [2]);
    }

    #[test]
    fn revisions_are_unique() {
        let first = next_revision();
        let second = next_revision();

        assert!(first > 0 && second > first);
    }
}
