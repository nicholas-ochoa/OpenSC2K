use std::fs;
use std::path::PathBuf;
use std::sync::atomic::{AtomicUsize, Ordering};

use super::Sandbox;
use super::files::EntryKind;

static NEXT_FOLDER: AtomicUsize = AtomicUsize::new(0);

/// A new empty folder in the temporary folder, with a "mod" folder in it.
/// The "mod" folder is the sandbox; the parent holds files outside it.
struct Folder {
    parent: PathBuf,
}

impl Folder {
    fn new() -> Folder {
        let index = NEXT_FOLDER.fetch_add(1, Ordering::SeqCst);
        let parent = std::env::temp_dir().join(format!("opensc2k-sandbox-{}-{index}", std::process::id()));
        let _ = fs::remove_dir_all(&parent);
        fs::create_dir_all(parent.join("mod")).unwrap();
        fs::write(parent.join("secret.txt"), "outside").unwrap();

        Folder { parent }
    }

    fn sandbox(&self) -> Sandbox {
        Sandbox::new(&self.parent.join("mod")).unwrap()
    }
}

impl Drop for Folder {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.parent);
    }
}

#[test]
fn reads_and_writes_files_in_the_folder() {
    let folder = Folder::new();
    let sandbox = folder.sandbox();

    sandbox.write("data/notes.txt", b"first", false).unwrap();
    sandbox.write("data/notes.txt", b" second", true).unwrap();
    assert_eq!(sandbox.read("data/notes.txt").unwrap(), b"first second");
    assert_eq!(sandbox.read("./data/../data/notes.txt").unwrap(), b"first second");
    assert_eq!(
        sandbox.read("data\\notes.txt").unwrap(),
        b"first second",
        "a backslash separates names too"
    );
    assert!(sandbox.exists("data").unwrap());
    assert!(!sandbox.exists("missing.txt").unwrap());

    sandbox.write("data/notes.txt", b"new", false).unwrap();
    assert_eq!(sandbox.read("data/notes.txt").unwrap(), b"new", "a write replaces the file");
}

#[test]
fn lists_stats_moves_and_removes() {
    let folder = Folder::new();
    let sandbox = folder.sandbox();
    sandbox.make_folder("a/b").unwrap();
    sandbox.write("a/z.txt", b"12345", false).unwrap();

    let entries = sandbox.list("a").unwrap();
    let names: Vec<_> = entries.iter().map(|entry| (entry.name.as_str(), entry.kind)).collect();
    assert_eq!(names, [("b", EntryKind::Directory), ("z.txt", EntryKind::File)]);
    assert_eq!(entries[1].size, 5);
    assert!(entries[1].modified > 0);

    let root = sandbox.list("").unwrap();
    assert_eq!(root.len(), 1, "an empty path is the mod folder");
    assert_eq!(sandbox.stat("a/z.txt").unwrap().unwrap().kind, EntryKind::File);
    assert!(sandbox.stat("a/none.txt").unwrap().is_none());

    sandbox.rename("a/z.txt", "c/y.txt").unwrap();
    assert!(!sandbox.exists("a/z.txt").unwrap() && sandbox.exists("c/y.txt").unwrap());

    assert!(sandbox.remove("a", false).is_err(), "a folder with files needs recursive");
    assert!(sandbox.remove("a", true).unwrap());
    assert!(!sandbox.remove("a", true).unwrap(), "nothing was there");
    assert!(
        sandbox.remove("", true).is_err() && sandbox.remove(".", true).is_err(),
        "the mod folder stays"
    );
    assert!(sandbox.write("c", b"x", false).is_err(), "a folder is not a file");
}

#[test]
fn refuses_paths_outside_the_folder() {
    let folder = Folder::new();
    let sandbox = folder.sandbox();
    let secret = folder.parent.join("secret.txt");

    for path in [
        "../secret.txt",
        "a/../../secret.txt",
        "..",
        "..\\secret.txt",
        "/etc/passwd",
        "\\secret.txt",
    ] {
        assert!(sandbox.read(path).is_err(), "{path} is outside");
    }

    assert!(sandbox.read(&secret.to_string_lossy()).is_err(), "an absolute path is refused");
    assert!(sandbox.write("../escape.txt", b"x", false).is_err());
    assert!(sandbox.make_folder("../escape").is_err());
    assert!(sandbox.rename("../secret.txt", "taken.txt").is_err());
    assert!(sandbox.remove("../secret.txt", false).is_err());
    assert!(sandbox.list("..").is_err());
    assert!(sandbox.exists("../secret.txt").is_err());
    assert!(!folder.parent.join("escape.txt").exists() && !folder.parent.join("escape").exists());
    assert_eq!(fs::read(&secret).unwrap(), b"outside");
}

#[test]
fn refuses_names_that_some_systems_change() {
    let folder = Folder::new();
    let sandbox = folder.sandbox();

    for path in [
        "C:/secret.txt",
        "c:secret.txt",
        "file.txt:stream",
        "con",
        "NUL.txt",
        "lpt1",
        "trailing.",
        ".. ",
        "a?b",
        "nul\0",
    ] {
        assert!(sandbox.write(path, b"x", false).is_err(), "{path:?} is refused");
    }

    assert!(
        sandbox.write("console.txt", b"x", false).is_ok(),
        "a device name is only the whole stem"
    );
    assert!(sandbox.write(".hidden", b"x", false).is_ok());
}

#[cfg(unix)]
#[test]
fn refuses_links_to_places_outside_the_folder() {
    use std::os::unix::fs::symlink;

    let folder = Folder::new();
    let sandbox = folder.sandbox();
    let mod_folder = folder.parent.join("mod");
    symlink(folder.parent.join("secret.txt"), mod_folder.join("link.txt")).unwrap();
    symlink(&folder.parent, mod_folder.join("up")).unwrap();
    sandbox.write("inside.txt", b"inside", false).unwrap();
    symlink(mod_folder.join("inside.txt"), mod_folder.join("inner-link.txt")).unwrap();

    assert!(sandbox.read("link.txt").is_err());
    assert!(sandbox.read("up/secret.txt").is_err());
    assert!(sandbox.write("up/new.txt", b"x", false).is_err());
    assert!(sandbox.write("up/new/deeper.txt", b"x", false).is_err());
    assert!(sandbox.remove("up", true).is_err());
    assert!(sandbox.list("up").is_err());
    assert!(!folder.parent.join("new.txt").exists() && !folder.parent.join("new").exists());
    assert_eq!(sandbox.read("inner-link.txt").unwrap(), b"inside", "a link inside the folder works");
}

#[test]
fn checks_module_paths() {
    let folder = Folder::new();
    let sandbox = folder.sandbox();
    sandbox.write("lib/util.mjs", b"export const a = 1;", false).unwrap();
    let inside = sandbox.root().join("lib/../lib/util.mjs");

    assert!(sandbox.module_path(&inside.to_string_lossy()).is_ok());
    assert!(sandbox.module_path(&folder.parent.join("secret.txt").to_string_lossy()).is_err());
    assert!(
        sandbox
            .module_path(&sandbox.root().join("../secret.txt").to_string_lossy())
            .is_err()
    );
    assert!(sandbox.module_path("util.mjs").is_err(), "a bare name is refused");
    assert!(sandbox.module_path(&sandbox.root().join("none.mjs").to_string_lossy()).is_err());
}
