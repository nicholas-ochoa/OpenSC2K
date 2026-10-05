# Mods

A mod is a folder of JavaScript files with an `info.json` file. OpenSC2K loads
each enabled mod when the game starts. Each mod runs in its own script runtime,
and can use files only in its own folder. For the script API, see
[Scripting](scripting.md). For example mods, see `examples/mods`.

- [Install a mod](#install-a-mod)
- [Turn mods on and off](#turn-mods-on-and-off)
- [The mod folder](#the-mod-folder)
- [info.json](#infojson)
- [The mod object](#the-mod-object)
- [The sandbox](#the-sandbox)
- [Talk to other mods](#talk-to-other-mods)
- [TypeScript types](#typescript-types)
- [Develop a mod](#develop-a-mod)

## Install a mod

Copy the mod folder into the `mods` folder of the OpenSC2K data folder:

| System | Mods folder |
| --- | --- |
| Windows | `%APPDATA%\Godot\app_userdata\OpenSC2K\mods` |
| macOS | `~/Library/Application Support/Godot/app_userdata/OpenSC2K/mods` |
| Linux | `~/.local/share/godot/app_userdata/OpenSC2K/mods` |
| Portable (Windows and Linux) | `data/mods` beside the game |

**Settings > Mods > Open Mods Folder** opens the folder, and makes it when it is
missing. Then select **Reload Mods**, or start the game again.

```text
mods/
  city-stats/
    info.json
    main.mjs
    format.mjs
  monthly-report/
    info.json
    main.js
```

## Turn mods on and off

The **Mods** tab of **Settings** shows each mod in the mods folder: its name,
version, author and status. Select a mod to see its description, email,
website, license and dependencies. The check box turns a mod on or off at once.
A disabled mod stays in its folder, and the settings file keeps the choice. A
new mod is enabled.

The status of a mod is one of:

| Status | Meaning |
| --- | --- |
| Running | The mod runs. |
| Disabled | The player turned the mod off. |
| An error | `info.json` has a problem, or the main script stopped with an error. The mod does not run. Fix the mod, then select **Reload Mods**, or turn the mod off and on. |
| Waits for the mod ... | A dependency of the mod does not run. |

When a mod stops, the mods that need it stop too. When it runs again, they
start again.

The Console has the same controls:

| Command | Effect |
| --- | --- |
| `mods` | Lists the mods and their status. |
| `mods enable <id>`, `mods disable <id>` | Turns a mod on or off, as the check box does. |
| `mods reload` | Stops all mods, finds the mods in the folder again, and starts the enabled ones. |
| `reset` | Also stops the console scripts. |

## The mod folder

The game reads `info.json`, then runs the main script. The main script can
import the other files of the folder. A `.mjs` file, or a file with `import` or
`export`, runs as an ES module:

```js
import { money } from './format.mjs';
```

A file or folder whose name starts with `.` is not a mod. Each mod can write
files in its folder; `game.storage` of a mod is `storage.json` in its folder.
Do not ship your own `storage.json`.

## info.json

```json
{
  "id": "monthly-report",
  "name": "Monthly Report",
  "version": "1.0.0",
  "description": "Writes each month of City Statistics to a CSV file.",
  "main": "main.js",
  "author": "A. Mayor",
  "email": "mayor@example.com",
  "website": "https://example.com/monthly-report",
  "license": "MIT",
  "gameVersion": "0.1.3",
  "dependencies": ["city-stats"]
}
```

| Field | Required | Use |
| --- | --- | --- |
| `name` | Yes | The name in the Mods tab. |
| `version` | Yes | The version of the mod, such as `"1.0.0"`. |
| `main` | Yes | The first script: a `.js` or `.mjs` file in the mod folder, such as `"main.js"` or `"src/main.mjs"`. |
| `id` | No | The id of the mod: lowercase letters, digits, `.`, `_` and `-`. The default is the folder name in lowercase. `console` and `game` are reserved. Events from the mod carry this id, and the settings file keeps the disabled ids. |
| `description` | No | What the mod does. |
| `author` | No | The name of the author. It can also be an object: `{ "name", "email", "website" }`. |
| `email` | No | The email address for questions about the mod. |
| `website` | No | The page of the mod. |
| `license` | No | The license of the mod, such as `"MIT"`. |
| `gameVersion` | No | The oldest OpenSC2K version that the mod works with. An older game does not run the mod. |
| `dependencies` | No | The ids of the mods that must run first. The mod waits until they run. |

The game ignores other fields. Mods load in id order, and each dependency loads
before the mods that need it. Two folders with the same id, and dependencies in
a cycle, are errors.

## The mod object

Only the runtime of a mod has the `mod` global:

| Member | Use |
| --- | --- |
| `mod.id`, `mod.name`, `mod.version` | From `info.json`. |
| `mod.info` | All fields of `info.json`, as the table above names them. |
| `mod.files.readText(path)` | The text of a file, as UTF-8. |
| `mod.files.readJSON(path)` | The JSON value of a file. |
| `mod.files.readBytes(path)` | The bytes of a file, as a `Uint8Array`. |
| `mod.files.writeText(path, text)`, `appendText(path, text)` | Writes text to a file, or adds it at the end. Makes the missing folders. |
| `mod.files.writeJSON(path, value, space = 2)` | Writes a value as JSON. |
| `mod.files.writeBytes(path, data)` | Writes a `Uint8Array`, an `ArrayBuffer`, another typed array or an array of bytes. |
| `mod.files.exists(path)` | True when the file or folder exists. |
| `mod.files.stat(path)` | `{ name, type, size, modified }`, or `null`. `type` is `"file"`, `"directory"` or `"other"`. `modified` is in milliseconds since 1970. |
| `mod.files.list(path = '.')` | The entries of a folder, by name: `[{ name, type, size, modified }]`. |
| `mod.files.makeFolder(path)` | Makes a folder and the missing folders above it. |
| `mod.files.remove(path, { recursive })` | Removes a file or a folder. A folder with files needs `recursive: true`. Returns false when nothing was there. |
| `mod.files.rename(from, to)` | Moves or renames a file or a folder. |

Each path is relative to the mod folder. `/` and `\` separate names. A failed
call throws an Error.

```js
const settings = mod.files.exists('settings.json') ? mod.files.readJSON('settings.json') : { rate: 5 };
mod.files.writeJSON('settings.json', settings);
mod.files.appendText('logs/2050.txt', `${city.date.year}: ${city.population}\n`);

for (const entry of mod.files.list('logs')) {
  console.log(entry.name, entry.size);
}
```

## The sandbox

Mods share the game, but not each other's state:

- **Own runtime.** Each mod has its own QuickJS runtime, globals, timers,
  memory limit (256 MiB) and time limit (5 seconds for each call from the game).
  A mod cannot read or change a variable of another mod or of the console.
- **Own folder.** `mod.files` and `import` work only in the mod folder. The
  native runtime checks each path: an absolute path, a path that leaves the
  folder with `..`, and a link to a place outside the folder are refused. A
  name cannot have `< > : " | ? *` or a control character, cannot end with a
  dot or a space, and cannot be a Windows device name such as `CON`. A mod can
  change and remove any file in its folder, but not the folder itself.
- **No other access.** QuickJS-ng has no file, network or process functions.
  The game API acts on the game only: `city.save()` saves the open city to its
  own file, as the File menu does.
- **Own storage.** `game.storage` of a mod is `storage.json` in its folder.
  The console scripts keep `scripts/storage.json` in the user data folder.

The game API can change the city and use cheats, as the Debug window can. Run
only the mods that you trust with your cities.

## Talk to other mods

Mods talk through events. `game.emit(type, detail)` sends an event to the
listeners of the console and of each mod, in load order. Each runtime receives
its own copy of `detail`: JSON data only, without functions. The game adds
`event.source`, the id of the sender, or `console`.

```js
// in city-stats
game.emit('city-stats.recorded', { date: '2050-03', population: 12000 });

// in monthly-report, which lists city-stats in "dependencies"
game.on('city-stats.recorded', (event) => {
  console.log(`${event.source} recorded ${event.date}: ${event.population}`);
});
```

- Start each event type with the id of your mod.
- A mod cannot send a game event, such as `sim.day`, or `*`. The console can,
  to test mods.
- A listener can send an event in turn. Events nest 16 deep at most.
- For a cancelable game event, such as `tool.beforeApply`, a later runtime sees
  `event.cancelled` from an earlier one.
- `mod.loaded` (`{ id, name, version }`) and `mod.unloaded` (`{ id }`) tell
  when a mod starts and stops. A mod also receives its own `mod.loaded`.
- `game.mods` lists the info of each mod that runs.

## TypeScript types

`game/assets/scripting/opensc2k.d.ts` declares the whole script API for
TypeScript and for the JavaScript checks of editors such as VS Code. Copy it
into the mod folder and add a `jsconfig.json`:

```json
{
  "compilerOptions": { "checkJs": true, "target": "ES2023", "module": "ES2022", "lib": ["ES2023"] },
  "include": ["*.js", "*.mjs", "opensc2k.d.ts"]
}
```

The editor then completes `game`, `city`, `mod` and the other globals, and
shows the fields of each event. A mod written in TypeScript must be compiled to
JavaScript; the game runs only `.js` and `.mjs` files.

## Develop a mod

1. Make a folder in the mods folder, with `info.json` and the main script.
2. Select **Reload Mods** in Settings, or type `mods reload` in the Console,
   after each change.
3. Errors of the main script show in the Console and in the Mods tab. Console
   output of a mod starts with its id, such as `[city-stats]`.
4. Connect Chrome DevTools to the mod: type `inspect <mod id>` in the Console.
   It prints the address of the DevTools page. A reload of the mods keeps the
   port. `inspect <mod id> off` stops the inspector.
5. Run the validation tests of the game for a mod that ships with OpenSC2K; see
   `game/tests/mods_workflow_test.gd`.
