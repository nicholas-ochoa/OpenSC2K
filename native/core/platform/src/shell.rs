//! Open a folder, a file, or a web address with the program of the system.

use std::process::Command;

/// Open `target` with the default program, as Godot's `OS.shell_open`.
pub fn open(target: &str) -> Result<(), String> {
    let mut command = if cfg!(target_os = "macos") {
        let mut command = Command::new("open");
        command.arg(target);
        command
    } else if cfg!(target_os = "windows") {
        let mut command = Command::new("cmd");
        command.args(["/C", "start", "", target]);
        command
    } else {
        let mut command = Command::new("xdg-open");
        command.arg(target);
        command
    };

    command
        .spawn()
        .map(|_| ())
        .map_err(|error| format!("Cannot open {target}: {error}"))
}
