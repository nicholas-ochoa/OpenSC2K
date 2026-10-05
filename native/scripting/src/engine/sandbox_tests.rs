use std::fs;
use std::path::PathBuf;

use super::tests::engine_with_host;
use crate::value::JsData;

/// A temporary folder with a "mod" folder for the sandbox and a file
/// outside it.
struct ModFolder {
    parent: PathBuf,
}

impl ModFolder {
    fn new(name: &str) -> ModFolder {
        let parent = std::env::temp_dir().join(format!("opensc2k_sandbox_{name}_{}", std::process::id()));
        let _ = fs::remove_dir_all(&parent);
        fs::create_dir_all(parent.join("mod/lib")).unwrap();
        fs::write(parent.join("outside.mjs"), "globalThis.escaped = true; export const secret = 1;").unwrap();
        fs::write(parent.join("secret.txt"), "outside").unwrap();

        ModFolder { parent }
    }

    fn root(&self) -> PathBuf {
        self.parent.join("mod")
    }

    fn write(&self, relative: &str, text: &str) {
        fs::write(self.root().join(relative), text).unwrap();
    }
}

impl Drop for ModFolder {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.parent);
    }
}

#[test]
fn files_exist_only_in_the_runtime_of_a_mod() {
    let folder = ModFolder::new("no_files");
    let (engine, _) = engine_with_host();

    assert_eq!(engine.eval_console("typeof __files"), Ok(Some("\"undefined\"".to_string())));
    assert!(engine.run_sandbox_file("main.js").is_err(), "the console runtime has no mod folder");

    engine.set_sandbox(&folder.root()).unwrap();
    assert_eq!(engine.eval_console("typeof __files.readText"), Ok(Some("\"function\"".to_string())));
    assert!(engine.set_sandbox(&folder.parent).is_err(), "the folder cannot change");
}

#[test]
fn a_mod_reads_and_writes_its_own_files() {
    let folder = ModFolder::new("files");
    let (engine, _) = engine_with_host();
    engine.set_sandbox(&folder.root()).unwrap();

    let script = "
        __files.write('data/state.json', JSON.stringify({ year: 2050 }), false);
        __files.write('data/log.txt', 'a', false);
        __files.write('data/log.txt', 'b', true);
        __files.write('data/bytes.bin', new Uint8Array([1, 2, 255]).subarray(1), false);
        const bytes = __files.readBytes('data/bytes.bin');
        __files.rename('data/log.txt', 'logs/log.txt');
        __files.makeFolder('empty/inner');
        [
            JSON.parse(__files.readText('data/state.json')).year,
            __files.readText('logs/log.txt'),
            bytes instanceof Uint8Array, Array.from(bytes).join(),
            __files.list('data').map((entry) => `${entry.name}:${entry.type}:${entry.size}`).join(),
            __files.stat('logs').type, __files.stat('none'), __files.exists('logs/log.txt'),
            __files.remove('empty', true), __files.exists('empty'),
        ].join('|')";

    assert_eq!(
        engine.eval_console(script),
        Ok(Some(
            "\"2050|ab|true|2,255|bytes.bin:file:2,state.json:file:13|directory||true|true|false\"".to_string()
        ))
    );
    assert_eq!(fs::read_to_string(folder.root().join("logs/log.txt")).unwrap(), "ab");
}

#[test]
fn a_mod_cannot_use_files_outside_its_folder() {
    let folder = ModFolder::new("outside_files");
    let (engine, _) = engine_with_host();
    engine.set_sandbox(&folder.root()).unwrap();
    let secret = folder.parent.join("secret.txt").to_string_lossy().replace('\\', "/");

    for call in [
        "__files.readText('../secret.txt')".to_string(),
        format!("__files.readText('{secret}')"),
        "__files.write('../written.txt', 'x', false)".to_string(),
        "__files.write('lib/../../written.txt', 'x', false)".to_string(),
        "__files.list('..')".to_string(),
        "__files.remove('..', true)".to_string(),
        "__files.remove('.', true)".to_string(),
        "__files.rename('../secret.txt', 'stolen.txt')".to_string(),
        "__files.exists('../secret.txt')".to_string(),
        "__files.write('bad.bin', [1, 2], false)".to_string(),
    ] {
        let result = engine.eval_console(&call);
        assert!(
            result.as_ref().is_err_and(|error| error.starts_with("Error: ")),
            "{call}: {result:?}"
        );
    }

    assert!(!folder.parent.join("written.txt").exists());
    assert!(!folder.root().join("stolen.txt").exists());
    assert_eq!(fs::read_to_string(folder.parent.join("secret.txt")).unwrap(), "outside");
    assert!(folder.root().exists());
}

#[test]
fn a_mod_imports_only_modules_in_its_folder() {
    let folder = ModFolder::new("modules");
    folder.write("lib/helper.mjs", "export const double = (value) => value * 2;");
    folder.write(
        "main.mjs",
        "import { double } from './lib/helper.mjs';\n__runtime.host('add', double(4), 1);",
    );
    let (engine, calls) = engine_with_host();
    engine.set_sandbox(&folder.root()).unwrap();

    engine.run_sandbox_file("main.mjs").unwrap();
    assert!(
        calls
            .borrow()
            .iter()
            .any(|(name, arguments)| name == "add" && arguments == &vec![JsData::Int(8), JsData::Int(1)])
    );

    let outside = folder.parent.join("outside.mjs").to_string_lossy().replace('\\', "/");

    for (file, import) in [
        ("up.mjs", "import { secret } from '../outside.mjs';".to_string()),
        ("deep.mjs", "import { secret } from './lib/../../outside.mjs';".to_string()),
        ("absolute.mjs", format!("import {{ secret }} from '{outside}';")),
        ("bare.mjs", "import { secret } from 'outside.mjs';".to_string()),
    ] {
        folder.write(file, &import);
        let error = engine.run_sandbox_file(file).unwrap_err();
        assert!(error.contains("A mod imports only"), "{file}: {error}");
    }

    folder.write(
        "dynamic.mjs",
        "globalThis.failure = await import('../outside.mjs').then(() => 'loaded', (error) => error.message);",
    );
    engine.run_sandbox_file("dynamic.mjs").unwrap();
    let failure = engine.eval_console("failure").unwrap().unwrap();
    assert!(failure.contains("A mod imports only"), "{failure}");
    assert_eq!(engine.eval_console("globalThis.escaped"), Ok(None), "no outside module ran");
    assert!(
        engine.run_sandbox_file("../outside.mjs").is_err(),
        "the main file must be in the folder"
    );
}

#[test]
fn emit_sends_events_through_the_host() {
    let (engine, calls) = engine_with_host();

    engine
        .eval_console("__runtime.events.emit('my-mod.ready', { version: 2 })")
        .unwrap();
    let emitted: Vec<Vec<JsData>> = calls
        .borrow()
        .iter()
        .filter(|(name, _)| name == "emit")
        .map(|(_, arguments)| arguments.clone())
        .collect();
    assert_eq!(
        emitted,
        vec![vec![
            JsData::String("my-mod.ready".to_string()),
            JsData::object(vec![("version", JsData::Int(2))]),
        ]]
    );

    // a listener of an earlier runtime cancelled the event
    let detail = JsData::object(vec![("cancelled", JsData::Bool(true))]);
    let event = engine
        .call(
            "__runtime.dispatch",
            &[JsData::String("tool.beforeApply".to_string()), detail.clone(), JsData::Bool(true)],
        )
        .unwrap();
    assert_eq!(event.get("cancelled"), Some(&JsData::Bool(true)));

    let event = engine
        .call(
            "__runtime.dispatch",
            &[JsData::String("sim.day".to_string()), detail, JsData::Bool(false)],
        )
        .unwrap();
    assert_eq!(
        event.get("cancelled"),
        Some(&JsData::Bool(false)),
        "only a cancelable event stays cancelled"
    );
}
