//! Native build and validation tasks. Run them from `native/`:
//!
//! - `cargo xtask check-cores`: each crate in `core/` builds without Godot.
//! - `cargo xtask lint`: rustfmt and Clippy over the workspace.
//! - `cargo xtask test`: `check-cores`, then the unit tests of the workspace.
//!
//! The crates in `core/` hold the game without engine types. The `opensc2k_*`
//! crates convert their values for Godot. A core crate must not depend on the
//! `godot` crate, directly or through another crate.

use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode};

// Crates that only an engine bridge may use.
const ENGINE_CRATES: [&str; 2] = ["godot", "godot-core"];

fn main() -> ExitCode {
    let task = std::env::args().nth(1).unwrap_or_default();

    let result = match task.as_str() {
        "check-cores" => check_cores(),
        "lint" => lint(),
        "test" => check_cores().and_then(|()| test()),
        _ => Err(format!("unknown task `{task}`. Tasks: check-cores, lint, test")),
    };

    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("xtask: {error}");

            ExitCode::FAILURE
        }
    }
}

fn workspace() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("xtask is in the workspace")
        .to_path_buf()
}

/// The package names of the crates in `core/`.
fn core_crates() -> Result<Vec<String>, String> {
    let folder = workspace().join("core");
    let entries = fs::read_dir(&folder).map_err(|error| format!("cannot read {}: {error}", folder.display()))?;
    let mut names = Vec::new();

    for entry in entries.flatten() {
        let manifest = entry.path().join("Cargo.toml");

        let Ok(text) = fs::read_to_string(&manifest) else {
            continue;
        };

        let name = text
            .lines()
            .find_map(|line| line.trim().strip_prefix("name = \""))
            .and_then(|rest| rest.strip_suffix('"'))
            .ok_or_else(|| format!("{} has no package name", manifest.display()))?;
        names.push(name.to_string());
    }

    names.sort();

    Ok(names)
}

fn check_cores() -> Result<(), String> {
    let crates = core_crates()?;

    if crates.is_empty() {
        return Err("no core crates found".into());
    }

    for name in &crates {
        let output = Command::new(env!("CARGO"))
            .current_dir(workspace())
            .args([
                "tree",
                "--package",
                name,
                "--edges",
                "normal,build",
                "--prefix",
                "none",
                "--format",
                "{p}",
            ])
            .output()
            .map_err(|error| format!("cannot run cargo tree: {error}"))?;

        if !output.status.success() {
            return Err(format!("cargo tree failed for {name}: {}", String::from_utf8_lossy(&output.stderr)));
        }

        let tree = String::from_utf8_lossy(&output.stdout);

        let engine = tree
            .lines()
            .filter_map(|line| line.split_whitespace().next())
            .find(|package| ENGINE_CRATES.contains(package));

        if let Some(package) = engine {
            return Err(format!(
                "core crate {name} depends on {package}. Move the engine code to a bridge crate"
            ));
        }
    }

    println!("xtask: {} core crates build without Godot: {}", crates.len(), crates.join(", "));

    Ok(())
}

fn cargo(arguments: &[&str]) -> Result<(), String> {
    let status = Command::new(env!("CARGO"))
        .current_dir(workspace())
        .args(arguments)
        .status()
        .map_err(|error| format!("cannot run cargo: {error}"))?;

    if status.success() {
        Ok(())
    } else {
        Err(format!("cargo {} failed", arguments.join(" ")))
    }
}

fn lint() -> Result<(), String> {
    cargo(&["fmt", "--all", "--check"])?;
    cargo(&["clippy", "--workspace", "--all-targets", "--all-features", "--", "-D", "warnings"])
}

fn test() -> Result<(), String> {
    cargo(&["test", "--release", "--workspace"])
}
